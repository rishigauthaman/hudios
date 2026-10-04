import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
struct PriceHudLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PriceHudAttributes.self) { context in
      PriceHudLockScreenView(state: context.state)
        .activityBackgroundTint(Color(red: 0.03, green: 0.04, blue: 0.04))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            Text(context.state.compactSymbol)
              .font(.headline.weight(.black))
            Text(context.state.direction)
              .font(.caption.weight(.bold))
              .foregroundStyle(context.state.isUp ? .green : .red)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 2) {
            Text(context.state.price)
              .font(.title3.weight(.black))
              .monospacedDigit()
              .minimumScaleFactor(0.7)
            Text("\(context.state.percentChange)%")
              .font(.caption.weight(.bold))
              .foregroundStyle(context.state.isUp ? .green : .red)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack {
            Text(context.state.symbol)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            Spacer()
            Text(context.state.updatedAt, style: .time)
              .font(.caption2.weight(.medium))
              .foregroundStyle(.secondary)
          }
        }
      } compactLeading: {
        Text(context.state.compactSymbol)
          .font(.caption.weight(.black))
      } compactTrailing: {
        Text(context.state.price)
          .font(.caption.weight(.black))
          .monospacedDigit()
          .minimumScaleFactor(0.6)
      } minimal: {
        Circle()
          .fill(context.state.isUp ? Color.green : Color.red)
          .overlay(
            Text(String(context.state.compactSymbol.prefix(1)))
              .font(.caption2.weight(.black))
              .foregroundStyle(.white)
          )
      }
      .keylineTint(context.state.isUp ? .green : .red)
    }
  }
}

@available(iOS 16.1, *)
private struct PriceHudLockScreenView: View {
  let state: PriceHudAttributes.ContentState

  var body: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 4) {
        Text(state.symbol)
          .font(.headline.weight(.black))
          .foregroundStyle(.white)
        Text("\(state.direction) \(state.percentChange)%")
          .font(.caption.weight(.bold))
          .foregroundStyle(state.isUp ? .green : .red)
      }

      Spacer()

      Text(state.price)
        .font(.system(size: 32, weight: .black, design: .rounded))
        .monospacedDigit()
        .minimumScaleFactor(0.65)
        .foregroundStyle(.white)
    }
    .padding(.vertical, 6)
  }
}
