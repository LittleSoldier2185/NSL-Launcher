import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../icons.dart';
import '../theme/launcher_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/widgets.dart';

/// หน้า "รายละเอียดโปรแกรม" (ดีไซน์ Detail): เส้นทาง, ฮีโร่, แท็บ, ภาพรวม/มีอะไรใหม่/ตั้งค่า, แผงข้อมูลด้านขวา
class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.app, required this.catalog, required this.onBack, required this.onOpenDetail});

  final CatalogApp app;
  final Catalog catalog;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenDetail;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

enum _Tab { overview, whatsNew, settings }

class _DetailPageState extends State<DetailPage> {
  _Tab _tab = _Tab.overview;

  @override
  void didUpdateWidget(DetailPage old) {
    super.didUpdateWidget(old);
    if (old.app.id != widget.app.id) _tab = _Tab.overview;
  }

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    final app = widget.app;
    final wide = MediaQuery.sizeOf(context).width > 900;

    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      switch (_tab) {
        _Tab.overview => _Overview(app: app, catalog: widget.catalog, onOpenDetail: widget.onOpenDetail),
        _Tab.whatsNew => _WhatsNew(app: app),
        _Tab.settings => const _Soon(text: 'ตั้งค่าโปรแกรมของแต่ละแอปจะมาในเวอร์ชันถัดไป'),
      },
    ]);
    final aside = _InfoAside(app: app);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
        TapArea(
          label: 'กลับไปคลังโปรแกรม',
          onTap: widget.onBack,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              LIcon('back', color: c.textMuted),
              const SizedBox(width: 6),
              Text('คลังโปรแกรม', style: lt.ui(14, color: c.textMuted)),
            ]),
          ),
        ),
        Text('/', style: lt.ui(14, color: c.textMuted)),
        Text(app.name, style: lt.ui(14)),
      ]),
      SizedBox(height: lt.space(28)),
      _Hero(app: app),
      SizedBox(height: lt.space(28)),
      _Tabs(selected: _tab, onSelected: (t) => setState(() => _tab = t)),
      SizedBox(height: lt.space(28)),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), SizedBox(width: lt.space(28)), SizedBox(width: 320, child: aside)])
      else ...[left, SizedBox(height: lt.space(28)), aside],
    ]);
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.app});
  final CatalogApp app;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt;
    // พื้นฮีโร่ = สีประจำแอปผสมกรมท่าให้เข้ม (ตกแต่งประจำแบรนด์ ไม่ผูกกับธีม) + แสงสีชมพู/ฟ้าตามดีไซน์
    final base = Color.lerp(Color(app.brand), LauncherTheme.nightBlue, app.id == 'nebular' ? 0 : 0.7)!;
    return Semantics(
      container: true,
      label: app.name,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(lt.radius(28)),
        child: Container(
          decoration: BoxDecoration(color: base, border: Border.all(color: LauncherTheme.heroText.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(lt.radius(28))),
          child: Stack(children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(center: const Alignment(0.7, -0.8), radius: 1.1, colors: [LauncherTheme.pink.withValues(alpha: 0.35), Colors.transparent], stops: const [0, 0.6]),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(center: const Alignment(0.1, 1.0), radius: 0.9, colors: [LauncherTheme.sky.withValues(alpha: 0.28), Colors.transparent], stops: const [0, 0.6]),
                ),
              ),
            ),
            Positioned.fill(child: ExcludeSemantics(child: CustomPaint(painter: _Stars()))),
            Padding(
              padding: EdgeInsets.fromLTRB(lt.space(36), lt.space(40), lt.space(36), lt.space(32)),
              child: LayoutBuilder(builder: (context, box) {
                final text = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _HeroTag('หมวด ${app.category.label}'),
                    _HeroTag(app.platform.label),
                    // ป้ายสถานะ: ดีไซน์มีเฉพาะ "มีอัปเดต" (สีเหลือง) — สถานะอื่นใช้ป้ายธรรมดารูปแบบเดียวกัน
                    if (app.state == InstallState.updateAvailable)
                      const _HeroTag('มีอัปเดต', accent: true)
                    else if (app.state != InstallState.notInstalled)
                      _HeroTag(statusLabel(app.state)),
                  ]),
                  const SizedBox(height: 10),
                  Semantics(header: true, child: Text(app.name, style: lt.display(40, color: LauncherTheme.heroText))),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(app.description, style: lt.ui(16, color: const Color(0xFFE1E4F5), height: 1.6)),
                  ),
                ]);
                final actions = Wrap(spacing: 12, runSpacing: 12, children: [
                  heroAction(app),
                  const LButton(label: 'ตัวเลือกเพิ่มเติม', icon: 'dots', semanticLabel: 'ตัวเลือกเพิ่มเติม'),
                ]);
                if (box.maxWidth >= 880) {
                  return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    AppIcon(app.iconAsset, size: 136),
                    const SizedBox(width: 28),
                    Expanded(child: text),
                    const SizedBox(width: 28),
                    actions,
                  ]);
                }
                return Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 28, runSpacing: 24, children: [
                  AppIcon(app.iconAsset, size: 136),
                  ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth > 240 ? box.maxWidth : 240, minWidth: 0), child: text),
                  actions,
                ]);
              }),
            ),
          ]),
        ),
      ),
    );
  }
}

/// ปุ่มหลักของฮีโร่ตามสถานะ (ยังไม่ทำงานจนกว่าเฟส 4 — ปิดไว้)
Widget heroAction(CatalogApp app) => switch (app.state) {
      InstallState.updateAvailable => const LButton(label: 'อัปเดตและเปิด', icon: 'refresh', kind: LButtonKind.primary),
      InstallState.installed => const LButton(label: 'เปิดโปรแกรม', icon: 'play', kind: LButtonKind.primary),
      InstallState.mobileOnly => const LButton(label: 'ส่งไปมือถือ', icon: 'phone', kind: LButtonKind.primary),
      InstallState.inDevelopment => const LButton(label: 'เร็ว ๆ นี้', kind: LButtonKind.soon),
      InstallState.notInstalled => const LButton(label: 'ติดตั้ง', icon: 'download', kind: LButtonKind.primary),
    };

class _HeroTag extends StatelessWidget {
  const _HeroTag(this.text, {this.accent = false});
  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: accent ? const Color(0x29FFC83D) : const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(13)),
      child: Center(widthFactor: 1, child: Text(text, style: lt.ui(12, weight: FontWeight.w500, color: accent ? const Color(0xFFFFC83D) : LauncherTheme.heroMuted))),
    );
  }
}

class _Stars extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    // ตำแหน่งดาวตามดีไซน์ (สัดส่วนของกรอบ 1440×300)
    const stars = [(0.82, 0.2, 2.0, 0.7), (0.68, 0.13, 1.5, 0.5), (0.92, 0.6, 1.5, 0.6), (0.53, 0.3, 1.0, 0.5), (0.86, 0.83, 2.0, 0.4), (0.61, 0.67, 1.0, 0.6)];
    for (final (x, y, r, o) in stars) {
      p.color = Colors.white.withValues(alpha: o);
      canvas.drawCircle(Offset(size.width * x, size.height * y), r, p);
    }
  }

  @override
  bool shouldRepaint(_Stars old) => false;
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelected});

  final _Tab selected;
  final ValueChanged<_Tab> onSelected;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    const names = {_Tab.overview: 'ภาพรวม', _Tab.whatsNew: 'มีอะไรใหม่', _Tab.settings: 'ตั้งค่าโปรแกรม'};
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderSoft))),
      child: Semantics(
        container: true,
        label: 'ส่วนของหน้า',
        child: Wrap(spacing: 28, children: [
          for (final t in _Tab.values)
            TapArea(
              label: names[t]!,
              selected: selected == t,
              onTap: () => onSelected(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected == t ? c.accent : Colors.transparent, width: 2))),
                child: Center(widthFactor: 1, child: Text(names[t]!, style: lt.ui(15, weight: selected == t ? FontWeight.w600 : FontWeight.w400, color: selected == t ? c.text : c.textMuted))),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.app, required this.catalog, required this.onOpenDetail});

  final CatalogApp app;
  final Catalog catalog;
  final ValueChanged<String> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    final same = [for (final a in catalog.inCategory(app.category)) if (a.id != app.id) a];
    Widget h2(String t) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Semantics(header: true, child: Text(t, style: lt.display(20))));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (app.features.isNotEmpty) ...[
        h2('ทำอะไรได้บ้าง'),
        LayoutBuilder(builder: (context, box) {
          final cols = ((box.maxWidth + 12) / (220 + 12)).floor().clamp(1, 6);
          final w = (box.maxWidth - 12 * (cols - 1)) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final f in app.features)
              SizedBox(
                width: w,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: c.hover, borderRadius: BorderRadius.circular(lt.radius(14)), border: Border.all(color: c.borderSoft)),
                  child: Row(children: [
                    LIcon('check', size: 18, color: LauncherTheme.pink.withValues(alpha: 0.85)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(f, style: lt.ui(14, color: c.text.withValues(alpha: 0.9)))),
                  ]),
                ),
              ),
          ]);
        }),
        SizedBox(height: lt.space(28)),
      ],
      if (app.features.isEmpty) ...[
        h2('เกี่ยวกับโปรแกรม'),
        Panel(radius: 18, child: Text(app.description, style: lt.ui(14, color: c.text.withValues(alpha: 0.85), height: 1.7))),
        SizedBox(height: lt.space(28)),
      ],
      if (app.notes != null) ...[
        h2('มีอะไรใหม่ใน ${app.latestVersion ?? 'เวอร์ชันใหม่'}'),
        Panel(radius: 18, child: Text(app.notes!, style: lt.ui(14, color: c.text.withValues(alpha: 0.85), height: 1.7))),
        SizedBox(height: lt.space(28)),
      ],
      if (same.isNotEmpty) ...[
        h2('โปรแกรมในหมวดเดียวกัน'),
        LayoutBuilder(builder: (context, box) {
          final cols = ((box.maxWidth + 16) / (300 + 16)).floor().clamp(1, 6);
          final w = (box.maxWidth - 16 * (cols - 1)) / cols;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            for (final a in same) SizedBox(width: w, child: AppCard(app: a, onOpenDetail: () => onOpenDetail(a.id))),
          ]);
        }),
      ],
    ]);
  }
}

class _WhatsNew extends StatelessWidget {
  const _WhatsNew({required this.app});
  final CatalogApp app;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    return Panel(
      radius: 18,
      child: Text(app.notes ?? 'ยังไม่มีข้อมูลประวัติการเปลี่ยนแปลง — จะแสดงเมื่อเชื่อมต่อรายการอัปเดตของโปรแกรม', style: lt.ui(14, color: app.notes == null ? c.textMuted : c.text.withValues(alpha: 0.85), height: 1.7)),
    );
  }
}

class _Soon extends StatelessWidget {
  const _Soon({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt;
    return Panel(radius: 18, child: Text(text, style: lt.ui(14, color: lt.c.textMuted)));
  }
}

class _InfoAside extends StatelessWidget {
  const _InfoAside({required this.app});
  final CatalogApp app;

  static String _size(int? b) {
    if (b == null) return '—';
    if (b >= 1 << 20) return '${(b / (1 << 20)).toStringAsFixed(1)} MB';
    return '${(b / 1024).round()} KB';
  }

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    final rows = [
      ('หมวด', app.category.label),
      ('แพลตฟอร์ม', app.platform.label),
      ('เวอร์ชันที่ติดตั้ง', app.installedVersion ?? '—'),
      ('เวอร์ชันล่าสุด', app.latestVersion ?? '—'),
      ('ขนาด', _size(app.sizeBytes)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(0, 12, 0, 4), child: Semantics(header: true, child: Text('ข้อมูล', style: lt.ui(16, weight: FontWeight.w600)))),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.borderSoft))),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rows[i].$1, style: lt.ui(14, color: c.textMuted)),
                const SizedBox(width: 12),
                Flexible(child: Text(rows[i].$2, textAlign: TextAlign.right, style: lt.ui(14))),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(header: true, child: Text('ที่ติดตั้ง', style: lt.ui(16, weight: FontWeight.w600))),
          const SizedBox(height: 12),
          Text(app.installDir ?? '—', style: lt.ui(13, color: c.textMuted)),
          const SizedBox(height: 12),
          const LButton(label: 'เปิดโฟลเดอร์', icon: 'folder'),
        ]),
      ),
    ]);
  }
}
