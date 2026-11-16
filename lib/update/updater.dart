// ระบบอัปเดตตัวเองของ NSL Launcher (วิธีแยกโฟลเดอร์ตามเวอร์ชัน)
//
// โครงสร้างบนเครื่องผู้ใช้:
//   <root>/
//     NSL Launcher.exe        stub ไม่ต้องอัปเดต (stub/stub.c)
//     app-1.0.0/              เวอร์ชันที่ใช้อยู่ (exe ตัวนี้)
//     app-1.1.0/              เวอร์ชันใหม่ที่ดาวน์โหลดมา
//     .staging/               ไฟล์ zip ระหว่างดาวน์โหลด
//
// ลำดับการใช้งาน:
//   final updater = Updater.forCurrentProcess(manifestUrl: kManifestUrl);
//   updater.markHealthy();                       // เรียกหลังเฟรมแรกขึ้นจอ
//   final info = await updater.check();          // null = ไม่มีอัปเดต
//   await updater.download(info!, onProgress: (p) => ...);
//   await updater.restart();                     // ปุ่ม "รีสตาร์ทเพื่ออัปเดต"
//
// dependencies ใน pubspec.yaml:
//   archive: ^4.0.0
//   crypto: ^3.0.0

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

/// ข้อมูลเวอร์ชันใหม่จาก manifest
class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.url,
    required this.sha256,
    required this.size,
    this.notes = '',
  });

  final Version version;
  final Uri url;
  final String sha256;
  final int size;
  final String notes;

  factory UpdateInfo.fromJson(Map<String, dynamic> j) => UpdateInfo(
        version: Version.parse(j['version'] as String),
        url: Uri.parse(j['url'] as String),
        sha256: (j['sha256'] as String).toLowerCase(),
        size: (j['size'] as num?)?.toInt() ?? 0,
        notes: j['notes'] as String? ?? '',
      );
}

/// เลขเวอร์ชันแบบ X.Y.Z
class Version implements Comparable<Version> {
  Version(this.major, this.minor, this.patch);
  final int major, minor, patch;

  static final _re = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');

  static Version parse(String s) {
    final m = _re.firstMatch(s.trim());
    if (m == null) throw FormatException('เวอร์ชันไม่ถูกต้อง: $s');
    return Version(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  static Version? tryParse(String s) {
    try {
      return parse(s);
    } on FormatException {
      return null;
    }
  }

  @override
  int compareTo(Version o) {
    if (major != o.major) return major.compareTo(o.major);
    if (minor != o.minor) return minor.compareTo(o.minor);
    return patch.compareTo(o.patch);
  }

  bool operator >(Version o) => compareTo(o) > 0;

  @override
  String toString() => '$major.$minor.$patch';
}

class UpdateException implements Exception {
  UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Updater {
  Updater({
    required this.manifestUrl,
    required this.appDir,
    required this.productId,
  });

  /// สร้างจาก exe ที่กำลังรันอยู่: `<root>/app-X.Y.Z/nsl_launcher.exe`
  factory Updater.forCurrentProcess({
    required Uri manifestUrl,
    String productId = 'launcher',
  }) {
    final exe = File(Platform.resolvedExecutable);
    return Updater(
      manifestUrl: manifestUrl,
      appDir: exe.parent,
      productId: productId,
    );
  }

  final Uri manifestUrl;
  final Directory appDir;
  final String productId;

  Directory get root => appDir.parent;

  /// เวอร์ชันปัจจุบันอ่านจากชื่อโฟลเดอร์ app-X.Y.Z
  /// เป็น null ตอนรันจาก flutter run หรือโฟลเดอร์ build (จะปิดระบบอัปเดต)
  Version? get currentVersion {
    final name = appDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (!name.startsWith('app-')) return null;
    return Version.tryParse(name.substring(4));
  }

  bool get isEnabled =>
      Platform.isWindows &&
      currentVersion != null &&
      File('${root.path}${Platform.pathSeparator}NSL Launcher.exe').existsSync();

  /// เรียกหลังแอปเปิดขึ้นมาได้ เพื่อบอก stub ว่าเวอร์ชันนี้ใช้งานได้
  void markHealthy() {
    if (currentVersion == null) return;
    final sep = Platform.pathSeparator;
    try {
      File('${appDir.path}$sep.ok').writeAsStringSync(DateTime.now().toIso8601String());
      final trying = File('${appDir.path}$sep.trying');
      if (trying.existsSync()) trying.deleteSync();
    } on FileSystemException {
      // ไม่มีสิทธิ์เขียนก็ข้ามไป stub จะลองใหม่ครั้งหน้า
    }
  }

  /// อ่าน manifest แล้วคืนข้อมูลถ้ามีเวอร์ชันใหม่กว่า
  Future<UpdateInfo?> check() async {
    final current = currentVersion;
    if (current == null) return null;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(manifestUrl);
      final res = await req.close();
      if (res.statusCode != 200) {
        throw UpdateException('ตรวจสอบอัปเดตไม่สำเร็จ (HTTP ${res.statusCode})');
      }
      var body = await res.transform(utf8.decoder).join();
      if (body.startsWith('\uFEFF')) body = body.substring(1); // ตัด BOM
      final json = jsonDecode(body) as Map<String, dynamic>;
      final entry = (json['products'] as Map<String, dynamic>?)?[productId];
      if (entry == null) return null;
      final info = UpdateInfo.fromJson(entry as Map<String, dynamic>);
      if (!(info.version > current)) return null;
      // เวอร์ชันนี้เคยลองแล้วเปิดไม่ขึ้น (stub ทำเครื่องหมายไว้) ไม่ต้องเสนอซ้ำ
      if (File('${_versionDir(info.version).path}${Platform.pathSeparator}.failed').existsSync()) {
        return null;
      }
      return info;
    } finally {
      client.close();
    }
  }

  /// เวอร์ชันใหม่ดาวน์โหลดและแตกไฟล์ไว้แล้ว รอแค่รีสตาร์ท
  bool isStaged(UpdateInfo info) => _versionDir(info.version).existsSync();

  /// ดาวน์โหลด ตรวจ SHA-256 แล้วแตกไฟล์ไปที่ app-X.Y.Z
  /// แตกลงโฟลเดอร์ .partial ก่อนแล้วค่อยเปลี่ยนชื่อ stub จึงไม่มีทางเห็นโฟลเดอร์ที่แตกไม่ครบ
  Future<void> download(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    if (isStaged(info)) return;
    final sep = Platform.pathSeparator;
    final staging = Directory('${root.path}$sep.staging')..createSync(recursive: true);
    final zip = File('${staging.path}${sep}app-${info.version}.zip');
    final partial = Directory('${root.path}${sep}app-${info.version}.partial');

    // 1. ดาวน์โหลด
    final client = HttpClient();
    try {
      final res = await (await client.getUrl(info.url)).close();
      if (res.statusCode != 200) {
        throw UpdateException('ดาวน์โหลดไม่สำเร็จ (HTTP ${res.statusCode})');
      }
      final total = info.size > 0 ? info.size : res.contentLength;
      var received = 0;
      final sink = zip.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call((received / total).clamp(0, 1).toDouble());
      }
      await sink.close();
    } finally {
      client.close();
    }

    // 2. ตรวจ hash
    final digest = await sha256.bind(zip.openRead()).first;
    if (digest.toString() != info.sha256) {
      zip.deleteSync();
      throw UpdateException('ไฟล์อัปเดตเสียหาย (SHA-256 ไม่ตรง) กรุณาลองใหม่');
    }

    // 3. แตกไฟล์ลง .partial แล้วเปลี่ยนชื่อเป็น app-X.Y.Z
    if (partial.existsSync()) partial.deleteSync(recursive: true);
    await extractFileToDisk(zip.path, partial.path);
    _checkExtracted(partial);
    partial.renameSync(_versionDir(info.version).path);
    zip.deleteSync();
  }

  /// เปิด stub ใหม่แล้วปิดตัวเอง stub จะเลือกเวอร์ชันสูงสุดให้
  Future<Never> restart() async {
    final stub = '${root.path}${Platform.pathSeparator}NSL Launcher.exe';
    await Process.start(stub, const [], mode: ProcessStartMode.detached, workingDirectory: root.path);
    exit(0);
  }

  Directory _versionDir(Version v) =>
      Directory('${root.path}${Platform.pathSeparator}app-$v');

  /// กัน zip ที่ห่อไว้อีกชั้น (เช่น Release/nsl_launcher.exe)
  void _checkExtracted(Directory dir) {
    final sep = Platform.pathSeparator;
    if (File('${dir.path}${sep}nsl_launcher.exe').existsSync()) return;
    final inner = dir.listSync().whereType<Directory>().toList();
    if (inner.length == 1 && File('${inner.first.path}${sep}nsl_launcher.exe').existsSync()) {
      for (final e in inner.first.listSync()) {
        e.renameSync('${dir.path}$sep${e.uri.pathSegments.where((s) => s.isNotEmpty).last}');
      }
      inner.first.deleteSync();
      return;
    }
    dir.deleteSync(recursive: true);
    throw UpdateException('ไฟล์อัปเดตไม่มี nsl_launcher.exe');
  }
}
