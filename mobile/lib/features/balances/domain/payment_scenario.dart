/// Four payment flows when settling group debts (see PILOT_TEST_CHECKLIST §4).
enum PaymentScenario {
  /// Member debtor → member creditor; creditor approves.
  memberToMember,
  /// Member debtor → guest creditor; admin confirms guest received.
  memberToGuest,
  /// Guest debtor → member creditor; admin confirms transfer, then member confirms.
  guestToMember,
  /// Guest debtor → guest creditor; single admin action.
  guestToGuest,
}

PaymentScenario detectPaymentScenario({
  required bool fromIsGuest,
  required bool toIsGuest,
}) {
  if (fromIsGuest && toIsGuest) return PaymentScenario.guestToGuest;
  if (fromIsGuest) return PaymentScenario.guestToMember;
  if (toIsGuest) return PaymentScenario.memberToGuest;
  return PaymentScenario.memberToMember;
}
