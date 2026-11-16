import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsl_launcher/settings/launcher_settings.dart';
import 'package:nsl_launcher/settings/theme_file_service.dart';
import 'package:nsl_launcher/theme_engine/theme_engine.dart';
import 'package:nsl_launcher/ui/pages/theme_manager.dart';
import 'package:nsl_launcher/ui/shell.dart';
import 'package:nsl_launcher/ui/theme/launcher_theme.dart';

import 'support/ui_harness.dart';

/// ของปลอมแทนหน้าต่างเลือก/บันทึกไฟล์ของระบบ: เรียงคำตอบไว้ล่วงหน้า และจดสิ่งที่ถูกบันทึก
class FakeFiles implements ThemeFileService {
  final picks = <PickedTheme?>[];
  final saved = <(String, String)>[];
  bool saveResult = true;

  @override
  Future<PickedTheme?> pickTheme() async => picks.isEmpty ? null : picks.removeAt(0);

  @override
  Future<bool> saveTheme(String fileName, String text) async {
    saved.add((fileName, text));
    return saveResult;
  }
}

String _nslt(String id, {String accent = '#00AA55', String name = ''}) =>
    '{"schema":1,"id":"$id","name":"${name.isEmpty ? 'Theme $id' : name}","extends":"nsl.launcher","dark":{"colors":{"accent":"$accent"}}}';

NslThemeController _memory([List<String> ids = const []]) {
  final st = NslMemoryThemeStorage();
  for (final id in ids) {
    st.saveTheme(parseNslt(_nslt(id)).spec!);
  }
  return NslThemeController(st);
}

/// รอผลของ I/O จริงที่เริ่มจากการแตะบนหน้าจอ: แต่ละ await ของไฟล์ต้องรอเหตุการณ์จริงแล้ว pump ให้ต่อ — ทำซ้ำจนเงื่อนไขเป็นจริง (สูงสุด ~3 วินาที)
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }  await settle(tester); // ให้ผู้ฟัง (UI) ได้สร้างใหม่หลังเงื่อนไขเป็นจริง
}

/// ลบโฟลเดอร์ชั่วคราวแบบซิงก์ — addTearDown ของ testWidgets รันใน fake-async ที่ I/O แบบ async จะไม่เสร็จ
void _cleanup(Directory d) {
  try {
    d.deleteSync(recursive: true);
  } catch (_) {}
}

Future<NslThemeController> _loaded([List<String> ids = const []]) async {
  final c = _memory(ids);
  await c.reload();
  return c;
}

Future<void> _open(WidgetTester tester, NslThemeController? themes, FakeFiles files, {Size size = const Size(1440, 2400), LauncherSettingsController? settings, bool safeMode = false}) async {
  await pumpLauncher(tester, size: size, themes: themes, files: files, settings: settings, safeMode: safeMode, section: Section.settings);
}

Finder _label(String l) => find.bySemanticsLabel(l);

/// ข้อความที่อยู่ในตัวจัดการธีมเท่านั้น (ชื่อธีมของผู้ใช้ยังปรากฏในรายการเลือกธีมของ Launcher ด้วย)
Finder _inManager(String text) => find.descendant(of: find.byType(ThemeManager), matching: find.text(text));

Future<void> _tapLabel(WidgetTester tester, String label) async {
  final f = _label(label);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

void main() {
  setUpLauncherUi();

  group('รายการธีมและการเลือกให้แอป', () {
    uiTest('แสดงค่าเริ่มต้น + ธีมของผู้ใช้ ; เลือกแล้วตั้งให้แอป แสดงข้อความ และป้าย "ใช้กับแอปอยู่"', (tester) async {
      final c = await _loaded(['green', 'blue']);
      await _open(tester, c, FakeFiles());
      expect(find.text('ค่าเริ่มต้นของแต่ละแอป'), findsOneWidget);
      expect(_inManager('Theme green'), findsOneWidget);
      expect(_inManager('Theme blue'), findsOneWidget);
      expect(find.text('ใช้กับแอปอยู่'), findsOneWidget); // แถวค่าเริ่มต้น (ยังไม่เลือกธีม)

      await _tapLabel(tester, 'ใช้ธีม Theme green กับแอป NSL');
      expect(c.settings.activeThemeId, 'green');
      expect(find.textContaining('ตั้งให้แอป NSL ใช้ธีม "Theme green" แล้ว'), findsOneWidget);
      expect(_label('ธีม Theme green กำลังใช้กับแอป NSL อยู่'), findsOneWidget);

      await _tapLabel(tester, 'ใช้ธีมเริ่มต้นของแต่ละแอป');
      expect(c.settings.activeThemeId, isNull);
      expect(find.textContaining('กลับไปใช้ธีมเริ่มต้น'), findsOneWidget);
    });

    uiTest('ธีมที่ใช้ไม่ได้ (ฐานหาย) / อ่านไม่ออก / contrast ต่ำ ถูกบอกเหตุผล และเลือกให้แอปไม่ได้ (ปุ่มปิด)', (tester) async {
      final st = NslMemoryThemeStorage();
      await st.saveTheme(parseNslt('{"schema":1,"id":"broken","name":"Broken","extends":"user.gone"}').spec!);
      await st.saveTheme(parseNslt('{"schema":1,"id":"invisible","name":"Invisible","dark":{"colors":{"bg":"#101010","surface":"#101010","text":"#111111","accent":"#222222"}},"light":{"colors":{"bg":"#FFFFFF","surface":"#FFFFFF","text":"#FEFEFE","accent":"#EEEEEE"}}}').spec!);
      await st.saveTheme(parseNslt('{"schema":1,"id":"dim","name":"Dim","extends":"nsl.launcher","dark":{"colors":{"textMuted":"#18284F"}}}').spec!);
      final c = NslThemeController(st);
      await c.reload();
      await _open(tester, c, FakeFiles());
      expect(find.textContaining('ใช้ไม่ได้: base theme "user.gone" not found'), findsOneWidget);
      expect(find.textContaining('ตัวอักษรอ่านไม่ออก'), findsOneWidget);
      expect(find.textContaining('ความอ่านออกต่ำกว่าเกณฑ์'), findsOneWidget);
      for (final id in ['Broken', 'Invisible']) {
        final s = tester.getSemantics(_label('ใช้ธีม $id กับแอป NSL'));
        expect(s.flagsCollection.isEnabled, tristateFalse, reason: '$id ต้องเลือกไม่ได้');
      }
      expect(tester.getSemantics(_label('ใช้ธีม Dim กับแอป NSL')).flagsCollection.isEnabled, tristateTrue, reason: 'contrast ต่ำเป็นแค่คำเตือน เลือกได้');
    });

    uiTest('ไม่มีไฟล์ธีมของผู้ใช้ = บอกวิธีเริ่มต้น', (tester) async {
      await _open(tester, await _loaded(), FakeFiles());
      expect(find.textContaining('ยังไม่มีไฟล์ธีมของคุณ'), findsOneWidget);
    });
  });

  group('นำเข้าไฟล์ธีม', () {
    uiTest('นำเข้าสำเร็จ: ธีมปรากฏในรายการ มีข้อความ ไม่เลือกให้แอปเอง', (tester) async {
      final c = await _loaded();
      final f = FakeFiles()..picks.add(PickedTheme(name: 'sea.nslt', text: _nslt('sea', name: 'Sea')));
      await _open(tester, c, f);
      await _tapLabel(tester, 'นำเข้าไฟล์ธีม');
      expect(c.userThemes.map((t) => t.id), ['sea']);
      expect(find.text('นำเข้าธีม "Sea" แล้ว'), findsOneWidget);
      expect(_inManager('Sea'), findsOneWidget);
      expect(c.settings.activeThemeId, isNull);
    });

    uiTest('ยกเลิกการเลือกไฟล์ = ไม่เกิดอะไรขึ้น', (tester) async {
      final c = await _loaded();
      await _open(tester, c, FakeFiles());
      await _tapLabel(tester, 'นำเข้าไฟล์ธีม');
      expect(c.userThemes, isEmpty);
      expect(find.textContaining('นำเข้า'), findsWidgets); // มีแต่ปุ่ม/หัวข้อ ไม่มีข้อความผลลัพธ์
      expect(find.textContaining('นำเข้า "'), findsNothing);
    });

    uiTest('ไฟล์เสีย / id สงวน / schema ใหม่เกิน / ใหญ่เกิน / อ่านไม่ได้ → ข้อความผิดพลาดชัดเจน ไม่สร้างไฟล์ ไม่ล้ม', (tester) async {
      final c = await _loaded();
      final f = FakeFiles()
        ..picks.addAll([
          const PickedTheme(name: 'bad.nslt', text: 'not json'),
          const PickedTheme(name: 'reserved.nslt', text: '{"schema":1,"id":"nsl.nebular","name":"fake"}'),
          const PickedTheme(name: 'future.nslt', text: '{"schema":99,"id":"f","name":"f"}'),
          const PickedTheme(name: 'big.nslt', error: 'ไฟล์ใหญ่เกิน 64 KB — ไฟล์ธีมไม่ควรใหญ่ขนาดนี้'),
          const PickedTheme(name: 'locked.nslt', error: 'อ่านไฟล์ไม่ได้'),
        ]);
      await _open(tester, c, f);
      for (final expected in ['not valid JSON', 'reserved for built-in', 'newer than supported', 'ไฟล์ใหญ่เกิน 64 KB', 'อ่านไฟล์ไม่ได้']) {
        await _tapLabel(tester, 'นำเข้าไฟล์ธีม');
        expect(find.textContaining(expected), findsOneWidget, reason: expected);
      }
      expect(c.userThemes, isEmpty);
      expect(tester.takeException(), isNull);
    });

    uiTest('นำเข้าชื่อซ้ำ: ถามก่อนแทนที่ — ยกเลิกแล้วของเดิมอยู่ครบ ; ยืนยันแล้วถูกแทนที่', (tester) async {
      final c = await _loaded(['dup']);
      final f = FakeFiles()
        ..picks.addAll([PickedTheme(name: 'dup1.nslt', text: _nslt('dup', accent: '#FF0000', name: 'New A')), PickedTheme(name: 'dup2.nslt', text: _nslt('dup', accent: '#0000FF', name: 'New B'))]);
      await _open(tester, c, f);
      await _tapLabel(tester, 'นำเข้าไฟล์ธีม');
      expect(find.text('แทนที่ธีมเดิม?'), findsOneWidget);
      await tester.tap(find.text('ยกเลิก'));
      await settle(tester);
      expect(c.userThemes.single.name, 'Theme dup');
      expect(find.text('ยกเลิกการนำเข้า'), findsOneWidget);

      await _tapLabel(tester, 'นำเข้าไฟล์ธีม');
      await tester.tap(find.text('แทนที่'));
      await settle(tester);
      expect(c.userThemes.single.name, 'New B');
    });

    uiTest('ไฟล์ที่มีค่าถูกข้าม (คำเตือน) นำเข้าได้ และบอกจำนวนที่ข้าม', (tester) async {
      final c = await _loaded();
      final f = FakeFiles()..picks.add(const PickedTheme(name: 'w.nslt', text: '{"schema":1,"id":"warn","name":"Warn","extends":"nsl.launcher","light":{"colors":{"accent":"nope"}}}'));
      await _open(tester, c, f);
      await _tapLabel(tester, 'นำเข้าไฟล์ธีม');
      expect(c.userThemes.map((t) => t.id), ['warn']);
      expect(find.textContaining('ค่าที่ถูกข้าม 1 รายการ'), findsOneWidget);
    });
  });

  group('ส่งออกและลบ', () {
    uiTest('ส่งออก: ชื่อไฟล์ = id.nslt และเนื้อหาเท่าที่ controller ส่งออก ; ยกเลิก/บันทึกไม่ได้บอกตรง ๆ', (tester) async {
      final c = await _loaded(['green']);
      final f = FakeFiles();
      await _open(tester, c, f);
      await _tapLabel(tester, 'ส่งออกธีม Theme green');
      expect(f.saved.single.$1, 'green.nslt');
      expect(f.saved.single.$2, c.exportThemeText('green'));
      expect(parseNslt(f.saved.single.$2).ok, isTrue);
      expect(find.text('ส่งออกธีม "Theme green" แล้ว'), findsOneWidget);
      f.saveResult = false;
      await _tapLabel(tester, 'ส่งออกธีม Theme green');
      expect(find.textContaining('ไม่ได้ส่งออก'), findsOneWidget);
    });

    uiTest('ลบ: ต้องยืนยัน ; ยกเลิกแล้วอยู่ ; ยืนยันแล้วหาย', (tester) async {
      final c = await _loaded(['green', 'blue']);
      await _open(tester, c, FakeFiles());
      await _tapLabel(tester, 'ลบธีม Theme green');
      expect(find.text('ลบธีม "Theme green"?'), findsOneWidget);
      await tester.tap(find.text('ยกเลิก'));
      await settle(tester);
      expect(c.userThemes.length, 2);
      await _tapLabel(tester, 'ลบธีม Theme green');
      await tester.tap(find.text('ลบ').last);
      await settle(tester);
      expect(c.userThemes.map((t) => t.id), ['blue']);
      expect(find.text('ลบธีม "Theme green" แล้ว'), findsOneWidget);
    });

    uiTest('ลบธีมที่แอปใช้อยู่และที่ Launcher ใช้อยู่: ล้างตัวเลือกทั้งสองที่ ไม่เหลือ "ธีมที่เลือกหาย"', (tester) async {
      final c = await _loaded(['green']);
      await c.select('green');
      final settings = LauncherSettingsController(null, const LauncherSettings(themeSource: 'green'));
      await _open(tester, c, FakeFiles(), settings: settings);
      expect(shellContext(tester).lt.c.accent, const Color(0xFF00AA55));
      await _tapLabel(tester, 'ลบธีม Theme green');
      expect(find.textContaining('แอปจะกลับไปใช้ธีมเริ่มต้น'), findsOneWidget);
      await tester.tap(find.text('ลบ').last);
      await settle(tester);
      expect(c.settings.activeThemeId, isNull);
      expect(c.problems, isEmpty);
      expect(settings.value.themeSource, kThemeSourceLauncher);
      expect(shellContext(tester).lt.c.accent, const Color(0xFFFFC83D));
    });
  });

  group('ปรับแต่งเร็ว (lite) และโหมดปลอดภัยของแอป', () {
    uiTest('เลือกสีเน้น preset / สีเอง / ล้าง และโหมด — เก็บใน controller', (tester) async {
      final c = await _loaded();
      await _open(tester, c, FakeFiles());
      await _tapLabel(tester, 'สีเน้น น้ำเงิน');
      expect(c.appearance.presetId, 'blue');
      await tester.enterText(find.bySemanticsLabel('รหัสสีเน้นที่กำหนดเอง'), '#112233');
      await settle(tester);
      expect(c.appearance.customAccent, const Color(0xFF112233));
      expect(c.appearance.presetId, isNull);
      await tester.enterText(find.bySemanticsLabel('รหัสสีเน้นที่กำหนดเอง'), '#12G');
      await settle(tester);
      expect(find.text('รหัสสีไม่ถูกต้อง'), findsOneWidget);
      expect(c.appearance.customAccent, const Color(0xFF112233), reason: 'ค่าผิดไม่เปลี่ยนค่าเดิม');
      await tester.enterText(find.bySemanticsLabel('รหัสสีเน้นที่กำหนดเอง'), '#11223380'); // ช่องจำกัด 7 ตัว → ถูกตัดเหลือ #112233 (สีเน้นทึบเสมอ)
      await settle(tester);
      expect(c.appearance.customAccent!.a, 1.0);
      expect(find.text('รหัสสีไม่ถูกต้อง'), findsNothing);
      await _tapLabel(tester, 'ล้างสีเน้น');
      expect(c.appearance.hasAccent, isFalse);
      await _tapLabel(tester, 'โหมดของแอป NSL: มืด');
      expect(c.appearance.mode, NslModeChoice.dark);
    });

    uiTest('โหมดปลอดภัยของแอป: เปิด/ปิดได้ มีข้อความ และเก็บลงไฟล์ ui-settings.json จริง', (tester) async {
      final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('launcher_mgr')))!;
      addTearDown(() => _cleanup(dir));
      final store = NslThemeStore.standard(documents: dir, settingsRoot: dir);
      final c = NslThemeController(store);
      await tester.runAsync(c.reload);
      await _open(tester, c, FakeFiles());
      final settingsFile = File('${dir.path}${Platform.pathSeparator}ui-settings.json');
      await _tapLabel(tester, 'ไม่ใช้ธีมของผู้ใช้ในแอป NSL: ปิด');
      await _until(tester, () => c.safeMode && settingsFile.existsSync());
      expect(c.safeMode, isTrue);
      expect(find.textContaining('โหมดปลอดภัย'), findsWidgets);
      final j = jsonDecode(File('${dir.path}${Platform.pathSeparator}ui-settings.json').readAsStringSync()) as Map;
      expect(j['safeMode'], true);
    });
  });

  group('กับที่เก็บจริงบนดิสก์ (โฟลเดอร์ชั่วคราว)', () {
    uiTest('นำเข้า → ไฟล์ปรากฏที่ Documents/NSL/Themes ; เลือก → ui-settings.json ; คีย์ที่ไม่รู้จักในไฟล์ค่าตั้งไม่หาย ; ไม่เหลือ .tmp', (tester) async {
      final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('launcher_mgr_real')))!;
      addTearDown(() => _cleanup(dir));
      final sep = Platform.pathSeparator;
      final app = Directory('${dir.path}${sep}AppData')..createSync();
      final docs = Directory('${dir.path}${sep}Documents')..createSync();
      File('${app.path}${sep}ui-settings.json').writeAsStringSync('{"schema":1,"perApp":{"x":1}}');
      final c = NslThemeController(NslThemeStore.standard(documents: docs, settingsRoot: app));
      await tester.runAsync(c.reload);
      final f = FakeFiles()..picks.add(PickedTheme(name: 'sea.nslt', text: _nslt('sea', name: 'Sea')));
      await _open(tester, c, f);
      final themeFile = File('${docs.path}${sep}NSL${sep}Themes${sep}sea.nslt');
      await _tapLabel(tester, 'นำเข้าไฟล์ธีม');
      await _until(tester, () => themeFile.existsSync() && c.userThemes.isNotEmpty);
      expect(themeFile.existsSync(), isTrue);
      expect(_inManager('Sea'), findsOneWidget);
      expect(find.textContaining('NSL${sep}Themes'), findsOneWidget, reason: 'แสดงโฟลเดอร์ธีมให้ผู้ใช้เห็น');
      await _tapLabel(tester, 'ใช้ธีม Sea กับแอป NSL');
      bool saved() {
        try {
          return (jsonDecode(File('${app.path}${sep}ui-settings.json').readAsStringSync()) as Map)['activeThemeId'] == 'sea';
        } catch (_) {
          return false;
        }
      }
      await _until(tester, saved);
      final j = jsonDecode(File('${app.path}${sep}ui-settings.json').readAsStringSync()) as Map;
      expect(j['activeThemeId'], 'sea');
      expect(j['perApp'], {'x': 1});
      expect(Directory('${docs.path}${sep}NSL${sep}Themes').listSync().where((e) => e.path.endsWith('.tmp')), isEmpty);
    });
  });

  group('กรณีไม่มีที่เก็บธีม / ขนาดจอ / การเข้าถึง', () {
    uiTest('ไม่มีตัวควบคุมธีม (safe mode หรือเปิดที่เก็บไม่ได้) = บอกเหตุผล ไม่ล้ม', (tester) async {
      await _open(tester, null, FakeFiles(), safeMode: true);
      expect(find.textContaining('Safe mode: ไม่เปิดที่เก็บธีมของผู้ใช้'), findsWidgets);
      await _open(tester, null, FakeFiles());
      expect(find.textContaining('เปิดที่เก็บธีม'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final size in const [Size(1440, 2600), Size(900, 2800), Size(390, 4200)]) {
      uiTest('ธีม 8 ไฟล์ + ข้อความผลลัพธ์ที่ ${size.width.toInt()}px ไม่ overflow (รวมตัวอักษร 1.5×)', (tester) async {
        final c = await _loaded([for (var i = 0; i < 8; i++) 'theme$i']);
        final f = FakeFiles()..picks.add(PickedTheme(name: 'x.nslt', text: _nslt('extra', name: 'ธีมชื่อยาวมากสำหรับทดสอบการตัดบรรทัดของรายการ ${'ยาว' * 8}')));
        await pumpLauncher(tester, size: size, themes: c, files: f, section: Section.settings, textScale: 1.5);
        await _tapLabel(tester, 'นำเข้าไฟล์ธีม');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('ปุ่มทุกตัวในหน้าจัดการธีมมีป้ายชื่อและพื้นที่แตะ ≥ 44px', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await _loaded(['green']);
      await _open(tester, c, FakeFiles());
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    uiTest('ข้อความผลลัพธ์เป็น live region (screen reader อ่านให้เอง) และเปลี่ยนธีมของ Launcher สดหลังนำเข้า+เลือกในหน้าเดียวกัน', (tester) async {
      final c = await _loaded();
      final f = FakeFiles()..picks.add(PickedTheme(name: 's.nslt', text: _nslt('sea')));
      final settings = LauncherSettingsController(null, const LauncherSettings(themeSource: kThemeSourceShared));
      await _open(tester, c, f, settings: settings);
      await _tapLabel(tester, 'นำเข้าไฟล์ธีม');
      final msg = find.ancestor(of: find.textContaining('นำเข้าธีม "Theme sea" แล้ว'), matching: find.byType(Semantics)).evaluate().any((e) => (e.widget as Semantics).properties.liveRegion == true);
      expect(msg, isTrue);
      expect(shellContext(tester).lt.c.accent, const Color(0xFFFFC83D));
      await _tapLabel(tester, 'ใช้ธีม Theme sea กับแอป NSL');
      expect(shellContext(tester).lt.c.accent, const Color(0xFF00AA55), reason: 'Launcher ตามธีมที่เลือกให้แอป');
    });
  });
}
