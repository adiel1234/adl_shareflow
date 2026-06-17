import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';

/// Fetches public config from the backend, including whether real payments are enabled.
final paymentsConfigProvider = FutureProvider<bool>((ref) async {
  try {
    final resp = await ApiClient.instance.get('/config/public');
    return (resp.data['payments_enabled'] as bool?) ?? false;
  } catch (_) {
    return false;
  }
});
