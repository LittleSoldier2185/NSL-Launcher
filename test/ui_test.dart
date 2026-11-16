import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsl_launcher/data/catalog.dart';
import 'package:nsl_launcher/settings/launcher_settings.dart';
import 'package:nsl_launcher/theme_engine/theme_engine.dart';
import 'package:nsl_launcher/ui/icons.dart';
import 'package:nsl_launcher/ui/pages/library_page.dart';
import 'package:nsl_launcher/ui/shell.dart';
import 'package:nsl_launcher/ui/theme/launcher_theme.dart';
import 'package:nsl_launcher/ui/theme/theme_source.dart';

import 'support/ui_harness.dart';

NslThemeSpec _theme(String id, {String accent = '#00AA55', String extra = ''}) => parseNslt(
      '{"schema":1,"id":"$id","name":"Theme $id","extends":"nsl.launcher","dark":{"colors":{"accent":"$accent"}},"light":{"colors":{"accent":"$accent"}}$extra}',
    ).spec!;

Future<NslThemeController> _controllerWith(List<NslThemeSpec> specs, {String? select}) async {
  final st = NslMemoryThemeStorage();
  for (final s in specs) {
    await st.saveTheme(s);
  }
  final c = NslThemeController(st);
  await c.reload();
  if (select != null) await c.select(select);
  return c;
}

void main() {
  setUpLauncherUi();

  group('การแปลงธีมเป็นหน้าตา', () {
    NslTokens t(NslThemeSpec s, [Brightness b = Brightness.dark]) => resolveTokens(s, b, lookup: builtinThemeById);

    test('ธีมของ Launcher → ThemeData/สี/ฟอนต์ตามดีไซน์', () {
      final theme = buildLauncherTheme(t(kBuiltinLauncher));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF071433));
      expect(theme.colorScheme.primary, const Color(0xFFFFC83D));
      expect(theme.colorScheme.onPrimary, const Color(0xFF1A1300));
      expect(theme.brightness, Brightness.dark);
      final lt = theme.extension<LauncherTheme>()!;
      expect(lt.uiFamily, 'Noto Sans Thai');
      expect(lt.display(28).fontFamily, 'Space Grotesk');
      expect(lt.controlHeight, 44);
      expect(lt.radius(12), 12);
    });

    test('รูปทรง/ตัวอักษร/density จากธีมผู้ใช้ปรับขนาดตามสัดส่วน และไม่ต่ำกว่าขั้นต่ำ', () {
      final spec = _theme('big', extra: ',"shape":{"radius":{"md":16}},"type":{"scale":1.2,"minSize":14},"density":"comfortable"');
      final lt = buildLauncherTheme(t(spec)).extension<LauncherTheme>()!;
      expect(lt.radiusFactor, 2.0);
      expect(lt.radius(12), 24);
      expect(lt.fs(12), closeTo(14.4, 1e-9));
      expect(lt.fs(10), 14); // ต่ำกว่าขั้นต่ำถูกยกขึ้น
      expect(lt.controlHeight, 52);
      final compact = buildLauncherTheme(t(_theme('c', extra: ',"density":"compact"'))).extension<LauncherTheme>()!;
      expect(compact.controlHeight, 36);
      expect(compact.space(10), 8);
    });

    test('ฟอนต์ UI จากธีมมาก่อน และ Noto Sans Thai อยู่ท้ายสำรองเสมอ', () {
      final lt = buildLauncherTheme(t(_theme('f', extra: ',"type":{"family":"Sarabun"}'))).extension<LauncherTheme>()!;
      expect(lt.uiFamily, 'Sarabun');
      expect(lt.ui(14).fontFamilyFallback, contains('Noto Sans Thai'));
    });

    test('ไอคอนทุกตัวมีและวาดได้ (ชื่อตรงกับที่หน้าจอใช้)', () {
      expect(launcherIconNames, containsAll(['grid', 'refresh', 'download', 'settings', 'search', 'play', 'back', 'dots', 'check', 'phone', 'folder']));
    });
  });

  group('เลือกธีมที่ Launcher ใช้ (launcherTokens)', () {
    test('ค่าเริ่มต้น = ธีมของ Launcher ทั้งสองโหมด', () {
      for (final b in Brightness.values) {
        final t = launcherTokens(const LauncherSettings(), null, b);
        expect(t.colors.accent, const Color(0xFFFFC83D));
        expect(t.brightness, b);
      }
    });

    test('ตามธีมที่เลือกให้แอป (shared): ไม่มี/ไม่ได้เลือก = ธีมของ Launcher ; เลือกแล้ว = ธีมนั้น', () async {
      const s = LauncherSettings(themeSource: kThemeSourceShared);
      expect(launcherTokens(s, null, Brightness.dark).colors.accent, const Color(0xFFFFC83D));
      final c = await _controllerWith([_theme('green')]);
      expect(launcherTokens(s, c, Brightness.dark).colors.accent, const Color(0xFFFFC83D)); // ยังไม่ได้เลือก
      await c.select('green');
      expect(launcherTokens(s, c, Brightness.dark).colors.accent, const Color(0xFF00AA55));
    });

    test('เลือกธีมตาม id: ของผู้ใช้ / ในตัวของแอปอื่น ; id ที่หายไป = ธีมของ Launcher', () async {
      final c = await _controllerWith([_theme('green')]);
      expect(launcherTokens(const LauncherSettings(themeSource: 'green'), c, Brightness.dark).colors.accent, const Color(0xFF00AA55));
      final neb = launcherTokens(const LauncherSettings(themeSource: 'nsl.nebular'), c, Brightness.dark);
      expect(neb.colors.accent, resolveTokens(builtinThemeById('nsl.nebular')!, Brightness.dark).colors.accent);
      expect(launcherTokens(const LauncherSettings(themeSource: 'gone'), c, Brightness.dark).colors.accent, const Color(0xFFFFC83D));
    });

    test('ธีมที่ใช้ไม่ได้ (ฐานหาย / อ่านไม่ออก) ถอยไปธีมของ Launcher ไม่โยน', () async {
      final broken = parseNslt('{"schema":1,"id":"broken","name":"B","extends":"user.gone"}').spec!;
      final invisible = parseNslt('{"schema":1,"id":"invisible","name":"I","dark":{"colors":{"bg":"#101010","surface":"#101010","text":"#111111","accent":"#222222"}}}').spec!;
      final c = await _controllerWith([broken, invisible]);
      for (final id in ['broken', 'invisible']) {
        final t = launcherTokens(LauncherSettings(themeSource: id), c, Brightness.dark);
        expect(t.colors.accent, const Color(0xFFFFC83D), reason: id);
      }
    });

    test('safe mode = ธีมของ Launcher ล้วน ๆ แม้เลือกธีมอื่นไว้', () async {
      final c = await _controllerWith([_theme('green')], select: 'green');
      const s = LauncherSettings(themeSource: 'green');
      expect(launcherTokens(s, c, Brightness.dark).colors.accent, const Color(0xFF00AA55));
      expect(launcherTokens(s, c, Brightness.dark, safeMode: true).colors.accent, const Color(0xFFFFC83D));
    });
  });

  group('ค่าตั้งของ Launcher (launcher-settings.json)', () {
    test('อ่านแบบไม่โยน: ไฟล์เสีย/ใหญ่เกิน/ค่าแปลก = ค่าเริ่มต้น', () {
      for (final bad in ['', '{', '[]', '5', '{"themeSource":5,"mode":7}', '{"themeSource":"../evil"}', '{"themeSource":"Bad Id"}', 'x' * 5000]) {
        final s = LauncherSettings.parse(bad);
        expect(s.themeSource, kThemeSourceLauncher, reason: bad.length > 30 ? 'big' : bad);
        expect(s.mode, LauncherMode.dark);
      }
      final ok = LauncherSettings.parse('{"themeSource":"my-theme","mode":"light"}');
      expect([ok.themeSource, ok.mode], ['my-theme', LauncherMode.light]);
    });

    test('เก็บ/โหลดจากไฟล์จริง แบบ atomic (ไม่เหลือ .tmp) และตัวควบคุมแจ้งผู้ฟัง', () async {
      final dir = await Directory.systemTemp.createTemp('launcher_settings');
      addTearDown(() => dir.delete(recursive: true));
      final c = LauncherSettingsController(LauncherSettingsStore(dir));
      var notified = 0;
      c.addListener(() => notified++);
      await c.update(const LauncherSettings(themeSource: kThemeSourceShared, mode: LauncherMode.system));
      await c.update(const LauncherSettings(themeSource: kThemeSourceShared, mode: LauncherMode.system)); // ซ้ำ = ไม่แจ้ง
      expect(notified, 1);
      expect(dir.listSync().where((e) => e.path.endsWith('.tmp')), isEmpty);
      final c2 = LauncherSettingsController(LauncherSettingsStore(dir));
      await c2.load();
      expect([c2.value.themeSource, c2.value.mode], [kThemeSourceShared, LauncherMode.system]);
    });

    test('เก็บไม่ได้ (โฟลเดอร์ปลายทางเป็นไฟล์) ไม่ทำให้แอปล้ม — ใช้ค่าในหน่วยความจำต่อ', () async {
      final dir = await Directory.systemTemp.createTemp('launcher_settings_bad');
      addTearDown(() => dir.delete(recursive: true));
      final blocker = File('${dir.path}${Platform.pathSeparator}NSL')..writeAsStringSync('x');
      final c = LauncherSettingsController(LauncherSettingsStore(Directory(blocker.path)));
      await c.update(const LauncherSettings(mode: LauncherMode.light));
      expect(c.value.mode, LauncherMode.light);
    });
  });

  group('ข้อมูลคลัง', () {
    test('คลังจริงก่อนมี manifest: ไม่แกล้งบอกว่าติดตั้งแล้ว/มีอัปเดต และไม่มีฮีโร่/ดาวน์โหลด/มือถือ', () {
      final c = staticCatalog();
      expect(c.apps.map((a) => a.id), ['spectrum', 'orbit', 'nebular', 'lyra']);
      expect(c.apps.any((a) => a.state == InstallState.installed || a.state == InstallState.updateAvailable), isFalse);
      expect([c.lastOpened, c.downloads, c.devices, c.updates].map((e) => e == null || (e is List && e.isEmpty)), everyElement(true));
      expect(c.apps.every((a) => a.installedVersion == null && a.latestVersion == null && a.sizeBytes == null), isTrue, reason: 'ไม่แต่งเลขเวอร์ชัน/ขนาด');
      expect(c.byId('orbit')!.state, InstallState.mobileOnly);
      expect(c.byId('lyra')!.state, InstallState.inDevelopment);
    });

    test('ค้นหา: ชื่อ/คำอธิบาย/หมวด ไม่สนตัวพิมพ์ ; กรองตามหมวด ; ไม่พบ = ว่าง', () {
      final c = staticCatalog();
      expect(c.search('orbit').map((a) => a.id), ['orbit']);
      expect(c.search('FLOWCHART').map((a) => a.id), ['nebular']);
      expect(c.search('นิยาย').map((a) => a.id), ['lyra']);
      expect(c.search('media').map((a) => a.id), ['spectrum']);
      expect(c.search('', category: AppCategory.create).map((a) => a.id), ['nebular', 'lyra']);
      expect(c.search('orbit', category: AppCategory.media), isEmpty);
      expect(c.search('zzzz'), isEmpty);
      expect(c.search('  nsl  ').length, 4);
    });

    test('โหมดสาธิต = ตัวอย่างในดีไซน์ (ติดตั้งแล้ว 1, มีอัปเดต 1, ดาวน์โหลด 64%, มือถือ 1) และติดป้ายว่าเป็นสาธิต', () {
      final c = demoCatalog();
      expect(c.isDemo, isTrue);
      expect(c.byId('spectrum')!.state, InstallState.installed);
      expect(c.updates.map((a) => a.id), ['nebular']);
      expect(c.downloads.single.progress, 0.64);
      expect(c.lastOpenedId, 'spectrum');
      expect(staticCatalog().isDemo, isFalse);
    });
  });

  group('หน้าคลังโปรแกรม', () {
    uiTest('แสดงหัวเรื่อง ค้นหา ชิปหมวด หมวดทั้งสาม และการ์ดครบ (โหมดสาธิต)', (tester) async {
      await pumpLauncher(tester);
      expect(find.text('คลังโปรแกรม'), findsWidgets);
      expect(find.text('ทุกโปรแกรมของ NSL จัดตามหมวด'), findsOneWidget);
      for (final t in ['หมวด Media', 'หมวด Life', 'หมวด Create']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      for (final n in ['NSL Spectrum', 'NSL Orbit', 'NSL Nebular', 'NSL Lyra']) {
        expect(find.text(n), findsWidgets, reason: n);
      }
      expect(find.text('เปิดล่าสุด · หมวด MEDIA'), findsOneWidget);
      expect(find.text('อัปเดตที่รอ'), findsOneWidget);
      expect(find.text('กำลังดาวน์โหลด'), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);
      expect(find.text('มือถือที่เชื่อมต่อ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    uiTest('คลังจริง (ไม่สาธิต): ไม่มีฮีโร่และแผงข้างที่ไม่มีข้อมูล', (tester) async {
      await pumpLauncher(tester, catalog: staticCatalog());
      expect(find.textContaining('เปิดล่าสุด'), findsNothing);
      for (final t in ['อัปเดตที่รอ', 'กำลังดาวน์โหลด', 'มือถือที่เชื่อมต่อ']) {
        expect(find.text(t), findsNothing, reason: t);
      }
      expect(find.text('ยังไม่ได้ติดตั้ง'), findsNWidgets(2)); // Spectrum, Nebular
      expect(find.text('ติดตั้ง'), findsNWidgets(2));
      expect(find.text('เร็ว ๆ นี้'), findsOneWidget);
    });

    uiTest('กรองตามหมวดด้วยชิป และค้นหาด้วยข้อความ (ไม่พบแสดงข้อความ)', (tester) async {
      await pumpLauncher(tester, catalog: staticCatalog());
      await tester.tap(find.text('Create'));
      await settle(tester);
      expect(find.text('หมวด Create'), findsOneWidget);
      expect(find.text('หมวด Media'), findsNothing);
      expect(find.text('NSL Spectrum'), findsNothing);
      await tester.tap(find.text('ทั้งหมด'));
      await settle(tester);
      expect(find.text('หมวด Media'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'orbit');
      await settle(tester);
      expect(find.text('NSL Orbit'), findsOneWidget);
      expect(find.text('NSL Spectrum'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzzz');
      await settle(tester);
      expect(find.textContaining('ไม่พบโปรแกรม'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    uiTest('ป้ายอัปเดตบนเมนูแสดงจำนวน และเปิด/กลับรายละเอียดได้', (tester) async {
      await pumpLauncher(tester);
      expect(find.bySemanticsLabel('อัปเดต (1)'), findsOneWidget);
      await openDetail(tester, 'NSL Nebular');
      expect(find.text('ทำอะไรได้บ้าง'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('กลับไปคลังโปรแกรม'));
      await settle(tester);
      expect(find.text('ทุกโปรแกรมของ NSL จัดตามหมวด'), findsOneWidget);
    });
  });

  group('หน้ารายละเอียด', () {
    Future<void> openNebular(WidgetTester tester, {Catalog? catalog}) async {
      await pumpLauncher(tester, catalog: catalog ?? demoCatalog(), size: const Size(1440, 1180));
      await openDetail(tester, 'NSL Nebular');
    }

    uiTest('เส้นทาง ฮีโร่ ป้าย ปุ่มตามสถานะ และ "ทำอะไรได้บ้าง" ตรงดีไซน์', (tester) async {
      await openNebular(tester);
      expect(find.text('NSL Nebular'), findsWidgets);
      for (final t in ['หมวด Create', 'Windows', 'มีอัปเดต', 'อัปเดตและเปิด', 'ภาพรวม', 'มีอะไรใหม่', 'ตั้งค่าโปรแกรม']) {
        expect(find.text(t), findsWidgets, reason: t);
      }
      for (final f in ['Flowchart', 'Data flow', 'Screen flow', 'SQL schema และส่งออก .sql', 'ER diagram']) {
        expect(find.text(f), findsOneWidget, reason: f);
      }
      expect(find.text('โปรแกรมในหมวดเดียวกัน'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    uiTest('ข้อมูลที่ยังไม่รู้แสดง "—" ไม่แต่งตัวเลข ; ไม่มีประวัติเวอร์ชัน = ข้อความบอกตรง ๆ', (tester) async {
      await openNebular(tester);
      expect(find.text('—'), findsNWidgets(4)); // เวอร์ชันที่ติดตั้ง, เวอร์ชันล่าสุด, ขนาด, โฟลเดอร์ติดตั้ง
      await tester.tap(find.text('มีอะไรใหม่').last);
      await settle(tester);
      expect(find.textContaining('ยังไม่มีข้อมูลประวัติการเปลี่ยนแปลง'), findsOneWidget);
      await tester.tap(find.text('ตั้งค่าโปรแกรม').last);
      await settle(tester);
      expect(find.textContaining('จะมาในเวอร์ชันถัดไป'), findsOneWidget);
    });

    uiTest('การ์ดในหมวดเดียวกัน (Lyra) เปิดรายละเอียดได้ และแอปที่ยังไม่ปล่อยแสดงปุ่ม "เร็ว ๆ นี้" ที่ใช้ไม่ได้', (tester) async {
      await openNebular(tester);
      await openDetail(tester, 'NSL Lyra');
      expect(find.text('กำลังพัฒนา'), findsWidgets);
      final soon = tester.getSemantics(find.bySemanticsLabel('เร็ว ๆ นี้').first);
      expect(soon.flagsCollection.isEnabled, ui.Tristate.isFalse); // ปุ่มปิดใช้งานจริง ไม่หลอกว่ากดได้
      expect(find.text('ทำอะไรได้บ้าง'), findsNothing); // Lyra ไม่มีรายการความสามารถ → ไม่แต่งขึ้น
      expect(find.text('เกี่ยวกับโปรแกรม'), findsOneWidget);
    });
  });

  group('นำทางและตั้งค่า', () {
    uiTest('เมนูข้างสลับหน้า: อัปเดต/ดาวน์โหลด (เร็ว ๆ นี้) และตั้งค่า', (tester) async {
      await pumpLauncher(tester);
      await tester.tap(find.bySemanticsLabel('ดาวน์โหลด'));
      await settle(tester);
      expect(find.textContaining('กำลังพัฒนา'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('ตั้งค่า'));
      await settle(tester);
      expect(find.text('ปรับหน้าตาของ Launcher'), findsOneWidget);
      expect(find.text('ธีมของ Launcher (ค่าเริ่มต้น)'), findsOneWidget);
      expect(find.text('โหมดของ Launcher'), findsOneWidget);
      expect(find.text('ธีมของแอป NSL'), findsOneWidget);
    });

    uiTest('เลือกธีมในหน้าตั้งค่า → หน้าตาเปลี่ยนสด และค่าตั้งถูกเก็บ ; เลือกโหมดสว่าง → Brightness เปลี่ยน', (tester) async {
      final themes = await _controllerWith([_theme('green')]);
      final settings = LauncherSettingsController(null);
      await pumpLauncher(tester, themes: themes, settings: settings, section: Section.settings);
      expect(shellContext(tester).lt.c.accent, const Color(0xFFFFC83D));
      await tester.tap(find.bySemanticsLabel('Theme green — ไฟล์ของคุณ'));
      await settle(tester);
      expect(settings.value.themeSource, 'green');
      expect(shellContext(tester).lt.c.accent, const Color(0xFF00AA55));
      expect(Theme.of(shellContext(tester)).colorScheme.primary, const Color(0xFF00AA55));

      await tester.tap(find.bySemanticsLabel('โหมดสว่าง'));
      await settle(tester);
      expect(Theme.of(shellContext(tester)).brightness, Brightness.light);
      expect(shellContext(tester).lt.isDark, isFalse);
      expect(tester.takeException(), isNull);
    });

    uiTest('ไฟล์ธีมเปลี่ยนจากภายนอกขณะเปิดอยู่ (ตามธีมที่เลือกให้แอป) → หน้าตาเปลี่ยนสด', (tester) async {
      final themes = await _controllerWith([_theme('green')]);
      final settings = LauncherSettingsController(null, const LauncherSettings(themeSource: kThemeSourceShared));
      await pumpLauncher(tester, themes: themes, settings: settings);
      expect(shellContext(tester).lt.c.accent, const Color(0xFFFFC83D));
      await tester.runAsync(() => themes.select('green')); // เหมือนแอปอื่น/Launcher หน้าจัดการธีมเลือกธีมให้แอป
      await settle(tester);
      expect(shellContext(tester).lt.c.accent, const Color(0xFF00AA55));
    });

    uiTest('safe mode: ไม่ใช้ธีมผู้ใช้ มีข้อความบอก ; ธีมเสียไม่ทำให้หน้าจอล้ม', (tester) async {
      final broken = parseNslt('{"schema":1,"id":"broken","name":"B","extends":"user.gone"}').spec!;
      final themes = await _controllerWith([_theme('green'), broken]);
      final settings = LauncherSettingsController(null, const LauncherSettings(themeSource: 'green'));
      await pumpLauncher(tester, themes: themes, settings: settings, safeMode: true, section: Section.settings);
      expect(shellContext(tester).lt.c.accent, const Color(0xFFFFC83D));
      expect(find.textContaining('Safe mode'), findsOneWidget);
      await settings.update(const LauncherSettings(themeSource: 'broken'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('จอหลายขนาด / ตัวอักษรใหญ่ / โหมดสว่าง ไม่ overflow', () {
    for (final size in const [Size(1440, 1060), Size(1024, 800), Size(901, 800), Size(900, 800), Size(700, 900), Size(390, 844)]) {
      uiTest('${size.width.toInt()}×${size.height.toInt()}: คลัง รายละเอียด ตั้งค่า', (tester) async {
        await pumpLauncher(tester, size: size);
        expect(tester.takeException(), isNull, reason: 'คลัง');
        await openDetail(tester, 'NSL Nebular');
        expect(tester.takeException(), isNull, reason: 'รายละเอียด');
        await tester.tap(find.bySemanticsLabel('ตั้งค่า'));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'ตั้งค่า');
      });
    }

    uiTest('ตัวอักษรระบบ 1.5× และธีมสัดส่วน 1.2 + density comfortable บนจอ 390', (tester) async {
      final themes = await _controllerWith([_theme('big', extra: ',"type":{"scale":1.2},"density":"comfortable"')]);
      final settings = LauncherSettingsController(null, const LauncherSettings(themeSource: 'big'));
      await pumpLauncher(tester, size: const Size(390, 844), themes: themes, settings: settings, textScale: 1.5);
      expect(tester.takeException(), isNull);
      await openDetail(tester, 'NSL Nebular');
      expect(tester.takeException(), isNull);
    });

    uiTest('โหมดสว่างทุกหน้าไม่ล้ม', (tester) async {
      final settings = LauncherSettingsController(null, const LauncherSettings(mode: LauncherMode.light));
      await pumpLauncher(tester, settings: settings);
      expect(Theme.of(shellContext(tester)).brightness, Brightness.light);
      await openDetail(tester, 'NSL Nebular');
      await tester.tap(find.bySemanticsLabel('ตั้งค่า'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('การเข้าถึง', () {
    testWidgets('ปุ่ม/ช่องที่กดได้ทุกตัวมีป้ายชื่อ และพื้นที่แตะ ≥ 44px ตามดีไซน์', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLauncher(tester);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('หัวข้อหลักเป็น header สำหรับ screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLauncher(tester);
      final title = find.descendant(of: find.byType(LibraryPage), matching: find.text('คลังโปรแกรม'));
      expect(tester.getSemantics(title).flagsCollection.isHeader, isTrue);
      handle.dispose();
    });
  });
}
