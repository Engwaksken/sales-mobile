$ErrorActionPreference = "Stop"

Write-Host "NSales Native Mobile Setup" -ForegroundColor Cyan

$flutter = Get-Command flutter -ErrorAction SilentlyContinue

if (-not $flutter) {
    $known = "D:\development\flutter\bin\flutter.bat"

    if (Test-Path $known) {
        $flutterCmd = $known
    }
    else {
        throw "Flutter was not found. Add Flutter to PATH or edit setup_native_app.ps1 with your flutter.bat path."
    }
}
else {
    $flutterCmd = $flutter.Source
}

Write-Host "Using Flutter: $flutterCmd" -ForegroundColor Green

# Preserve NSales sources because `flutter create` may create template files.
$temp = Join-Path $env:TEMP ("nsales-native-" + [Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $temp | Out-Null

Copy-Item ".\lib" $temp -Recurse -Force
Copy-Item ".\pubspec.yaml" $temp -Force
Copy-Item ".\analysis_options.yaml" $temp -Force

& $flutterCmd create . --platforms=android,ios --org com.kemmytech --project-name nsales_native

Remove-Item ".\lib" -Recurse -Force
Copy-Item (Join-Path $temp "lib") ".\lib" -Recurse -Force
Copy-Item (Join-Path $temp "pubspec.yaml") ".\pubspec.yaml" -Force
Copy-Item (Join-Path $temp "analysis_options.yaml") ".\analysis_options.yaml" -Force

# Android permissions/application config.
Copy-Item ".\platform\AndroidManifest.xml" ".\android\app\src\main\AndroidManifest.xml" -Force

# iOS ML Kit requires iOS 15.5+.
Copy-Item ".\platform\Podfile" ".\ios\Podfile" -Force

# Add iOS permission keys if not already present.
$plistPath = ".\ios\Runner\Info.plist"
$plist = Get-Content $plistPath -Raw

if ($plist -notmatch "NSCameraUsageDescription") {
    $keys = @"
    <key>NSCameraUsageDescription</key>
    <string>NSales uses the camera to scan expense receipts.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>NSales lets you select receipt images from your photo library.</string>
"@
    $plist = $plist -replace "</dict>", "$keys`r`n</dict>"
    Set-Content $plistPath $plist -Encoding UTF8
}

& $flutterCmd clean
& $flutterCmd pub get

Write-Host ""
Write-Host "Setup completed." -ForegroundColor Green
Write-Host "Android: flutter run" -ForegroundColor Yellow
Write-Host "Release APK: flutter build apk --release" -ForegroundColor Yellow
Write-Host "iOS must be built on macOS/Xcode: flutter build ios" -ForegroundColor Yellow
