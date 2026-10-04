import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../models/app_settings.dart';
import '../models/price_model.dart';
import '../overlay/price_hud_overlay.dart';
import '../providers/app_providers.dart';
import '../services/live_activity_platform_service.dart';
import '../services/overlay_platform_service.dart';
import '../utils/formatters.dart';
import 'pair_selector_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final price = ref.watch(livePriceProvider);

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      ref.listen<AsyncValue<PriceModel>>(livePriceProvider, (_, next) {
        final value = _priceOrNull(next);
        if (value == null) {
          return;
        }
        LiveActivityPlatformService.updatePriceActivity(
          settings: ref.read(appSettingsProvider),
          price: value,
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 24),
            SizedBox(width: 10),
            Text(AppConstants.appName),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _PriceCard(
                  settings: settings,
                  price: price,
                  onSymbol: () => _openSymbolSelector(context),
                  onSettings: () => _openSettings(context),
                ),
                const SizedBox(height: 16),
                _ActionGrid(
                  settings: settings,
                  price: price,
                  onSymbol: () => _openSymbolSelector(context),
                  onSettings: () => _openSettings(context),
                ),
              ],
            ),
          ),
          if (defaultTargetPlatform != TargetPlatform.android)
            PriceHudOverlay(onOpenSettings: () => _openSettings(context)),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  void _openSymbolSelector(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PairSelectorScreen()));
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.settings,
    required this.price,
    required this.onSymbol,
    required this.onSettings,
  });

  final AppSettings settings;
  final AsyncValue<PriceModel> price;
  final VoidCallback onSymbol;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: price.when(
          data: (value) {
            final down = value.isDown;
            final accent = settings.priceFlashEnabled
                ? (down ? const Color(0xFFDC2626) : const Color(0xFF16A34A))
                : theme.colorScheme.onSurfaceVariant;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onSymbol,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Text(
                                value.symbol,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.expand_more, size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _SourceBadge(
                      label: value.symbol.endsWith('USDT')
                          ? 'BINANCE'
                          : 'MT5 DEMO',
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: FittedBox(
                    key: ValueKey(value.price),
                    fit: BoxFit.scaleDown,
                    child: Text(
                      Formatters.compactPrice(
                        value.price,
                        showDecimals: settings.showDecimals,
                      ),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 0.95,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      down ? Icons.south_east : Icons.north_east,
                      color: accent,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${down ? 'DOWN' : 'UP'} ${value.percentChange.abs().toStringAsFixed(3)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => const SizedBox(
            height: 184,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => SizedBox(
            height: 184,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'Price unavailable',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString().replaceFirst('Bad state: ', ''),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onSettings,
                  icon: const Icon(Icons.tune),
                  label: const Text('Open settings'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ActionGrid extends ConsumerStatefulWidget {
  const _ActionGrid({
    required this.settings,
    required this.price,
    required this.onSymbol,
    required this.onSettings,
  });

  final AppSettings settings;
  final AsyncValue<PriceModel> price;
  final VoidCallback onSymbol;
  final VoidCallback onSettings;

  @override
  ConsumerState<_ActionGrid> createState() => _ActionGridState();
}

class _ActionGridState extends ConsumerState<_ActionGrid> {
  var _busy = false;
  var _running = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_running ? Icons.stop : Icons.open_in_new),
                label: Text(
                  _running
                      ? (isIOS ? 'Stop Live Activity' : 'Stop Widget')
                      : (isIOS ? 'Start Live Activity' : 'Start Widget'),
                ),
                onPressed: _busy
                    ? null
                    : _running
                    ? _stop
                    : isAndroid
                    ? _startWidget
                    : isIOS
                    ? _startLiveActivity
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Symbol'),
                    onPressed: widget.onSymbol,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.tune),
                    label: const Text('Customize'),
                    onPressed: widget.onSettings,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshStatus() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final running = await OverlayPlatformService.isOverlayRunning();
    if (mounted) setState(() => _running = running);
  }

  Future<void> _startWidget() async {
    setState(() => _busy = true);
    try {
      final allowed = await OverlayPlatformService.canDrawOverlays();
      if (!allowed) {
        await OverlayPlatformService.openOverlaySettings();
      } else {
        await OverlayPlatformService.startOverlay(
          widget.settings,
          mt5DeviceToken: await ref
              .read(mt5AccessServiceProvider)
              .readAccessToken(),
        );
        if (mounted) setState(() => _running = true);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Widget started')));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allow overlay permission, then start again'),
          ),
        );
      }
      await OverlayPlatformService.openOverlaySettings();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await OverlayPlatformService.stopOverlay();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await LiveActivityPlatformService.endPriceActivity();
      }
      if (mounted) setState(() => _running = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startLiveActivity() async {
    setState(() => _busy = true);
    try {
      final enabled = await LiveActivityPlatformService.areActivitiesEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Turn on Live Activities in Settings'),
            ),
          );
        }
        return;
      }

      await LiveActivityPlatformService.startPriceActivity(
        settings: widget.settings,
        price: _priceOrNull(widget.price),
      );
      if (mounted) setState(() => _running = true);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Live Activity started')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live Activity is not available')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

PriceModel? _priceOrNull(AsyncValue<PriceModel> value) {
  return value.whenOrNull(data: (price) => price);
}
