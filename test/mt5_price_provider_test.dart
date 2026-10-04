import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:price_hud/providers/mt5_price_provider.dart';

void main() {
  const deviceToken = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test(
    'reads a midpoint quote from the configured secure MT5 backend',
    () async {
      final provider = Mt5PriceProvider(
        backendUrl: 'https://api.example.com',
        deviceToken: deviceToken,
        updateFrequencyMs: 1000,
        client: MockClient((request) async {
          expect(request.url.path, '/v1/quotes/XAUUSD');
          expect(request.headers['authorization'], 'Bearer $deviceToken');
          return http.Response(jsonEncode({'midpoint': 4319.43}), 200);
        }),
      );

      final quote = await provider.subscribe('XAUUSD').first;
      expect(quote.price, 4319.43);
    },
  );

  test('reports an unavailable secure MT5 backend', () async {
    final provider = Mt5PriceProvider(
      backendUrl: 'https://api.example.com',
      deviceToken: deviceToken,
      updateFrequencyMs: 1000,
      client: MockClient((_) async => http.Response('{}', 503)),
    );
    await expectLater(
      provider.subscribe('EURUSD'),
      emitsError(isA<StateError>()),
    );
  });
}
