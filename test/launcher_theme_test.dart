import 'dart:ui';

import 'dart:typed_data';

import 'package:flutter/services.dart' show CachingAssetBundle, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:nsl_launcher/theme_engine/theme_engine.dart';

import 'support/builtins.dart';

NslTokens _r(NslThemeSpec s, Brightness b) => resolveTokens(s, b, lookup: builtinThemeById);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ธีม nsl.launcher (ตามดีไซน์)', () {
    test('โหมดมืดมีค่าตามดีไซน์ทุกตัว', () {
      final c = _r(kBuiltinLauncher, Brightness.dark).colors;
      expect(c.bg, const Color(0xFF071433));
      expect(c.chrome, const Color(0xFF050F28));
      expect(c.surface, const Color(0xFF0E1D45));
      expect(c.text, const Color(0xFFFFFFFF));
      expect(c.textMuted, const Color(0xFFA9B3D6));
      expect(c.accent, const Color(0xFFFFC83D));
      expect(c.onAccent, const Color(0xFF1A1300));
      expect(c.success, const Color(0xFF4FE3B0));
      expect(c.successText, const Color(0xFF7DF0C6));
      expect(c.infoText, const Color(0xFF9AD8FF));
      // ขอบเป็นสีขาวโปร่ง 8/12/16%
      expect((c.borderSoft.a * 255).round(), 0x14);
      expect((c.border.a * 255).round(), 0x1F);
      expect((c.borderStrong.a * 255).round(), 0x29);
    });

    test('โหมดมืดอ่านออกตามกติกา contrast (ตัวอักษร/ป้าย/ปุ่ม accent ผ่าน 4.5:1) และไม่ใช่ธีมที่ใช้ไม่ได้', () {
      final t = _r(kBuiltinLauncher, Brightness.dark);
      expect(isUnusable(t), isFalse);
      final fails = contrastFailures(t).map((f) => '${f.name} ${f.ratio.toStringAsFixed(2)}').toList();
      expect(fails, isEmpty, reason: 'ไม่ผ่าน: $fails');
    });

    test('โหมดสว่าง (ดีไซน์ไม่ได้ทำไว้) resolve ได้ ใช้งานได้ และอ่านออก', () {
      final t = _r(kBuiltinLauncher, Brightness.light);
      expect(isUnusable(t), isFalse);
      expect(contrastRatio(t.colors.text, t.colors.surface), greaterThan(7));
      expect(contrastRatio(t.colors.onAccent, t.colors.accent), greaterThanOrEqualTo(4.5));
      expect(contrastFailures(t).map((f) => f.name), isEmpty);
    });

    test('ธีมผู้ใช้ที่ extends nsl.launcher เปลี่ยน accent แล้วชุดที่ขึ้นกับ accent คำนวณใหม่', () {
      final child = parseNslt('{"schema":1,"id":"mint","name":"Mint","extends":"nsl.launcher","dark":{"colors":{"accent":"#4FE3B0"}}}').spec!;
      final t = resolveTokens(child, Brightness.dark, lookup: builtinThemeById);
      final base = _r(kBuiltinLauncher, Brightness.dark);
      expect(t.colors.accent, const Color(0xFF4FE3B0));
      expect(t.colors.accentTint, isNot(base.colors.accentTint));
      expect(t.colors.bg, base.colors.bg);
    });

    test('ค่า lite (preset) ชนะ accent ของธีม และใช้กับ Launcher ได้', () {
      final t = _r(kBuiltinLauncher.withAppearance(const NslAppearance(presetId: 'teal')), Brightness.dark);
      expect(t.colors.accent, accentPresetById('teal')!.dark.$1);
    });
  });

  group('ธีมในตัวของแอปอื่น (จาก asset ที่ core สร้าง)', () {
    test('โหลดจาก asset จริงผ่าน rootBundle ได้ครบ และไม่ทับ nsl.launcher', () async {
      registerCoreBuiltinThemes(const {}); // ล้างก่อน
      expect(builtinThemeById('nsl.nebular'), isNull);
      await loadCoreBuiltinThemes(rootBundle);
      for (final id in ['nsl.default', 'nsl.nebular', 'nsl.spectrum', 'nsl.lyra.paper']) {
        expect(builtinThemeById(id), isNotNull, reason: id);
      }
      expect(builtinThemeIds.first, kBuiltinLauncherId);
      expect(builtinThemeIds.length, 5);
      expect(builtinThemeById(kBuiltinLauncherId), same(kBuiltinLauncher));
    });

    test('รายการที่อ่านไม่ได้/id ไม่ตรง/ชนกับ nsl.launcher ถูกข้ามพร้อมรายงาน', () {
      final skipped = registerCoreBuiltinThemes({
        'nsl.ok': '{"schema":1,"id":"nsl.ok","name":"ok","light":{"colors":{"bg":"#FFFFFF","surface":"#FFFFFF","text":"#000000","accent":"#112233"}}}',
        'nsl.bad': 'not json',
        'nsl.mismatch': '{"schema":1,"id":"nsl.other","name":"x"}',
        kBuiltinLauncherId: '{"schema":1,"id":"nsl.launcher","name":"fake"}',
      });
      expect(skipped.toSet(), {'nsl.bad', 'nsl.mismatch', kBuiltinLauncherId});
      expect(builtinThemeById('nsl.ok'), isNotNull);
      expect(builtinThemeById(kBuiltinLauncherId)!.name, 'NSL Launcher'); // ของจริง ไม่ถูกทับ
      registerCoreForTests(); // คืนค่าสำหรับเทสต์อื่น
    });

    test('ไฟล์ asset เสีย/หายไม่ทำให้ล้ม — เหลือแค่ธีมของ Launcher', () async {
      registerCoreForTests();
      await loadCoreBuiltinThemes(_BrokenBundle());
      expect(builtinThemeIds, [kBuiltinLauncherId]);
      registerCoreForTests();
    });
  });
}

class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => throw Exception('no asset');
}
