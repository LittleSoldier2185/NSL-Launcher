import 'package:flutter/material.dart';

import '../../settings/launcher_settings.dart';
import '../../settings/theme_file_service.dart';
import '../../theme_engine/theme_engine.dart';
import '../theme/launcher_theme.dart';
import '../theme/theme_source.dart';
import '../widgets/widgets.dart';
import 'theme_manager.dart';

/// หน้า "ตั้งค่า" — เฟส 2 มีเฉพาะการเลือกธีม/โหมดของ Launcher เอง (การจัดการไฟล์ธีมของทั้งชุดอยู่เฟส 3)
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings, required this.themes, required this.safeMode, this.files = const SystemThemeFileService()});

  final LauncherSettingsController settings;
  final NslThemeController? themes;
  final bool safeMode;
  final ThemeFileService files;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, ?themes]),
      builder: (context, _) {
        final s = settings.value;
        final installed = [
          for (final id in builtinThemeIds)
            if (id != kBuiltinLauncherId) (id, themeDisplayName(id, themes), true),
          for (final t in themes?.userThemes ?? const <NslThemeSpec>[]) (t.id, t.name, false),
        ];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(header: true, child: Text('ตั้งค่า', style: lt.display(28))),
          const SizedBox(height: 4),
          Text('ปรับหน้าตาของ Launcher', style: lt.ui(14, color: c.textMuted)),
          SizedBox(height: lt.space(28)),
          if (safeMode) ...[
            Panel(child: Text('กำลังใช้ Safe mode — ธีมของ Launcher เท่านั้น (ไม่อ่านธีมของผู้ใช้)', style: lt.ui(14, color: c.warnText))),
            SizedBox(height: lt.space(16)),
          ],
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(header: true, child: Text('ธีม', style: lt.ui(16, weight: FontWeight.w600))),
              const SizedBox(height: 4),
              Text('ธีมใช้กับหน้าตาของ Launcher เท่านั้น ธีมของแอปอื่นตั้งแยกในหน้าจัดการธีม', style: lt.ui(13, color: c.textMuted)),
              const SizedBox(height: 12),
              _Choice(label: 'ธีมของ Launcher (ค่าเริ่มต้น)', selected: s.themeSource == kThemeSourceLauncher, onTap: () => settings.update(s.copyWith(themeSource: kThemeSourceLauncher))),
              _Choice(
                label: 'ตามธีมที่เลือกให้แอป NSL',
                hint: themes?.activeSpec?.name ?? 'ยังไม่ได้เลือกธีมให้แอป — ใช้ธีมของ Launcher',
                selected: s.themeSource == kThemeSourceShared,
                onTap: () => settings.update(s.copyWith(themeSource: kThemeSourceShared)),
              ),
              if (installed.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('ธีมที่มี', style: lt.ui(13, weight: FontWeight.w600, color: c.textMuted)),
                const SizedBox(height: 4),
                for (final (id, name, builtin) in installed)
                  _Choice(label: name, hint: builtin ? 'ธีมในตัวของแอปอื่น' : 'ไฟล์ของคุณ', selected: s.themeSource == id, onTap: () => settings.update(s.copyWith(themeSource: id))),
              ],
              if ((themes?.problems ?? const <String>[]).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('ไฟล์ธีมที่ข้าม', style: lt.ui(13, weight: FontWeight.w600, color: c.warnText)),
                for (final p in themes!.problems) Text(p, style: lt.ui(12, color: c.textMuted)),
              ],
            ]),
          ),
          SizedBox(height: lt.space(16)),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(header: true, child: Text('โหมดของ Launcher', style: lt.ui(16, weight: FontWeight.w600))),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final (m, label) in const [(LauncherMode.dark, 'มืด'), (LauncherMode.light, 'สว่าง'), (LauncherMode.system, 'ตามระบบ')])
                  _ModeChip(label: label, selected: s.mode == m, onTap: () => settings.update(s.copyWith(mode: m))),
              ]),
              const SizedBox(height: 10),
              Text('ดีไซน์ของ Launcher ทำไว้เฉพาะโหมดมืด โหมดสว่างคำนวณสีจากธีม จึงอาจไม่ละเอียดเท่า', style: lt.ui(12, color: c.textMuted)),
            ]),
          ),
          SizedBox(height: lt.space(28)),
          Semantics(header: true, child: Text('ธีมของแอป NSL', style: lt.display(22))),
          SizedBox(height: lt.space(14)),
          ThemeManager(themes: themes, settings: settings, files: files, safeMode: safeMode),
        ]);
      },
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap, this.hint});

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    return TapArea(
      label: hint == null ? label : '$label — $hint',
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? c.accent : c.borderStrong, width: 2)),
            alignment: Alignment.center,
            child: selected ? Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: c.accent)) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: lt.ui(14, weight: selected ? FontWeight.w600 : FontWeight.w400)),
              if (hint != null) Text(hint!, style: lt.ui(12, color: c.textMuted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    return TapArea(
      label: 'โหมด$label',
      selected: selected,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? c.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(lt.radius(12)),
          border: Border.all(color: selected ? c.accentBorder : c.borderStrong),
        ),
        child: Center(widthFactor: 1, child: Text(label, style: lt.ui(14, weight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? c.text : c.textMuted))),
      ),
    );
  }
}
