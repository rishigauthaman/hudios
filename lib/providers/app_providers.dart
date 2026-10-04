import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../models/price_model.dart';
import '../repository/price_repository.dart';
import '../repository/settings_repository.dart';
import '../services/local_storage_service.dart';
import '../services/mt5_access_service.dart';
import 'binance_price_provider.dart';
import 'mt5_price_provider.dart';
import 'price_provider.dart';

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  throw StateError(
    'LocalStorageService must be initialized before PriceHUD starts.',
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return HiveSettingsRepository(ref.watch(localStorageServiceProvider));
});

final mt5AccessServiceProvider = Provider<Mt5AccessService>((ref) {
  return Mt5AccessService();
});

final mt5AccessTokenProvider = FutureProvider<String?>((ref) {
  return ref.watch(mt5AccessServiceProvider).readAccessToken();
});

final priceProviderProvider = Provider<PriceProvider>((ref) {
  final settings = ref.watch(appSettingsProvider);
  final deviceToken = ref
      .watch(mt5AccessTokenProvider)
      .when(data: (token) => token, loading: () => null, error: (_, _) => null);
  return RoutedPriceProvider(
    binance: const BinancePriceProvider(),
    mt5: Mt5PriceProvider(
      backendUrl: settings.mt5BackendUrl,
      deviceToken: deviceToken,
      updateFrequencyMs: settings.updateFrequencyMs,
    ),
  );
});

final priceRepositoryProvider = Provider<PriceRepository>((ref) {
  return ProviderPriceRepository(ref.watch(priceProviderProvider));
});

final livePriceProvider = StreamProvider.autoDispose<PriceModel>((ref) {
  final settings = ref.watch(appSettingsProvider);
  final repository = ref.watch(priceRepositoryProvider);
  return repository.watch(settings.selectedPair);
});

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends Notifier<AppSettings> {
  late final SettingsRepository _repository;

  @override
  AppSettings build() {
    _repository = ref.watch(settingsRepositoryProvider);
    return _repository.loadSettings();
  }

  Future<void> save(AppSettings settings) async {
    state = settings;
    await _repository.saveSettings(settings);
  }

  Future<void> reset() async {
    await save(AppSettings.defaults());
  }
}
