import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/price_model.dart';
import 'price_provider.dart';

class OandaPriceProvider implements PriceProvider {
  OandaPriceProvider({
    required this.apiToken,
    required this.updateFrequencyMs,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiToken;
  final int updateFrequencyMs;
  final http.Client _client;

  static const _symbols = <String>{'XAUUSD', 'EURUSD', 'GBPUSD', 'USDJPY'};

  bool supports(String symbol) => _symbols.contains(symbol.toUpperCase());

  @override
  Stream<PriceModel> subscribe(String symbol) {
    final normalized = symbol.toUpperCase();
    if (!supports(normalized)) {
      return Stream.error(ArgumentError('OANDA does not support $symbol'));
    }
    if (apiToken.trim().isEmpty) {
      return Stream.error(StateError('Set up OANDA in Settings'));
    }

    late StreamController<PriceModel> controller;
    Timer? timer;
    var fetching = false;
    double? previousPrice;

    Future<void> fetch() async {
      if (fetching || controller.isClosed) return;
      fetching = true;
      try {
        final price = await _fetchPrice(normalized);
        final previous = previousPrice ?? price;
        previousPrice = price;
        if (!controller.isClosed) {
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
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      } finally {
        fetching = false;
      }
    }

    controller = StreamController<PriceModel>(
      onListen: () {
        fetch();
        timer = Timer.periodic(
          Duration(milliseconds: updateFrequencyMs.clamp(5000, 60000)),
          (_) => fetch(),
        );
      },
      onCancel: () {
        timer?.cancel();
      },
    );
    return controller.stream;
  }

  Future<double> _fetchPrice(String symbol) async {
    final uri = Uri.https(
      'exchange-rates-api.oanda.com',
      '/v2/rates/spot.json',
      {'base': symbol.substring(0, 3), 'quote': symbol.substring(3)},
    );
    final response = await _client
        .get(uri, headers: {'Authorization': 'Bearer ${apiToken.trim()}'})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      if (response.statusCode == 401) {
        throw StateError('OANDA rejected the API key');
      }
      if (response.statusCode == 403) {
        throw StateError('OANDA real-time rates require an account upgrade');
      }
      throw StateError('OANDA returned ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final quotes = body['quotes'] as List<dynamic>?;
    if (quotes == null || quotes.isEmpty) {
      throw StateError('OANDA returned no price for $symbol');
    }
    final quote = quotes.first as Map<String, dynamic>;
    final midpoint = double.tryParse(quote['midpoint']?.toString() ?? '');
    if (midpoint == null) {
      throw const FormatException('Invalid OANDA price response');
    }
    return midpoint;
  }
}
