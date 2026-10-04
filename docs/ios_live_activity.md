# PriceHUD iOS Live Activity

This project includes the Flutter and Swift source for an iOS Live Activity / Dynamic Island price widget.

## What Is Already Added

- `ios/Runner/Info.plist` enables Live Activities with `NSSupportsLiveActivities`.
- `ios/Runner/PriceHudLiveActivityManager.swift` exposes Flutter methods:
  - `areActivitiesEnabled`
  - `startPriceActivity`
  - `updatePriceActivity`
  - `endPriceActivity`
- `ios/Runner/PriceHudAttributes.swift` defines the ActivityKit state model.
- `ios/PriceHudLiveActivity/PriceHudLiveActivityWidget.swift` defines the Lock Screen and Dynamic Island UI.
- `lib/services/live_activity_platform_service.dart` connects Flutter to iOS.
- The home screen shows `Start Live Activity` / `Stop Live Activity` on iOS.

## Finish On A Mac

Apple requires macOS and Xcode to build, sign, and run iOS apps.

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select `Runner`, then set your Apple Team under Signing & Capabilities.
3. Add a new target:
   - File > New > Target
   - Choose `Widget Extension`
   - Product Name: `PriceHudLiveActivity`
   - Enable `Include Live Activity`
4. Replace the generated widget files with the files in `ios/PriceHudLiveActivity`.
5. Add `ios/Runner/PriceHudAttributes.swift` to both targets:
   - `Runner`
   - `PriceHudLiveActivity`
6. Set the widget extension bundle id to:
   - `com.pricehud.priceHud.PriceHudLiveActivity`
7. Set the iOS deployment target for the widget extension to iOS 16.2 or newer.
8. Run on the iPhone, open PriceHUD, then press `Start Live Activity`.

## Important Limitation

The app can update the Live Activity while PriceHUD is running or recently active. For continuous price updates after the app is killed or suspended for a long time, Apple expects ActivityKit push updates through APNs from a server.
