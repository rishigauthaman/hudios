import SwiftUI
import WidgetKit

@main
struct PriceHudLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOS 16.1, *) {
      PriceHudLiveActivityWidget()
    }
  }
}
