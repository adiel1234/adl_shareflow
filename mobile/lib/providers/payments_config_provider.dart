import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';

class PublicAppConfig {
  final bool paymentsEnabled;
  final bool pilotModeEnabled;

  const PublicAppConfig({
    required this.paymentsEnabled,
    required this.pilotModeEnabled,
  });
}

/// Public backend config: payments + pilot mode (from feature flags).
final publicAppConfigProvider = FutureProvider<PublicAppConfig>((ref) async {
  try {
    final resp = await ApiClient.instance.get('/config/public');
    final data = resp.data;
    return PublicAppConfig(
      paymentsEnabled: (data['payments_enabled'] as bool?) ?? false,
      pilotModeEnabled: (data['pilot_mode_enabled'] as bool?) ?? true,
    );
  } catch (_) {
    // Safe defaults for pilot phase if config is unreachable.
    return const PublicAppConfig(
      paymentsEnabled: false,
      pilotModeEnabled: true,
    );
  }
});

/// Whether real payments (IAP) are enabled.
final paymentsConfigProvider = FutureProvider<bool>((ref) async {
  final cfg = await ref.watch(publicAppConfigProvider.future);
  return cfg.paymentsEnabled;
});

/// Whether the product is in pilot mode (affects create-group copy, etc.).
final pilotModeConfigProvider = FutureProvider<bool>((ref) async {
  final cfg = await ref.watch(publicAppConfigProvider.future);
  return cfg.pilotModeEnabled;
});
