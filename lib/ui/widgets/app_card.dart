import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../theme/launcher_theme.dart';
import 'widgets.dart';

/// การ์ดโปรแกรมในคลัง (ไอคอน 60 + ชื่อ + คำอธิบาย + ป้ายสถานะ + ปุ่มหลัก) — แตะที่การ์ดเพื่อเปิดรายละเอียด
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.app, required this.onOpenDetail});

  final CatalogApp app;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final lt = context.lt, c = lt.c;
    return Semantics(
      container: true,
      label: '${app.name} ${statusLabel(app.state)}',
      child: Container(
        padding: EdgeInsets.all(lt.space(18)),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(lt.radius(18)), border: Border.all(color: c.borderSoft)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TapArea(
              label: 'ดูรายละเอียด ${app.name}',
              onTap: onOpenDetail,
              minHeight: 60,
              child: Row(
                children: [
                  AppIcon(app.iconAsset, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(app.name, style: lt.display(18), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(app.tagline, style: lt.ui(13, color: c.textMuted, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: lt.space(16)),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                StatusChip(statusLabel(app.state), tone: statusTone(app.state)),
                primaryAction(app),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String statusLabel(InstallState s) => switch (s) {
      InstallState.notInstalled => 'ยังไม่ได้ติดตั้ง',
      InstallState.installed => 'ติดตั้งแล้ว',
      InstallState.updateAvailable => 'มีอัปเดต',
      InstallState.mobileOnly => 'แอปมือถือ',
      InstallState.inDevelopment => 'กำลังพัฒนา',
    };

ChipTone statusTone(InstallState s) => switch (s) {
      InstallState.installed => ChipTone.success,
      InstallState.updateAvailable => ChipTone.accent,
      InstallState.mobileOnly => ChipTone.info,
      _ => ChipTone.neutral,
    };

/// ปุ่มหลักของการ์ด ตามสถานะ — การติดตั้ง/เปิด/อัปเดต/ส่งไปมือถือยังไม่ทำงาน (เฟส 4 / ยังไม่มีสเปก) จึง **ปิดไว้** ไม่หลอกว่ากดแล้วได้
Widget primaryAction(CatalogApp app) => switch (app.state) {
      InstallState.installed => const LButton(label: 'เปิด', icon: 'play'),
      InstallState.updateAvailable => const LButton(label: 'อัปเดต', icon: 'refresh', kind: LButtonKind.primary),
      InstallState.mobileOnly => const LButton(label: 'ส่งไปมือถือ', icon: 'phone'),
      InstallState.inDevelopment => const LButton(label: 'เร็ว ๆ นี้', kind: LButtonKind.soon),
      InstallState.notInstalled => const LButton(label: 'ติดตั้ง', icon: 'download'),
    };
