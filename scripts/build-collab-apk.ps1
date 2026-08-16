#Requires -Version 5.1
# Build APK TeriyaScore collab (API cloud) — meme ligne que TeriyaScore-collaborateur.apk.
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Mobile = Join-Path $Root "apps\mobile"
$OutDir = Join-Path $Root "dist\apk"
$ParentRoot = Split-Path -Parent $Root
$ApiBase = "https://neoforma-api.onrender.com"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Push-Location $Mobile
try {
  flutter pub get
  flutter build apk --debug --dart-define=API_BASE=$ApiBase
  $apk = Join-Path $Mobile "build\app\outputs\flutter-apk\app-debug.apk"
  if (-not (Test-Path $apk)) { throw "APK introuvable: $apk" }

  $destRoot = Join-Path $Root "TeriyaScore-collaborateur.apk"
  $destDist = Join-Path $OutDir "TeriyaScore-collaborateur.apk"
  $destParent = Join-Path $ParentRoot "TeriyaScore-collaborateur.apk"
  Copy-Item $apk $destRoot -Force
  Copy-Item $apk $destDist -Force
  # Racine teriyascore, a cote de TeriyaScore-collaborateur.apk
  if (Test-Path (Join-Path $ParentRoot "package.json")) {
    Copy-Item $apk $destParent -Force
  }

  Write-Host "API_BASE=$ApiBase"
  Write-Host "APK clone:  $destRoot"
  Write-Host "APK parent: $destParent"
} finally {
  Pop-Location
}
