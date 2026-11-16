import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/catalog.dart';
import '../settings/launcher_settings.dart';
import '../settings/theme_file_service.dart';
import '../theme_engine/theme_engine.dart';
import 'icons.dart';
import 'pages/detail_page.dart';
import 'pages/library_page.dart';
import 'pages/settings_page.dart';
import 'theme/launcher_theme.dart';
import 'widgets/widgets.dart';

enum Section { library, updates, downloads, settings }

/// โครงหน้าจอ: แถบข้างซ้าย 248px + เนื้อหา ; จอแคบ (≤ 900px) แถบข้างย้ายไปอยู่บนสุดแบบแถวที่ตัดบรรทัดได้
class LauncherShell extends StatefulWidget {
  const LauncherShell({super.key, required this.catalog, required this.settings, required this.themes, this.safeMode = false, this.initialSection = Section.library, this.files = const SystemThemeFileService()});

  final Catalog catalog;
  final LauncherSettingsController settings;
  final NslThemeController? themes;
  final bool safeMode;
  final Section initialSection;
  final ThemeFileService files;

  @override
  State<LauncherShell> createState() => _LauncherShellState();
}

class _LauncherShellState extends State<LauncherShell> {
  late Section _section = widget.initialSection;
  String? _detailId;

  void _go(Section s) => setState(() {
        _section = s;
        _detailId = null;
      });

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width > 900;
    final updates = widget.catalog.updates.length;
    final sidebar = _Sidebar(wide: wide, section: _section, updateCount: updates, onSelect: _go);

    final detail = _section == Section.library && _detailId != null ? widget.catalog.byId(_detailId!) : null;
    final Widget page = switch (_section) {
      Section.library => detail != null
          ? DetailPage(app: detail, catalog: widget.catalog, onBack: () => setState(() => _detailId = null), onOpenDetail: (id) => setState(() => _detailId = id))
          : LibraryPage(catalog: widget.catalog, onOpenDetail: (id) => setState(() => _detailId = id)),
      Section.settings => SettingsPage(settings: widget.settings, themes: widget.themes, safeMode: widget.safeMode, files: widget.files),
      Section.updates => const _SoonPage(title: 'อัปเดต', subtitle: 'โปรแกรมที่มีเวอร์ชันใหม่'),
      Section.downloads => const _SoonPage(title: 'ดาวน์โหลด', subtitle: 'ความคืบหน้าและประวัติการดาวน์โหลด'),
    };

    final hPad = (width * 0.03).clamp(20.0, 40.0);
    final content = Stack(children: [
      // แสงม่วงจาง ๆ มุมขวาบนตามดีไซน์ (ตกแต่งประจำแบรนด์ เฉพาะโหมดมืด)
      if (lt.isDark)
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(center: const Alignment(0.6, -1.0), radius: 0.9, colors: [const Color(0xFF5B3DF5).withValues(alpha: 0.16), Colors.transparent], stops: const [0, 0.7]),
              ),
            ),
          ),
        ),
      Positioned.fill(
        child: SingleChildScrollView(
          // คีย์ตามหน้า/โปรแกรมที่เปิด: เปลี่ยนหน้าแล้วเลื่อนกลับบนสุด (ไม่งั้นเปิดรายละเอียดจากคลังที่เลื่อนลงไปแล้วจะค้างกลางหน้า)
          key: ValueKey('${_section.name}/${_detailId ?? ''}'),
          primary: true,
          padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 48),
          child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: math.max(width, 0)), child: page)),
        ),
      ),
    ]);

    return Material(
      color: c.bg,
      child: wide
          ? Row(children: [SizedBox(width: 248, child: sidebar), Expanded(child: content)])
          : Column(children: [sidebar, Expanded(child: content)]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.wide, required this.section, required this.updateCount, required this.onSelect});

  final bool wide;
  final Section section;
  final int updateCount;
  final ValueChanged<Section> onSelect;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    final brand = Row(mainAxisSize: MainAxisSize.min, children: [
      ExcludeSemantics(child: SvgPicture.asset('assets/images/logo.svg', width: 40, height: 40)),
      const SizedBox(width: 12),
      // Flexible + ellipsis: ฟอนต์/ขนาดตัวอักษรของธีมผู้ใช้ทำให้ข้อความกว้างขึ้นได้ ต้องไม่ล้นแถบข้าง (248px)
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('NSL Launcher', style: lt.display(18), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('Northern Star Laboratory', style: lt.ui(12, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
    final items = [
      (Section.library, 'grid', 'คลังโปรแกรม', 0),
      (Section.updates, 'refresh', 'อัปเดต', updateCount),
      (Section.downloads, 'download', 'ดาวน์โหลด', 0),
      (Section.settings, 'settings', 'ตั้งค่า', 0),
    ];
    final nav = Semantics(
      container: true,
      label: 'เมนูหลัก',
      child: wide
          ? Column(children: [for (final i in items) Padding(padding: const EdgeInsets.only(bottom: 6), child: _NavButton(icon: i.$2, label: i.$3, badge: i.$4, selected: section == i.$1, onTap: () => onSelect(i.$1)))])
          : Wrap(spacing: 6, runSpacing: 6, children: [for (final i in items) _NavButton(icon: i.$2, label: i.$3, badge: i.$4, selected: section == i.$1, onTap: () => onSelect(i.$1), compact: true)]),
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: wide ? 24 : 12),
      decoration: BoxDecoration(color: c.chrome, border: wide ? Border(right: BorderSide(color: c.borderSoft)) : Border(bottom: BorderSide(color: c.borderSoft))),
      child: wide
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: brand), const SizedBox(height: 28), nav])
          : SizedBox(width: double.infinity, child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 24, runSpacing: 8, children: [brand, nav])),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.badge, required this.selected, required this.onTap, this.compact = false});

  final String icon, label;
  final int badge;
  final bool selected, compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    final fg = selected ? c.text : c.textMuted;
    return TapArea(
      label: badge > 0 ? '$label ($badge)' : label,
      selected: selected,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? c.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(lt.radius(12)),
          border: Border.all(color: selected ? c.accentBorder : Colors.transparent),
        ),
        child: Row(mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max, children: [
          LIcon(icon, color: fg),
          const SizedBox(width: 12),
          Text(label, style: lt.ui(15, color: fg)),
          if (badge > 0) ...[
            if (!compact) const Spacer() else const SizedBox(width: 12),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(11)),
              alignment: Alignment.center,
              child: Text('$badge', style: lt.ui(12, weight: FontWeight.w600, color: c.onAccent)),
            ),
          ],
        ]),
      ),
    );
  }
}

class _SoonPage extends StatelessWidget {
  const _SoonPage({required this.title, required this.subtitle});

  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text(title, style: lt.display(28))),
      const SizedBox(height: 4),
      Text(subtitle, style: lt.ui(14, color: c.textMuted)),
      SizedBox(height: lt.space(28)),
      Panel(child: Text('ส่วนนี้จะใช้งานได้เมื่อเชื่อมต่อรายการโปรแกรมและระบบติดตั้ง (กำลังพัฒนา)', style: lt.ui(14, color: c.textMuted))),
    ]);
  }
}
