# NSL Launcher · ระบบอัปเดตตัวเอง

ใช้วิธี **แยกโฟลเดอร์ตามเวอร์ชัน** ไม่มีไฟล์ไหนถูกเขียนทับระหว่างโปรแกรมเปิดอยู่ และถ้าเวอร์ชันใหม่เปิดไม่ขึ้นจะย้อนกลับเวอร์ชันเดิมให้เอง

```
NSL Launcher/
├── NSL Launcher.exe     ← stub ตัวเปิด (ไม่ต้องอัปเดต) ผู้ใช้ปักหมุด/สร้างทางลัดที่ไฟล์นี้
├── app-1.0.0/           ← เวอร์ชันสำรอง
│   ├── nsl_launcher.exe
│   └── .ok
├── app-1.1.0/           ← เวอร์ชันที่ใช้อยู่
└── .staging/            ← ไฟล์ zip ระหว่างดาวน์โหลด
```

## ไฟล์ในชุดนี้

| ไฟล์ | หน้าที่ |
|---|---|
| `stub/NSL Launcher.exe` | stub ที่ build แล้ว (Windows x64, 19 KB) ใช้ได้เลย |
| `stub/stub.c` | ซอร์สของ stub ถ้าต้องการแก้ |
| `lib/update/updater.dart` | คลาส `Updater` สำหรับใส่ในโปรเจกต์ Flutter |
| `tools/release.ps1` | สคริปต์ build และแพ็กไฟล์เวลาปล่อยเวอร์ชันใหม่ |
| `tools/latest.example.json` | ตัวอย่าง manifest |

## ลำดับการทำงาน

1. Launcher เปิดขึ้นมา เรียก `markHealthy()` เพื่อบอกว่าเวอร์ชันนี้ใช้ได้ (เขียนไฟล์ `.ok`)
2. `check()` อ่าน `latest.json` ถ้ามีเวอร์ชันใหม่ก็แสดงการ์ดอัปเดต
3. `download()` ดาวน์โหลด zip → ตรวจ SHA-256 → แตกไฟล์ลง `app-X.Y.Z.partial` → เปลี่ยนชื่อเป็น `app-X.Y.Z`
4. ผู้ใช้กด **รีสตาร์ทเพื่ออัปเดต** → `restart()` เปิด stub แล้วปิดตัวเอง
5. stub เลือกโฟลเดอร์เวอร์ชันสูงสุดแล้วเปิด

**ถ้าเวอร์ชันใหม่พัง:** stub สร้าง `.trying` ก่อนเปิดเวอร์ชันที่ยังไม่เคยเปิดสำเร็จ ถ้าแอปปิดไปก่อนถึง `markHealthy()` ครั้งถัดไป stub จะเห็น `.trying` ค้าง แล้วทำเครื่องหมาย `.failed` และเปิดเวอร์ชันก่อนหน้าแทน แอปจะไม่เสนอเวอร์ชันที่ `.failed` ซ้ำ จนกว่าจะมีเวอร์ชันใหม่กว่านั้น

**การล้างไฟล์:** stub เก็บไว้แค่เวอร์ชันที่เปิดอยู่และเวอร์ชันสำรองที่ดีล่าสุด 1 ตัว ที่เหลือลบทิ้ง

## ใส่ในโปรเจกต์ Flutter

1. คัดลอก `lib/update/updater.dart` เข้าโปรเจกต์
2. เพิ่มใน `pubspec.yaml`
   ```yaml
   dependencies:
     archive: ^4.0.0
     crypto: ^3.0.0
   ```
3. ชื่อ exe ต้องเป็น `nsl_launcher.exe` (ชื่อโปรเจกต์ Flutter `nsl_launcher`) ถ้าใช้ชื่ออื่นให้แก้ `APP_EXE` ใน `stub.c` และชื่อใน `updater.dart`
4. ตัวอย่างการเรียกใช้
   ```dart
   final kManifestUrl = Uri.parse(
     'https://github.com/<user>/<repo>/releases/latest/download/latest.json');

   final updater = Updater.forCurrentProcess(manifestUrl: kManifestUrl);

   // หลังเฟรมแรก
   WidgetsBinding.instance.addPostFrameCallback((_) => updater.markHealthy());

   // ตอนเปิดหน้าอัปเดต
   if (updater.isEnabled) {
     final info = await updater.check();
     if (info != null) {
       await updater.download(info, onProgress: (p) => setState(() => progress = p));
       // แสดงปุ่ม "รีสตาร์ทเพื่ออัปเดต" → updater.restart()
     }
   }
   ```

ตอนรันด้วย `flutter run` ระบบอัปเดตจะปิดเอง (`isEnabled == false`) เพราะไม่ได้อยู่ในโฟลเดอร์ `app-X.Y.Z`

## ปล่อยเวอร์ชันใหม่

1. แก้ `version:` ใน `pubspec.yaml` เช่น `1.1.0+3`
2. วาง `stub/NSL Launcher.exe` ไว้ในโปรเจกต์ที่ `stub\`
3. รัน
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\release.ps1 `
     -BaseUrl "https://github.com/<user>/<repo>/releases/download" `
     -Notes "แก้บั๊กหน้าคลังโปรแกรม"
   ```
4. สร้าง GitHub Release แท็ก `v1.1.0` แล้วอัปโหลด
   - `dist\app-1.1.0.zip`
   - `dist\latest.json`
   - `dist\NSL-Launcher-1.1.0-portable.zip` (สำหรับคนที่ติดตั้งครั้งแรก)

ลิงก์ `releases/latest/download/latest.json` ของ GitHub จะชี้ไป release ล่าสุดให้เอง

## build stub ใหม่ (ถ้าแก้ stub.c)

```
x86_64-w64-mingw32-gcc -O2 -municode -mwindows -s stub.c -o "NSL Launcher.exe" -lshell32
```
หรือใน Developer Command Prompt ของ Visual Studio
```
cl /O2 stub.c /link /SUBSYSTEM:WINDOWS shell32.lib user32.lib
```

## ทดสอบแล้ว / ยังไม่ได้ทดสอบ

- **stub:** ทดสอบใน Wine แล้ว ครบ 5 กรณี คือติดตั้งครั้งแรก, เปิดเวอร์ชันใหม่, ย้อนกลับเมื่อเวอร์ชันใหม่พัง, ล้างเวอร์ชันเก่า และเปรียบเทียบ 1.10.0 > 1.9.0 ยังไม่ได้ลองบน Windows จริง
- **updater.dart:** ยังไม่ได้คอมไพล์หรือรัน เพราะเครื่องที่ใช้ทำไม่มี Flutter SDK
- **release.ps1:** ยังไม่ได้รัน
- **SmartScreen:** stub และแอปยังไม่ได้เซ็นดิจิทัล ครั้งแรกที่เปิด Windows อาจเตือน
