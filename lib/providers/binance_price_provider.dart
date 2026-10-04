import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/price_model.dart';
import 'price_provider.dart';
import 'mt5_price_provider.dart';

class BinancePriceProvider implements PriceProvider {
  const BinancePriceProvider();

  static const _supportedSymbols = <String>{
    'BTCUSDT',
    'ETHUSDT',
    'BNBUSDT',
    'SOLUSDT',
    'XRPUSDT',
  };

  bool supports(String symbol) {
    return _supportedSymbols.contains(symbol.toUpperCase());
  }

  @override
  Stream<PriceModel> subscribe(String symbol) {
    final normalized = symbol.toUpperCase();
    final controller = StreamController<PriceModel>();
    final uri = Uri.parse(
      'wss://stream.binance.com:9443/ws/${normalized.toLowerCase()}@trade',
    );
    final channel = WebSocketChannel.connect(uri);

    double? previousPrice;

    final subscription = channel.stream.listen(
      (event) {
        final json = jsonDecode(event as String) as Map<String, dynamic>;
        final price = double.tryParse(json['p'] as String? ?? '');
        if (price == null) {
          return;
        }

        final previous = previousPrice ?? price;
        previousPrice = price;

        controller.add(
          PriceModel(
            symbol: normalized,
            price: price,
            previousPrice: previous,
            percentChange: previous == 0
                ? 0
                : ((price - previous) / previous) * 100,
            updatedAt: DateTime.now(),
          ),
        );
      },
      onError: controller.addError,
      onDone: controller.close,
      cancelOnError: false,
    );

    controller.onCancel = () async {
      await subscription.cancel();
      await channel.sink.close();
    };

    return controller.stream;
  }
}

class RoutedPriceProvider implements PriceProvider {
  const RoutedPriceProvider({
    required BinancePriceProvider binance,
    required Mt5PriceProvider mt5,
  }) : this._(binance, mt5);

  const RoutedPriceProvider._(this._binance, this._mt5);

  final BinancePriceProvider _binance;
  final Mt5PriceProvider _mt5;

  @override
  Stream<PriceModel> subscribe(String symbol) {
    if (_binance.supports(symbol)) {
      return _binance.subscribe(symbol);
    }
    if (_mt5.supports(symbol)) {
      return _mt5.subscribe(symbol);
    }
    return Stream.error(ArgumentError('No live source for $symbol'));
  }
}
