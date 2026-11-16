import 'dart:ui';

import '../../settings/launcher_settings.dart';
import '../../theme_engine/theme_engine.dart';

/// หาธีมที่ Launcher ใช้จริงของโหมด [brightness] ตามค่าตั้ง — **ไม่โยน** และอ่านออกเสมอ:
/// ธีมหาย/resolve ไม่ผ่าน/อ่านไม่ออก (ตัวอักษรหลักต่ำกว่า 3:1) = ถอยไปธีมของ Launcher เอง ; [safeMode] = ธีมของ Launcher ล้วน ๆ
///
/// ลำดับ: ธีมในตัว < ไฟล์ธีมที่ผู้ใช้เลือก < ค่า lite (เฉพาะเมื่อ "ตามธีมที่เลือกให้แอป" เพราะ lite เป็นของแอปชุดเดียวกัน)
NslTokens launcherTokens(LauncherSettings s, NslThemeController? themes, Brightness brightness, {bool safeMode = false}) {
  NslTokens brand() => resolveTokens(kBuiltinLauncher, brightness, lookup: builtinThemeById);
  if (safeMode) return brand();

  NslThemeSpec? spec;
  NslThemeLookup lookup = themes?.lookup ?? builtinThemeById;
  switch (s.themeSource) {
    case kThemeSourceLauncher:
      spec = kBuiltinLauncher;
    case kThemeSourceShared:
      spec = themes?.effective(kBuiltinLauncher);
    default:
      spec = lookup(s.themeSource);
  }
  if (spec == null) return brand();
  try {
    final t = resolveTokens(spec, brightness, lookup: lookup);
    return isUnusable(t) ? brand() : t;
  } on NslResolveException {
    return brand();
  }
}

/// ชื่อที่แสดงของธีมตัวเลือก (หาไม่เจอ = id)
String themeDisplayName(String id, NslThemeController? themes) => themes?.lookup(id)?.name ?? builtinThemeById(id)?.name ?? id;
