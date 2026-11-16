import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// ไอคอนเส้น (stroke) ตามดีไซน์ — path เดียวกับใน Design canvas ; สีและความหนาเส้นกำหนดตอนวาด
const _paths = <String, String>{
  'grid': '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
  'refresh': '<path d="M21 12a9 9 0 1 1-3-6.7"/><path d="M21 4v5h-5"/>',
  'download': '<path d="M12 3v12"/><path d="M7 10l5 5 5-5"/><path d="M4 20h16"/>',
  'settings':
      '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
  'search': '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>',
  'play': '<path d="M7 5l12 7-12 7z"/>',
  'back': '<path d="M15 18l-6-6 6-6"/>',
  'dots': '<circle cx="5" cy="12" r="1.2"/><circle cx="12" cy="12" r="1.2"/><circle cx="19" cy="12" r="1.2"/>',
  'check': '<path d="M5 12l5 5 9-10"/>',
  'phone': '<rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/>',
  'folder': '<path d="M3 6a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
};

/// ชื่อไอคอนที่มี (ให้เทสต์ตรวจ)
List<String> get launcherIconNames => _paths.keys.toList();

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// ไอคอนเส้นขนาด [size] สี [color] — ตกแต่งอย่างเดียว (ซ่อนจาก screen reader) ; ปุ่มต้องมีข้อความ/Semantics ของตัวเอง
class LIcon extends StatelessWidget {
  const LIcon(this.name, {super.key, this.size = 20, required this.color, this.strokeWidth = 1.8});

  final String name;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final body = _paths[name];
    assert(body != null, 'ไม่มีไอคอน "$name"');
    final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="${_hex(color)}" '
        'stroke-opacity="${(color.a).toStringAsFixed(3)}" stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">${body ?? ''}</svg>';
    return ExcludeSemantics(child: SvgPicture.string(svg, width: size, height: size));
  }
}
