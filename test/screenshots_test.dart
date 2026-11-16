// ถ่ายภาพหน้าจอเป็น PNG เพื่อตรวจหน้าตาด้วยตา — ทำงานเฉพาะเมื่อกำหนดตัวแปรสภาพแวดล้อม NSL_SHOTS_DIR
//   NSL_SHOTS_DIR=C:\path\to\folder flutter test test/screenshots_test.dart
// (ไม่ใช่ golden: ไม่เทียบกับไฟล์เดิม เพราะการเรนเดอร์ข้อความต่างกันตามเครื่อง)
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsl_launcher/data/catalog.dart';
import 'package:nsl_launcher/settings/launcher_settings.dart';
import 'package:nsl_launcher/theme_engine/theme_engine.dart';
import 'package:nsl_launcher/ui/shell.dart';

import 'support/ui_harness.dart';

void main() {
  setUpLauncherUi();
  final dir = Platform.environment['NSL_SHOTS_DIR'];

  Future<void> shot(WidgetTester tester, String name) async => savePng(tester, '$dir${Platform.pathSeparator}$name.png');

  testWidgets('ภาพหน้าจอ: คลังโปรแกรม (สาธิต) 1440', (tester) async {
    await pumpLauncher(tester, size: const Size(1440, 1060));
    await shot(tester, 'library-demo-1440');
  }, skip: dir == null);

  testWidgets('ภาพหน้าจอ: คลังโปรแกรม (จริง ไม่สาธิต) 1440', (tester) async {
    await pumpLauncher(tester, size: const Size(1440, 800), catalog: staticCatalog());
    await shot(tester, 'library-real-1440');
  }, skip: dir == null);

  testWidgets('ภาพหน้าจอ: รายละเอียด Nebular 1440', (tester) async {
    await pumpLauncher(tester, size: const Size(1440, 1180));
    await openDetail(tester, 'NSL Nebular');
    await shot(tester, 'detail-nebular-1440');
  }, skip: dir == null);

  testWidgets('ภาพหน้าจอ: คลังโปรแกรมจอแคบ 390', (tester) async {
    await pumpLauncher(tester, size: const Size(390, 1500));
    await shot(tester, 'library-demo-390');
  }, skip: dir == null);

  testWidgets('ภาพหน้าจอ: ตั้งค่า + ธีมผู้ใช้สีเขียว', (tester) async {
    final st = NslMemoryThemeStorage();
    await st.saveTheme(parseNslt('{"schema":1,"id":"green","name":"Green","extends":"nsl.launcher","dark":{"colors":{"accent":"#2FD08A","accentInk":"#2FD08A","accentTint":"#2FD08A29","selected":"#2FD08A1F","accentBorder":"#2FD08A59"}},"shape":{"radius":{"md":12}}}').spec!);
    final themes = NslThemeController(st);
    await themes.reload();
    await pumpLauncher(tester, size: const Size(1440, 900), themes: themes, settings: LauncherSettingsController(null, const LauncherSettings(themeSource: 'green')), section: Section.settings);
    await shot(tester, 'settings-green-1440');
  }, skip: dir == null);

  testWidgets('ภาพหน้าจอ: โหมดสว่าง', (tester) async {
    await pumpLauncher(tester, size: const Size(1440, 1060), settings: LauncherSettingsController(null, const LauncherSettings(mode: LauncherMode.light)));
    await shot(tester, 'library-light-1440');
  }, skip: dir == null);
}
