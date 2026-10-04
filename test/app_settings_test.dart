import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:price_hud/models/app_settings.dart';

void main() {
  test('AppSettings round-trips through JSON', () {
    final settings = AppSettings.defaults().copyWith(
      selectedPair: 'ETHUSDT',
      opacity: 0.75,
      textSize: 20,
      themeMode: ThemeMode.dark,
      lockPosition: true,
      showDecimals: false,
      widgetScale: 1.25,
      widgetLayout: OverlayWidgetLayout.circle,
      oandaAccountId: '001-001-1234567-001',
      oandaApiToken: 'test-token',
      oandaUsePractice: false,
    );

    final restored = AppSettings.fromJson(settings.toJson());

    expect(restored.selectedPair, 'ETHUSDT');
    expect(restored.opacity, 0.75);
    expect(restored.textSize, 20);
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.lockPosition, isTrue);
    expect(restored.showDecimals, isFalse);
    expect(restored.widgetScale, 1.25);
    expect(restored.widgetLayout, OverlayWidgetLayout.circle);
    expect(restored.oandaAccountId, '001-001-1234567-001');
    expect(restored.oandaApiToken, 'test-token');
    expect(restored.oandaUsePractice, isFalse);
    expect(restored.mt5BackendUrl, isEmpty);
  });
}
