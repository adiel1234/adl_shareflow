import '../../../core/network/api_client.dart';
import '../domain/balance_model.dart';

export '../domain/balance_model.dart' show SettlementRecord;

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

  /// Debtor step: create a pending settlement request (marks "I paid").
  Future<SettlementRecord> requestSettlement({
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
    return SettlementRecord.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  /// Creditor step: confirm receipt of payment.
  Future<void> approveSettlement(String settlementId) async {
    await _api.put('/settlements/$settlementId/confirm');
  }

  /// Cancel a pending settlement (debtor or creditor).
  Future<void> cancelSettlement(String settlementId) async {
    await _api.put('/settlements/$settlementId/cancel');
  }

  /// Fetch pending settlements involving the current user in this group.
  Future<List<SettlementRecord>> fetchPendingSettlements(
      String groupId) async {
    final response =
        await _api.get('/groups/$groupId/settlements/pending');
    final list =
        (response.data['data']['settlements'] as List<dynamic>);
    return list
        .map((j) => SettlementRecord.fromJson(j as Map<String, dynamic>))
        .toList();
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

  Future<Map<String, dynamic>> scheduleReminder({
    required String groupId,
    required DateTime sendAt,
    String? toUserId,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/reminders/schedule',
      data: {
        'send_at': sendAt.toUtc().toIso8601String(),
        if (toUserId != null) 'to_user_id': toUserId,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateReminderSettings({
    required String frequency,
    required List<String> platforms,
    required bool enabled,
    int? preferredHour,
  }) async {
    final response = await _api.put('/users/me/reminder-settings', data: {
      'frequency': frequency,
      'platforms': platforms,
      'enabled': enabled,
      'preferred_hour': preferredHour,
    });
    return response.data['data'] as Map<String, dynamic>;
  }
}
