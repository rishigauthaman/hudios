# PriceHUD

PriceHUD is a Flutter market-price overlay for Android with an iOS Live
Activity and Dynamic Island implementation.

## Secure MT5 architecture

The mobile app never connects to a PC or private Wi-Fi address. A Windows MT5
agent publishes read-only quotes to the public HTTPS API; authorized devices
then read the latest quote with a device token stored in secure storage.

See [backend/README.md](backend/README.md) for deployment and
[docs/PLAY_STORE_RELEASE.md](docs/PLAY_STORE_RELEASE.md) for Android release
work.

## Run on a Mac

Read [docs/IOS_LIVE_ACTIVITY.md](docs/IOS_LIVE_ACTIVITY.md), then use the
copy-ready prompt in [docs/MAC_DEPLOY_PROMPT.md](docs/MAC_DEPLOY_PROMPT.md).

## Local Flutter commands

```powershell
. .\scripts\toolchain_env.ps1
flutter analyze
flutter test
flutter build apk --debug
```

## Local Toolchain

This workspace uses a project-local Flutter, JDK, and Android SDK under `.tooling/`.
The directory is ignored by Git.

Run commands through the helper script:

```powershell
. .\scripts\toolchain_env.ps1
flutter analyze
flutter test
flutter build apk --debug
```

To reinstall or repair the local toolchain:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\setup_toolchain.ps1
```
