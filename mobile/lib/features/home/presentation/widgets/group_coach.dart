import 'package:flutter/material.dart';

import '../../../../core/storage/secure_storage.dart';
import '../../../../l10n/app_localizations.dart';
import 'home_coach.dart';

const kGroupCoachDoneKey = 'group_coach_done_v3';

Future<bool> isGroupCoachDone() async {
  return await AppSecureStorage.read(kGroupCoachDoneKey) == 'true';
}

Future<void> markGroupCoachDone() async {
  await AppSecureStorage.write(kGroupCoachDoneKey, 'true');
}

/// Walk through invite / expenses / balances / members inside a group.
Future<void> showGroupCoach(
  BuildContext context, {
  required List<CoachTarget> targets,
  bool markDone = true,
  int stepOffset = 0,
  int? totalSteps,
}) async {
  await showSpotlightCoach(
    context,
    targets: targets,
    stepOffset: stepOffset,
    totalSteps: totalSteps,
  );
  if (markDone) await markGroupCoachDone();
}

List<CoachTarget> buildGroupCoachTargets({
  required AppLocalizations l,
  required GlobalKey inviteKey,
  required GlobalKey expensesTabKey,
  required GlobalKey fabKey,
  required GlobalKey balancesTabKey,
  required GlobalKey membersTabKey,
  required TabController tabController,
}) {
  Future<void> goTab(int i) async {
    if (tabController.index != i) {
      tabController.animateTo(i);
    }
  }

  return [
    CoachTarget(
      key: inviteKey,
      title: l.groupCoachInviteTitle,
      body: l.groupCoachInviteBody,
      onEnter: () => goTab(0),
    ),
    CoachTarget(
      key: expensesTabKey,
      title: l.groupCoachExpensesTabTitle,
      body: l.groupCoachExpensesTabBody,
      onEnter: () => goTab(0),
    ),
    CoachTarget(
      key: fabKey,
      title: l.groupCoachExpenseTitle,
      body: l.groupCoachExpenseBody,
      onEnter: () => goTab(0),
    ),
    CoachTarget(
      key: balancesTabKey,
      title: l.groupCoachBalancesTitle,
      body: l.groupCoachBalancesBody,
      onEnter: () => goTab(1),
    ),
    CoachTarget(
      key: membersTabKey,
      title: l.groupCoachMembersTitle,
      body: l.groupCoachMembersBody,
      onEnter: () => goTab(2),
    ),
  ];
}
