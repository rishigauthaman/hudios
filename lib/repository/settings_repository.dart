import '../models/app_settings.dart';
import '../models/overlay_position.dart';
import '../services/local_storage_service.dart';

abstract interface class SettingsRepository {
  AppSettings loadSettings();

  Future<void> saveSettings(AppSettings settings);

  OverlayPosition loadOverlayPosition();

  Future<void> saveOverlayPosition(OverlayPosition position);
}

class HiveSettingsRepository implements SettingsRepository {
  const HiveSettingsRepository(this._storage);

  final LocalStorageService _storage;

  @override
  AppSettings loadSettings() {
    return _storage.readSettings();
  }

  @override
  Future<void> saveSettings(AppSettings settings) {
    return _storage.writeSettings(settings);
  }

  @override
  OverlayPosition loadOverlayPosition() {
    return _storage.readOverlayPosition();
  }

  @override
  Future<void> saveOverlayPosition(OverlayPosition position) {
    return _storage.writeOverlayPosition(position);
  }
}
