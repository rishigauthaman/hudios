import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../providers/app_providers.dart';
import '../services/overlay_platform_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final mt5Access = ref.read(mt5AccessServiceProvider);
    final mt5Connected = ref
        .watch(mt5AccessTokenProvider)
        .when(
          data: (token) => token != null,
          loading: () => false,
          error: (_, _) => false,
        );

    Future<void> save(AppSettings updated) async {
      await controller.save(updated);
      if (defaultTargetPlatform == TargetPlatform.android &&
          await OverlayPlatformService.canDrawOverlays()) {
        await OverlayPlatformService.startOverlay(
          updated,
          mt5DeviceToken: await mt5Access.readAccessToken(),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Customize')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Preview(settings: settings),
            const SizedBox(height: 24),
            const _SectionLabel('MARKET DATA'),
            const SizedBox(height: 8),
            _Card(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.desktop_windows_outlined),
                  title: const Text('Secure MT5 feed'),
                  subtitle: Text(
                    mt5Connected
                        ? 'Device authorized'
                        : 'Connect a public HTTPS feed',
                  ),
                  trailing: Icon(
                    mt5Connected ? Icons.verified_user : Icons.chevron_right,
                  ),
                  onTap: () async {
                    if (mt5Connected) {
                      final disconnect = await _confirmDisconnect(context);
                      if (disconnect) {
                        await mt5Access.disconnect(settings.mt5BackendUrl);
                        ref.invalidate(mt5AccessTokenProvider);
                        await save(settings.copyWith(mt5BackendUrl: ''));
                      }
                      return;
                    }
                    final setup = await _showMt5Setup(context, settings);
                    if (setup == null) return;
                    try {
                      await mt5Access.activate(
                        backendUrl: setup.backendUrl,
                        activationCode: setup.activationCode,
                      );
                      ref.invalidate(mt5AccessTokenProvider);
                      await save(
                        settings.copyWith(mt5BackendUrl: setup.backendUrl),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('MT5 feed connected')),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.toString().replaceFirst('Bad state: ', ''),
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('WIDGET'),
            const SizedBox(height: 8),
            _Card(
              children: [
                _LayoutPicker(
                  value: settings.widgetLayout,
                  onChanged: (value) =>
                      save(settings.copyWith(widgetLayout: value)),
                ),
                _SliderRow(
                  title: 'Widget Size',
                  value: settings.widgetScale,
                  min: 0.75,
                  max: 1.6,
                  divisions: 17,
                  label: '${(settings.widgetScale * 100).round()}%',
                  onChanged: (value) =>
                      save(settings.copyWith(widgetScale: value)),
                ),
                _ColorPicker(
                  value: settings.overlayColorValue,
                  onChanged: (value) =>
                      save(settings.copyWith(overlayColorValue: value)),
                ),
                _SliderRow(
                  title: 'Transparency',
                  value: settings.backgroundTransparency,
                  min: 0,
                  max: 0.92,
                  divisions: 23,
                  label: '${(settings.backgroundTransparency * 100).round()}%',
                  onChanged: (value) => save(
                    settings.copyWith(
                      opacity: 1,
                      backgroundTransparency: value,
                    ),
                  ),
                ),
                _SliderRow(
                  title: 'Shape',
                  value: settings.cornerRadius,
                  min: 0,
                  max: 40,
                  divisions: 20,
                  label: settings.cornerRadius.toStringAsFixed(0),
                  onChanged: (value) =>
                      save(settings.copyWith(cornerRadius: value)),
                ),
                _SliderRow(
                  title: 'Text Size',
                  value: settings.textSize,
                  min: 12,
                  max: 30,
                  divisions: 18,
                  label: settings.textSize.toStringAsFixed(0),
                  onChanged: (value) =>
                      save(settings.copyWith(textSize: value)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('BEHAVIOR'),
            const SizedBox(height: 8),
            _Card(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show Decimals'),
                  value: settings.showDecimals,
                  onChanged: (value) =>
                      save(settings.copyWith(showDecimals: value)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Price Flash'),
                  value: settings.priceFlashEnabled,
                  onChanged: (value) =>
                      save(settings.copyWith(priceFlashEnabled: value)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lock Position'),
                  value: settings.lockPosition,
                  onChanged: (value) =>
                      save(settings.copyWith(lockPosition: value)),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start on Boot'),
                  value: settings.startOnBoot,
                  onChanged: (value) =>
                      save(settings.copyWith(startOnBoot: value)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
              onPressed: () async {
                await mt5Access.disconnect(settings.mt5BackendUrl);
                ref.invalidate(mt5AccessTokenProvider);
                await save(AppSettings.defaults());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Mt5Setup {
  const _Mt5Setup({required this.backendUrl, required this.activationCode});

  final String backendUrl;
  final String activationCode;
}

Future<_Mt5Setup?> _showMt5Setup(
  BuildContext context,
  AppSettings settings,
) async {
  final formKey = GlobalKey<FormState>();
  final urlController = TextEditingController(text: settings.mt5BackendUrl);
  final codeController = TextEditingController();

  final result = await showDialog<_Mt5Setup>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Connect MT5 feed'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: urlController,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                validator: (value) {
                  final uri = Uri.tryParse(value?.trim() ?? '');
                  return uri != null &&
                          uri.scheme == 'https' &&
                          uri.host.isNotEmpty
                      ? null
                      : 'Enter the public HTTPS API address.';
                },
                decoration: const InputDecoration(
                  labelText: 'HTTPS API address',
                  hintText: 'https://api.example.com',
                  helperText: 'Your public PriceHUD backend',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: codeController,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                validator: (value) => (value?.trim().length ?? 0) >= 8
                    ? null
                    : 'Enter the activation code you were given.',
                decoration: const InputDecoration(
                  labelText: 'Activation code',
                  helperText: 'Used once to authorize this phone',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _Mt5Setup(
                backendUrl: urlController.text.trim().replaceAll(
                  RegExp(r'/+$'),
                  '',
                ),
                activationCode: codeController.text.trim(),
              ),
            );
          },
          child: const Text('Connect'),
        ),
      ],
    ),
  );
  urlController.dispose();
  codeController.dispose();
  return result;
}

Future<bool> _confirmDisconnect(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disconnect MT5 feed?'),
          content: const Text(
            'This revokes this phone\'s access to the live feed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Disconnect'),
            ),
          ],
        ),
      ) ??
      false;
}

class _Preview extends StatelessWidget {
  const _Preview({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final color = Color(settings.overlayColorValue);
    final textColor = color.computeLuminance() > 0.55
        ? const Color(0xFF111827)
        : Colors.white;
    final isCircle = settings.widgetLayout == OverlayWidgetLayout.circle;
    final isCompact = settings.widgetLayout != OverlayWidgetLayout.pill;
    final side = 98.0 * settings.widgetScale;
    final minWidth = (78.0 * settings.widgetScale)
        .clamp(66.0, 130.0)
        .toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.all(isCompact ? 9 : 10),
            width: isCompact ? side : null,
            height: isCompact ? side : null,
            constraints: isCompact
                ? null
                : BoxConstraints(minWidth: minWidth, maxWidth: 240),
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: (1 - settings.backgroundTransparency)
                    .clamp(0.08, 1)
                    .toDouble(),
              ),
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircle
                  ? null
                  : BorderRadius.circular(
                      isCompact
                          ? settings.cornerRadius.clamp(4, 22).toDouble()
                          : settings.cornerRadius,
                    ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: isCompact
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  _compactSymbol(settings.selectedPair),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isCompact ? TextAlign.center : TextAlign.start,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.75),
                    fontSize: isCompact ? 12 : 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    settings.showDecimals ? '1847.52' : '1848',
                    maxLines: 1,
                    textAlign: isCompact ? TextAlign.center : TextAlign.start,
                    style: TextStyle(
                      color: textColor,
                      fontSize: settings.textSize * (isCompact ? 0.88 : 1.0),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _compactSymbol(String symbol) {
    return symbol.endsWith('USDT')
        ? symbol.substring(0, symbol.length - 4)
        : symbol;
  }
}

class _LayoutPicker extends StatelessWidget {
  const _LayoutPicker({required this.value, required this.onChanged});

  final OverlayWidgetLayout value;
  final ValueChanged<OverlayWidgetLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SegmentedButton<OverlayWidgetLayout>(
        segments: const [
          ButtonSegment(
            value: OverlayWidgetLayout.pill,
            icon: Icon(Icons.horizontal_rule),
            label: Text('Pill'),
          ),
          ButtonSegment(
            value: OverlayWidgetLayout.square,
            icon: Icon(Icons.crop_square),
            label: Text('Square'),
          ),
          ButtonSegment(
            value: OverlayWidgetLayout.circle,
            icon: Icon(Icons.circle_outlined),
            label: Text('Circle'),
          ),
        ],
        selected: {value},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.value, required this.onChanged});

  static const colors = <int>[
    0xFF050608,
    0xFF111827,
    0xFF0F172A,
    0xFF12312E,
    0xFF164E63,
    0xFF3B0764,
    0xFF5B21B6,
    0xFFFFFFFF,
  ];

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final color in colors)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onChanged(color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(color),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color == value
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: color == value ? 3 : 1,
                  ),
                ),
                child: color == value
                    ? Icon(
                        Icons.check,
                        size: 18,
                        color: color == 0xFFFFFFFF
                            ? Colors.black
                            : Colors.white,
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            Text(label),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: label,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
