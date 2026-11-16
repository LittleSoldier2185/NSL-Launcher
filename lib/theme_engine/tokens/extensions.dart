// PORT จาก NSL-UI (core) — NSL Launcher ไม่พึ่งแพ็กเกจ nsl_ui ตั้งใจ ; ตรวจว่าตรงกับ core ด้วย fixture กลาง (test/parity_test.dart)
// ซิงก์ใหม่ด้วย tool/sync_from_core.ps1 แล้วดูผลต่างก่อนรวม — อย่าแก้สูตรที่นี่โดยไม่แก้ที่ core
import 'dart:ui';

import 'color_tokens.dart';

/// นิยามส่วนขยาย token เฉพาะแอป — Launcher ไม่รู้จักส่วนขยายใดเลย (ส่งต่อค่าที่ไฟล์ระบุโดยไม่แตะ ไม่คำนวณค่า derive)
class NslExtensionDef {
  const NslExtensionDef(this.name, this.keys, this.derive, {this.accentDependents = const []});

  final String name;
  final List<String> keys;
  final List<String> accentDependents;
  final Map<String, Color> Function(NslColors core, Brightness brightness) derive;
}

const kKnownExtensions = <NslExtensionDef>[];
