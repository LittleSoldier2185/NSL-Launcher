import 'dart:convert';
import 'dart:io';

import 'package:nsl_launcher/theme_engine/theme_engine.dart';

/// ลงทะเบียนธีมในตัวของแอปอื่นจาก assets/core/builtin-themes.json (เหมือนที่แอปทำตอนเปิด แต่อ่านไฟล์ตรง ๆ ในเทสต์)
void registerCoreForTests() {
  final j = jsonDecode(File('assets/core/builtin-themes.json').readAsStringSync()) as Map<String, dynamic>;
  final skipped = registerCoreBuiltinThemes({for (final e in j.entries) e.key: e.value as String});
  if (skipped.isNotEmpty) throw StateError('ธีมในตัวที่อ่านไม่ได้: $skipped');
}
