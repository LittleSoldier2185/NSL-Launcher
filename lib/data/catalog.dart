import 'package:flutter/foundation.dart';

/// หมวดของโปรแกรม (ตามดีไซน์: Media / Life / Create)
enum AppCategory {
  media('Media', 'สื่อและความบันเทิง'),
  life('Life', 'ชีวิตประจำวัน'),
  create('Create', 'สร้างและวางแผน');

  const AppCategory(this.label, this.subtitle);
  final String label;
  final String subtitle;
}

enum AppPlatform {
  windows('Windows'),
  android('Android');

  const AppPlatform(this.label);
  final String label;
}

/// สถานะของโปรแกรมบนเครื่องนี้
enum InstallState {
  /// ยังไม่ได้ติดตั้ง (Windows)
  notInstalled,
  installed,
  updateAvailable,

  /// แอปมือถือ — Launcher บน Windows ติดตั้งให้ไม่ได้
  mobileOnly,

  /// ยังไม่ปล่อย
  inDevelopment,
}

/// โปรแกรมหนึ่งตัวในคลัง
///
/// ค่าที่ยังไม่รู้ (เวอร์ชัน ขนาด โฟลเดอร์ ประวัติการเปลี่ยนแปลง) เป็น null — หน้าจอแสดง "—" ไม่แต่งตัวเลขขึ้นมาเอง
@immutable
class CatalogApp {
  const CatalogApp({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.category,
    required this.platform,
    required this.iconAsset,
    required this.brand,
    this.features = const [],
    this.state = InstallState.notInstalled,
    this.installedVersion,
    this.latestVersion,
    this.sizeBytes,
    this.installDir,
    this.notes,
  });

  final String id;
  final String name;

  /// คำอธิบายสั้นบนการ์ด
  final String tagline;

  /// คำอธิบายในหน้ารายละเอียด/ฮีโร่
  final String description;
  final AppCategory category;
  final AppPlatform platform;
  final String iconAsset;

  /// สีประจำแอป (ARGB) — ใช้ทำพื้นฮีโร่
  final int brand;
  final List<String> features;
  final InstallState state;
  final String? installedVersion, latestVersion;
  final int? sizeBytes;
  final String? installDir;
  final String? notes;

  bool get canOpen => state == InstallState.installed || state == InstallState.updateAvailable;
}

/// การดาวน์โหลดที่กำลังทำ
@immutable
class DownloadItem {
  const DownloadItem({required this.appId, required this.progress});
  final String appId;

  /// 0.0–1.0
  final double progress;
}

/// มือถือที่เชื่อมต่อ (ยังไม่มีสเปกโปรโตคอล — ใช้แสดงเฉพาะโหมดสาธิต)
@immutable
class ConnectedDevice {
  const ConnectedDevice({required this.name, required this.online});
  final String name;
  final bool online;
}

/// ข้อมูลทั้งหมดที่หน้าจอใช้
@immutable
class Catalog {
  const Catalog({required this.apps, this.lastOpenedId, this.downloads = const [], this.devices = const [], this.isDemo = false});

  final List<CatalogApp> apps;

  /// โปรแกรมที่เปิดล่าสุด (null = ไม่ทราบ → ไม่แสดงฮีโร่ "เปิดล่าสุด")
  final String? lastOpenedId;
  final List<DownloadItem> downloads;
  final List<ConnectedDevice> devices;

  /// ข้อมูลสาธิตตามตัวอย่างในดีไซน์ (ไม่ใช่สถานะจริง)
  final bool isDemo;

  CatalogApp? byId(String id) {
    for (final a in apps) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<CatalogApp> get updates => [for (final a in apps) if (a.state == InstallState.updateAvailable) a];
  CatalogApp? get lastOpened => lastOpenedId == null ? null : byId(lastOpenedId!);

  List<CatalogApp> inCategory(AppCategory c) => [for (final a in apps) if (a.category == c) a];

  /// ค้นหาด้วยชื่อ/คำอธิบาย/หมวด (ไม่สนตัวพิมพ์เล็กใหญ่) ; [category] = null ทุกหมวด
  List<CatalogApp> search(String query, {AppCategory? category}) {
    final q = query.trim().toLowerCase();
    return [
      for (final a in apps)
        if ((category == null || a.category == category) &&
            (q.isEmpty || a.name.toLowerCase().contains(q) || a.tagline.toLowerCase().contains(q) || a.description.toLowerCase().contains(q) || a.category.label.toLowerCase().contains(q)))
          a,
    ];
  }
}

// ---- รายการโปรแกรม NSL (ข้อความตามดีไซน์) -------------------------------------------------------------------------

const _spectrum = CatalogApp(
  id: 'spectrum',
  name: 'NSL Spectrum',
  tagline: 'ภาพ เสียง วิดีโอ eBook · Windows',
  description: 'ศูนย์รวมสื่อส่วนตัว ดูภาพ ฟังเพลง ดูวิดีโอ อ่าน eBook และสตรีมจากคอมไปมือถือ',
  category: AppCategory.media,
  platform: AppPlatform.windows,
  iconAsset: 'assets/images/app_spectrum.svg',
  brand: 0xFF0E7C7B,
);

const _orbit = CatalogApp(
  id: 'orbit',
  name: 'NSL Orbit',
  tagline: 'การเงิน ตารางชีวิต และเครื่องมือประจำวัน · Android',
  description: 'การเงิน ตารางชีวิต และเครื่องมือประจำวัน',
  category: AppCategory.life,
  platform: AppPlatform.android,
  iconAsset: 'assets/images/app_orbit.svg',
  brand: 0xFF5B3DF5,
  state: InstallState.mobileOnly,
);

// ชื่อแอป Create: ดีไซน์ใช้ "NSL Nebula" ส่วนแบรนด์ที่ตกลงไว้คือ "Nebular" — ใช้ "Nebular" (รอผู้ใช้ยืนยัน ดู Plan 7 ข้อ 1)
const _nebular = CatalogApp(
  id: 'nebular',
  name: 'NSL Nebular',
  tagline: 'วางโครงสร้างโปรเจกต์ Flowchart, ER, SQL · Windows',
  description: 'จุดกำเนิดของทุกโปรเจกต์ วางโครงสร้างระบบด้วย Flowchart, Data flow, Screen flow, SQL schema และ ER diagram ในที่เดียว',
  category: AppCategory.create,
  platform: AppPlatform.windows,
  iconAsset: 'assets/images/app_nebular.svg',
  brand: 0xFF1B1745,
  features: ['Flowchart', 'Data flow', 'Screen flow', 'SQL schema และส่งออก .sql', 'ER diagram'],
);

const _lyra = CatalogApp(
  id: 'lyra',
  name: 'NSL Lyra',
  tagline: 'ตัวช่วยเขียนนิยาย',
  description: 'ตัวช่วยเขียนนิยาย',
  category: AppCategory.create,
  platform: AppPlatform.windows,
  iconAsset: 'assets/images/app_lyra.svg',
  brand: 0xFFC2255C,
  state: InstallState.inDevelopment,
);

/// คลังจริง (ก่อนมี manifest ในเฟส 4): รู้แค่รายการและคำอธิบาย — **ยังไม่รู้สถานะการติดตั้ง** จึงไม่แสดงว่า "ติดตั้งแล้ว"/"มีอัปเดต"
Catalog staticCatalog() => const Catalog(apps: [_spectrum, _orbit, _nebular, _lyra]);

/// ข้อมูลสาธิตตามตัวอย่างในดีไซน์ (`--demo`): Spectrum ติดตั้งแล้ว, Nebular มีอัปเดตและกำลังดาวน์โหลด 64%, มือถือหนึ่งเครื่อง
/// **ไม่ใช่สถานะจริง** — ใช้ดูหน้าตาและทดสอบเท่านั้น (เวอร์ชัน/ขนาดเว้นว่าง ไม่แต่งตัวเลข)
Catalog demoCatalog() => Catalog(
      isDemo: true,
      lastOpenedId: 'spectrum',
      apps: [
        _copy(_spectrum, InstallState.installed),
        _orbit,
        _copy(_nebular, InstallState.updateAvailable),
        _lyra,
      ],
      downloads: const [DownloadItem(appId: 'nebular', progress: 0.64)],
      devices: const [ConnectedDevice(name: 'มือถือของฉัน', online: true)],
    );

CatalogApp _copy(CatalogApp a, InstallState s) => CatalogApp(
      id: a.id,
      name: a.name,
      tagline: a.tagline,
      description: a.description,
      category: a.category,
      platform: a.platform,
      iconAsset: a.iconAsset,
      brand: a.brand,
      features: a.features,
      state: s,
    );
