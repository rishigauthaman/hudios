import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct PriceHudAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    let symbol: String
    let compactSymbol: String
    let price: String
    let direction: String
    let percentChange: String
    let isUp: Bool
    let showDecimals: Bool
    let updatedAt: Date
  }

  let selectedPair: String
}
#endif
