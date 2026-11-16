import 'package:flutter/material.dart';

import 'data/catalog.dart';
import 'settings/launcher_settings.dart';
import 'settings/theme_file_service.dart';
import 'theme_engine/theme_engine.dart';
import 'ui/shell.dart';
import 'ui/theme/launcher_theme.dart';
import 'ui/theme/theme_source.dart';

/// แอป Launcher: สร้างธีมจากค่าตั้ง + ตัวควบคุมธีม (ไฟล์ `.nslt` ที่ `Documents\NSL\Themes`) และเปลี่ยนสดเมื่อมีอะไรเปลี่ยน
class LauncherApp extends StatelessWidget {
  const LauncherApp({super.key, required this.catalog, required this.settings, this.themes, this.safeMode = false, this.initialSection = Section.library, this.files = const SystemThemeFileService()});

  final Catalog catalog;
  final LauncherSettingsController settings;
  final NslThemeController? themes;
  final bool safeMode;
  final Section initialSection;
  final ThemeFileService files;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([settings, ?themes]),
      builder: (context, _) {
        final s = settings.value;
        final light = buildLauncherTheme(launcherTokens(s, themes, Brightness.light, safeMode: safeMode));
        final dark = buildLauncherTheme(launcherTokens(s, themes, Brightness.dark, safeMode: safeMode));
        return MaterialApp(
          title: 'NSL Launcher',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: switch (s.mode) {
            LauncherMode.dark => ThemeMode.dark,
            LauncherMode.light => ThemeMode.light,
            LauncherMode.system => ThemeMode.system,
          },
          themeAnimationDuration: Duration.zero,
          home: Builder(
            builder: (context) => LauncherShell(catalog: catalog, settings: settings, themes: themes, safeMode: safeMode, initialSection: initialSection, files: files),
          ),
        );
      },
    );
  }
}

/// สีที่ใช้ตัดสินว่าธีมถูกใช้จริงหรือไม่ (ให้เทสต์ตรวจ) — อ่านจากธีมที่ MaterialApp ใช้อยู่
Color accentOf(BuildContext context) => context.lt.c.accent;
