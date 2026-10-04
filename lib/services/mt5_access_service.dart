import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class Mt5AccessService {
  Mt5AccessService({FlutterSecureStorage? storage, http.Client? client})
    : _storage = storage ?? const FlutterSecureStorage(),
      _client = client ?? http.Client();

  static const _tokenKey = 'pricehud_mt5_device_token';

  final FlutterSecureStorage _storage;
  final http.Client _client;

  Future<String?> readAccessToken() => _storage.read(key: _tokenKey);

  Future<void> activate({
    required String backendUrl,
    required String activationCode,
  }) async {
    final baseUrl = _validateBackendUrl(backendUrl);
    final response = await _client
        .post(
          Uri.parse('$baseUrl/v1/devices/activate'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'activation_code': activationCode.trim(),
            'device_label': 'PriceHUD Android',
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 201) {
      throw StateError(
        _readError(response.body, 'Activation was not accepted.'),
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['access_token'] as String?;
    if (token == null || token.length < 32) {
      throw const FormatException(
        'The server returned an invalid device token.',
      );
    }
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> disconnect(String backendUrl) async {
    final token = await readAccessToken();
    if (token != null && backendUrl.startsWith('https://')) {
      try {
        await _client
            .delete(
              Uri.parse(
                '${backendUrl.replaceAll(RegExp(r'/+$'), '')}/v1/devices/me',
              ),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Clearing the local credential prevents further access even offline.
      }
    }
    await _storage.delete(key: _tokenKey);
  }

  String _validateBackendUrl(String value) {
    final url = value.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Enter a public HTTPS API address.');
    }
    return url;
  }

  String _readError(String body, String fallback) {
    try {
      return (jsonDecode(body) as Map<String, dynamic>)['detail'] as String? ??
          fallback;
    } catch (_) {
      return fallback;
    }
  }
}
