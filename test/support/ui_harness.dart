import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nsl_launcher/app.dart';
import 'package:nsl_launcher/data/catalog.dart';
import 'package:nsl_launcher/settings/launcher_settings.dart';
import 'package:nsl_launcher/settings/theme_file_service.dart';
import 'package:nsl_launcher/theme_engine/theme_engine.dart';
import 'package:nsl_launcher/ui/shell.dart';

import 'builtins.dart';

/// โหลดฟอนต์จริงของ Launcher เข้าเทสต์ (ไม่งั้นเทสต์ใช้ฟอนต์สี่เหลี่ยม Ahem — ขนาดข้อความไม่จริง และภาพถ่ายหน้าจอใช้ไม่ได้)
Future<void> loadLauncherFonts() async {
  Future<void> load(String family, List<String> files) async {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await l.load();
  }

  await load('Noto Sans Thai', ['NotoSansThai-Regular.ttf', 'NotoSansThai-Medium.ttf', 'NotoSansThai-SemiBold.ttf', 'NotoSansThai-Bold.ttf']);
  await load('Space Grotesk', ['SpaceGrotesk-Variable.ttf']);
}

/// ตั้งค่าเริ่มต้นของชุดเทสต์ UI: ลงทะเบียนธีมในตัวของแอปอื่นจากไฟล์ asset
void setUpLauncherUi() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    registerCoreForTests();
    await loadLauncherFonts();
  });
}

Future<void> pumpLauncher(
  WidgetTester tester, {
  Size size = const Size(1440, 1060),
  Catalog? catalog,
  LauncherSettingsController? settings,
  NslThemeController? themes,
  bool safeMode = false,
  Section section = Section.library,
  double textScale = 1.0,
  ThemeFileService? files,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(RepaintBoundary(
    key: launcherBoundaryKey,
    child: LauncherApp(
      catalog: catalog ?? demoCatalog(),
      settings: settings ?? LauncherSettingsController(null),
      themes: themes,
      safeMode: safeMode,
      initialSection: section,
      files: files ?? const SystemThemeFileService(),
    ),
  ));
  await settle(tester);
}

/// ขอบเขตสำหรับถ่ายภาพหน้าจอ
final launcherBoundaryKey = GlobalKey();

/// รอให้ SVG (ถอดรหัสแบบ async) และแอนิเมชันเสร็จ
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

BuildContext shellContext(WidgetTester tester) => tester.element(find.byType(LauncherShell));

/// บันทึกภาพหน้าจอของ widget ทั้งต้นไม้เป็น PNG (ใช้ตรวจหน้าตาด้วยตา) — เฉพาะเมื่อกำหนด [path]
Future<void> savePng(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(launcherBoundaryKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File(path).writeAsBytes(Uint8List.view(bytes.buffer));
  });
}

/// เลื่อนการ์ดโปรแกรม [name] เข้าจอแล้วแตะเพื่อเปิดรายละเอียด (การ์ดอยู่ในหน้าที่เลื่อนได้ อาจอยู่นอกจอ)
Future<void> openDetail(WidgetTester tester, String name) async {
  final f = find.bySemanticsLabel('ดูรายละเอียด $name');
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

/// testWidgets ที่เปิด Semantics ไว้ตลอดเทสต์ (ค้นด้วยป้ายชื่อได้ เหมือนที่ screen reader เห็น) แล้วปิดก่อนจบ
/// — Flutter ตรวจว่า SemanticsHandle ถูกปิดก่อนสิ้นสุดเทสต์ จึงปิดใน finally ไม่ใช่ addTearDown
void uiTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await body(tester);
    } finally {
      handle.dispose();
    }
  });
}

// Semantics flags ใน Flutter รุ่นนี้ใช้ Tristate สำหรับ isEnabled
final tristateTrue = ui.Tristate.isTrue;
final tristateFalse = ui.Tristate.isFalse;
