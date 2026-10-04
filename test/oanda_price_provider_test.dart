import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:price_hud/providers/oanda_price_provider.dart';

void main() {
  test('uses FX Data spot endpoint and reads midpoint', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'exchange-rates-api.oanda.com');
      expect(request.url.path, '/v2/rates/spot.json');
      expect(request.url.queryParameters['base'], 'EUR');
      expect(request.url.queryParameters['quote'], 'USD');
      expect(request.headers['Authorization'], 'Bearer test-key');
      return http.Response(
        jsonEncode({
          'quotes': [
            {'midpoint': '1.12345'},
          ],
        }),
        200,
      );
    });
    final provider = OandaPriceProvider(
      apiToken: 'test-key',
      updateFrequencyMs: 5000,
      client: client,
    );

    final price = await provider.subscribe('EURUSD').first;
    expect(price.price, 1.12345);
  });

  test('reports when the plan lacks real-time access', () async {
    final provider = OandaPriceProvider(
      apiToken: 'test-key',
      updateFrequencyMs: 5000,
      client: MockClient((_) async => http.Response('{}', 403)),
    );

    await expectLater(
      provider.subscribe('XAUUSD'),
      emitsError(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('account upgrade'),
        ),
      ),
    );
  });
}
