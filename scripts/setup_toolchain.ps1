param(
    [string]$ToolingRoot = ".tooling"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Resolve-ToolPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path (Get-Location) $Path
}

function Download-File([string]$Url, [string]$OutFile) {
    $parent = Split-Path -Parent $OutFile
    New-Item -ItemType Directory -Force -Path $parent | Out-Null

    if (Test-Path $OutFile) {
        Write-Host "Using existing download: $OutFile"
        return
    }

    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $OutFile
}

function Expand-ZipOnce([string]$ZipFile, [string]$Destination, [string]$ExpectedPath) {
    if (Test-Path $ExpectedPath) {
        Write-Host "Using existing extracted directory: $ExpectedPath"
        return
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Write-Host "Extracting $ZipFile"
    Expand-Archive -LiteralPath $ZipFile -DestinationPath $Destination -Force
}

$root = Resolve-ToolPath $ToolingRoot
$downloads = Join-Path $root "downloads"
$sdks = Join-Path $root "sdks"
$androidSdk = Join-Path $root "android-sdk"

New-Item -ItemType Directory -Force -Path $downloads, $sdks, $androidSdk | Out-Null

$flutterReleasesUri = "https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json"
$flutterReleases = Invoke-RestMethod -Uri $flutterReleasesUri
$stableHash = $flutterReleases.current_release.stable
$stableRelease = $flutterReleases.releases | Where-Object { $_.hash -eq $stableHash } | Select-Object -First 1
if (-not $stableRelease) {
    throw "Could not resolve the latest stable Flutter release."
}

$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/$($stableRelease.archive)"
$flutterZip = Join-Path $downloads (Split-Path $stableRelease.archive -Leaf)
$flutterRoot = Join-Path $sdks "flutter"

Download-File -Url $flutterUrl -OutFile $flutterZip
Expand-ZipOnce -ZipFile $flutterZip -Destination $sdks -ExpectedPath $flutterRoot

$jdkVersion = "21.0.7+6"
$jdkVersionEncoded = $jdkVersion.Replace("+", "%2B")
$jdkFileVersion = $jdkVersion.Replace("+", "_")
$jdkUrl = "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-$jdkVersionEncoded/OpenJDK21U-jdk_x64_windows_hotspot_$jdkFileVersion.zip"
$jdkZip = Join-Path $downloads "OpenJDK21U-jdk_x64_windows_hotspot_$jdkFileVersion.zip"
$jdkExtractRoot = Join-Path $sdks "jdk-21"

Download-File -Url $jdkUrl -OutFile $jdkZip
Expand-ZipOnce -ZipFile $jdkZip -Destination $jdkExtractRoot -ExpectedPath (Join-Path $jdkExtractRoot "jdk-21.0.7+6")

$cmdlineToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip"
$cmdlineToolsZip = Join-Path $downloads "commandlinetools-win-latest.zip"
$cmdlineToolsLatest = Join-Path $androidSdk "cmdline-tools\latest"

Download-File -Url $cmdlineToolsUrl -OutFile $cmdlineToolsZip
Expand-ZipOnce -ZipFile $cmdlineToolsZip -Destination $androidSdk -ExpectedPath $cmdlineToolsLatest

$extractedCmdlineTools = Join-Path $androidSdk "cmdline-tools"
$nestedCmdlineTools = Join-Path $extractedCmdlineTools "cmdline-tools"
if ((Test-Path $nestedCmdlineTools) -and -not (Test-Path $cmdlineToolsLatest)) {
    New-Item -ItemType Directory -Force -Path $cmdlineToolsLatest | Out-Null
    Get-ChildItem -LiteralPath $nestedCmdlineTools -Force | Move-Item -Destination $cmdlineToolsLatest
    Remove-Item -LiteralPath $nestedCmdlineTools -Force
}

$flatSdkManager = Join-Path $extractedCmdlineTools "bin\sdkmanager.bat"
if ((Test-Path $flatSdkManager) -and -not (Test-Path $cmdlineToolsLatest)) {
    New-Item -ItemType Directory -Force -Path $cmdlineToolsLatest | Out-Null
    Get-ChildItem -LiteralPath $extractedCmdlineTools -Force |
        Where-Object { $_.FullName -ne $cmdlineToolsLatest } |
        Move-Item -Destination $cmdlineToolsLatest
}

$jdkHome = Join-Path $jdkExtractRoot "jdk-21.0.7+6"
$env:JAVA_HOME = $jdkHome
$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk
$env:Path = "$flutterRoot\bin;$jdkHome\bin;$cmdlineToolsLatest\bin;$androidSdk\platform-tools;$env:Path"

$sdkManager = Join-Path $cmdlineToolsLatest "bin\sdkmanager.bat"
if (-not (Test-Path $sdkManager)) {
    throw "sdkmanager was not found at $sdkManager"
}

Write-Host "Accepting Android SDK licenses"
cmd /c "for /l %i in (1,1,80) do @echo y" | & $sdkManager --licenses | Out-Host

$packages = @(
    "platform-tools",
    "platforms;android-35",
    "platforms;android-36",
    "build-tools;35.0.0",
    "build-tools;36.0.0",
    "build-tools;28.0.3"
)

Write-Host "Installing Android SDK packages"
& $sdkManager --install $packages

Write-Host ""
Write-Host "Toolchain installed."
Write-Host "Flutter: $flutterRoot"
Write-Host "Java: $jdkHome"
Write-Host "Android SDK: $androidSdk"
Write-Host ""
Write-Host "For this PowerShell session, run:"
Write-Host "`$env:JAVA_HOME='$jdkHome'"
Write-Host "`$env:ANDROID_HOME='$androidSdk'"
Write-Host "`$env:ANDROID_SDK_ROOT='$androidSdk'"
Write-Host "`$env:Path='$flutterRoot\bin;$jdkHome\bin;$cmdlineToolsLatest\bin;$androidSdk\platform-tools;' + `$env:Path"
