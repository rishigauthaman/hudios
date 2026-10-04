import 'package:flutter/services.dart';

import '../models/app_settings.dart';

class OverlayPlatformService {
  const OverlayPlatformService._();

  static const _channel = MethodChannel('pricehud/overlay');

  static Future<bool> canDrawOverlays() async {
    final value = await _channel.invokeMethod<bool>('canDrawOverlays');
    return value ?? false;
  }

  static Future<void> openOverlaySettings() {
    return _channel.invokeMethod<void>('openOverlaySettings');
  }

  static Future<bool> isOverlayRunning() async {
    final value = await _channel.invokeMethod<bool>('isOverlayRunning');
    return value ?? false;
  }

  static Future<void> startOverlay(
    AppSettings settings, {
    String? mt5DeviceToken,
  }) {
    return _channel.invokeMethod<void>('startOverlay', {
      'symbol': settings.selectedPair,
      'opacity': settings.opacity,
      'transparency': settings.backgroundTransparency,
      'color': settings.overlayColorValue,
      'cornerRadius': settings.cornerRadius,
      'textSize': settings.textSize,
      'widgetScale': settings.widgetScale,
      'widgetLayout': settings.widgetLayout.name,
      'priceFlashEnabled': settings.priceFlashEnabled,
      'showDecimals': settings.showDecimals,
      'lockPosition': settings.lockPosition,
      'mt5BackendUrl': settings.mt5BackendUrl,
      'mt5DeviceToken': mt5DeviceToken,
    });
  }

  static Future<void> stopOverlay() {
    return _channel.invokeMethod<void>('stopOverlay');
  }
}
