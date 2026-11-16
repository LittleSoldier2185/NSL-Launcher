# สร้างไฟล์สำหรับปล่อยเวอร์ชันใหม่ของ NSL Launcher
# รันจากโฟลเดอร์โปรเจกต์ Flutter:  powershell -ExecutionPolicy Bypass -File tools\release.ps1 -BaseUrl "https://github.com/<user>/<repo>/releases/download"
#
# ผลลัพธ์ในโฟลเดอร์ dist\
#   app-X.Y.Z.zip                  ไฟล์อัปเดต (Launcher ดาวน์โหลดตัวนี้)
#   NSL-Launcher-X.Y.Z-portable.zip  ชุดติดตั้งครั้งแรก: stub + app-X.Y.Z\ แตกแล้วใช้ได้เลย
#   latest.json                    manifest ที่อัปเดตแล้ว (อัปโหลดทับของเดิม)

param(
  [Parameter(Mandatory = $true)][string]$BaseUrl,
  [string]$Notes = "",
  [string]$Stub = "stub\NSL Launcher.exe",
  [string]$Manifest = "dist\latest.json"
)
$ErrorActionPreference = "Stop"

# 1. อ่านเวอร์ชันจาก pubspec.yaml (ตัด +build ทิ้ง)
$line = Select-String -Path pubspec.yaml -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)' | Select-Object -First 1
if (-not $line) { throw "ไม่พบ version: X.Y.Z ใน pubspec.yaml" }
$ver = $line.Matches[0].Groups[1].Value
Write-Host "เวอร์ชัน $ver"

# 2. build
flutter build windows --release
$release = "build\windows\x64\runner\Release"
if (-not (Test-Path "$release\nsl_launcher.exe")) { throw "ไม่พบ $release\nsl_launcher.exe" }

New-Item -ItemType Directory -Force dist | Out-Null

# 3. zip สำหรับอัปเดต (ไฟล์อยู่ที่ระดับบนสุดของ zip)
$zip = "dist\app-$ver.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$release\*" -DestinationPath $zip
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $zip).Length

# 4. ชุดติดตั้งครั้งแรก
$stage = "dist\portable\NSL Launcher"
if (Test-Path "dist\portable") { Remove-Item -Recurse -Force "dist\portable" }
New-Item -ItemType Directory -Force "$stage\app-$ver" | Out-Null
Copy-Item "$release\*" "$stage\app-$ver" -Recurse
Copy-Item $Stub "$stage\NSL Launcher.exe"
New-Item -ItemType File "$stage\app-$ver\.ok" | Out-Null
$portable = "dist\NSL-Launcher-$ver-portable.zip"
if (Test-Path $portable) { Remove-Item $portable }
Compress-Archive -Path "dist\portable\NSL Launcher" -DestinationPath $portable

# 5. อัปเดต manifest
if (Test-Path $Manifest) { $m = Get-Content $Manifest -Raw | ConvertFrom-Json }
else { $m = [pscustomobject]@{ schema = 1; products = [pscustomobject]@{} } }
$entry = [pscustomobject]@{
  version = $ver
  url     = "$BaseUrl/v$ver/app-$ver.zip"
  sha256  = $hash
  size    = $size
  notes   = $Notes
}
$m.products | Add-Member -NotePropertyName launcher -NotePropertyValue $entry -Force
# เขียนแบบ UTF-8 ไม่มี BOM (PowerShell 5 ใส่ BOM ถ้าใช้ Set-Content)
$json = $m | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText((Join-Path (Get-Location) $Manifest), $json, (New-Object System.Text.UTF8Encoding $false))

Write-Host ""
Write-Host "เสร็จแล้ว:"
Write-Host "  $zip  ($size bytes, sha256 $hash)"
Write-Host "  $portable"
Write-Host "  $Manifest"
Write-Host "อัปโหลด app-$ver.zip ไปที่ release แท็ก v$ver แล้วอัปโหลด latest.json ไปยัง URL ที่ Launcher อ่าน"
