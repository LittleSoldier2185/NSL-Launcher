# Sync the files that the core (NSL-UI) generates for the Launcher.
# The Launcher does NOT depend on the nsl_ui package on purpose, but it uses the same data:
#   assets/core/builtin-themes.json   built-in themes of the other apps (so user themes that "extends" them still work)
#   test/fixtures/core-fixtures.json  shared fixture that proves the Launcher engine matches the core
# Usage: powershell -ExecutionPolicy Bypass -File tool\sync_from_core.ps1 [-Core "H:\NSL Project\NSL-UI"]
# (ASCII only on purpose: Windows PowerShell 5.1 reads BOM-less files as ANSI.)
param([string]$Core = (Join-Path $PSScriptRoot '..\..\NSL-UI'))

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$pairs = @(
  @{ From = 'web\src\generated\builtin-themes.json'; To = 'assets\core\builtin-themes.json' },
  @{ From = 'web\fixtures\core-fixtures.json'; To = 'test\fixtures\core-fixtures.json' }
)
foreach ($p in $pairs) {
  $src = Join-Path $Core $p.From
  if (-not (Test-Path $src)) { throw "Missing $src - run NSL_UPDATE_FIXTURES=1 flutter test test/web_fixtures_test.dart in NSL-UI first" }
  $dst = Join-Path $root $p.To
  New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
  Copy-Item $src $dst -Force
  '{0} -> {1}' -f $p.From, $p.To
}
'Done. If the core formulas changed, diff lib/theme_engine against NSL-UI/lib/src (ported files are listed in each file header), then run flutter test.'
