// NSL Launcher stub — ตัวเปิดเล็ก ๆ ที่อยู่นอกโฟลเดอร์เวอร์ชันและไม่ต้องอัปเดตเลย
//
// โครงสร้างที่คาดไว้:
//   <โฟลเดอร์ติดตั้ง>/
//     NSL Launcher.exe      <- ไฟล์นี้
//     app-1.0.0/nsl_launcher.exe ...
//     app-1.1.0/nsl_launcher.exe ...
//
// การทำงาน:
//   1. หาโฟลเดอร์ app-X.Y.Z ทั้งหมด ข้ามโฟลเดอร์ที่มีไฟล์ .failed
//   2. เลือกเวอร์ชันสูงสุด
//      - มี .ok            -> เปิดได้เลย
//      - ยังไม่มี .ok      -> เวอร์ชันใหม่ที่ยังไม่เคยเปิดสำเร็จ: สร้าง .trying แล้วลองเปิด
//      - มี .trying ค้างอยู่ -> ครั้งก่อนเปิดไม่สำเร็จ: ทำเครื่องหมาย .failed แล้วถอยไปเวอร์ชันก่อนหน้า
//   3. แอปเขียน .ok และลบ .trying เองหลังเปิดขึ้นมาได้ (ดู updater.dart: markHealthy)
//   4. ลบโฟลเดอร์เก่า เก็บไว้แค่ตัวที่เปิดและตัวสำรองที่ดีล่าสุด 1 ตัว
//
// build: x86_64-w64-mingw32-gcc -O2 -municode -mwindows stub.c -o "NSL Launcher.exe" -lshell32
//   หรือ MSVC: cl /O2 stub.c /link /SUBSYSTEM:WINDOWS shell32.lib user32.lib

#define WIN32_LEAN_AND_MEAN
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <shellapi.h>
#include <wchar.h>

#define APP_EXE L"nsl_launcher.exe"   // ชื่อ exe ของ Flutter (ตามชื่อโปรเจกต์)
#define MAX_VERSIONS 64

typedef struct { int v[3]; wchar_t name[MAX_PATH]; int ok, trying, failed; } Ver;

static wchar_t g_root[MAX_PATH];

static int parse_version(const wchar_t *name, int out[3]) {
  if (wcsncmp(name, L"app-", 4) != 0) return 0;
  const wchar_t *p = name + 4;
  for (int i = 0; i < 3; i++) {
    if (*p < L'0' || *p > L'9') return 0;
    int n = 0;
    while (*p >= L'0' && *p <= L'9') { n = n * 10 + (*p - L'0'); p++; if (n > 99999) return 0; }
    out[i] = n;
    if (i < 2) { if (*p != L'.') return 0; p++; }
  }
  return *p == 0;  // ไม่รับ app-1.2.0.partial หรือชื่ออื่นที่มีส่วนต่อท้าย
}

static int cmp(const Ver *a, const Ver *b) {
  for (int i = 0; i < 3; i++) if (a->v[i] != b->v[i]) return a->v[i] < b->v[i] ? -1 : 1;
  return 0;
}

static void path_in(wchar_t *out, const wchar_t *dir, const wchar_t *file) {
  _snwprintf(out, MAX_PATH, L"%ls\\%ls\\%ls", g_root, dir, file);
  out[MAX_PATH - 1] = 0;
}

static int has_marker(const wchar_t *dir, const wchar_t *marker) {
  wchar_t p[MAX_PATH]; path_in(p, dir, marker);
  return GetFileAttributesW(p) != INVALID_FILE_ATTRIBUTES;
}

static void touch_marker(const wchar_t *dir, const wchar_t *marker) {
  wchar_t p[MAX_PATH]; path_in(p, dir, marker);
  HANDLE h = CreateFileW(p, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
  if (h != INVALID_HANDLE_VALUE) CloseHandle(h);
}

static void delete_dir(const wchar_t *dir) {
  // SHFileOperation ต้องการ path ที่จบด้วย \0\0
  wchar_t from[MAX_PATH + 2] = {0};
  _snwprintf(from, MAX_PATH, L"%ls\\%ls", g_root, dir);
  SHFILEOPSTRUCTW op = {0};
  op.wFunc = FO_DELETE;
  op.pFrom = from;
  op.fFlags = FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_SILENT;
  SHFileOperationW(&op);
}

static int launch(const wchar_t *dir) {
  wchar_t exe[MAX_PATH], cwd[MAX_PATH];
  path_in(exe, dir, APP_EXE);
  _snwprintf(cwd, MAX_PATH, L"%ls\\%ls", g_root, dir);
  if (GetFileAttributesW(exe) == INVALID_FILE_ATTRIBUTES) return 0;

  // ส่งต่ออาร์กิวเมนต์ทั้งหมดที่ stub ได้รับ
  const wchar_t *args = GetCommandLineW();
  if (*args == L'"') { args++; while (*args && *args != L'"') args++; if (*args) args++; }
  else { while (*args && *args != L' ') args++; }
  while (*args == L' ') args++;

  static wchar_t cmd[32768];
  _snwprintf(cmd, 32767, L"\"%ls\" %ls", exe, args);
  STARTUPINFOW si = { sizeof(si) };
  PROCESS_INFORMATION pi;
  if (!CreateProcessW(exe, cmd, NULL, NULL, FALSE, 0, NULL, cwd, &si, &pi)) return 0;
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  return 1;
}

int WINAPI wWinMain(HINSTANCE hi, HINSTANCE hp, PWSTR cmdline, int show) {
  (void)hi; (void)hp; (void)cmdline; (void)show;
  GetModuleFileNameW(NULL, g_root, MAX_PATH);
  wchar_t *slash = wcsrchr(g_root, L'\\');
  if (slash) *slash = 0;

  // 1. หาโฟลเดอร์เวอร์ชัน
  static Ver vers[MAX_VERSIONS];
  int n = 0;
  wchar_t pattern[MAX_PATH];
  _snwprintf(pattern, MAX_PATH, L"%ls\\app-*", g_root);
  WIN32_FIND_DATAW fd;
  HANDLE h = FindFirstFileW(pattern, &fd);
  if (h != INVALID_HANDLE_VALUE) {
    do {
      if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) || n >= MAX_VERSIONS) continue;
      Ver v = {0};
      if (!parse_version(fd.cFileName, v.v)) continue;
      wcsncpy(v.name, fd.cFileName, MAX_PATH - 1);
      v.ok = has_marker(v.name, L".ok");
      v.trying = has_marker(v.name, L".trying");
      v.failed = has_marker(v.name, L".failed");
      vers[n++] = v;
    } while (FindNextFileW(h, &fd));
    FindClose(h);
  }

  // เรียงจากใหม่ไปเก่า
  for (int i = 1; i < n; i++) {
    Ver t = vers[i]; int j = i - 1;
    while (j >= 0 && cmp(&vers[j], &t) < 0) { vers[j + 1] = vers[j]; j--; }
    vers[j + 1] = t;
  }

  // 2. เลือกและเปิด
  int chosen = -1;
  for (int i = 0; i < n; i++) {
    Ver *v = &vers[i];
    if (v->failed) continue;
    if (!v->ok && v->trying) {          // ครั้งก่อนเปิดแล้วไม่ถึง markHealthy
      touch_marker(v->name, L".failed");
      v->failed = 1;
      continue;
    }
    if (!v->ok) touch_marker(v->name, L".trying");
    if (launch(v->name)) { chosen = i; break; }
    touch_marker(v->name, L".failed");  // ไม่มี exe หรือเปิดไม่ได้
    v->failed = 1;
  }

  if (chosen < 0) {
    MessageBoxW(NULL, L"ไม่พบ NSL Launcher ที่เปิดได้\nลองติดตั้งใหม่อีกครั้ง", L"NSL Launcher", MB_ICONERROR);
    return 1;
  }

  // 3. ล้างของเก่า: เก็บตัวที่เปิด + ตัวที่ดี (.ok) ล่าสุดที่เก่ากว่า 1 ตัวไว้ย้อนกลับ
  //    เวอร์ชันที่ใหม่กว่าและ .failed เก็บไว้ เพื่อให้แอปรู้ว่าไม่ต้องดาวน์โหลดเวอร์ชันนั้นซ้ำ
  int kept_backup = 0;
  for (int i = 0; i < n; i++) {
    if (i == chosen) continue;
    Ver *v = &vers[i];
    if (i > chosen && v->ok && !v->failed && !kept_backup) { kept_backup = 1; continue; }
    if (i < chosen) continue;  // ใหม่กว่าตัวที่เปิด (เวอร์ชันที่พัง) เก็บไว้
    delete_dir(v->name);
  }
  return 0;
}
