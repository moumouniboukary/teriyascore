#Requires -Version 5.1
<#
.SYNOPSIS
  Génère un keystore (si besoin) et construit l'APK release signée TeriyaScore.

.EXAMPLE
  powershell -File scripts/build-release-apk.ps1
#>
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$AndroidDir = Join-Path $Root "apps\mobile\android"
$KeyProps = Join-Path $AndroidDir "key.properties"
$Keystore = Join-Path $AndroidDir "upload-keystore.jks"
$Mobile = Join-Path $Root "apps\mobile"
$OutDir = Join-Path $Root "dist\apk"

if (-not (Test-Path $KeyProps)) {
  Write-Host "Création keystore + key.properties (dev local — NE PAS committer)..."
  if (-not (Get-Command keytool -ErrorAction SilentlyContinue)) {
    throw "keytool introuvable (JDK requis)."
  }
  $pass = "teriyascore-upload-dev"
  & keytool -genkeypair -v `
    -keystore $Keystore `
    -storepass $pass `
    -keypass $pass `
    -alias upload `
    -keyalg RSA -keysize 2048 -validity 10000 `
    -dname "CN=TeriyaScore, OU=Pilote, O=TeriyaScore, L=Ouagadougou, C=BF"
  @"
storePassword=$pass
keyPassword=$pass
keyAlias=upload
storeFile=upload-keystore.jks
"@ | Set-Content -Path $KeyProps -Encoding ASCII
  Write-Host "Écrit: $KeyProps"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Push-Location $Mobile
try {
  flutter pub get
  flutter build apk --release
  $apk = Join-Path $Mobile "build\app\outputs\flutter-apk\app-release.apk"
  if (-not (Test-Path $apk)) { throw "APK introuvable: $apk" }
  $dest = Join-Path $OutDir "TeriyaScore-commercant.apk"
  Copy-Item $apk $dest -Force
  Write-Host "APK signée: $dest"
} finally {
  Pop-Location
}
