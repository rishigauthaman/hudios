import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/price_model.dart';
import 'price_provider.dart';

class Mt5PriceProvider implements PriceProvider {
  Mt5PriceProvider({
    required this.backendUrl,
    required this.deviceToken,
    required this.updateFrequencyMs,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String backendUrl;
  final String? deviceToken;
  final int updateFrequencyMs;
  final http.Client _client;

  static const symbols = <String>{'XAUUSD', 'EURUSD', 'GBPUSD', 'USDJPY'};

  bool supports(String symbol) => symbols.contains(symbol.toUpperCase());

  @override
  Stream<PriceModel> subscribe(String symbol) {
    final normalized = symbol.toUpperCase();
    if (!supports(normalized)) {
      return Stream.error(ArgumentError('MT5 does not support $symbol'));
    }
    if (!backendUrl.startsWith('https://') ||
        (deviceToken?.isNotEmpty != true)) {
      return Stream.error(
        StateError('Activate the secure MT5 connection in Customize.'),
      );
    }

    late StreamController<PriceModel> controller;
    Timer? timer;
    var fetching = false;
    double? previousPrice;

    Future<void> fetch() async {
      if (fetching || controller.isClosed) return;
      fetching = true;
      try {
        final uri = Uri.parse(
          '${backendUrl.replaceAll(RegExp(r'/+$'), '')}/v1/quotes/$normalized',
        );
        final response = await _client
            .get(uri, headers: {'Authorization': 'Bearer $deviceToken'})
            .timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) {
          throw StateError(
            'Secure MT5 service returned ${response.statusCode}',
          );
        }
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final price = (body['midpoint'] as num?)?.toDouble();
        if (price == null || price <= 0 || !price.isFinite) {
          throw const FormatException('Invalid MT5 quote');
        }
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
                  : (price - previous) / previous * 100,
              updatedAt: DateTime.now(),
            ),
          );
        }
      } catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(
            error is TimeoutException || error is http.ClientException
                ? StateError('Live MT5 price is temporarily unavailable.')
                : error,
            stackTrace,
          );
        }
      } finally {
        fetching = false;
      }
    }

    controller = StreamController<PriceModel>(
      onListen: () {
        fetch();
        timer = Timer.periodic(
          Duration(milliseconds: updateFrequencyMs.clamp(1000, 60000)),
          (_) => fetch(),
        );
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }
}
