import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/catalog.dart';
import '../icons.dart';
import '../theme/launcher_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/widgets.dart';

/// หน้า "คลังโปรแกรม" (ดีไซน์ Main): หัวเรื่อง + ค้นหา, ชิปหมวด, ฮีโร่เปิดล่าสุด, รายการตามหมวด, แผงสถานะด้านขวา
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.catalog, required this.onOpenDetail});

  final Catalog catalog;
  final ValueChanged<String> onOpenDetail;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _query = TextEditingController();
  AppCategory? _category;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    final cat = widget.catalog;
    final results = cat.search(_query.text, category: _category);
    final filtering = _query.text.trim().isNotEmpty;
    final wide = MediaQuery.sizeOf(context).width > 900;
    final last = cat.lastOpened;

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (last != null && !filtering && _category == null) ...[
          _LastOpenedHero(app: last, onDetail: () => widget.onOpenDetail(last.id)),
          SizedBox(height: lt.space(32)),
        ],
        if (results.isEmpty)
          Panel(
            child: Text(filtering ? 'ไม่พบโปรแกรมที่ตรงกับ "${_query.text.trim()}"' : 'ยังไม่มีโปรแกรมในหมวดนี้', style: lt.ui(14, color: c.textMuted)),
          )
        else
          for (final category in AppCategory.values)
            if (results.any((a) => a.category == category)) ...[
              _CategorySection(
                category: category,
                apps: [for (final a in results) if (a.category == category) a],
                onOpenDetail: widget.onOpenDetail,
              ),
              SizedBox(height: lt.space(32)),
            ],
      ],
    );

    final aside = _StatusAside(catalog: cat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(controller: _query, onChanged: (_) => setState(() {})),
        SizedBox(height: lt.space(28)),
        _CategoryChips(selected: _category, onSelected: (v) => setState(() => _category = v)),
        SizedBox(height: lt.space(28)),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: main), SizedBox(width: lt.space(28)), SizedBox(width: 320, child: aside)])
        else ...[main, aside],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(header: true, child: Text('คลังโปรแกรม', style: lt.display(28))),
            const SizedBox(height: 4),
            Text('ทุกโปรแกรมของ NSL จัดตามหมวด', style: lt.ui(14, color: c.textMuted)),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Container(
            constraints: BoxConstraints(minHeight: lt.controlHeight, minWidth: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(lt.radius(12)), border: Border.all(color: c.border)),
            child: Row(
              children: [
                LIcon('search', size: 18, color: c.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    textField: true,
                    label: 'ค้นหาโปรแกรม',
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      cursorColor: c.accent,
                      style: lt.ui(14),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'ค้นหาโปรแกรม',
                        hintStyle: lt.ui(14, color: c.textMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final AppCategory? selected;
  final ValueChanged<AppCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    Widget chip(String label, AppCategory? value) {
      final on = selected == value;
      return TapArea(
        label: 'กรอง: $label',
        selected: on,
        minHeight: lt.controlHeight < 44 ? lt.controlHeight : 40,
        onTap: () => onSelected(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: on ? c.text : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? c.text : c.borderStrong),
          ),
          child: Center(widthFactor: 1, child: Text(label, style: lt.ui(14, weight: on ? FontWeight.w600 : FontWeight.w400, color: on ? c.bg : c.textMuted))),
        ),
      );
    }

    return Semantics(
      container: true,
      label: 'กรองตามหมวด',
      child: Wrap(spacing: 10, runSpacing: 10, children: [
        chip('ทั้งหมด', null),
        for (final a in AppCategory.values) chip(a.label, a),
      ]),
    );
  }
}

/// ฮีโร่ "เปิดล่าสุด" — พื้นเข้มของตัวเองเสมอ (ตกแต่งประจำแบรนด์ ไม่ผูกกับธีม)
class _LastOpenedHero extends StatelessWidget {
  const _LastOpenedHero({required this.app, required this.onDetail});

  final CatalogApp app;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt;
    return Semantics(
      container: true,
      label: 'เปิดล่าสุด ${app.name}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(lt.radius(24)),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment(-1, -0.4),
              end: Alignment(1, 0.4),
              colors: [Color(0xFF0E3B4F), Color(0xFF0B2347), Color(0xFF0E1D45)],
              stops: [0, 0.55, 1],
            ),
            border: Border.all(color: LauncherTheme.mint.withValues(alpha: 0.22)),
            borderRadius: BorderRadius.circular(lt.radius(24)),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -90,
                top: -120,
                child: Opacity(opacity: 0.5, child: ExcludeSemantics(child: SvgPicture.string(_ringsSvg, width: 420, height: 420))),
              ),
              Padding(
                padding: EdgeInsets.all(lt.space(32)),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 28,
                  runSpacing: 20,
                  children: [
                    AppIcon(app.iconAsset, size: 112),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560, minWidth: 240),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('เปิดล่าสุด · หมวด ${app.category.label.toUpperCase()}', style: lt.display(13, weight: FontWeight.w500, color: LauncherTheme.mintText, letterSpacing: 1.5)),
                          const SizedBox(height: 10),
                          Text(app.name, style: lt.display(34, color: LauncherTheme.heroText)),
                          const SizedBox(height: 10),
                          Text(app.description, style: lt.ui(15, color: LauncherTheme.heroBody, height: 1.6)),
                          const SizedBox(height: 16),
                          Wrap(spacing: 12, runSpacing: 12, children: [
                            primaryActionForHero(app),
                            LButton(label: 'รายละเอียด', onPressed: onDetail),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ปุ่มหลักของฮีโร่: เปิดโปรแกรม (ยังไม่ทำงานจนกว่าเฟส 4 — ปิดไว้)
Widget primaryActionForHero(CatalogApp app) => LButton(label: app.canOpen ? 'เปิดโปรแกรม' : 'ติดตั้ง', icon: app.canOpen ? 'play' : 'download', kind: LButtonKind.primary);

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.apps, required this.onOpenDetail});

  final AppCategory category;
  final List<CatalogApp> apps;
  final ValueChanged<String> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    final (ring, size) = switch (category) {
      AppCategory.media => (LauncherTheme.sky, 14.0),
      AppCategory.life => (LauncherTheme.mint, 19.0),
      AppCategory.create => (LauncherTheme.pink, 24.0),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
          ExcludeSemantics(child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: 2)))),
          Semantics(header: true, child: Text('หมวด ${category.label}', style: lt.display(20))),
          Text(category.subtitle, style: lt.ui(13, color: c.textMuted)),
        ]),
        SizedBox(height: lt.space(14)),
        LayoutBuilder(builder: (context, box) {
          // ตาราง auto-fill ขั้นต่ำ 300 ช่องว่าง 16 (ตามดีไซน์)
          final cols = ((box.maxWidth + 16) / (300 + 16)).floor().clamp(1, 6);
          final w = (box.maxWidth - 16 * (cols - 1)) / cols;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            for (final a in apps) SizedBox(width: w, child: AppCard(app: a, onOpenDetail: () => onOpenDetail(a.id))),
          ]);
        }),
      ],
    );
  }
}

/// แผงด้านขวา: อัปเดตที่รอ / กำลังดาวน์โหลด / มือถือที่เชื่อมต่อ — แสดงเฉพาะที่มีข้อมูลจริง (ไม่แต่งตัวอย่างขึ้นมา)
class _StatusAside extends StatelessWidget {
  const _StatusAside({required this.catalog});

  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    final updates = catalog.updates;
    final panels = <Widget>[
      if (updates.isNotEmpty)
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Semantics(header: true, child: Text('อัปเดตที่รอ', style: lt.ui(16, weight: FontWeight.w600))),
            const SizedBox(height: 14),
            for (final a in updates) ...[
              Row(children: [
                AppIcon(a.iconAsset, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.name, style: lt.ui(14, weight: FontWeight.w600)),
                    Text('${a.installedVersion ?? '—'} → ${a.latestVersion ?? '—'}', style: lt.ui(12, color: c.textMuted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
            ],
            const LButton(label: 'อัปเดตทั้งหมด', icon: 'refresh'),
          ]),
        ),
      if (catalog.downloads.isNotEmpty)
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Semantics(header: true, child: Text('กำลังดาวน์โหลด', style: lt.ui(16, weight: FontWeight.w600))),
            const SizedBox(height: 14),
            for (final d in catalog.downloads) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(catalog.byId(d.appId)?.name ?? d.appId, style: lt.ui(13, color: c.text.withValues(alpha: 0.85))),
                Text('${(d.progress * 100).round()}%', style: lt.ui(13, color: c.text.withValues(alpha: 0.85))),
              ]),
              const SizedBox(height: 8),
              LProgress(value: d.progress, label: 'ดาวน์โหลด ${catalog.byId(d.appId)?.name ?? d.appId}'),
            ],
          ]),
        ),
      if (catalog.devices.isNotEmpty)
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Semantics(header: true, child: Text('มือถือที่เชื่อมต่อ', style: lt.ui(16, weight: FontWeight.w600))),
            const SizedBox(height: 12),
            for (final d in catalog.devices)
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.infoBg, borderRadius: BorderRadius.circular(lt.radius(12))),
                  alignment: Alignment.center,
                  child: LIcon('phone', color: c.infoText),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, style: lt.ui(14, color: c.text.withValues(alpha: 0.85))),
                  Text(d.online ? 'ออนไลน์ในเครือข่าย LAN' : 'ออฟไลน์', style: lt.ui(12, color: d.online ? c.successText : c.textMuted)),
                ]),
              ]),
            const SizedBox(height: 12),
            Text('ใช้ส่งไฟล์ติดตั้ง Orbit และสตรีมจาก Spectrum', style: lt.ui(13, color: c.textMuted, height: 1.6)),
          ]),
        ),
    ];
    if (panels.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < panels.length; i++) ...[if (i > 0) const SizedBox(height: 16), panels[i]],
    ]);
  }
}

const _ringsSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 420 420">'
    '<ellipse cx="210" cy="210" rx="200" ry="70" transform="rotate(-24 210 210)" fill="none" stroke="#4FE3B0" stroke-opacity="0.35" stroke-width="2"/>'
    '<ellipse cx="210" cy="210" rx="150" ry="50" transform="rotate(-24 210 210)" fill="none" stroke="#FFC83D" stroke-opacity="0.4" stroke-width="2"/>'
    '<circle cx="210" cy="210" r="46" fill="#FFC83D" fill-opacity="0.18"/></svg>';
