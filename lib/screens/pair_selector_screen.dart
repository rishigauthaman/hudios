import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../providers/app_providers.dart';
import '../services/overlay_platform_service.dart';

class PairSelectorScreen extends ConsumerStatefulWidget {
  const PairSelectorScreen({super.key});

  @override
  ConsumerState<PairSelectorScreen> createState() => _PairSelectorScreenState();
}

class _PairSelectorScreenState extends ConsumerState<PairSelectorScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);
    final symbols = AppConstants.supportedPairs
        .where((symbol) => symbol.toLowerCase().contains(_query.toLowerCase()))
        .toList(growable: false);

    Future<void> saveSymbol(String symbol) async {
      final updated = settings.copyWith(selectedPair: symbol, opacity: 1);
      await controller.save(updated);
      if (defaultTargetPlatform == TargetPlatform.android &&
          await OverlayPlatformService.canDrawOverlays()) {
        await OverlayPlatformService.startOverlay(
          updated,
          mt5DeviceToken: await ref
              .read(mt5AccessServiceProvider)
              .readAccessToken(),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Symbol')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SearchBar(
                hintText: 'Search symbol',
                leading: const Icon(Icons.search),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: symbols.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final symbol = symbols[index];
                  final selected = symbol == settings.selectedPair;

                  return ListTile(
                    title: Text(symbol),
                    trailing: selected ? const Icon(Icons.check_circle) : null,
                    onTap: () async {
                      await saveSymbol(symbol);

                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
