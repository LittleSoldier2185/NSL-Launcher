// ทดสอบระบบอัปเดตตัวเอง (updater.dart) — เดิมยังไม่เคยคอมไพล์/รัน ตอนนี้ทดสอบกับ HTTP เซิร์ฟเวอร์ในเครื่องและไฟล์จริงในโฟลเดอร์ชั่วคราว
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsl_launcher/update/updater.dart';

List<int> _zip(Map<String, String> files) {
  final a = Archive();
  for (final e in files.entries) {
    a.add(ArchiveFile.string(e.key, e.value));
  }
  return ZipEncoder().encode(a);
}

void main() {
  group('Version', () {
    test('อ่าน X.Y.Z และเทียบเป็นตัวเลข (1.10.0 > 1.9.0)', () {
      expect(Version.parse('1.10.0') > Version.parse('1.9.0'), isTrue);
      expect(Version.parse('2.0.0') > Version.parse('1.99.99'), isTrue);
      expect(Version.parse('1.0.0') > Version.parse('1.0.0'), isFalse);
      expect(Version.parse(' 1.2.3 ').toString(), '1.2.3');
    });

    test('รูปแบบผิดถูกปฏิเสธ ไม่โยนจาก tryParse', () {
      for (final bad in ['', '1', '1.2', '1.2.3.4', 'v1.2.3', '1.2.x', '1.2.3-beta', '-1.0.0']) {
        expect(Version.tryParse(bad), isNull, reason: bad);
        expect(() => Version.parse(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('UpdateInfo.fromJson', () {
    test('อ่านครบ + sha256 เป็นตัวพิมพ์เล็ก', () {
      final i = UpdateInfo.fromJson({'version': '1.1.0', 'url': 'https://x/y.zip', 'sha256': 'ABCDEF', 'size': 12, 'notes': 'n'});
      expect(i.version.toString(), '1.1.0');
      expect(i.sha256, 'abcdef');
      expect(i.size, 12);
    });
  });

  group('Updater กับโฟลเดอร์และเซิร์ฟเวอร์จริง', () {
    late Directory tmp, root, app;
    late HttpServer server;
    late Map<String, List<int>> routes;
    final sep = Platform.pathSeparator;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('nsl_updater');
      root = Directory('${tmp.path}${sep}NSL Launcher')..createSync();
      File('${root.path}${sep}NSL Launcher.exe').writeAsStringSync('stub');
      app = Directory('${root.path}${sep}app-1.0.0')..createSync();
      routes = {};
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final body = routes[req.uri.path];
        if (body == null) {
          req.response.statusCode = 404;
        } else {
          req.response.add(body);
        }
        await req.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    });

    Uri url(String p) => Uri.parse('http://127.0.0.1:${server.port}$p');

    Updater updater() => Updater(manifestUrl: url('/latest.json'), appDir: app, productId: 'launcher');

    List<int> manifest(String version, List<int> zip, {String? sha}) => utf8.encode(jsonEncode({
          'schema': 1,
          'products': {
            'launcher': {
              'version': version,
              'url': url('/app-$version.zip').toString(),
              'sha256': sha ?? sha256.convert(zip).toString(),
              'size': zip.length,
              'notes': 'ทดสอบ',
            },
          },
        }));

    test('เปิดใช้เฉพาะเมื่ออยู่ในโฟลเดอร์ app-X.Y.Z ที่มี stub ; flutter run (โฟลเดอร์อื่น) ปิดอัตโนมัติ', () {
      expect(updater().isEnabled, Platform.isWindows);
      expect(updater().currentVersion.toString(), '1.0.0');
      final dev = Updater(manifestUrl: url('/x'), appDir: Directory('${tmp.path}${sep}build'), productId: 'launcher');
      expect(dev.isEnabled, isFalse);
      expect(dev.currentVersion, isNull);
      // ไม่มี stub = ปิด
      File('${root.path}${sep}NSL Launcher.exe').deleteSync();
      expect(updater().isEnabled, isFalse);
    });

    test('markHealthy เขียน .ok และลบ .trying ; นอก app-X.Y.Z ไม่ทำอะไร', () {
      File('${app.path}$sep.trying').writeAsStringSync('1');
      updater().markHealthy();
      expect(File('${app.path}$sep.ok').existsSync(), isTrue);
      expect(File('${app.path}$sep.trying').existsSync(), isFalse);
      final dev = Directory('${tmp.path}${sep}build')..createSync();
      Updater(manifestUrl: url('/x'), appDir: dev, productId: 'launcher').markHealthy();
      expect(File('${dev.path}$sep.ok').existsSync(), isFalse);
    });

    test('check: เวอร์ชันใหม่กว่า → ได้ข้อมูล ; เท่ากัน/เก่ากว่า/ไม่มีสินค้า → null', () async {
      final z = _zip({'nsl_launcher.exe': 'x'});
      routes['/latest.json'] = manifest('1.1.0', z);
      final info = await updater().check();
      expect(info!.version.toString(), '1.1.0');
      expect(info.notes, 'ทดสอบ');
      routes['/latest.json'] = manifest('1.0.0', z);
      expect(await updater().check(), isNull);
      routes['/latest.json'] = manifest('0.9.0', z);
      expect(await updater().check(), isNull);
      routes['/latest.json'] = utf8.encode('{"schema":1,"products":{}}');
      expect(await updater().check(), isNull);
    });

    test('check: ตัด BOM ได้ ; เวอร์ชันที่เคยเปิดไม่ขึ้น (.failed) ไม่เสนอซ้ำ ; HTTP ผิดโยน UpdateException', () async {
      final z = _zip({'nsl_launcher.exe': 'x'});
      routes['/latest.json'] = [0xEF, 0xBB, 0xBF, ...manifest('1.2.0', z)];
      expect((await updater().check())!.version.toString(), '1.2.0');
      Directory('${root.path}${sep}app-1.2.0').createSync();
      File('${root.path}${sep}app-1.2.0$sep.failed').writeAsStringSync('x');
      expect(await updater().check(), isNull);
      routes.remove('/latest.json');
      expect(updater().check(), throwsA(isA<UpdateException>()));
    });

    test('download: ตรวจ SHA-256 แตกไฟล์ลง app-X.Y.Z รายงานความคืบหน้า ลบ zip ทิ้ง', () async {
      final z = _zip({'nsl_launcher.exe': 'exe', 'data/a.txt': 'hello'});
      routes['/latest.json'] = manifest('1.1.0', z);
      routes['/app-1.1.0.zip'] = z;
      final u = updater();
      final info = (await u.check())!;
      expect(u.isStaged(info), isFalse);
      final progress = <double>[];
      await u.download(info, onProgress: progress.add);
      final dir = Directory('${root.path}${sep}app-1.1.0');
      expect(File('${dir.path}${sep}nsl_launcher.exe').readAsStringSync(), 'exe');
      expect(File('${dir.path}${sep}data${sep}a.txt').readAsStringSync(), 'hello');
      expect(u.isStaged(info), isTrue);
      expect(progress.isNotEmpty && progress.last == 1.0, isTrue);
      expect(Directory('${root.path}${sep}app-1.1.0.partial').existsSync(), isFalse);
      expect(File('${root.path}$sep.staging${sep}app-1.1.0.zip').existsSync(), isFalse);
      await u.download(info); // ซ้ำ = ไม่ทำอะไร ไม่โยน
    });

    test('download: SHA-256 ไม่ตรง → ปฏิเสธ ลบ zip ไม่สร้างโฟลเดอร์เวอร์ชัน', () async {
      final z = _zip({'nsl_launcher.exe': 'exe'});
      routes['/latest.json'] = manifest('1.1.0', z, sha: 'a' * 64);
      routes['/app-1.1.0.zip'] = z;
      final u = updater();
      final info = (await u.check())!;
      await expectLater(u.download(info), throwsA(isA<UpdateException>()));
      expect(Directory('${root.path}${sep}app-1.1.0').existsSync(), isFalse);
      expect(Directory('${root.path}${sep}app-1.1.0.partial').existsSync(), isFalse);
      expect(File('${root.path}$sep.staging${sep}app-1.1.0.zip').existsSync(), isFalse);
    });

    test('download: zip ที่ห่อโฟลเดอร์ไว้อีกชั้น (Release/…) ถูกแกะออกให้ ; zip ที่ไม่มี nsl_launcher.exe ถูกปฏิเสธ', () async {
      final wrapped = _zip({'Release/nsl_launcher.exe': 'exe', 'Release/data/b.txt': 'b'});
      routes['/latest.json'] = manifest('1.1.0', wrapped);
      routes['/app-1.1.0.zip'] = wrapped;
      final u = updater();
      await u.download((await u.check())!);
      expect(File('${root.path}${sep}app-1.1.0${sep}nsl_launcher.exe').existsSync(), isTrue);
      expect(File('${root.path}${sep}app-1.1.0${sep}data${sep}b.txt').existsSync(), isTrue);

      final bad = _zip({'readme.txt': 'no exe'});
      routes['/latest.json'] = manifest('1.2.0', bad);
      routes['/app-1.2.0.zip'] = bad;
      await expectLater(u.download((await u.check())!), throwsA(isA<UpdateException>()));
      expect(Directory('${root.path}${sep}app-1.2.0').existsSync(), isFalse);
    });

    test('download: HTTP 404 → UpdateException', () async {
      final z = _zip({'nsl_launcher.exe': 'x'});
      routes['/latest.json'] = manifest('1.1.0', z); // ไม่ได้ใส่เส้นทาง zip
      final u = updater();
      await expectLater(u.download((await u.check())!), throwsA(isA<UpdateException>()));
    });

    // ความปลอดภัย: zip ที่พยายามเขียนออกนอกโฟลเดอร์ปลายทาง (zip-slip) ต้องไม่ทำให้ไฟล์หลุดออกไปนอก <root>
    test('download: zip-slip (ชื่อไฟล์มี ../) ไม่เขียนไฟล์นอกโฟลเดอร์ปลายทาง', () async {
      final evil = _zip({'nsl_launcher.exe': 'exe', '../../escaped.txt': 'pwned'});
      routes['/latest.json'] = manifest('1.1.0', evil);
      routes['/app-1.1.0.zip'] = evil;
      final u = updater();
      try {
        await u.download((await u.check())!);
      } catch (_) {
        // จะปฏิเสธหรือแตกอย่างปลอดภัยก็ได้ — ที่ห้ามคือไฟล์หลุดออกนอกโฟลเดอร์
      }
      expect(File('${tmp.path}${sep}escaped.txt').existsSync(), isFalse, reason: 'ไฟล์หลุดออกนอก <root>');
      expect(File('${tmp.path}${sep}NSL Launcher${sep}escaped.txt').existsSync(), isFalse);
      expect(File('${root.path}${sep}escaped.txt').existsSync(), isFalse);
    });
  });
}
