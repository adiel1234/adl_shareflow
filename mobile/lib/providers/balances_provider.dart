import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/balances/data/balance_repository.dart';
import '../features/balances/domain/balance_model.dart';
import 'auth_provider.dart';

final balanceRepositoryProvider = Provider((_) => BalanceRepository());

final balancesProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, groupId) async {
  final auth = ref.watch(authProvider);
  if (auth.isLoading) return {'balances': <dynamic>[], 'currency': 'ILS'};
  return ref.watch(balanceRepositoryProvider).fetchBalances(groupId);
});

final settlementPlanProvider = FutureProvider.autoDispose
    .family<List<SettlementSuggestion>, String>((ref, groupId) async {
  final auth = ref.watch(authProvider);
  if (auth.isLoading) return <SettlementSuggestion>[];
  return ref.watch(balanceRepositoryProvider).fetchSettlementPlan(groupId);
});

final pendingSettlementsProvider = FutureProvider.autoDispose
    .family<List<SettlementRecord>, String>((ref, groupId) async {
  final auth = ref.watch(authProvider);
  if (auth.isLoading) return <SettlementRecord>[];
  return ref.watch(balanceRepositoryProvider).fetchPendingSettlements(groupId);
});
