import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

enum OverlayWidgetLayout { pill, square, circle }

class AppSettings {
  const AppSettings({
    required this.selectedPair,
    required this.opacity,
    required this.backgroundTransparency,
    required this.overlayColorValue,
    required this.cornerRadius,
    required this.priceFlashEnabled,
    required this.showDecimals,
    required this.textSize,
    required this.widgetScale,
    required this.widgetLayout,
    required this.updateFrequencyMs,
    required this.themeMode,
    required this.lockPosition,
    required this.startOnBoot,
    required this.oandaAccountId,
    required this.oandaApiToken,
    required this.oandaUsePractice,
    required this.mt5BackendUrl,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      selectedPair: AppConstants.defaultPair,
      opacity: 1,
      backgroundTransparency: 0.18,
      overlayColorValue: 0xFF050608,
      cornerRadius: 16,
      priceFlashEnabled: true,
      showDecimals: true,
      textSize: 18,
      widgetScale: 1,
      widgetLayout: OverlayWidgetLayout.pill,
      updateFrequencyMs: 1000,
      themeMode: ThemeMode.system,
      lockPosition: false,
      startOnBoot: false,
      oandaAccountId: '',
      oandaApiToken: '',
      oandaUsePractice: true,
      mt5BackendUrl: '',
    );
  }

  factory AppSettings.fromJson(Map<dynamic, dynamic> json) {
    final defaults = AppSettings.defaults();

    return AppSettings(
      selectedPair: json['selectedPair'] as String? ?? defaults.selectedPair,
      opacity: (json['opacity'] as num?)?.toDouble() ?? defaults.opacity,
      backgroundTransparency:
          (json['backgroundTransparency'] as num?)?.toDouble() ??
          defaults.backgroundTransparency,
      overlayColorValue:
          (json['overlayColorValue'] as num?)?.toInt() ??
          defaults.overlayColorValue,
      cornerRadius:
          (json['cornerRadius'] as num?)?.toDouble() ?? defaults.cornerRadius,
      priceFlashEnabled:
          json['priceFlashEnabled'] as bool? ?? defaults.priceFlashEnabled,
      showDecimals: json['showDecimals'] as bool? ?? defaults.showDecimals,
      textSize: (json['textSize'] as num?)?.toDouble() ?? defaults.textSize,
      widgetScale:
          (json['widgetScale'] as num?)?.toDouble() ?? defaults.widgetScale,
      widgetLayout:
          _widgetLayoutFromName(json['widgetLayout'] as String?) ??
          defaults.widgetLayout,
      updateFrequencyMs:
          (json['updateFrequencyMs'] as num?)?.toInt() ??
          defaults.updateFrequencyMs,
      themeMode:
          _themeModeFromName(json['themeMode'] as String?) ??
          defaults.themeMode,
      lockPosition: json['lockPosition'] as bool? ?? defaults.lockPosition,
      startOnBoot: json['startOnBoot'] as bool? ?? defaults.startOnBoot,
      oandaAccountId:
          json['oandaAccountId'] as String? ?? defaults.oandaAccountId,
      oandaApiToken: json['oandaApiToken'] as String? ?? defaults.oandaApiToken,
      oandaUsePractice:
          json['oandaUsePractice'] as bool? ?? defaults.oandaUsePractice,
      mt5BackendUrl: _readBackendUrl(json, defaults.mt5BackendUrl),
    );
  }

  final String selectedPair;
  final double opacity;
  final double backgroundTransparency;
  final int overlayColorValue;
  final double cornerRadius;
  final bool priceFlashEnabled;
  final bool showDecimals;
  final double textSize;
  final double widgetScale;
  final OverlayWidgetLayout widgetLayout;
  final int updateFrequencyMs;
  final ThemeMode themeMode;
  final bool lockPosition;
  final bool startOnBoot;
  final String oandaAccountId;
  final String oandaApiToken;
  final bool oandaUsePractice;

  /// Public HTTPS endpoint. Device credentials live in secure storage, never here.
  final String mt5BackendUrl;

  bool get isOandaConfigured => oandaApiToken.trim().isNotEmpty;

  AppSettings copyWith({
    String? selectedPair,
    double? opacity,
    double? backgroundTransparency,
    int? overlayColorValue,
    double? cornerRadius,
    bool? priceFlashEnabled,
    bool? showDecimals,
    double? textSize,
    double? widgetScale,
    OverlayWidgetLayout? widgetLayout,
    int? updateFrequencyMs,
    ThemeMode? themeMode,
    bool? lockPosition,
    bool? startOnBoot,
    String? oandaAccountId,
    String? oandaApiToken,
    bool? oandaUsePractice,
    String? mt5BackendUrl,
  }) {
    return AppSettings(
      selectedPair: selectedPair ?? this.selectedPair,
      opacity: opacity ?? this.opacity,
      backgroundTransparency:
          backgroundTransparency ?? this.backgroundTransparency,
      overlayColorValue: overlayColorValue ?? this.overlayColorValue,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      priceFlashEnabled: priceFlashEnabled ?? this.priceFlashEnabled,
      showDecimals: showDecimals ?? this.showDecimals,
      textSize: textSize ?? this.textSize,
      widgetScale: widgetScale ?? this.widgetScale,
      widgetLayout: widgetLayout ?? this.widgetLayout,
      updateFrequencyMs: updateFrequencyMs ?? this.updateFrequencyMs,
      themeMode: themeMode ?? this.themeMode,
      lockPosition: lockPosition ?? this.lockPosition,
      startOnBoot: startOnBoot ?? this.startOnBoot,
      oandaAccountId: oandaAccountId ?? this.oandaAccountId,
      oandaApiToken: oandaApiToken ?? this.oandaApiToken,
      oandaUsePractice: oandaUsePractice ?? this.oandaUsePractice,
      mt5BackendUrl: mt5BackendUrl ?? this.mt5BackendUrl,
    );
  }

  Map<String, Object> toJson() {
    return {
      'selectedPair': selectedPair,
      'opacity': opacity,
      'backgroundTransparency': backgroundTransparency,
      'overlayColorValue': overlayColorValue,
      'cornerRadius': cornerRadius,
      'priceFlashEnabled': priceFlashEnabled,
      'showDecimals': showDecimals,
      'textSize': textSize,
      'widgetScale': widgetScale,
      'widgetLayout': widgetLayout.name,
      'updateFrequencyMs': updateFrequencyMs,
      'themeMode': themeMode.name,
      'lockPosition': lockPosition,
      'startOnBoot': startOnBoot,
      'oandaAccountId': oandaAccountId,
      'oandaApiToken': oandaApiToken,
      'oandaUsePractice': oandaUsePractice,
      'mt5BackendUrl': mt5BackendUrl,
    };
  }

  static ThemeMode? _themeModeFromName(String? name) {
    for (final mode in ThemeMode.values) {
      if (mode.name == name) {
        return mode;
      }
    }
    return null;
  }

  static OverlayWidgetLayout? _widgetLayoutFromName(String? name) {
    for (final layout in OverlayWidgetLayout.values) {
      if (layout.name == name) {
        return layout;
      }
    }
    return null;
  }

  static String _readBackendUrl(Map<dynamic, dynamic> json, String fallback) {
    final configured = (json['mt5BackendUrl'] as String? ?? '').trim();
    if (configured.isNotEmpty) return configured;

    // A private bridge was never a valid production endpoint. Drop it during
    // migration so an upgraded app must be explicitly activated on HTTPS.
    final legacy = (json['mt5BridgeUrl'] as String? ?? '').trim();
    return legacy.startsWith('https://') ? legacy : fallback;
  }
}
