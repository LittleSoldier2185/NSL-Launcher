import 'package:flutter/material.dart';

import '../../theme_engine/theme_engine.dart';

/// ธีมของ Launcher = token ที่ resolve แล้ว (จากไฟล์ `.nslt` / ธีมในตัว) + ตัวช่วยคำนวณขนาดตามธีม
///
/// ทุก widget อ่านสีผ่าน [LauncherTheme.c] และขนาดผ่าน [radius]/[fs]/[controlHeight] — ไม่มีค่าสีตายตัวในหน้า
/// ยกเว้นสีตกแต่งประจำแบรนด์ (ด้านล่าง) ที่ไม่ใช่ token ธีม
class LauncherTheme extends ThemeExtension<LauncherTheme> {
  const LauncherTheme(this.tokens);

  final NslTokens tokens;

  NslColors get c => tokens.colors;
  bool get isDark => tokens.isDark;

  // ---- สีตกแต่งประจำแบรนด์ (ฮีโร่ วงแหวนหมวด แถบความคืบหน้า) — ไม่ผูกกับธีม ฮีโร่มีพื้นเข้มของตัวเองเสมอ
  static const sky = Color(0xFF6EC8FF);
  static const mint = Color(0xFF4FE3B0);
  static const mintText = Color(0xFF7DF0C6);
  static const pink = Color(0xFFFF7AA8);
  static const heroText = Color(0xFFFFFFFF);
  static const heroBody = Color(0xFFD3DAF2);
  static const heroMuted = Color(0xFFA9B3D6);
  static const nightBlue = Color(0xFF071433);

  /// ตัวคูณมุมโค้งจากธีม (`shape.md` ÷ 8 ; ธีมที่ไม่แตะค่านี้ = 1.0 ตรงดีไซน์)
  double get radiusFactor => tokens.shape.md / const NslShape().md;

  /// มุมโค้งตามดีไซน์ [base] px ปรับตามธีม
  double radius(double base) => (base * radiusFactor).clamp(NslShape.minRadius, NslShape.maxRadius).toDouble();

  /// ขนาดตัวอักษรตามดีไซน์ [base] ปรับตามสัดส่วนและขนาดขั้นต่ำของธีม
  double fs(double base) => tokens.type.fit(base);

  /// ความสูงขั้นต่ำของปุ่ม/ช่องกรอก: ดีไซน์กำหนด 44 (พื้นที่แตะ) — density เปลี่ยนได้ แต่ compact ไม่ต่ำกว่า 36
  double get controlHeight => switch (tokens.density) {
        NslDensity.compact => 36,
        NslDensity.normal => 44,
        NslDensity.comfortable => 52,
      };

  /// ระยะห่างตามความหนาแน่น
  double space(double base) => base * switch (tokens.density) {
        NslDensity.compact => 0.8,
        NslDensity.normal => 1.0,
        NslDensity.comfortable => 1.15,
      };

  /// ฟอนต์ UI (ธีมระบุได้ ปิดท้ายด้วย Noto Sans Thai เสมอ)
  String get uiFamily => tokens.type.effectiveFamily;
  List<String> get uiFallback => tokens.type.fallback;

  TextStyle ui(double size, {FontWeight weight = FontWeight.w400, Color? color, double? height, double? letterSpacing}) => TextStyle(
        fontFamily: uiFamily,
        fontFamilyFallback: uiFallback,
        fontSize: fs(size),
        fontWeight: weight,
        color: color ?? c.text,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// หัวข้อ: Space Grotesk ของแบรนด์ (ตัวอักษรไทยตกไปฟอนต์ UI)
  TextStyle display(double size, {FontWeight weight = FontWeight.w600, Color? color, double? letterSpacing}) => TextStyle(
        fontFamily: 'Space Grotesk',
        fontFamilyFallback: [uiFamily, ...uiFallback],
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
        fontSize: fs(size),
        fontWeight: weight,
        color: color ?? c.text,
        letterSpacing: letterSpacing,
      );

  @override
  LauncherTheme copyWith({NslTokens? tokens}) => LauncherTheme(tokens ?? this.tokens);

  @override
  LauncherTheme lerp(ThemeExtension<LauncherTheme>? other, double t) => other is LauncherTheme && t >= 0.5 ? other : this;
}

extension LauncherContext on BuildContext {
  LauncherTheme get lt => Theme.of(this).extension<LauncherTheme>()!;
}

/// token → ThemeData (Material ใช้แค่เป็นฐาน: scaffold, ตัวอักษร, scrollbar, tooltip ; หน้าจอวาดด้วย widget ของ Launcher เอง)
ThemeData buildLauncherTheme(NslTokens t) {
  final lt = LauncherTheme(t);
  final c = t.colors;
  final scheme = ColorScheme(
    brightness: t.brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.accent,
    onSecondary: c.onAccent,
    error: c.danger,
    onError: c.onAccent,
    surface: c.surface,
    onSurface: c.text,
    outline: c.borderStrong,
    outlineVariant: c.border,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: t.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    fontFamily: lt.uiFamily,
    fontFamilyFallback: lt.uiFallback,
    dividerColor: c.borderSoft,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: c.hover,
    focusColor: c.accentTint,
    extensions: [lt],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.text, displayColor: c.text, fontFamily: lt.uiFamily),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(c.borderStrong),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(8),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(lt.radius(8)), border: Border.all(color: c.border)),
      textStyle: lt.ui(12),
    ),
  );
}
