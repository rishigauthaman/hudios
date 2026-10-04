# Mac deployment prompt

Open this repository in Codex on a Mac, connect the iPhone by USB, then send
the following prompt:

```text
You are continuing PriceHUD from this repository. Build and run the iOS app on
my connected iPhone, including the Live Activity and Dynamic Island extension.

First inspect docs/IOS_LIVE_ACTIVITY.md and the existing iOS project. Configure
the Runner and PriceHudLiveActivity targets in Xcode with my Apple Team and
unique bundle identifiers. Keep the iOS deployment target at 16.2 or newer.
Verify the Flutter app builds, install it on the connected iPhone, and test
Start Live Activity, live price updates while the app is foregrounded, Stop
Live Activity, and Dynamic Island presentation. Do not add API keys, Apple
certificates, provisioning profiles, or payment details to the repository.

For continuous updates after the app is backgrounded, preserve the secure public
backend design and explain exactly which APNs credentials and server changes are
still required before attempting them.
```

## Mac prerequisites

- macOS with the current Xcode release installed
- Flutter installed or bootstrapped on the Mac
- An iPhone with iOS 16.2 or newer, unlocked and trusted over USB
- An Apple Developer Program membership for device distribution/TestFlight
- Live Activities enabled on the iPhone in Settings
