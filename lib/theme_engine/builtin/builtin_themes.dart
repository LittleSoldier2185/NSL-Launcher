import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show AssetBundle;

import '../format/nslt_codec.dart';
import '../format/theme_spec.dart';

/// ธีมในตัวของ Launcher
///
/// - `nsl.launcher` เป็นของ Launcher เอง (แบรนด์ตามดีไซน์) นิยามที่นี่
/// - ธีมในตัวของแอปอื่น (`nsl.default`, `nsl.nebular`, `nsl.spectrum`, `nsl.lyra.paper`) **ไม่คัดลอกค่าสีมาไว้** — อ่านจาก
///   `assets/core/builtin-themes.json` ที่ฝั่ง core สร้าง (ซิงก์ด้วย tool/sync_from_core.ps1) เพื่อให้ไฟล์ธีมที่ `extends` ธีมเหล่านี้ใช้ได้
const kBuiltinLauncherId = 'nsl.launcher';
const kBuiltinDefaultId = 'nsl.default';

const _asset = 'assets/core/builtin-themes.json';

/// ธีมของ Launcher: โหมดมืดตามดีไซน์ทุกค่า ; โหมดสว่าง **ดีไซน์ไม่ได้ทำไว้** — กำหนดแค่สีหลัก ที่เหลือคำนวณจาก token
final NslThemeSpec kBuiltinLauncher = NslThemeSpec(
  id: kBuiltinLauncherId,
  name: 'NSL Launcher',
  core: kNslCoreVersion,
  dark: const NslModeSpec(
    colors: {
      'bg': Color(0xFF071433), // พื้นหน้า
      'chrome': Color(0xFF050F28), // แถบข้าง
      'surface': Color(0xFF0E1D45), // การ์ด/แผง
      'borderSoft': Color(0x14FFFFFF), // ขาว 8%
      'border': Color(0x1FFFFFFF), // ขาว 12%
      'borderStrong': Color(0x29FFFFFF), // ขาว 16%
      'text': Color(0xFFFFFFFF),
      'textMuted': Color(0xFFA9B3D6),
      'icon': Color(0xFFA9B3D6),
      'hover': Color(0x0FFFFFFF), // ขาว 6%
      'selected': Color(0x1FFFC83D), // accent 12%
      'accent': Color(0xFFFFC83D),
      'accentInk': Color(0xFFFFC83D),
      'accentTint': Color(0x29FFC83D), // accent 16%
      'accentBorder': Color(0x59FFC83D), // accent 35%
      'onAccent': Color(0xFF1A1300),
      'success': Color(0xFF4FE3B0),
      'successBg': Color(0x244FE3B0), // 14%
      'successText': Color(0xFF7DF0C6),
      'infoBg': Color(0x246EC8FF),
      'infoText': Color(0xFF9AD8FF),
      'warnBg': Color(0x29FFC83D),
      'warnText': Color(0xFFFFC83D),
      'shadow': Color(0xFF000000),
    },
  ),
  light: const NslModeSpec(
    colors: {
      'bg': Color(0xFFEEF2FA),
      'chrome': Color(0xFFE2E8F5),
      'surface': Color(0xFFFFFFFF),
      'text': Color(0xFF0B1633),
      'textMuted': Color(0xFF4A5578),
      'accent': Color(0xFFFFC83D),
      'onAccent': Color(0xFF1A1300),
    },
  ),
);

final Map<String, NslThemeSpec> _core = {};

/// ลงทะเบียนธีมในตัวที่มาจาก core (id → ข้อความ .nslt) ; ที่อ่านไม่ได้หรือชนกับ `nsl.launcher` ถูกข้าม (คืนรายการที่ข้าม)
List<String> registerCoreBuiltinThemes(Map<String, String> texts) {
  final skipped = <String>[];
  _core.clear();
  for (final e in texts.entries) {
    final spec = parseNslt(e.value).spec;
    if (spec == null || spec.id != e.key || e.key == kBuiltinLauncherId) {
      skipped.add(e.key);
      continue;
    }
    _core[e.key] = spec;
  }
  return skipped;
}

/// โหลดจาก asset ตอนเปิดแอป (ล้มเหลว = มีแค่ธีมของ Launcher เอง ไฟล์ธีมที่ extends ธีมอื่นจะ resolve ไม่ได้และถอยไปธีมของ Launcher)
Future<void> loadCoreBuiltinThemes(AssetBundle bundle) async {
  try {
    final j = jsonDecode(await bundle.loadString(_asset));
    if (j is Map) registerCoreBuiltinThemes({for (final e in j.entries) if (e.value is String) '${e.key}': e.value as String});
  } catch (_) {
    _core.clear();
  }
}

NslThemeSpec? builtinThemeById(String id) => id == kBuiltinLauncherId ? kBuiltinLauncher : _core[id];

/// id ของธีมในตัวทั้งหมดที่ใช้ได้ตอนนี้ (Launcher ก่อน)
List<String> get builtinThemeIds => [kBuiltinLauncherId, ..._core.keys];
