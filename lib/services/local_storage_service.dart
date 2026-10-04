import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants/app_constants.dart';
import '../models/app_settings.dart';
import '../models/overlay_position.dart';

class LocalStorageService {
  const LocalStorageService._(this._box);

  final Box<dynamic> _box;

  static Future<LocalStorageService> open() async {
    await Hive.initFlutter();
    final box = await _openSettingsBox();
    return LocalStorageService._(box);
  }

  static Future<Box<dynamic>> _openSettingsBox() async {
    try {
      return await Hive.openBox<dynamic>(AppConstants.settingsBox);
    } catch (_) {
      await Hive.deleteBoxFromDisk(AppConstants.settingsBox);
      return Hive.openBox<dynamic>(AppConstants.settingsBox);
    }
  }

  AppSettings readSettings() {
    final value = _box.get(AppConstants.appSettingsKey);
    if (value is Map) {
      return AppSettings.fromJson(value);
    }
    return AppSettings.defaults();
  }

  Future<void> writeSettings(AppSettings settings) {
    return _box.put(AppConstants.appSettingsKey, settings.toJson());
  }

  OverlayPosition readOverlayPosition() {
    final value = _box.get(AppConstants.overlayPositionKey);
    if (value is Map) {
      return OverlayPosition.fromJson(value);
    }
    return OverlayPosition.defaults();
  }

  Future<void> writeOverlayPosition(OverlayPosition position) {
    return _box.put(AppConstants.overlayPositionKey, position.toJson());
  }
}
