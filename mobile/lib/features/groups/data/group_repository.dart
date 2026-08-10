import '../../../core/network/api_client.dart';
import '../../../services/iap_service.dart';
import '../domain/group_model.dart';
import '../domain/period_report_model.dart';

class GroupRepository {
  final _api = ApiClient.instance;

  Future<List<Group>> fetchGroups() async {
    final response = await _api.get('/groups');
    final list = response.data['data'] as List<dynamic>;
    final groups = list.map((j) => Group.fromJson(j as Map<String, dynamic>)).toList();
    // Sort: newest groups first
    groups.sort((a, b) {
      final aDate = a.createdAt;
      final bDate = b.createdAt;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return groups;
  }

  Future<Group> fetchGroup(String groupId) async {
    final response = await _api.get('/groups/$groupId');
    return Group.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Fresh expense count from server — use before split_mode dialogs (cached Group may be stale).
  Future<int> fetchExpenseCount(String groupId) async {
    final group = await fetchGroup(groupId);
    return group.expenseCount;
  }

  /// Returns a record: (group, limitReached).
  /// limitReached is true when the user hit the 3-group free limit
  /// and the new group was created in 'limited' state.
  Future<(Group, bool)> createGroup({
    required String name,
    String? description,
    required String baseCurrency,
    String? category,
    String groupType = 'event',
    String settlementType = 'none',
    String? settlementPeriod,
  }) async {
    final response = await _api.post('/groups', data: {
      'name': name,
      if (description != null) 'description': description,
      'base_currency': baseCurrency,
      if (category != null) 'category': category,
      'group_type': groupType,
      'settlement_type': settlementType,
      if (settlementPeriod != null) 'settlement_period': settlementPeriod,
    });
    final data = response.data['data'] as Map<String, dynamic>;
    final group = Group.fromJson(data);
    final limitReached = data['creation_reason'] == 'free_group_limit_reached';
    return (group, limitReached);
  }

  Future<List<PeriodReport>> fetchPeriodReports(String groupId) async {
    final response = await _api.get('/groups/$groupId/period-reports');
    final list = response.data['data'] as List<dynamic>;
    return list.map((j) => PeriodReport.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<PeriodReport> settlePeriod(String groupId) async {
    final response = await _api.post('/groups/$groupId/settle-period');
    return PeriodReport.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<PeriodDebt> markDebtPaid(String debtId) async {
    final response = await _api.post('/groups/period-debts/$debtId/mark-paid');
    return PeriodDebt.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<GroupMember>> fetchMembers(String groupId) async {
    final response = await _api.get('/groups/$groupId/members');
    final list = response.data['data'] as List<dynamic>;
    return list
        .map((j) => GroupMember.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> fetchInviteLink(String groupId, {String? splitMode}) async {
    final response = await _api.get(
      '/groups/$groupId/invite-link',
      params: splitMode != null ? {'split_mode': splitMode} : null,
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> addGuest(
    String groupId,
    String name, {
    String splitMode = 'forward',
  }) async {
    await _api.post('/groups/$groupId/guests', data: {
      'name': name.trim(),
      'split_mode': splitMode,
    });
  }

  Future<void> removeMember(
    String groupId,
    String userId,
  ) async {
    await _api.delete(
      '/groups/$groupId/members/$userId',
    );
  }

  Future<Map<String, dynamic>> checkInvite(String inviteCode) async {
    final response = await _api.get('/groups/check/$inviteCode');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Group> joinGroup(String inviteCode, {String splitMode = 'forward'}) async {
    final response = await _api.post(
      '/groups/join/$inviteCode',
      data: {'split_mode': splitMode},
    );
    return Group.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Permanently deletes a group (admin only).
  /// Pass [force] = true to delete even when open debts exist.
  Future<void> deleteGroup(String groupId, {bool force = false}) async {
    await _api.delete('/groups/$groupId',
        data: force ? {'force': true} : null);
  }

  /// Reopen a closed group — same group with all data restored.
  Future<Group> reopenGroup(String groupId) async {
    final response = await _api.post('/groups/$groupId/reopen');
    return Group.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Duplicate a closed group into a fresh empty group with the same members.
  /// Returns (newGroup, limitReached) — same semantics as [createGroup].
  Future<(Group, bool)> duplicateGroup(
    String groupId, {
    String? name,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/duplicate',
      data: {if (name != null) 'name': name},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final group = Group.fromJson(data);
    final limitReached = data['creation_reason'] == 'free_group_limit_reached';
    return (group, limitReached);
  }

  /// Closes the group. Returns the updated group on success.
  /// Throws [DioException] 409 if there are unsettled debts (unless [force]).
  /// When [dryRun] is true the group is not closed — only debt status is checked.
  Future<Group?> closeGroup(
    String groupId, {
    bool force = false,
    bool dryRun = false,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/close',
      data: {
        'force': force,
        'dry_run': dryRun,
      },
    );
    if (dryRun) return null;
    return Group.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Map<String, dynamic> _iapPayload(
      bool splitAmongGroup, IapPurchaseResult? iap) {
    final body = <String, dynamic>{'split_among_group': splitAmongGroup};
    if (iap != null) {
      body['receipt_data'] = iap.serverVerificationData;
      body['platform'] = iap.platform;
      body['product_id'] = iap.productId;
    }
    return body;
  }

  /// Activate a free/limited group.
  /// When payments are enabled, [iapResult] must be provided.
  Future<Map<String, dynamic>> activateGroup(
    String groupId, {
    bool splitAmongGroup = true,
    IapPurchaseResult? iapResult,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/activate',
      data: _iapPayload(splitAmongGroup, iapResult),
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Extend an event group by 7 days.
  Future<Map<String, dynamic>> extendGroup(
    String groupId, {
    bool splitAmongGroup = true,
    IapPurchaseResult? iapResult,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/extend',
      data: _iapPayload(splitAmongGroup, iapResult),
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Renew an ongoing group for another billing period.
  Future<Map<String, dynamic>> renewGroup(
    String groupId, {
    bool splitAmongGroup = true,
    IapPurchaseResult? iapResult,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/renew',
      data: _iapPayload(splitAmongGroup, iapResult),
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Upgrade the group's pricing tier after member count crossed a boundary.
  Future<Map<String, dynamic>> upgradeTier(
    String groupId, {
    bool splitAmongGroup = true,
    IapPurchaseResult? iapResult,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/upgrade-tier',
      data: _iapPayload(splitAmongGroup, iapResult),
    );
    return response.data['data'] as Map<String, dynamic>;
  }
}
