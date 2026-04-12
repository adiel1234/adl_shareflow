import '../../../core/network/api_client.dart';
import '../domain/balance_model.dart';

class BalanceRepository {
  final _api = ApiClient.instance;

  Future<Map<String, dynamic>> fetchBalances(String groupId) async {
    final response = await _api.get('/groups/$groupId/balances');
    final data = response.data['data'] as Map<String, dynamic>;
    final list = data['balances'] as List<dynamic>;
    return {
      'currency': data['base_currency'] as String,
      'balances': list
          .map((j) => UserBalance.fromJson(j as Map<String, dynamic>))
          .toList(),
    };
  }

  Future<List<SettlementSuggestion>> fetchSettlementPlan(
      String groupId) async {
    final response =
        await _api.get('/groups/$groupId/balances/settlements-plan');
    final data = response.data['data'] as Map<String, dynamic>;
    final list = data['settlements'] as List<dynamic>;
    return list
        .map((j) =>
            SettlementSuggestion.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> confirmSettlement({
    required String groupId,
    required String toUserId,
    required double amount,
    required String currency,
  }) async {
    final response = await _api.post('/groups/$groupId/settlements', data: {
      'to_user_id': toUserId,
      'amount': amount,
      'currency': currency,
    });
    final settlementId = response.data['data']['id'] as String;
    await _api.put('/settlements/$settlementId/confirm');
  }

  Future<Map<String, dynamic>> fetchEventSummary(
      String groupId, {bool sendApp = true}) async {
    final response = await _api.post('/groups/$groupId/summary',
        data: {'send_app': sendApp});
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> sendPaymentReminder({
    required String groupId,
    required String toUserId,
    required String amount,
    required String currency,
  }) async {
    await _api.post('/groups/$groupId/remind', data: {
      'to_user_id': toUserId,
      'amount': amount,
      'currency': currency,
    });
  }

  Future<Map<String, dynamic>> getReminderSettings() async {
    final response = await _api.get('/users/me/reminder-settings');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateReminderSettings({
    required String frequency,
    required List<String> platforms,
    required bool enabled,
  }) async {
    final response = await _api.put('/users/me/reminder-settings', data: {
      'frequency': frequency,
      'platforms': platforms,
      'enabled': enabled,
    });
    return response.data['data'] as Map<String, dynamic>;
  }
}
