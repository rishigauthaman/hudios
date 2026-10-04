import 'dart:async';
import 'dart:math';

import '../models/price_model.dart';
import 'price_provider.dart';

class MockPriceProvider implements PriceProvider {
  MockPriceProvider({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const _seedPrices = <String, double>{
    'BTCUSDT': 118452.35,
    'ETHUSDT': 6420.10,
    'BNBUSDT': 841.25,
    'SOLUSDT': 238.44,
    'XRPUSDT': 2.84,
    'XAUUSD': 3412.20,
    'EURUSD': 1.1725,
    'GBPUSD': 1.3412,
    'USDJPY': 148.22,
    'NAS100': 22840.50,
    'US30': 44720.80,
    'SPX500': 6042.10,
  };

  @override
  Stream<PriceModel> subscribe(String symbol) async* {
    var previous = _seedPrices[symbol] ?? 100;
    var current = previous;

    yield PriceModel(
      symbol: symbol,
      price: current,
      previousPrice: previous,
      percentChange: 0,
      updatedAt: DateTime.now(),
    );

    while (true) {
      await Future<void>.delayed(const Duration(seconds: 1));
      previous = current;

      final volatility = _volatilityFor(symbol);
      final drift = (_random.nextDouble() - 0.48) * volatility;
      current = max(0.0001, previous * (1 + drift));

      yield PriceModel(
        symbol: symbol,
        price: current,
        previousPrice: previous,
        percentChange: ((current - previous) / previous) * 100,
        updatedAt: DateTime.now(),
      );
    }
  }

  double _volatilityFor(String symbol) {
    if (symbol.endsWith('USD') && symbol.length == 6) {
      return 0.0008;
    }
    if (symbol == 'XAUUSD') {
      return 0.0015;
    }
    if (symbol == 'NAS100' || symbol == 'US30' || symbol == 'SPX500') {
      return 0.0012;
    }
    return 0.0028;
  }
}
