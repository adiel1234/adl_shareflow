import 'package:adl_shareflow/features/groups/data/group_repository.dart';
import 'package:adl_shareflow/features/groups/domain/group_model.dart';
import 'package:flutter_test/flutter_test.dart';

Group _group({
  required String id,
  required String state,
  DateTime? createdAt,
  bool isClosed = false,
}) {
  return Group(
    id: id,
    name: id,
    baseCurrency: 'ILS',
    groupState: state,
    isClosed: isClosed,
    createdAt: createdAt,
  );
}

void main() {
  final older = DateTime.utc(2026, 1, 1);
  final newer = DateTime.utc(2026, 6, 1);
  final newest = DateTime.utc(2026, 9, 1);

  test('older ACTIVE group appears above newer EXPIRED group', () {
    final sorted = sortGroupsForList([
      _group(id: 'expired-new', state: 'expired', createdAt: newer),
      _group(id: 'active-old', state: 'active', createdAt: older),
    ]);

    expect(sorted.map((g) => g.id).toList(), ['active-old', 'expired-new']);
  });

  test('older ACTIVE group appears above newer READ_ONLY group', () {
    final sorted = sortGroupsForList([
      _group(id: 'readonly-new', state: 'read_only', createdAt: newer),
      _group(id: 'active-old', state: 'active', createdAt: older),
    ]);

    expect(sorted.map((g) => g.id).toList(), ['active-old', 'readonly-new']);
  });

  test('closed group appears in the inactive bucket', () {
    final sorted = sortGroupsForList([
      _group(id: 'closed-new', state: 'active', isClosed: true, createdAt: newer),
      _group(id: 'free-old', state: 'free', createdAt: older),
    ]);

    expect(sorted.first.id, 'free-old');
    expect(sorted.last.isInactive, isTrue);
    expect(sorted.last.isClosed, isTrue);
  });

  test('LIMITED group remains in the active bucket', () {
    final limited = _group(id: 'limited', state: 'limited', createdAt: older);
    expect(limited.isInactive, isFalse);

    final sorted = sortGroupsForList([
      _group(id: 'expired-new', state: 'expired', createdAt: newer),
      limited,
    ]);

    expect(sorted.first.id, 'limited');
    expect(sorted.first.groupState, 'limited');
  });

  test('multiple active groups remain createdAt descending', () {
    final sorted = sortGroupsForList([
      _group(id: 'active-old', state: 'active', createdAt: older),
      _group(id: 'free-newest', state: 'free', createdAt: newest),
      _group(id: 'limited-mid', state: 'limited', createdAt: newer),
    ]);

    expect(sorted.map((g) => g.id).toList(), [
      'free-newest',
      'limited-mid',
      'active-old',
    ]);
  });

  test('multiple inactive groups remain createdAt descending', () {
    final sorted = sortGroupsForList([
      _group(id: 'expired-old', state: 'expired', createdAt: older),
      _group(id: 'closed-newest', state: 'read_only', isClosed: true, createdAt: newest),
      _group(id: 'readonly-mid', state: 'read_only', createdAt: newer),
    ]);

    expect(sorted.map((g) => g.id).toList(), [
      'closed-newest',
      'readonly-mid',
      'expired-old',
    ]);
  });

  test('null createdAt goes last within its own bucket', () {
    final sorted = sortGroupsForList([
      _group(id: 'expired-dated', state: 'expired', createdAt: newer),
      _group(id: 'expired-null', state: 'expired'),
      _group(id: 'active-null', state: 'active'),
      _group(id: 'active-dated', state: 'active', createdAt: older),
    ]);

    expect(sorted.map((g) => g.id).toList(), [
      'active-dated',
      'active-null',
      'expired-dated',
      'expired-null',
    ]);
  });

  test('mixed list is all active first, then all inactive', () {
    final sorted = sortGroupsForList([
      _group(id: 'expired-newest', state: 'expired', createdAt: newest),
      _group(id: 'active-old', state: 'active', createdAt: older),
      _group(id: 'readonly-old', state: 'read_only', createdAt: older),
      _group(id: 'limited-mid', state: 'limited', createdAt: newer),
      _group(id: 'closed-mid', state: 'read_only', isClosed: true, createdAt: newer),
      _group(id: 'free-newest', state: 'free', createdAt: newest),
    ]);

    expect(sorted.map((g) => g.id).toList(), [
      'free-newest',
      'limited-mid',
      'active-old',
      'expired-newest',
      'closed-mid',
      'readonly-old',
    ]);
    expect(sorted.take(3).every((g) => !g.isInactive), isTrue);
    expect(sorted.skip(3).every((g) => g.isInactive), isTrue);
  });
}
