import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../theme_engine/theme_engine.dart';

/// โหมดสว่าง/มืดของ Launcher — ค่าเริ่มต้น **มืด** (ดีไซน์ของ Launcher เป็นธีมมืด)
enum LauncherMode {
  dark,
  light,
  system;

  static LauncherMode parse(Object? v) {
    for (final m in values) {
      if (m.name == v) return m;
    }
    return LauncherMode.dark;
  }
}

/// ธีมของ Launcher มาจากไหน
const kThemeSourceLauncher = 'launcher'; // ธีมของ Launcher เอง (nsl.launcher)
const kThemeSourceShared = 'shared'; // ตามธีมที่เลือกให้แอป NSL (ui-settings.json ร่วม)

/// ค่าตั้งของ Launcher เอง — เก็บแยกใน `launcher-settings.json` (ไม่ใช่ `ui-settings.json` ร่วม เพราะแอปอื่นเขียนทับทั้งไฟล์)
@immutable
class LauncherSettings {
  const LauncherSettings({this.themeSource = kThemeSourceLauncher, this.mode = LauncherMode.dark});

  /// [kThemeSourceLauncher] | [kThemeSourceShared] | id ธีม (ในตัวหรือของผู้ใช้)
  final String themeSource;
  final LauncherMode mode;

  LauncherSettings copyWith({String? themeSource, LauncherMode? mode}) =>
      LauncherSettings(themeSource: themeSource ?? this.themeSource, mode: mode ?? this.mode);

  static const _maxBytes = 4096;

  /// อ่านแบบไม่โยน: ไฟล์เสีย/ใหญ่เกิน/ค่าผิดรูปแบบ = ค่าเริ่มต้น
  static LauncherSettings parse(String source) {
    try {
      if (utf8.encode(source).length > _maxBytes) return const LauncherSettings();
      final j = jsonDecode(source);
      if (j is! Map) return const LauncherSettings();
      final t = j['themeSource'];
      final ok = t is String && (t == kThemeSourceLauncher || t == kThemeSourceShared || isValidThemeId(t));
      return LauncherSettings(themeSource: ok ? t : kThemeSourceLauncher, mode: LauncherMode.parse(j['mode']));
    } catch (_) {
      return const LauncherSettings();
    }
  }

  String toJson() => const JsonEncoder.withIndent('  ').convert({'schema': 1, 'themeSource': themeSource, 'mode': mode.name});

  @override
  bool operator ==(Object other) => other is LauncherSettings && themeSource == other.themeSource && mode == other.mode;

  @override
  int get hashCode => Object.hash(themeSource, mode);
}

/// ที่เก็บค่าตั้ง (ไฟล์ใน [root]) — เขียนแบบ atomic
class LauncherSettingsStore {
  LauncherSettingsStore(this.root);
  final Directory root;

  File get file => File('${root.path}${Platform.pathSeparator}launcher-settings.json');

  Future<LauncherSettings> load() async {
    try {
      if (!await file.exists() || await file.length() > 4096) return const LauncherSettings();
      return LauncherSettings.parse(await file.readAsString());
    } on FileSystemException {
      return const LauncherSettings();
    }
  }

  Future<void> save(LauncherSettings s) async {
    await root.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(s.toJson(), flush: true);
    await tmp.rename(file.path);
  }
}

/// ตัวควบคุมค่าตั้ง (ฟังได้) — [store] เป็น null = ไม่เก็บถาวร (เทสต์/เก็บไม่ได้)
class LauncherSettingsController extends ChangeNotifier {
  LauncherSettingsController(this.store, [LauncherSettings initial = const LauncherSettings()]) : _value = initial;

  final LauncherSettingsStore? store;
  LauncherSettings _value;

  LauncherSettings get value => _value;

  Future<void> load() async {
    final s = await store?.load();
    if (s != null && s != _value) {
      _value = s;
      notifyListeners();
    }
  }

  Future<void> update(LauncherSettings s) async {
    if (s == _value) return;
    _value = s;
    notifyListeners();
    try {
      await store?.save(s);
    } on FileSystemException {
      // เก็บไม่ได้ก็ใช้ค่าในหน่วยความจำต่อ ไม่ให้แอปล้ม
    }
  }
}
