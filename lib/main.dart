import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'services/local_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await LocalStorageService.open();

  runApp(
    ProviderScope(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      child: const PriceHudApp(),
    ),
  );
}

class PriceHudApp extends ConsumerWidget {
  const PriceHudApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp(
      title: 'PriceHUD',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const HomeScreen(),
    );
  }
}
