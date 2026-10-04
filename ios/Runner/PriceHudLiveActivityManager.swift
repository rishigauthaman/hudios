import Flutter
import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

final class PriceHudLiveActivityManager {
  private var activityId: String?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "areActivitiesEnabled":
      result(areActivitiesEnabled())
    case "startPriceActivity":
      startPriceActivity(arguments: call.arguments, result: result)
    case "updatePriceActivity":
      updatePriceActivity(arguments: call.arguments, result: result)
    case "endPriceActivity":
      endPriceActivity(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func areActivitiesEnabled() -> Bool {
    #if canImport(ActivityKit)
    if #available(iOS 16.1, *) {
      return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    #endif
    return false
  }

  private func startPriceActivity(arguments: Any?, result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    guard #available(iOS 16.2, *) else {
      result(FlutterError(code: "unsupported_ios", message: "Live Activities require iOS 16.2 or newer in this build.", details: nil))
      return
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(FlutterError(code: "disabled", message: "Live Activities are disabled in Settings.", details: nil))
      return
    }
    guard let data = arguments as? [String: Any] else {
      result(FlutterError(code: "bad_args", message: "Missing Live Activity data.", details: nil))
      return
    }

    Task {
      await endExistingActivity()
      let attributes = PriceHudAttributes(selectedPair: stringValue(data["selectedPair"], fallback: stringValue(data["symbol"], fallback: "BTCUSDT")))
      let content = ActivityContent(state: contentState(from: data), staleDate: Date().addingTimeInterval(60))

      do {
        let activity = try Activity<PriceHudAttributes>.request(
          attributes: attributes,
          content: content,
          pushType: nil
        )
        activityId = activity.id
        DispatchQueue.main.async { result(nil) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
    #else
    result(FlutterError(code: "unavailable", message: "ActivityKit is unavailable.", details: nil))
    #endif
  }

  private func updatePriceActivity(arguments: Any?, result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    guard #available(iOS 16.2, *) else {
      result(nil)
      return
    }
    guard let data = arguments as? [String: Any] else {
      result(FlutterError(code: "bad_args", message: "Missing Live Activity data.", details: nil))
      return
    }

    Task {
      guard let activity = currentActivity() else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      await activity.update(
        ActivityContent(
          state: contentState(from: data),
          staleDate: Date().addingTimeInterval(60)
        )
      )
      DispatchQueue.main.async { result(nil) }
    }
    #else
    result(nil)
    #endif
  }

  private func endPriceActivity(result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    guard #available(iOS 16.2, *) else {
      result(nil)
      return
    }

    Task {
      await endExistingActivity()
      DispatchQueue.main.async { result(nil) }
    }
    #else
    result(nil)
    #endif
  }

  #if canImport(ActivityKit)
  @available(iOS 16.2, *)
  private func endExistingActivity() async {
    for activity in Activity<PriceHudAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
    activityId = nil
  }

  @available(iOS 16.2, *)
  private func currentActivity() -> Activity<PriceHudAttributes>? {
    if let activityId {
      return Activity<PriceHudAttributes>.activities.first { $0.id == activityId }
    }
    return Activity<PriceHudAttributes>.activities.first
  }

  @available(iOS 16.2, *)
  private func contentState(from data: [String: Any]) -> PriceHudAttributes.ContentState {
    let updatedAtMillis = doubleValue(data["updatedAtMillis"], fallback: Date().timeIntervalSince1970 * 1000)
    return PriceHudAttributes.ContentState(
      symbol: stringValue(data["symbol"], fallback: "BTCUSDT"),
      compactSymbol: stringValue(data["compactSymbol"], fallback: "BTC"),
      price: stringValue(data["price"], fallback: "Loading"),
      direction: stringValue(data["direction"], fallback: "UP"),
      percentChange: stringValue(data["percentChange"], fallback: "0.000"),
      isUp: boolValue(data["isUp"], fallback: true),
      showDecimals: boolValue(data["showDecimals"], fallback: true),
      updatedAt: Date(timeIntervalSince1970: updatedAtMillis / 1000)
    )
  }
  #endif

  private func stringValue(_ value: Any?, fallback: String) -> String {
    return value as? String ?? fallback
  }

  private func boolValue(_ value: Any?, fallback: Bool) -> Bool {
    return value as? Bool ?? fallback
  }

  private func doubleValue(_ value: Any?, fallback: Double) -> Double {
    if let double = value as? Double {
      return double
    }
    if let int = value as? Int {
      return Double(int)
    }
    if let number = value as? NSNumber {
      return number.doubleValue
    }
    return fallback
  }
}
