import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/catalog.dart';
import 'settings/launcher_settings.dart';
import 'theme_engine/theme_engine.dart';

/// ตัวเลือกบรรทัดคำสั่ง:
///   --safe-mode  ใช้ธีมของ Launcher ล้วน ๆ ไม่อ่านธีมของผู้ใช้ (ทางกู้เมื่อธีมทำให้ใช้งานไม่ได้)
///   --demo       แสดงข้อมูลสาธิตตามตัวอย่างในดีไซน์ (ไม่ใช่สถานะจริง)
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final safe = args.contains('--safe-mode');
  final demo = args.contains('--demo');

  // ธีมในตัวของแอปอื่น (จาก core) — ล้มเหลว = มีแค่ธีมของ Launcher
  await loadCoreBuiltinThemes(rootBundle);

  // ค่าตั้งของ Launcher: %APPDATA%\NSL\launcher-settings.json
  final settingsRoot = NslThemeStore.defaultRoot();
  final settings = LauncherSettingsController(settingsRoot == null ? null : LauncherSettingsStore(settingsRoot));
  await settings.load();

  // ไฟล์ธีม: Documents\NSL\Themes (แชร์กับแอป NSL อื่น) — ล้มเหลว = ไม่ใช้ธีมผู้ใช้ ไม่ให้แอปเปิดไม่ขึ้น
  NslThemeController? themes;
  if (!safe) {
    try {
      themes = NslThemeController(NslThemeStore.standard(documents: await getApplicationDocumentsDirectory()));
      await themes.reload();
      themes.startWatching();
    } catch (_) {
      themes = null;
    }
  }

  runApp(LauncherApp(catalog: demo ? demoCatalog() : staticCatalog(), settings: settings, themes: themes, safeMode: safe));
}
