import 'dart:io';

import 'package:flutter/material.dart';

import '../../settings/launcher_settings.dart';
import '../../settings/theme_file_service.dart';
import '../../theme_engine/theme_engine.dart';
import '../icons.dart';
import '../theme/launcher_theme.dart';
import '../widgets/widgets.dart';

/// จัดการธีมของทั้งชุด NSL: นำเข้า/ส่งออก/ลบไฟล์ธีม, เลือกธีมให้แอป, ปรับแต่งเร็ว (lite), โหมดปลอดภัยของแอป
///
/// ไฟล์ธีมอยู่ที่ `Documents\NSL\Themes` ใช้ร่วมกับแอป NSL ทุกตัว — Launcher เป็นแค่ผู้เขียนไฟล์อีกตัว
/// (แอปที่เปิดอยู่เปลี่ยนตามทันทีผ่านตัวเฝ้าโฟลเดอร์)
class ThemeManager extends StatefulWidget {
  const ThemeManager({super.key, required this.themes, required this.settings, required this.files, required this.safeMode});

  final NslThemeController? themes;
  final LauncherSettingsController settings;
  final ThemeFileService files;

  /// Launcher เปิดด้วย `--safe-mode` (ไม่ได้เปิดที่เก็บธีมของผู้ใช้)
  final bool safeMode;

  @override
  State<ThemeManager> createState() => _ThemeManagerState();
}

class _Msg {
  const _Msg(this.text, {this.error = false});
  final String text;
  final bool error;
}

class _Assessment {
  const _Assessment({this.error, this.unusable = false, this.lowContrast = 0});
  final String? error;
  final bool unusable;
  final int lowContrast;
  bool get bad => error != null || unusable;
}

class _ThemeManagerState extends State<ThemeManager> {
  _Msg? _msg;
  bool _busy = false;
  final _hex = TextEditingController();
  bool _hexBad = false;

  NslThemeController? get _c => widget.themes;

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _say(String text, {bool error = false}) {
    if (!mounted) return;
    setState(() => _msg = _Msg(text, error: error));
  }

  /// ทำงานที่ใช้เวลา/อาจล้ม โดยกันกดซ้ำและไม่ให้ข้อผิดพลาดของไฟล์ทำให้แอปล้ม
  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } on FileSystemException catch (e) {
      _say('ทำไม่สำเร็จ: ${e.message}', error: true);
    } catch (_) {
      _say('ทำไม่สำเร็จ (เกิดข้อผิดพลาดที่ไม่คาดคิด)', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({required String title, required String body, required String action, bool danger = false}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final lt = ctx.lt;
        return Dialog(
          backgroundColor: lt.c.surfaceRaised,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(lt.radius(20)), side: BorderSide(color: lt.c.border)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Semantics(header: true, child: Text(title, style: lt.display(20))),
                const SizedBox(height: 12),
                Text(body, style: lt.ui(14, color: lt.c.textMuted, height: 1.6)),
                const SizedBox(height: 20),
                Wrap(alignment: WrapAlignment.end, spacing: 12, runSpacing: 12, children: [
                  LButton(label: 'ยกเลิก', onPressed: () => Navigator.of(ctx).pop(false)),
                  LButton(label: action, kind: danger ? LButtonKind.danger : LButtonKind.primary, onPressed: () => Navigator.of(ctx).pop(true)),
                ]),
              ]),
            ),
          ),
        );
      },
    );
    return r ?? false;
  }

  // ---- การทำงาน -----------------------------------------------------------------------------------------------

  Future<void> _import() => _run(() async {
        final c = _c!;
        final picked = await widget.files.pickTheme();
        if (picked == null) return;
        final text = picked.text;
        if (text == null) {
          _say('นำเข้า "${picked.name}" ไม่ได้: ${picked.error ?? 'อ่านไฟล์ไม่ได้'}', error: true);
          return;
        }
        final preview = parseNslt(text).spec;
        if (preview != null && c.userThemes.any((t) => t.id == preview.id)) {
          final ok = await _confirm(title: 'แทนที่ธีมเดิม?', body: 'มีธีมรหัส "${preview.id}" อยู่แล้ว การนำเข้าจะแทนที่ไฟล์เดิมของธีมนี้', action: 'แทนที่');
          if (!ok) {
            _say('ยกเลิกการนำเข้า');
            return;
          }
        }
        final r = await c.importThemeText(text);
        if (!r.ok) {
          _say('นำเข้า "${picked.name}" ไม่ได้: ${r.errors.join('; ')}', error: true);
          return;
        }
        final name = c.lookup(r.id!)?.name ?? r.id!;
        _say(r.warnings.isEmpty ? 'นำเข้าธีม "$name" แล้ว' : 'นำเข้าธีม "$name" แล้ว (มีค่าที่ถูกข้าม ${r.warnings.length} รายการ: ${r.warnings.take(2).join('; ')}${r.warnings.length > 2 ? ' …' : ''})');
      });

  Future<void> _export(NslThemeSpec t) => _run(() async {
        final text = _c!.exportThemeText(t.id);
        if (text == null) {
          _say('ส่งออกไม่ได้: ไม่พบธีม "${t.name}"', error: true);
          return;
        }
        final ok = await widget.files.saveTheme('${t.id}.nslt', text);
        _say(ok ? 'ส่งออกธีม "${t.name}" แล้ว' : 'ไม่ได้ส่งออก (ยกเลิกหรือบันทึกไม่ได้)', error: false);
      });

  Future<void> _delete(NslThemeSpec t) => _run(() async {
        final c = _c!;
        final usedByApps = c.settings.activeThemeId == t.id;
        final ok = await _confirm(
          title: 'ลบธีม "${t.name}"?',
          body: 'ไฟล์ธีมจะถูกลบออกจาก Documents\\NSL\\Themes ทันทีและกู้คืนไม่ได้${usedByApps ? '\nธีมนี้ใช้กับแอป NSL อยู่ — แอปจะกลับไปใช้ธีมเริ่มต้น' : ''}',
          action: 'ลบ',
          danger: true,
        );
        if (!ok) return;
        await c.deleteTheme(t.id);
        if (widget.settings.value.themeSource == t.id) {
          await widget.settings.update(widget.settings.value.copyWith(themeSource: kThemeSourceLauncher));
        }
        _say('ลบธีม "${t.name}" แล้ว');
      });

  Future<void> _select(NslThemeSpec? t) => _run(() async {
        await _c!.select(t?.id);
        _say(t == null ? 'แอป NSL กลับไปใช้ธีมเริ่มต้นของแต่ละแอป' : 'ตั้งให้แอป NSL ใช้ธีม "${t.name}" แล้ว — แอปที่เปิดอยู่จะเปลี่ยนตามทันที');
      });

  Future<void> _appearance(NslAppearance a) => _run(() async => _c!.setAppearance(a));

  Future<void> _safe(bool on) => _run(() async {
        await _c!.setSafeMode(on);
        _say(on ? 'แอป NSL จะไม่ใช้ธีมของผู้ใช้ชั่วคราว (โหมดปลอดภัย)' : 'ปิดโหมดปลอดภัยของแอป NSL แล้ว');
      });

  _Assessment _assess(NslThemeSpec t) {
    final c = _c!;
    var low = 0;
    var unusable = false;
    try {
      for (final b in Brightness.values) {
        final tk = resolveTokens(t, b, lookup: c.lookup);
        low += contrastFailures(tk).length;
        if (isUnusable(tk)) unusable = true;
      }
    } on NslResolveException catch (e) {
      return _Assessment(error: e.message);
    }
    return _Assessment(unusable: unusable, lowContrast: low);
  }

  // ---- หน้าจอ -------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    final themes = _c;
    if (themes == null) {
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(header: true, child: Text('ธีมสำหรับแอป NSL', style: lt.ui(16, weight: FontWeight.w600))),
          const SizedBox(height: 8),
          Text(
            widget.safeMode ? 'Safe mode: ไม่เปิดที่เก็บธีมของผู้ใช้ จึงจัดการธีมไม่ได้ในรอบนี้' : 'เปิดที่เก็บธีม (Documents\\NSL\\Themes) ไม่ได้ จึงจัดการธีมไม่ได้ในรอบนี้',
            style: lt.ui(14, color: c.warnText),
          ),
        ]),
      );
    }
    return ListenableBuilder(
      listenable: themes,
      builder: (context, _) {
        final store = themes.store;
        final folder = store is NslThemeStore ? store.themesDir.path : null;
        final active = themes.settings.activeThemeId;
        final user = themes.userThemes;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(header: true, child: Text('ธีมสำหรับแอป NSL', style: lt.ui(16, weight: FontWeight.w600))),
              const SizedBox(height: 4),
              Text('ไฟล์ธีมใช้ร่วมกับแอป NSL ทุกตัว เลือกแล้วแอปที่เปิดอยู่จะเปลี่ยนตามทันที', style: lt.ui(13, color: c.textMuted)),
              if (folder != null) ...[
                const SizedBox(height: 4),
                Semantics(label: 'โฟลเดอร์ธีม $folder', child: ExcludeSemantics(child: Text(folder, style: lt.ui(12, color: c.textMuted)))),
              ],
              SizedBox(height: lt.space(16)),
              Wrap(spacing: 12, runSpacing: 12, children: [
                LButton(label: 'นำเข้าไฟล์ธีม', icon: 'download', kind: LButtonKind.primary, onPressed: _busy ? null : _import),
                const LButton(label: 'เว็บ NSL Palette · เร็ว ๆ นี้', kind: LButtonKind.soon),
              ]),
              if (_msg != null) ...[
                SizedBox(height: lt.space(14)),
                Semantics(
                  liveRegion: true,
                  container: true,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _msg!.error ? c.dangerBg : c.successBg, borderRadius: BorderRadius.circular(lt.radius(12))),
                    child: Text(_msg!.text, style: lt.ui(13, color: _msg!.error ? c.dangerText : c.successText, height: 1.5)),
                  ),
                ),
              ],
              SizedBox(height: lt.space(16)),
              _ThemeRow(
                title: 'ค่าเริ่มต้นของแต่ละแอป',
                subtitle: 'ไม่ใช้ธีมของผู้ใช้ — แต่ละแอปใช้ธีมในตัวของตัวเอง',
                active: active == null,
                actions: [
                  LButton(label: active == null ? 'กำลังใช้อยู่' : 'ใช้ค่าเริ่มต้น', onPressed: active == null || _busy ? null : () => _select(null), semanticLabel: 'ใช้ธีมเริ่มต้นของแต่ละแอป'),
                ],
              ),
              if (user.isEmpty)
                Padding(padding: const EdgeInsets.only(top: 12), child: Text('ยังไม่มีไฟล์ธีมของคุณ — นำเข้าไฟล์ .nslt ที่สร้างจาก NSL Palette ได้', style: lt.ui(13, color: c.textMuted))),
              for (final t in user) ...[
                Builder(builder: (context) {
                  final a = _assess(t);
                  return _ThemeRow(
                    title: t.name,
                    subtitle: t.id,
                    active: active == t.id,
                    notes: [
                      if (a.error != null) _Note('ใช้ไม่ได้: ${a.error}', bad: true),
                      if (a.error == null && a.unusable) const _Note('ตัวอักษรอ่านไม่ออก (ต่ำกว่า 3:1) — แอปจะถอยไปธีมในตัว', bad: true),
                      if (a.error == null && !a.unusable && a.lowContrast > 0) _Note('ความอ่านออกต่ำกว่าเกณฑ์ ${a.lowContrast} รายการ (ตรวจและแก้ได้ใน NSL Palette)'),
                    ],
                    actions: [
                      LButton(
                        label: active == t.id ? 'กำลังใช้อยู่' : 'ใช้กับแอป',
                        kind: active == t.id ? LButtonKind.secondary : LButtonKind.primary,
                        onPressed: active == t.id || a.bad || _busy ? null : () => _select(t),
                        semanticLabel: active == t.id ? 'ธีม ${t.name} กำลังใช้กับแอป NSL อยู่' : 'ใช้ธีม ${t.name} กับแอป NSL',
                      ),
                      LButton(label: 'ส่งออก', onPressed: _busy ? null : () => _export(t), semanticLabel: 'ส่งออกธีม ${t.name}'),
                      LButton(label: 'ลบ', kind: LButtonKind.danger, onPressed: _busy ? null : () => _delete(t), semanticLabel: 'ลบธีม ${t.name}'),
                    ],
                  );
                }),
              ],
              if (themes.problems.isNotEmpty) ...[
                SizedBox(height: lt.space(16)),
                Text('ไฟล์ที่ข้าม', style: lt.ui(13, weight: FontWeight.w600, color: c.warnText)),
                for (final p in themes.problems) Padding(padding: const EdgeInsets.only(top: 2), child: Text(p, style: lt.ui(12, color: c.textMuted))),
              ],
            ]),
          ),
          SizedBox(height: lt.space(16)),
          _Lite(themes: themes, hex: _hex, hexBad: _hexBad, onHexBad: (v) => setState(() => _hexBad = v), onChange: _appearance, busy: _busy),
          SizedBox(height: lt.space(16)),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(header: true, child: Text('โหมดปลอดภัยของแอป NSL', style: lt.ui(16, weight: FontWeight.w600))),
              const SizedBox(height: 4),
              Text('ถ้าธีมทำให้แอปใช้งานไม่ได้ เปิดโหมดนี้เพื่อให้ทุกแอปไม่ใช้ธีมของผู้ใช้ชั่วคราว (ไฟล์ธีมไม่ถูกลบ)', style: lt.ui(13, color: c.textMuted)),
              const SizedBox(height: 12),
              _Toggle(label: 'ไม่ใช้ธีมของผู้ใช้ในแอป NSL', value: themes.safeMode, onChanged: _busy ? null : _safe),
            ]),
          ),
        ]);
      },
    );
  }
}

class _Note {
  const _Note(this.text, {this.bad = false});
  final String text;
  final bool bad;
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.title, required this.subtitle, required this.active, required this.actions, this.notes = const []});

  final String title, subtitle;
  final bool active;
  final List<Widget> actions;
  final List<_Note> notes;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? c.selected : c.hover,
        borderRadius: BorderRadius.circular(lt.radius(14)),
        border: Border.all(color: active ? c.accentBorder : c.borderSoft),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 6, children: [
          Text(title, style: lt.ui(15, weight: FontWeight.w600)),
          if (active) const StatusChip('ใช้กับแอปอยู่', tone: ChipTone.accent),
        ]),
        Text(subtitle, style: lt.ui(12, color: c.textMuted)),
        for (final n in notes) Padding(padding: const EdgeInsets.only(top: 6), child: Text(n.text, style: lt.ui(12, color: n.bad ? c.dangerText : c.warnText))),
        SizedBox(height: lt.space(12)),
        Wrap(spacing: 10, runSpacing: 10, children: actions),
      ]),
    );
  }
}

/// ปรับแต่งเร็ว (lite) ของแอป NSL: accent จาก preset หรือสีเอง + โหมด — เก็บใน ui-settings.json ร่วม
class _Lite extends StatelessWidget {
  const _Lite({required this.themes, required this.hex, required this.hexBad, required this.onHexBad, required this.onChange, required this.busy});

  final NslThemeController themes;
  final TextEditingController hex;
  final bool hexBad, busy;
  final ValueChanged<bool> onHexBad;
  final Future<void> Function(NslAppearance) onChange;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    return ListenableBuilder(
      listenable: themes,
      builder: (context, _) {
        final a = themes.appearance;
        Widget swatch(NslAccentPreset p) {
          final on = a.presetId == p.id;
          final color = p.set(lt.isDark).$1;
          return TapArea(
            label: 'สีเน้น ${p.nameTh}',
            selected: on,
            minHeight: 40,
            onTap: busy ? null : () => onChange(a.withPreset(p.id)),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color, border: Border.all(color: on ? c.text : c.borderStrong, width: on ? 3 : 1)),
              child: on ? Center(child: LIcon('check', size: 20, color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black)) : null,
            ),
          );
        }

        return Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Semantics(header: true, child: Text('ปรับแต่งเร็วสำหรับแอป NSL', style: lt.ui(16, weight: FontWeight.w600))),
            const SizedBox(height: 4),
            Text('สีเน้นและโหมดที่ทุกแอป NSL ใช้ทับธีม — ปรับละเอียดกว่านี้ทำที่ NSL Palette', style: lt.ui(13, color: c.textMuted)),
            SizedBox(height: lt.space(14)),
            Text('สีเน้น', style: lt.ui(13, weight: FontWeight.w600, color: c.textMuted)),
            const SizedBox(height: 8),
            Wrap(spacing: 12, runSpacing: 12, children: [for (final p in kAccentPresets) swatch(p)]),
            SizedBox(height: lt.space(12)),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Semantics(
                  textField: true,
                  label: 'รหัสสีเน้นที่กำหนดเอง',
                  child: TextField(
                    controller: hex,
                    maxLength: 7,
                    style: lt.ui(14),
                    cursorColor: c.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      hintText: '#RRGGBB',
                      hintStyle: lt.ui(14, color: c.textMuted),
                      errorText: hexBad ? 'รหัสสีไม่ถูกต้อง' : null,
                      errorStyle: lt.ui(12, color: c.dangerText),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(lt.radius(12)), borderSide: BorderSide(color: c.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(lt.radius(12)), borderSide: BorderSide(color: c.accent)),
                      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(lt.radius(12)), borderSide: BorderSide(color: c.danger)),
                      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(lt.radius(12)), borderSide: BorderSide(color: c.danger)),
                    ),
                    onChanged: (t) {
                      final s = t.trim();
                      if (s.isEmpty) return onHexBad(false);
                      final col = parseHexColor(s.startsWith('#') ? s : '#$s');
                      // สีเน้นต้องทึบ (ไม่รับ #RRGGBBAA)
                      if (col == null || col.a != 1.0) return onHexBad(true);
                      onHexBad(false);
                      onChange(a.withCustom(col));
                    },
                  ),
                ),
              ),
              LButton(label: 'ล้างสีเน้น', onPressed: busy || !a.hasAccent ? null : () => onChange(a.clearedAccent())),
            ]),
            SizedBox(height: lt.space(14)),
            Text('โหมด', style: lt.ui(13, weight: FontWeight.w600, color: c.textMuted)),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final (m, label) in const [(NslModeChoice.system, 'ตามระบบ'), (NslModeChoice.light, 'สว่าง'), (NslModeChoice.dark, 'มืด')])
                TapArea(
                  label: 'โหมดของแอป NSL: $label',
                  selected: a.mode == m,
                  onTap: busy ? null : () => onChange(a.withMode(m)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: a.mode == m ? c.selected : Colors.transparent,
                      borderRadius: BorderRadius.circular(lt.radius(12)),
                      border: Border.all(color: a.mode == m ? c.accentBorder : c.borderStrong),
                    ),
                    child: Center(widthFactor: 1, child: Text(label, style: lt.ui(14, weight: a.mode == m ? FontWeight.w600 : FontWeight.w400, color: a.mode == m ? c.text : c.textMuted))),
                  ),
                ),
            ]),
          ]),
        );
      },
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    return Semantics(
      container: true,
      toggled: value,
      child: TapArea(
        label: '$label: ${value ? 'เปิด' : 'ปิด'}',
        selected: value,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: Row(children: [
          Container(
            width: 44,
            height: 26,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: value ? c.accent : c.borderStrong, borderRadius: BorderRadius.circular(13)),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: value ? c.onAccent : c.text)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: lt.ui(14))),
        ]),
      ),
    );
  }
}
