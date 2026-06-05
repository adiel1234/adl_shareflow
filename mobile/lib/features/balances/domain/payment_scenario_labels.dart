import '../../../../l10n/app_localizations.dart';
import 'balance_model.dart';
import 'payment_scenario.dart';

/// Hebrew labels and hints for the four payment scenarios.
class PaymentScenarioLabels {
  static PaymentScenario scenarioFor({
    required bool fromIsGuest,
    required bool toIsGuest,
  }) =>
      detectPaymentScenario(fromIsGuest: fromIsGuest, toIsGuest: toIsGuest);

  static String scenarioName(AppLocalizations l, PaymentScenario s) {
    switch (s) {
      case PaymentScenario.memberToMember:
        return l.paymentScenarioMemberToMember;
      case PaymentScenario.memberToGuest:
        return l.paymentScenarioMemberToGuest;
      case PaymentScenario.guestToMember:
        return l.paymentScenarioGuestToMember;
      case PaymentScenario.guestToGuest:
        return l.paymentScenarioGuestToGuest;
    }
  }

  static String transferHint(AppLocalizations l, PaymentScenario s) {
    switch (s) {
      case PaymentScenario.memberToMember:
        return l.transferHintMemberToMember;
      case PaymentScenario.memberToGuest:
        return l.transferHintMemberToGuest;
      case PaymentScenario.guestToMember:
        return l.transferHintGuestToMember;
      case PaymentScenario.guestToGuest:
        return l.transferHintGuestToGuest;
    }
  }

  static String pendingCardTitle(
    AppLocalizations l,
    List<SettlementRecord> records, {
    required String currentUserId,
    required bool isAdmin,
  }) {
    final hasCreditorAction = records.any(
      (r) => r.toUserId == currentUserId && !r.toIsGuest,
    );
    final hasAdminAction =
        isAdmin && records.any((r) => r.toIsGuest && !r.fromIsGuest);
    final hasDebtorWaiting =
        records.any((r) => r.fromUserId == currentUserId);

    if (hasCreditorAction) return l.pendingCardTitleCreditor;
    if (hasAdminAction) return l.pendingCardTitleAdmin;
    if (hasDebtorWaiting) return l.pendingCardTitleDebtor;
    return l.pendingCardTitleMixed;
  }

  static String pendingHint(
    AppLocalizations l,
    SettlementRecord r, {
    required String currentUserId,
    required bool isAdmin,
  }) {
    final s = scenarioFor(fromIsGuest: r.fromIsGuest, toIsGuest: r.toIsGuest);

    switch (s) {
      case PaymentScenario.memberToMember:
        return l.pendingHintMemberPaid(r.fromDisplayName, r.toDisplayName);
      case PaymentScenario.memberToGuest:
        if (isAdmin && r.toIsGuest) {
          return l.pendingHintMemberToGuestAdmin(r.toDisplayName);
        }
        return l.pendingHintMemberToGuestDebtor;
      case PaymentScenario.guestToMember:
        if (r.toUserId == currentUserId) {
          return l.pendingHintGuestToMemberCreditor;
        }
        return l.pendingHintGuestToMemberWaiting(r.toDisplayName);
      case PaymentScenario.guestToGuest:
        return l.transferHintGuestToGuest;
    }
  }

  static bool canCreditorApprove(SettlementRecord r, String currentUserId) =>
      r.toUserId == currentUserId && !r.toIsGuest;

  static bool canAdminConfirmGuestReceipt(
          SettlementRecord r, String currentUserId, bool isAdmin) =>
      isAdmin && r.toIsGuest && !r.fromIsGuest;

  static bool isDebtorWaiting(SettlementRecord r, String currentUserId) =>
      r.fromUserId == currentUserId;
}
