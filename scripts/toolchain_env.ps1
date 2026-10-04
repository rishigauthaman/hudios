$toolingRoot = Join-Path (Get-Location) ".tooling"
$flutterRoot = Join-Path $toolingRoot "sdks\flutter"
$jdkHome = Join-Path $toolingRoot "sdks\jdk-21\jdk-21.0.7+6"
$androidSdk = Join-Path $toolingRoot "android-sdk"
$cmdlineTools = Join-Path $androidSdk "cmdline-tools\latest"
$appData = Join-Path $toolingRoot "appdata"
$localAppData = Join-Path $toolingRoot "localappdata"
$pubCache = Join-Path $toolingRoot "pub-cache"
$tempDir = Join-Path $toolingRoot "tmp"

New-Item -ItemType Directory -Force -Path $appData, $localAppData, $pubCache, $tempDir | Out-Null

$env:JAVA_HOME = $jdkHome
$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk
$env:APPDATA = $appData
$env:LOCALAPPDATA = $localAppData
$env:PUB_CACHE = $pubCache
$env:TEMP = $tempDir
$env:TMP = $tempDir
$env:FLUTTER_SUPPRESS_ANALYTICS = "true"
$env:DART_SUPPRESS_ANALYTICS = "true"
$env:Path = "$flutterRoot\bin;$jdkHome\bin;$cmdlineTools\bin;$androidSdk\platform-tools;$env:Path"

$safeFlutterRoot = $flutterRoot.Replace("\", "/")
$env:GIT_CONFIG_COUNT = "1"
$env:GIT_CONFIG_KEY_0 = "safe.directory"
$env:GIT_CONFIG_VALUE_0 = $safeFlutterRoot
