import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../theme_engine/theme_engine.dart';

/// ผลการเลือกไฟล์ธีม: [text] = เนื้อไฟล์ ; [error] = ข้อความเมื่ออ่านไม่ได้/ใหญ่เกิน (ไม่อ่านไฟล์ที่ใหญ่เกินเข้าหน่วยความจำ)
class PickedTheme {
  const PickedTheme({required this.name, this.text, this.error});
  final String name;
  final String? text;
  final String? error;
}

/// เลือก/บันทึกไฟล์ธีมผ่านหน้าต่างของระบบ — แยกเป็น interface เพื่อให้เทสต์ใช้ของปลอมได้ (หน้าต่างของระบบทดสอบอัตโนมัติไม่ได้)
abstract interface class ThemeFileService {
  /// null = ผู้ใช้ยกเลิก
  Future<PickedTheme?> pickTheme();

  /// true = บันทึกแล้ว, false = ยกเลิก/บันทึกไม่ได้
  Future<bool> saveTheme(String fileName, String text);
}

class SystemThemeFileService implements ThemeFileService {
  const SystemThemeFileService();

  @override
  Future<PickedTheme?> pickTheme() async {
    final f = await FilePicker.pickFile(dialogTitle: 'นำเข้าไฟล์ธีม', type: FileType.custom, allowedExtensions: const ['nslt', 'json']);
    if (f == null) return null;
    final tooBig = PickedTheme(name: f.name, error: 'ไฟล์ใหญ่เกิน ${kNsltMaxBytes ~/ 1024} KB — ไฟล์ธีมไม่ควรใหญ่ขนาดนี้');
    try {
      // ตรวจขนาดก่อนอ่าน ไม่ดึงไฟล์ใหญ่เข้าหน่วยความจำ (ไฟล์ที่เลือกถือเป็นข้อมูลไม่น่าเชื่อถือ)
      final len = await f.length();
      if (len != null && len > kNsltMaxBytes) return tooBig;
      final bytes = await f.readAsBytes();
      if (bytes.length > kNsltMaxBytes) return tooBig;
      return PickedTheme(name: f.name, text: utf8.decode(bytes, allowMalformed: true));
    } catch (_) {
      return PickedTheme(name: f.name, error: 'อ่านไฟล์ไม่ได้');
    }
  }

  @override
  Future<bool> saveTheme(String fileName, String text) async {
    try {
      final uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode('$text\n')),
        mimeType: 'application/json',
        dialogTitle: 'ส่งออกไฟล์ธีม',
      );
      return uri != null;
    } catch (_) {
      return false;
    }
  }
}
