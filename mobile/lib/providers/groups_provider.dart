import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/groups/data/group_repository.dart';
import '../features/groups/domain/group_model.dart';

final groupRepositoryProvider = Provider((_) => GroupRepository());

// All groups list
final groupsProvider = FutureProvider.autoDispose<List<Group>>((ref) async {
  return ref.watch(groupRepositoryProvider).fetchGroups();
});

// Single group detail
final groupDetailProvider =
    FutureProvider.autoDispose.family<Group, String>((ref, groupId) async {
  return ref.watch(groupRepositoryProvider).fetchGroup(groupId);
});

// Group members
final groupMembersProvider =
    FutureProvider.autoDispose.family<List<GroupMember>, String>(
  (ref, groupId) async {
    return ref.watch(groupRepositoryProvider).fetchMembers(groupId);
  },
);
