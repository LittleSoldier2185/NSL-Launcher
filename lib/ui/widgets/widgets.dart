import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../icons.dart';
import '../theme/launcher_theme.dart';

/// พื้นที่แตะขั้นต่ำตามดีไซน์ — ปุ่มทุกปุ่มสูง ≥ [LauncherTheme.controlHeight]
enum LButtonKind { primary, secondary, danger, soon }

/// ปุ่มของ Launcher: primary = accent ทึบ, secondary = พื้นจางมีขอบ, danger = การลบ/ย้อนไม่ได้, soon = ขอบประ ใช้ไม่ได้ ("เร็ว ๆ นี้")
class LButton extends StatelessWidget {
  const LButton({super.key, required this.label, this.icon, this.kind = LButtonKind.secondary, this.onPressed, this.semanticLabel});

  final String label;
  final String? icon;
  final LButtonKind kind;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    final enabled = onPressed != null && kind != LButtonKind.soon;
    final (bg, fg, border, weight) = switch (kind) {
      LButtonKind.primary => (c.accent, c.onAccent, c.accent, FontWeight.w600),
      LButtonKind.secondary => (c.hover, c.text, c.borderStrong, FontWeight.w400),
      LButtonKind.danger => (c.dangerBg, c.dangerText, c.danger.withValues(alpha: 0.5), FontWeight.w400),
      LButtonKind.soon => (Colors.transparent, c.textMuted, c.borderStrong, FontWeight.w400),
    };
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[LIcon(icon!, size: 18, color: fg), const SizedBox(width: 8)],
        Flexible(child: Text(label, style: lt.ui(14, weight: weight, color: fg), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
    final shape = BorderRadius.circular(lt.radius(12));
    final child = kind == LButtonKind.soon
        ? CustomPaint(painter: _DashedBorder(color: c.borderStrong, radius: lt.radius(12)), child: _padded(lt, content))
        : DecoratedBox(
            decoration: BoxDecoration(color: bg, borderRadius: shape, border: Border.all(color: border)),
            child: _padded(lt, content),
          );
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: enabled ? onPressed : null, child: child),
      ),
    );
  }

  Widget _padded(LauncherTheme lt, Widget content) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: lt.controlHeight),
        child: Padding(padding: EdgeInsets.symmetric(horizontal: lt.space(18)), child: Center(widthFactor: 1, child: content)),
      );
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}

enum ChipTone { neutral, success, info, accent }

/// ป้ายสถานะ (สูง 26, มุมกลม)
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = ChipTone.neutral});

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    final (bg, fg) = switch (tone) {
      ChipTone.neutral => (c.borderSoft, c.textMuted),
      ChipTone.success => (c.successBg, c.successText),
      ChipTone.info => (c.infoBg, c.infoText),
      ChipTone.accent => (c.accentTint, c.accentInk),
    };
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
      child: Center(widthFactor: 1, child: Text(label, style: lt.ui(12, weight: FontWeight.w500, color: fg))),
    );
  }
}

/// ไอคอนโปรแกรม (SVG จากดีไซน์) ขนาด [size]
class AppIcon extends StatelessWidget {
  const AppIcon(this.asset, {super.key, required this.size});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: SvgPicture.asset(asset, width: size, height: size));
}

/// แผงข้างขวา/การ์ดรอง (พื้น surface มุม 20 ขอบจาง)
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 20});

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt;
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: lt.c.surface, borderRadius: BorderRadius.circular(lt.radius(radius)), border: Border.all(color: lt.c.borderSoft)),
      child: child,
    );
  }
}

/// ปุ่มข้อความแบบเมนู/แท็บ ที่มีพื้นที่แตะและ Semantics ครบ
class TapArea extends StatelessWidget {
  const TapArea({super.key, required this.label, required this.onTap, required this.child, this.selected, this.minHeight});

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final bool? selected;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(constraints: BoxConstraints(minHeight: minHeight ?? context.lt.controlHeight), child: child),
        ),
      ),
    );
  }
}

/// แถบความคืบหน้า (ไล่เฉดชมพู→ฟ้าของแบรนด์) ความสูง 8
class LProgress extends StatelessWidget {
  const LProgress({super.key, required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt;
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      label: label,
      value: '${(v * 100).round()}%',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 8,
            color: lt.c.borderSoft,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              child: const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [LauncherTheme.pink, LauncherTheme.sky])),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
