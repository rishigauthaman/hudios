import 'package:flutter/services.dart';

import '../models/app_settings.dart';
import '../models/price_model.dart';
import '../utils/formatters.dart';

class LiveActivityPlatformService {
  const LiveActivityPlatformService._();

  static const _channel = MethodChannel('pricehud/live_activity');

  static Future<bool> areActivitiesEnabled() async {
    final value = await _channel.invokeMethod<bool>('areActivitiesEnabled');
    return value ?? false;
  }

  static Future<void> startPriceActivity({
    required AppSettings settings,
    PriceModel? price,
  }) {
    return _channel.invokeMethod<void>('startPriceActivity', {
      'selectedPair': settings.selectedPair,
      ..._payload(settings: settings, price: price),
    });
  }

  static Future<void> updatePriceActivity({
    required AppSettings settings,
    required PriceModel price,
  }) {
    return _channel.invokeMethod<void>(
      'updatePriceActivity',
      _payload(settings: settings, price: price),
    );
  }

  static Future<void> endPriceActivity() {
    return _channel.invokeMethod<void>('endPriceActivity');
  }

  static Map<String, Object> _payload({
    required AppSettings settings,
    PriceModel? price,
  }) {
    final symbol = price?.symbol ?? settings.selectedPair;
    final compactSymbol = symbol.endsWith('USDT')
        ? symbol.substring(0, symbol.length - 4)
        : symbol;
    final latest = price?.price ?? 0;
    final percentChange = price?.percentChange ?? 0;

    return {
      'symbol': symbol,
      'compactSymbol': compactSymbol,
      'price': latest > 0
          ? Formatters.compactPrice(latest, showDecimals: settings.showDecimals)
          : 'Loading',
      'direction': percentChange < 0 ? 'DOWN' : 'UP',
      'percentChange': percentChange.toStringAsFixed(3),
      'isUp': percentChange >= 0,
      'showDecimals': settings.showDecimals,
      'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
    };
  }
}
