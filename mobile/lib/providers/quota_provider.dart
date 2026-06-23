import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';

class GroupQuota {
  final int groupsCreated;
  final int freeLimit;
  final bool limitReached;

  const GroupQuota({
    required this.groupsCreated,
    required this.freeLimit,
    required this.limitReached,
  });

  factory GroupQuota.fromJson(Map<String, dynamic> json) => GroupQuota(
        groupsCreated: (json['groups_created'] as num?)?.toInt() ?? 0,
        freeLimit: (json['free_limit'] as num?)?.toInt() ?? 3,
        limitReached: (json['limit_reached'] as bool?) ?? false,
      );
}

final groupQuotaProvider = FutureProvider<GroupQuota>((ref) async {
  try {
    final resp = await ApiClient.instance.get('/groups/quota');
    return GroupQuota.fromJson(resp.data['data'] as Map<String, dynamic>);
  } catch (_) {
    return const GroupQuota(groupsCreated: 0, freeLimit: 3, limitReached: false);
  }
});
