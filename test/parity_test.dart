// พิสูจน์ว่า engine ธีมของ Launcher (port แยก ไม่พึ่ง nsl_ui) ให้ผลตรงกับ core ที่ระดับ 8 บิตต่อช่อง
// โดยเทียบกับ fixture กลางที่เทสต์ฝั่ง core สร้าง (test/fixtures/core-fixtures.json — ซิงก์ด้วย tool/sync_from_core.ps1)
// ชุดเดียวกับที่ใช้พิสูจน์ TS port ของเว็บ NSL Palette
//
// ไม่เทียบ: ค่า "ส่วนขยายของแอป" ที่ core คำนวณ (nebular/spectrum/lyra) เพราะ Launcher ไม่รู้จักส่วนขยาย
// (ส่งต่อค่าที่ไฟล์ระบุไว้โดยไม่แตะ — เทสต์ข้างล่างตรวจว่าไม่ทำของหาย) และ autoFix (Launcher ไม่มีตัวแก้สี)
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nsl_launcher/theme_engine/theme_engine.dart';

import 'support/builtins.dart';

void main() {
  late Map<String, dynamic> fx;
  late Map<String, NslThemeSpec> users;

  setUpAll(() {
    registerCoreForTests();
    fx = jsonDecode(File('test/fixtures/core-fixtures.json').readAsStringSync()) as Map<String, dynamic>;
    users = {
      for (final e in (fx['userThemes'] as Map<String, dynamic>).entries) e.key: parseNslt(e.value as String).spec!,
    };
  });

  NslThemeSpec? lookup(String id) => users[id] ?? builtinThemeById(id);
  String norm(String m) => m.startsWith('not valid JSON') ? 'not valid JSON' : m;

  test('เวอร์ชัน core/schema ที่ Launcher เข้าใจตรงกับ fixture', () {
    expect(kNslCoreVersion, fx['core']);
    expect(kNsltSchema, fx['schema']);
    expect(kCoreColorKeys.length, 30);
  });

  test('tint: accentTints / tintFor ตรงกับ core ทุกบิต', () {
    final rows = (fx['tint'] as List).cast<Map<String, dynamic>>();
    expect(rows.length, greaterThan(800));
    for (final r in rows) {
      final base = Color(r['base'] as int), dark = r['dark'] as bool;
      final a = accentTints(base, dark), t = tintFor(base, dark);
      final why = '${(r['base'] as int).toRadixString(16)} dark=$dark';
      expect([a.$1.toARGB32(), a.$2.toARGB32(), a.$3.toARGB32()], [r['accent'], r['soft'], r['ink']], reason: why);
      expect([t.$1.toARGB32(), t.$2.toARGB32()], [r['bg'], r['fg']], reason: why);
    }
  });

  test('resolveTokens: สี/รูปทรง/ตัวอักษร/density/เงา ตรงกับ core (ธีมในตัว ธีมผู้ใช้ ค่า lite ทุก preset ธีมเสีย × 2 โหมด)', () {
    final rows = (fx['resolve'] as List).cast<Map<String, dynamic>>();
    var ok = 0, err = 0;
    for (final r in rows) {
      final specId = r['spec'] as String;
      final base = lookup(specId);
      final why = '${r['label']} $specId ${r['brightness']} ${r['appearance'] ?? ''}';
      expect(base, isNotNull, reason: 'หาธีม $specId ไม่เจอ');
      final spec = r['appearance'] == null ? base! : base!.withAppearance(NslAppearance.fromJson(r['appearance']));
      final b = r['brightness'] == 'light' ? Brightness.light : Brightness.dark;
      if (r['error'] != null) {
        err++;
        expect(() => resolveTokens(spec, b, lookup: lookup), throwsA(isA<NslResolveException>().having((e) => e.message, 'message', r['error'])), reason: why);
        continue;
      }
      ok++;
      final t = resolveTokens(spec, b, lookup: lookup);
      final want = r['expected'] as Map<String, dynamic>;
      expect({for (final k in kCoreColorKeys) k: t.colors[k].toARGB32()}, want['colors'], reason: why);
      expect(t.shape.toMap(), (want['shape'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())), reason: why);
      final wt = want['type'] as Map<String, dynamic>;
      expect(t.type.family, wt['family'], reason: why);
      expect(t.type.content, wt['content'], reason: why);
      expect(t.type.mono, wt['mono'], reason: why);
      expect(t.type.scale, (wt['scale'] as num).toDouble(), reason: why);
      expect(t.type.minSize, (wt['minSize'] as num?)?.toDouble(), reason: why);
      expect(t.density.name, want['density'], reason: why);
      expect(t.elevation.mode.name, (want['elevation'] as Map)['mode'], reason: why);
      expect(t.elevation.strength, ((want['elevation'] as Map)['strength'] as num).toDouble(), reason: why);
    }
    expect(ok, greaterThan(100));
    expect(err, greaterThanOrEqualTo(6));
  });

  test('parseNslt / serializeNslt ตรงกับ core: ok, ข้อผิดพลาด, คำเตือน และข้อความที่เขียนกลับ (349 กรณี รวมสุ่มกลายพันธุ์)', () {
    final rows = (fx['parse'] as List).cast<Map<String, dynamic>>();
    var okCount = 0;
    for (final r in rows) {
      final src = r['source'] as String;
      final why = src.length > 100 ? '${src.substring(0, 100)}…' : src;
      final res = parseNslt(src);
      expect(res.ok, r['ok'], reason: why);
      expect(res.errors.map(norm).toList(), (r['errors'] as List).cast<String>(), reason: why);
      expect(res.warnings, (r['warnings'] as List).cast<String>(), reason: why);
      if (res.spec != null) {
        okCount++;
        expect(serializeNslt(res.spec!), r['serialized'], reason: why);
      }
    }
    expect(rows.length, greaterThan(300));
    expect(okCount, greaterThan(40));
  });

  test('contrast: รายงานและเกณฑ์ตรงกับ core', () {
    final rows = (fx['contrast'] as List).cast<Map<String, dynamic>>();
    for (final r in rows) {
      final spec = lookup(r['spec'] as String)!;
      final t = resolveTokens(spec, r['brightness'] == 'light' ? Brightness.light : Brightness.dark, lookup: lookup);
      final got = checkContrast(t);
      final want = (r['checks'] as List).cast<Map<String, dynamic>>();
      expect(got.map((c) => c.name).toList(), want.map((c) => c['name']).toList());
      for (var i = 0; i < got.length; i++) {
        expect(got[i].ratio, closeTo((want[i]['ratio'] as num).toDouble(), 1e-9), reason: '${r['spec']} ${got[i].name}');
        expect(got[i].passes, want[i]['passes']);
      }
      expect(isUnusable(t), r['unusable']);
    }
  });

  test('Launcher ไม่รู้จักส่วนขยาย แต่ไม่ทำของหาย: ค่าส่วนขยายในไฟล์ผ่าน resolve และเขียนกลับครบ', () {
    final spec = users['user.pinned']!; // มี extensions.lyra (accentDark, typePlace)
    final t = resolveTokens(spec, Brightness.light, lookup: lookup);
    expect(t.ext('lyra', 'accentDark'), const Color(0xFF123456));
    final out = serializeNslt(spec);
    expect(out, contains('"accentDark": "#123456"'));
    expect(out, contains('"typePlace": "#112233"'));
  });

  test('fixture ครอบคลุมจริง: ไฟล์ที่เช็กอินไม่ว่างเปล่า', () {
    expect((fx['resolve'] as List).length, greaterThan(150));
    expect((fx['userThemes'] as Map).length, greaterThan(10));
  });
}
