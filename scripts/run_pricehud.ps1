$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
. .\scripts\toolchain_env.ps1

Write-Host "Starting PriceHUD..."
Write-Host ""

$devicesOutput = flutter devices --machine
$devices = $devicesOutput | ConvertFrom-Json
$androidDevice = $devices | Where-Object { $_.targetPlatform -like "android*" } | Select-Object -First 1

if ($androidDevice) {
    Write-Host "Launching on Android device: $($androidDevice.name)"
    flutter run -d $androidDevice.id
    exit $LASTEXITCODE
}

Write-Host "No Android phone or emulator is connected."
Write-Host "Launching PriceHUD in Chrome preview instead."
Write-Host ""
flutter run -d chrome
exit $LASTEXITCODE
