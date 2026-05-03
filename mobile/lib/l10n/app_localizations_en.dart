// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ADL ShareFlow';

  @override
  String get login => 'Login';

  @override
  String get register => 'Sign Up';

  @override
  String get logout => 'Logout';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get displayName => 'Full Name';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get groups => 'Groups';

  @override
  String get myGroups => 'My Groups';

  @override
  String get createGroup => 'New Group';

  @override
  String get groupName => 'Group Name';

  @override
  String get baseCurrency => 'Base Currency';

  @override
  String get category => 'Category';

  @override
  String get members => 'Members';

  @override
  String get inviteLink => 'Invite Link';

  @override
  String get expenses => 'Expenses';

  @override
  String get addExpense => 'Add Expense';

  @override
  String get title => 'Title';

  @override
  String get amount => 'Amount';

  @override
  String get currency => 'Currency';

  @override
  String get paidBy => 'Paid by';

  @override
  String get splitBetween => 'Split between';

  @override
  String get date => 'Date';

  @override
  String get notes => 'Notes';

  @override
  String get balances => 'Ledger';

  @override
  String get settlements => 'Settlements';

  @override
  String get settleUp => 'Settle Up';

  @override
  String get youOwe => 'You owe';

  @override
  String get owesYou => 'Owes you';

  @override
  String get settled => 'Settled';

  @override
  String get profile => 'Profile';

  @override
  String get notifications => 'Notifications';

  @override
  String get scanReceipt => 'Scan Receipt';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get share => 'Share';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get noExpenses => 'No expenses yet';

  @override
  String get noGroups => 'No groups yet';

  @override
  String get categoryApartment => 'Apartment';

  @override
  String get categoryTrip => 'Trip';

  @override
  String get categoryVehicle => 'Vehicle';

  @override
  String get categoryEvent => 'Event';

  @override
  String get categoryOther => 'Other';

  @override
  String get free => 'Free';

  @override
  String get pro => 'Pro';

  @override
  String helloUser(String name) {
    return 'Hello, $name 👋';
  }

  @override
  String get joinGroup => 'Join Group';

  @override
  String get errorLoadingGroups => 'Error loading groups';

  @override
  String get alreadyMember => 'Already a member of this group';

  @override
  String get invalidCode => 'Invalid code - check and try again';

  @override
  String get splitExpenses => 'Split Expenses';

  @override
  String get howToJoin => 'How would you like to join?';

  @override
  String get howShouldNewMemberJoin =>
      'How should the new member join expense splitting?';

  @override
  String get includePastExpenses => 'Including past expenses';

  @override
  String get splitAll => 'Split all expenses';

  @override
  String get fromNowOn => 'From now on only';

  @override
  String get notChargedPast => 'Not charged for past expenses';

  @override
  String get enterInviteCode => 'Enter the invite code you received';

  @override
  String get join => 'Join';

  @override
  String get noGroupsDescription =>
      'Create a new group with friends,\nroommates, or family';

  @override
  String get joinWithCode => 'Join with invite code';

  @override
  String memberCount(int count) {
    return '$count members';
  }

  @override
  String get stateActive => 'Active';

  @override
  String get stateFree => 'Free';

  @override
  String get stateNeedsActivation => 'Needs activation';

  @override
  String get stateExpired => 'Expired';

  @override
  String get stateReadOnly => 'Read only';

  @override
  String get stateClosed => 'Closed';

  @override
  String get closeGroup => 'Close Group';

  @override
  String get groupClosedSuccess => 'Group closed successfully 🔒';

  @override
  String get errorClosingGroup => 'Error closing group';

  @override
  String get unsettledDebts => 'Unsettled Debts';

  @override
  String get closeGroupConfirm =>
      'Are you sure you want to close this group?\nAfter closing, no new expenses can be added.';

  @override
  String get unsettledDebtsTitle => 'Not all debts have been settled:';

  @override
  String get closeAnywayNote =>
      'You can close anyway, but debts will remain unsettled.';

  @override
  String get closeAnywayBtn => 'Close anyway';

  @override
  String get inviteFriends => 'Invite Friends';

  @override
  String get inviteCode => 'Invite Code';

  @override
  String get codeCopied => 'Code copied!';

  @override
  String get copyCode => 'Copy Code';

  @override
  String get copyLink => 'Copy Link';

  @override
  String get linkCopied => 'Link copied!';

  @override
  String get sendViaWhatsApp => 'Send via WhatsApp';

  @override
  String get sendEmailInviteTitle => 'Send email invite';

  @override
  String get invalidEmail => 'Please enter a valid email address';

  @override
  String get errorLoadingInvite => 'Error loading invite link';

  @override
  String inviteSentTo(String email) {
    return 'Invite sent to $email ✉️';
  }

  @override
  String get errorSendingInvite => 'Error sending invite';

  @override
  String get language => 'Language / שפה';

  @override
  String get hebrew => 'עברית';

  @override
  String get english => 'English';

  @override
  String get defaultCurrency => 'Default Currency';

  @override
  String get paymentReminders => 'Payment Reminders';

  @override
  String get setReminderFrequency => 'Set frequency and platform';

  @override
  String get paymentDetails => 'Payment Details';

  @override
  String get confirmLogout => 'Are you sure you want to log out?';

  @override
  String get chooseCurrency => 'Choose default currency';

  @override
  String get summarizeEvent => 'Summarize Event';

  @override
  String get sendSummaryToMembers => 'Send cost summary to members';

  @override
  String get expenseDescription => 'Expense description';

  @override
  String get expenseDescriptionHint => 'e.g. Dinner';

  @override
  String get saveExpense => 'Save Expense';

  @override
  String get errorAddingExpense => 'Error adding expense';

  @override
  String get descriptionRequired => 'Description is required';

  @override
  String get amountRequired => 'Amount is required';

  @override
  String get invalidAmount => 'Invalid amount';

  @override
  String get catFood => 'Food';

  @override
  String get catTravel => 'Travel';

  @override
  String get catHousing => 'Housing';

  @override
  String get catTransport => 'Transport';

  @override
  String get catEntertainment => 'Entertainment';

  @override
  String get catShopping => 'Shopping';

  @override
  String get catUtilities => 'Utilities';

  @override
  String get catOther => 'Other';

  @override
  String get closedBadge => '🔒 Closed';

  @override
  String groupExpensesCount(String name, int count) {
    return 'Group \"$name\" already has $count expenses.';
  }

  @override
  String get youPaid => 'You paid';

  @override
  String paidByPerson(String name) {
    return 'Paid by $name';
  }

  @override
  String get yourShare => 'Your share:';

  @override
  String get noExpensesHint => 'Tap \"Add Expense\" to add one';

  @override
  String get errorLoadingExpenses => 'Error loading expenses';

  @override
  String get groupBalances => 'Group Ledger';

  @override
  String get groupTotalExpenses => 'Total group expenses';

  @override
  String get expensesCountLabel => 'expenses';

  @override
  String get owesYouLabel => 'Others owe you';

  @override
  String get balanceSettled => 'Settled ✅';

  @override
  String get owesLabel => 'Owes';

  @override
  String get owesHimLabel => 'Owed';

  @override
  String get errorLoadingBalances => 'Error loading balances';

  @override
  String get paidByHint => 'Choose who paid';

  @override
  String get errorLoadingMembers => 'Error loading members';

  @override
  String get optionalNotes => 'Notes (optional)';

  @override
  String get addNotesHint => 'Add a note...';

  @override
  String get addExpenseBtn => 'Add Expense';

  @override
  String get scanReceiptDescription => 'Save time - auto-fill from receipt';

  @override
  String get receiptScanned => 'Receipt scanned - you can update the data';

  @override
  String get rescan => 'Rescan';

  @override
  String get groupTypeOngoing => 'Ongoing';

  @override
  String get groupTypeEvent => 'Event';

  @override
  String get newGroup => 'New Group';

  @override
  String get activityType => 'Activity Type';

  @override
  String get sevenDays => '7 days';

  @override
  String get monthly => 'Monthly';

  @override
  String get eventTypeDesc =>
      'For trips, events & gatherings - up to 25 participants';

  @override
  String get ongoingTypeDesc => 'For roommates, offices - monthly billing';

  @override
  String get groupNameHint => 'e.g. Apartment on Main St';

  @override
  String get groupNameRequired => 'Group name is required';

  @override
  String get groupDescription => 'Description (optional)';

  @override
  String get groupDescriptionHint => 'Add a short description...';

  @override
  String get errorCreatingGroup => 'Error creating group';

  @override
  String get createGroupBtn => 'Create Group';

  @override
  String get bannerLimitedTitle => 'Activation required';

  @override
  String bannerLimitedSubtitle(int price) {
    return 'Group reached free limit. Activation cost: ₪$price';
  }

  @override
  String get bannerActivate => 'Activate';

  @override
  String get bannerExpiredTitle => 'Group expired';

  @override
  String get bannerExpiredSubtitle =>
      'Cannot add expenses. Extension: ₪15 for 7 more days.';

  @override
  String get bannerExtend => 'Extend';

  @override
  String get bannerReadOnlyTitle => 'Read only';

  @override
  String bannerReadOnlySubtitle(int price) {
    return 'Paid period ended. Renewal: ₪$price';
  }

  @override
  String get bannerRenew => 'Renew';

  @override
  String get bannerFreeTitle => 'Free mode';

  @override
  String get bannerFreeSubtitle => 'Up to 7 participants and 7 days free.';

  @override
  String get justNow => 'now';

  @override
  String minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get notifNewExpenseTitle => 'New expense';

  @override
  String notifNewExpenseBody(String payer, String group) {
    return '$payer added an expense in $group';
  }

  @override
  String get notifSettlementRequestedTitle => 'Payment request';

  @override
  String get notifSettlementConfirmedTitle => 'Payment confirmed';

  @override
  String get notifMemberJoinedTitle => 'New member';

  @override
  String get notifGeneralTitle => 'Notification';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get noNotificationsHint =>
      'When group members add expenses\nyou\'ll get a notification here';

  @override
  String get errorLoadingNotifications => 'Error loading notifications';

  @override
  String get youLabel => 'You';

  @override
  String get adminLabel => 'Admin';

  @override
  String get removeMember => 'Remove member';

  @override
  String removeMemberTitle(String name) {
    return 'Remove $name';
  }

  @override
  String memberHasBalance(String name, String amount) {
    return '$name has an open balance of $amount — it will remain visible until manually settled.';
  }

  @override
  String get settleDebt => 'Settle the debt';

  @override
  String get settleDebtDesc =>
      'Balance will be reset and recorded as settlement';

  @override
  String get redistributeDebt => 'Distribute among other members';

  @override
  String get redistributeDebtDesc => 'Expenses will be recalculated';

  @override
  String get removeMemberConfirm => 'Remove this member from the group?';

  @override
  String get removeMemberExplain =>
      'Existing expenses remain.\nIf there is an open debt — it will continue to appear in settlements until manually resolved.\nThis action cannot be undone.';

  @override
  String get remove => 'Remove';

  @override
  String memberRemovedSuccess(String name) {
    return '$name was removed. Open debts will remain visible until settled.';
  }

  @override
  String get errorRemovingMember => 'Error removing member';

  @override
  String get formerMember => 'Former';

  @override
  String get extendGroupTitle => 'Extend Group';

  @override
  String get renewGroupTitle => 'Renew Group';

  @override
  String get activateGroupTitle => 'Activate Group';

  @override
  String get paymentAmountLabel => 'Payment amount';

  @override
  String get validityLabel => 'Validity';

  @override
  String get participantsLabel => 'Participants';

  @override
  String get howToRecordPayment => 'How to record the activation payment?';

  @override
  String get splitAmongAll => 'Split among all members';

  @override
  String get splitAmongAllDesc => 'Activation fee split among all participants';

  @override
  String get pay => 'Pay';

  @override
  String get payAlone => 'I pay alone';

  @override
  String get payAloneDesc => 'Expense recorded only for me';

  @override
  String get betaNoteActivation =>
      'During beta, activation is done manually by the admin. Direct payment coming soon.';

  @override
  String get extendedSuccess => 'Group extended successfully 🎉';

  @override
  String get renewedSuccess => 'Group renewed successfully 🎉';

  @override
  String get activatedSuccess => 'Group activated successfully 🎉';

  @override
  String get errorTryAgain => 'Error - try again';

  @override
  String extendBtnLabel(int price) {
    return 'Extend 7 days - ₪$price';
  }

  @override
  String renewBtnLabel(int price) {
    return 'Renew for a month - ₪$price';
  }

  @override
  String activateBtnLabel(int price) {
    return 'Activate group - ₪$price';
  }

  @override
  String get sevenDaysPlus => '+7 days';

  @override
  String get thirtyDays => '30 days';

  @override
  String get expenseHint => 'e.g. Dinner';

  @override
  String get expenseTitleRequired => 'Description is required';

  @override
  String get notesHint => 'Add a note...';

  @override
  String get editExpense => 'Edit Expense';

  @override
  String get errorUpdatingExpense => 'Error updating expense';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get selectPaidBy => 'Please select who paid';

  @override
  String get loginBtn => 'Sign In';

  @override
  String get welcomeTitle => 'Welcome to ADL ShareFlow';

  @override
  String get loginSubtitle => 'Sign in to your account';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get wrongCredentials => 'Incorrect email or password';

  @override
  String get loginError => 'Login error, please try again';

  @override
  String get orDivider => 'or';

  @override
  String get fullName => 'Full Name';

  @override
  String get createAccount => 'Create a new account';

  @override
  String get fillDetails => 'Fill in the details to continue';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get nameTooShort => 'Name must be at least 2 characters';

  @override
  String get passwordHint => 'Password (minimum 8 characters)';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get emailAlreadyRegistered => 'This email is already registered';

  @override
  String get registerError => 'Registration error, please try again';

  @override
  String get calculating => 'Calculating...';

  @override
  String get exchangeRateLabel => 'Rate:';

  @override
  String get eventSummary => 'Event Summary';

  @override
  String get participants => 'Participants';

  @override
  String get costPerParticipant => 'Cost per participant';

  @override
  String get requiredTransfers => 'Required transfers';

  @override
  String get allSettled => 'All settled! No transfers needed';

  @override
  String get sendSummary => 'Send summary';

  @override
  String get sendPushToAll => 'Send notification to all members';

  @override
  String get sendPushSubtitle => 'Push notification to all group members';

  @override
  String get shareViaWhatsApp => 'Share via WhatsApp';

  @override
  String get shareWhatsAppSubtitle => 'Open WhatsApp with summary text';

  @override
  String reminderSent(String name) {
    return 'Reminder sent to $name ✓';
  }

  @override
  String get errorSendingReminder => 'Error sending reminder';

  @override
  String get errorLoadingSummary => 'Error loading summary';

  @override
  String get notificationSentToAll =>
      'Notification sent to all group members ✓';

  @override
  String get errorSendingNotification => 'Error sending notification';

  @override
  String sendExpenseSplit(String groupName, String code, String link) {
    return 'Join our group \"$groupName\" on ADL ShareFlow!\nInvite code: $code\nLink: $link';
  }

  @override
  String get freeGroupLimitReachedTitle => 'Free group limit reached';

  @override
  String get freeGroupLimitReachedBody =>
      'You can create up to 3 groups for free. Your group has been created, but you need to activate it before you can use it.';

  @override
  String get activateGroupBtn => 'Activate Group';

  @override
  String get laterBtn => 'Later';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get settingsSaved => 'Settings saved ✓';

  @override
  String get settingsSaveError => 'Error saving settings';

  @override
  String get enableReminders => 'Enable automatic reminders';

  @override
  String get enableRemindersSubtitle =>
      'Send/receive reminders for open payments';

  @override
  String get reminderFrequency => 'Send frequency';

  @override
  String get reminderPlatforms => 'Platforms';

  @override
  String get inAppNotification => 'In-app notification';

  @override
  String get whatsappMessage => 'Direct WhatsApp message';

  @override
  String get reminderInfo =>
      'Automatic reminders will be sent to debtors until the payment is marked as done.';

  @override
  String get freqNone => 'None';

  @override
  String get freqNoneDesc => 'Don\'t send automatic reminders';

  @override
  String get freqManual => 'Manual only';

  @override
  String get freqManualDesc => 'Only by pressing a button in the app';

  @override
  String get freqDaily => 'Daily';

  @override
  String get freqDailyDesc => 'Send every day';

  @override
  String get freqEvery2Days => 'Every 2 days';

  @override
  String get freqEvery2DaysDesc => 'Send every 2 days';

  @override
  String get freqWeekly => 'Weekly';

  @override
  String get freqWeeklyDesc => 'Once a week';

  @override
  String get freqBiweekly => 'Biweekly';

  @override
  String get freqBiweeklyDesc => 'Once every two weeks';

  @override
  String get paymentDetailsSaved => 'Payment details updated ✓';

  @override
  String get paymentDetailsSaveError => 'Error saving details';

  @override
  String get bitPayboxSubtitle => 'Phone number to receive payments';

  @override
  String get bankTransfer => 'Bank transfer';

  @override
  String get bankTransferSubtitle => 'Bank account details for wire transfers';

  @override
  String get saveDetails => 'Save details';

  @override
  String get bankNameHint => 'Bank name (e.g. Hapoalim)';

  @override
  String get bankBranchHint => 'Branch';

  @override
  String get bankAccountHint => 'Account number';

  @override
  String get paymentPrivacyNote =>
      'Details are only visible to group members for debt settlement';

  @override
  String get cannotOpenApp => 'Cannot open the app';

  @override
  String get errorOpeningApp => 'Error opening the app';

  @override
  String get sendPayment => 'Send Payment';

  @override
  String payTo(String name) {
    return 'Pay to $name';
  }

  @override
  String get choosePaymentMethod => 'Choose payment method';

  @override
  String get noPaymentDetails =>
      'The recipient hasn\'t set up payment details yet.';

  @override
  String get noPaymentDetailsHint =>
      'Ask them to add a Bit/PayBox phone number or bank details in their profile.';

  @override
  String get copyAll => 'Copy all';

  @override
  String get bankDetailsCopied => 'Bank details copied';

  @override
  String get bankLabel => 'Bank';

  @override
  String get branchLabel => 'Branch';

  @override
  String get accountLabel => 'Account';

  @override
  String get amountLabel => 'Amount';

  @override
  String get forCredit => 'For credit';

  @override
  String get pickFromGallery => 'Pick from gallery';

  @override
  String get takePhoto => 'Take photo';

  @override
  String sendReminderTo(String name) {
    return 'Send reminder to $name';
  }

  @override
  String get qrCodeTitle => 'QR Code';

  @override
  String get qrCodeSubtitle => 'Show this to a friend to scan';

  @override
  String get scanQrCode => 'Scan QR';

  @override
  String get scanQrSubtitle => 'Point the camera at the group QR code';

  @override
  String get qrScanSuccess => 'Code scanned successfully!';

  @override
  String get qrScanError => 'Could not read the QR code';

  @override
  String get noCameraPermission => 'Camera permission is required';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get showQrCode => 'Show QR';

  @override
  String get aboutTitle => 'About ADL ShareFlow';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get contactUs => 'Contact Us';

  @override
  String get contactSubtitle => 'Questions, issues and more';

  @override
  String get adlProjects => 'ADL Projects';

  @override
  String get adlProjectsSubtitle => 'More projects by ADL';

  @override
  String get suggestions => 'Suggestions & Feedback';

  @override
  String get suggestionsSubtitle => 'Tell us how we can improve';

  @override
  String get proPlanTitle => 'Pro Plan';

  @override
  String get proPlanSubtitle => 'Coming soon - analytics, stats and more';

  @override
  String get appSection => 'App';

  @override
  String get paymentMethodSubtitle => 'Bit, PayBox, Bank transfer';

  @override
  String get pricingSection => 'Pricing';

  @override
  String get estimatedCost => 'Estimated cost';

  @override
  String upToParticipants(int count) {
    return 'Up to $count members';
  }

  @override
  String aboveParticipants(int count) {
    return '$count+ members';
  }

  @override
  String get freeTierLabel => 'Free - up to 7 members';

  @override
  String get freeIncluded => 'Free: up to 7 members & 7 days';

  @override
  String get createGroupFree => 'Create Group - Free';

  @override
  String createGroupPaid(int price) {
    return 'Create Group - ₪$price';
  }

  @override
  String durationDays(int days) {
    return '$days days';
  }

  @override
  String get durationMonth => 'Month';

  @override
  String get tierUpgradeRequired => 'Plan Upgrade Required';

  @override
  String tierUpgradeSubtitle(int price) {
    return 'Group has grown - upgrade payment of ₪$price required';
  }

  @override
  String get tierUpgradeBtn => 'Upgrade Now';

  @override
  String get upgradeTierTitle => 'Upgrade Plan';

  @override
  String get upgradeTierDesc =>
      'Member count has grown to a higher tier. Pay the difference to continue.';

  @override
  String upgradeBtnLabel(int price) {
    return 'Upgrade - ₪$price';
  }

  @override
  String get upgradedSuccess => 'Plan upgraded successfully 🎉';

  @override
  String get errorUpgradingTier => 'Error upgrading plan';

  @override
  String get periodicSettlement => 'Periodic Settlement';

  @override
  String get manualSettlement => 'Manual / One-time';

  @override
  String get manualSettlementDesc => 'Close accounts whenever you want';

  @override
  String get automaticPeriodic => 'Automatic Periodic';

  @override
  String get automaticPeriodicDesc =>
      'Report sent automatically, debts can be marked as paid';

  @override
  String get settlementFrequency => 'Settlement Frequency';

  @override
  String get periodWeekly => 'Weekly';

  @override
  String get periodBiweekly => 'Biweekly';

  @override
  String get periodMonthly => 'Monthly';

  @override
  String get periodBimonthly => 'Bimonthly';

  @override
  String get periodQuarterly => 'Quarterly';

  @override
  String get periodSemiannual => 'Semiannual';

  @override
  String get periodAnnual => 'Annual';

  @override
  String get settlePeriodBtn => 'Settle Period';

  @override
  String settlePeriodNext(String date) {
    return 'Next: $date';
  }

  @override
  String get settlePeriodCreateReport => 'Close period and create report';

  @override
  String get settlePeriodDialogTitle => 'Period Summary';

  @override
  String get settlePeriodConfirmMsg =>
      'Would you like to settle the current period?\n\nA report will be sent to all group members and the period will reset.';

  @override
  String get settlePeriodSuccess =>
      'Period settled successfully! Report sent to group members';

  @override
  String get errorSettlingPeriod => 'Error settling period';

  @override
  String get previousPeriodReports => 'Previous Period Reports';

  @override
  String periodLabel(int number) {
    return 'Period #$number';
  }

  @override
  String get allDebtsPaid => 'All debts paid ✓';

  @override
  String openDebtsCount(int count) {
    return '$count open debts';
  }

  @override
  String get openDebtCount => '1 open debt';

  @override
  String get noDebtsBalanced => 'All balanced - no debts';

  @override
  String get markAsPaid => 'Paid ✓';

  @override
  String get currentPeriodExpenses => 'Current period expenses';

  @override
  String periodSince(String date) {
    return 'Since $date';
  }

  @override
  String get openDebtsGroupClosed => 'Open debts - group is closed';

  @override
  String get groupClosedUnpaidDebts =>
      'The group is closed but there are unpaid debts';

  @override
  String get requiredTransfersTitle => 'Required transfers';

  @override
  String transferNeeded(String from, String to) {
    return '$from needs to transfer to $to';
  }

  @override
  String get deleteGroup => 'Delete Group';

  @override
  String get deleteGroupDialogTitle => 'Delete Group';

  @override
  String deleteGroupConfirm(String name) {
    return 'Permanently delete group \"$name\"?\n\nAll expenses, balances and history will be deleted and cannot be recovered.';
  }

  @override
  String get deleteGroupPermanently => 'Delete Permanently';

  @override
  String get groupDeletedSuccess => 'Group deleted successfully';

  @override
  String get errorDeletingGroup => 'Error deleting group';

  @override
  String get addGuest => 'Add Guest';

  @override
  String get addGuestTitle => 'Add member without the app';

  @override
  String get addGuestHint => 'Member name (e.g. John Smith)';

  @override
  String get addGuestBtn => 'Add';

  @override
  String get guestBadge => 'Guest';

  @override
  String get guestAddedSuccess => 'Guest added to group';

  @override
  String get guestLabel => '👤 Guest';

  @override
  String get guestExplainTitle => 'What is a guest?';

  @override
  String get guestExplainBody =>
      'A guest is a member who doesn\'t have the app yet.\n• They are included in expense calculations like any other member\n• The admin manages their payments until they download the app\n• Once they download it — the admin links them to their account and they become fully independent';

  @override
  String get guestReminderTitle => 'Guests without an account';

  @override
  String guestReminderBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0 are marked as guests.\nOnce they download the app, link them to their account using the link button.';
  }

  @override
  String get guestReminderAction => 'Manage guests';

  @override
  String get linkGuestTitle => 'Link guest to account';

  @override
  String linkGuestSubtitle(String name) {
    return 'Select the registered member to link $name to';
  }

  @override
  String get linkGuestExplain =>
      'All of the guest\'s expenses and balances will be transferred to the selected account.';

  @override
  String get linkGuestBtn => 'Link';

  @override
  String get linkGuestSuccess => 'Guest linked successfully';

  @override
  String get removeGuest => 'Remove Guest';

  @override
  String removeGuestConfirm(String name) {
    return 'Guest $name will be removed from the active members list.\nExisting expenses remain.\nIf there is an open debt — it will continue to appear in settlements until manually resolved.\nThis action cannot be undone.';
  }

  @override
  String guestRemovedSuccess(String name) {
    return '$name removed. Open debt will remain visible until settled.';
  }

  @override
  String get markGuestPaid => 'Mark as paid (on behalf of guest)';

  @override
  String get guestNoApp => 'For members who haven\'t downloaded the app yet';
}
