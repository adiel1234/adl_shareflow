import '../../../core/network/api_client.dart';
import '../domain/group_model.dart';

class GroupRepository {
  final _api = ApiClient.instance;

  Future<List<Group>> fetchGroups() async {
    final response = await _api.get('/groups');
    final list = response.data['data'] as List<dynamic>;
    return list.map((j) => Group.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Group> fetchGroup(String groupId) async {
    final response = await _api.get('/groups/$groupId');
    return Group.fromJson(response.data['data'] as Map<String, dynamic>);
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
  }) async {
    final response = await _api.post('/groups', data: {
      'name': name,
      if (description != null) 'description': description,
      'base_currency': baseCurrency,
      if (category != null) 'category': category,
      'group_type': groupType,
    });
    final data = response.data['data'] as Map<String, dynamic>;
    final group = Group.fromJson(data);
    final limitReached = data['creation_reason'] == 'free_group_limit_reached';
    return (group, limitReached);
  }

  Future<List<GroupMember>> fetchMembers(String groupId) async {
    final response = await _api.get('/groups/$groupId/members');
    final list = response.data['data'] as List<dynamic>;
    return list
        .map((j) => GroupMember.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> fetchInviteLink(String groupId) async {
    final response = await _api.get('/groups/$groupId/invite-link');
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> removeMember(String groupId, String userId,
      {String mode = 'settle'}) async {
    await _api.delete(
      '/groups/$groupId/members/$userId',
      data: {'mode': mode},
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

  /// Closes the group. Returns the updated group on success.
  /// Throws [CloseGroupException] if there are unsettled debts.
  Future<Group> closeGroup(String groupId, {bool force = false}) async {
    final response = await _api.post(
      '/groups/$groupId/close',
      data: {'force': force},
    );
    return Group.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Activate a free/limited group (beta: manual, no real payment).
  Future<Map<String, dynamic>> activateGroup(
    String groupId, {
    bool splitAmongGroup = true,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/activate',
      data: {'split_among_group': splitAmongGroup},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Extend an event group by 7 days.
  Future<Map<String, dynamic>> extendGroup(
    String groupId, {
    bool splitAmongGroup = true,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/extend',
      data: {'split_among_group': splitAmongGroup},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Renew an ongoing group for another billing period.
  Future<Map<String, dynamic>> renewGroup(
    String groupId, {
    bool splitAmongGroup = true,
  }) async {
    final response = await _api.post(
      '/groups/$groupId/renew',
      data: {'split_among_group': splitAmongGroup},
    );
    return response.data['data'] as Map<String, dynamic>;
  }
}
