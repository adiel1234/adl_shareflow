// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appName => 'ShareFlow';

  @override
  String get login => 'כניסה';

  @override
  String get register => 'הרשמה';

  @override
  String get logout => 'יציאה';

  @override
  String get email => 'אימייל';

  @override
  String get password => 'סיסמה';

  @override
  String get confirmPassword => 'אימות סיסמה';

  @override
  String get displayName => 'שם מלא';

  @override
  String get continueWithGoogle => 'המשך עם Google';

  @override
  String get continueWithApple => 'המשך עם Apple';

  @override
  String get forgotPassword => 'שכחתי סיסמה';

  @override
  String get dontHaveAccount => 'אין לך חשבון?';

  @override
  String get alreadyHaveAccount => 'כבר יש לך חשבון?';

  @override
  String get groups => 'קבוצות';

  @override
  String get myGroups => 'הקבוצות שלי';

  @override
  String get createGroup => 'קבוצה חדשה';

  @override
  String get groupName => 'שם הקבוצה';

  @override
  String get baseCurrency => 'מטבע בסיס';

  @override
  String get category => 'קטגוריה';

  @override
  String get members => 'חברים';

  @override
  String get inviteLink => 'קישור הזמנה';

  @override
  String get expenses => 'הוצאות';

  @override
  String get addExpense => 'הוצאה חדשה';

  @override
  String get title => 'כותרת';

  @override
  String get amount => 'סכום';

  @override
  String get currency => 'מטבע';

  @override
  String get paidBy => 'שילם';

  @override
  String get splitBetween => 'חלוקה בין';

  @override
  String get date => 'תאריך';

  @override
  String get notes => 'הערות';

  @override
  String get balances => 'יתרות';

  @override
  String get settlements => 'הסדרות';

  @override
  String get settleUp => 'הסדר חוב';

  @override
  String get youOwe => 'אתה חייב';

  @override
  String get owesYou => 'חייב לך';

  @override
  String get settled => 'מסודר';

  @override
  String get profile => 'פרופיל';

  @override
  String get notifications => 'התראות';

  @override
  String get scanReceipt => 'סרוק קבלה';

  @override
  String get confirm => 'אישור';

  @override
  String get cancel => 'ביטול';

  @override
  String get save => 'שמור';

  @override
  String get delete => 'מחק';

  @override
  String get edit => 'ערוך';

  @override
  String get share => 'שתף';

  @override
  String get loading => 'טוען...';

  @override
  String get error => 'שגיאה';

  @override
  String get tryAgain => 'נסה שוב';

  @override
  String get noExpenses => 'אין הוצאות עדיין';

  @override
  String get noGroups => 'אין קבוצות עדיין';

  @override
  String get categoryApartment => 'דירה';

  @override
  String get categoryTrip => 'טיול';

  @override
  String get categoryVehicle => 'רכב';

  @override
  String get categoryEvent => 'אירוע';

  @override
  String get categoryOther => 'אחר';

  @override
  String get free => 'חינמי';

  @override
  String get pro => 'Pro';

  @override
  String helloUser(String name) {
    return 'שלום, $name 👋';
  }

  @override
  String get joinGroup => 'הצטרף לקבוצה';

  @override
  String get errorLoadingGroups => 'שגיאה בטעינת הקבוצות';

  @override
  String get alreadyMember => 'כבר חבר בקבוצה זו';

  @override
  String get invalidCode => 'קוד לא תקין — בדוק ונסה שוב';

  @override
  String get splitExpenses => 'חלוקת הוצאות';

  @override
  String get howToJoin => 'כיצד תרצה להצטרף?';

  @override
  String get splitAll => 'חלק את כל ההוצאות';

  @override
  String get fromNowOn => 'רק מעכשיו והלאה';

  @override
  String get notChargedPast => 'לא מחויב בהוצאות עד כה';

  @override
  String get enterInviteCode => 'הכנס את קוד ההזמנה שקיבלת';

  @override
  String get join => 'הצטרף';

  @override
  String get noGroupsDescription =>
      'צור קבוצה חדשה עם חברים,\nשותפים לדירה, או בני משפחה';

  @override
  String get joinWithCode => 'הצטרף עם קוד הזמנה';

  @override
  String memberCount(int count) {
    return '$count חברים';
  }

  @override
  String get stateActive => 'פעיל';

  @override
  String get stateFree => 'חינמי';

  @override
  String get stateNeedsActivation => 'דרושה הפעלה';

  @override
  String get stateExpired => 'פג תוקף';

  @override
  String get stateReadOnly => 'קריאה בלבד';

  @override
  String get stateClosed => 'סגורה';

  @override
  String get closeGroup => 'סגור קבוצה';

  @override
  String get groupClosedSuccess => 'הקבוצה נסגרה בהצלחה 🔒';

  @override
  String get errorClosingGroup => 'שגיאה בסגירת הקבוצה';

  @override
  String get unsettledDebts => 'חובות שטרם הוסדרו';

  @override
  String get closeGroupConfirm =>
      'האם אתה בטוח שברצונך לסגור את הקבוצה?\nלאחר הסגירה לא ניתן יהיה להוסיף הוצאות חדשות.';

  @override
  String get unsettledDebtsTitle => 'טרם הוסדרו כלל החובות בקבוצה:';

  @override
  String get closeAnywayNote =>
      'ניתן לסגור בכל זאת, אך החובות יישארו ללא הסדרה.';

  @override
  String get closeAnywayBtn => 'סגור בכל זאת';

  @override
  String get inviteFriends => 'הזמן חברים';

  @override
  String get inviteCode => 'קוד הזמנה';

  @override
  String get codeCopied => 'הקוד הועתק!';

  @override
  String get copyCode => 'העתק קוד';

  @override
  String get copyLink => 'העתק לינק';

  @override
  String get linkCopied => 'הקישור הועתק!';

  @override
  String get sendViaWhatsApp => 'שלח ב-WhatsApp';

  @override
  String get sendEmailInviteTitle => 'שלח הזמנה במייל';

  @override
  String get invalidEmail => 'נא להזין כתובת אימייל תקינה';

  @override
  String get errorLoadingInvite => 'שגיאה בטעינת קישור הזמנה';

  @override
  String inviteSentTo(String email) {
    return 'הזמנה נשלחה ל-$email ✉️';
  }

  @override
  String get errorSendingInvite => 'שגיאה בשליחת ההזמנה';

  @override
  String get language => 'שפה / Language';

  @override
  String get hebrew => 'עברית';

  @override
  String get english => 'English';

  @override
  String get defaultCurrency => 'מטבע ברירת מחדל';

  @override
  String get paymentReminders => 'תזכורות תשלום';

  @override
  String get setReminderFrequency => 'הגדר תדירות ופלטפורמה';

  @override
  String get paymentDetails => 'פרטי תשלום';

  @override
  String get confirmLogout => 'האם אתה בטוח שברצונך לצאת?';

  @override
  String get chooseCurrency => 'בחר מטבע ברירת מחדל';

  @override
  String get summarizeEvent => 'סכם אירוע';

  @override
  String get sendSummaryToMembers => 'שלח סיכום וחלוקת עלויות לחברים';

  @override
  String get expenseDescription => 'תיאור ההוצאה';

  @override
  String get expenseDescriptionHint => 'לדוגמה: ארוחת ערב';

  @override
  String get saveExpense => 'שמור הוצאה';

  @override
  String get errorAddingExpense => 'שגיאה בהוספת הוצאה';

  @override
  String get descriptionRequired => 'נדרש תיאור';

  @override
  String get amountRequired => 'נדרש סכום';

  @override
  String get invalidAmount => 'סכום לא תקין';

  @override
  String get catFood => 'אוכל';

  @override
  String get catTravel => 'טיול';

  @override
  String get catHousing => 'דיור';

  @override
  String get catTransport => 'תחבורה';

  @override
  String get catEntertainment => 'בידור';

  @override
  String get catShopping => 'קניות';

  @override
  String get catUtilities => 'חשבונות';

  @override
  String get catOther => 'אחר';

  @override
  String get closedBadge => '🔒 סגורה';

  @override
  String groupExpensesCount(String name, int count) {
    return 'בקבוצה \"$name\" יש כבר $count הוצאות.';
  }

  @override
  String get youPaid => 'שילמת';

  @override
  String paidByPerson(String name) {
    return 'שילם $name';
  }

  @override
  String get yourShare => 'החלק שלך:';

  @override
  String get noExpensesHint => 'לחץ על \"הוצאה חדשה\" להוסיף';

  @override
  String get errorLoadingExpenses => 'שגיאה בטעינת הוצאות';

  @override
  String get groupBalances => 'יתרות הקבוצה';

  @override
  String get groupTotalExpenses => 'סך הוצאות הקבוצה';

  @override
  String get expensesCountLabel => 'הוצאות';

  @override
  String get owesYouLabel => 'חייבים לך';

  @override
  String get allSettled => 'הכל מסודר! אין העברות נדרשות';

  @override
  String get owesLabel => 'חייב';

  @override
  String get owesHimLabel => 'חייבים לו';

  @override
  String get errorLoadingBalances => 'שגיאה בטעינת יתרות';

  @override
  String get paidByHint => 'בחר מי שילם';

  @override
  String get errorLoadingMembers => 'שגיאה בטעינת חברים';

  @override
  String get optionalNotes => 'הערות (אופציונלי)';

  @override
  String get addNotesHint => 'הוסף הערה...';

  @override
  String get addExpenseBtn => 'הוסף הוצאה';

  @override
  String get scanReceiptDescription => 'חסוך זמן — מלא אוטומטית מקבלה';

  @override
  String get receiptScanned => 'הקבלה נסרקה — ניתן לעדכן את הנתונים';

  @override
  String get rescan => 'סרוק שוב';

  @override
  String get groupTypeOngoing => 'שוטף';

  @override
  String get groupTypeEvent => 'אירוע';

  @override
  String get newGroup => 'קבוצה חדשה';

  @override
  String get activityType => 'סוג פעילות';

  @override
  String get sevenDays => '7 ימים';

  @override
  String get monthly => 'חודשי';

  @override
  String get eventTypeDesc => 'מתאים לטיולים, אירועים, ומפגשים — עד 25 משתתפים';

  @override
  String get ongoingTypeDesc => 'מתאים לדירות שותפים, משרדים — חיוב חודשי';

  @override
  String get groupNameHint => 'לדוגמה: דירה ברחוב הרצל';

  @override
  String get groupNameRequired => 'נדרש שם לקבוצה';

  @override
  String get groupDescription => 'תיאור (אופציונלי)';

  @override
  String get groupDescriptionHint => 'הוסף תיאור קצר...';

  @override
  String get errorCreatingGroup => 'שגיאה ביצירת הקבוצה';

  @override
  String get createGroupBtn => 'צור קבוצה';

  @override
  String get bannerLimitedTitle => 'נדרשת הפעלה';

  @override
  String bannerLimitedSubtitle(int price) {
    return 'הקבוצה הגיעה למגבלת החינם. עלות הפעלה: $price ₪';
  }

  @override
  String get bannerActivate => 'הפעל';

  @override
  String get bannerExpiredTitle => 'פג תוקף הקבוצה';

  @override
  String get bannerExpiredSubtitle =>
      'לא ניתן להוסיף הוצאות. הארכה: 15 ₪ ל-7 ימים נוספים.';

  @override
  String get bannerExtend => 'הארך';

  @override
  String get bannerReadOnlyTitle => 'קריאה בלבד';

  @override
  String bannerReadOnlySubtitle(int price) {
    return 'פרק הזמן שבתשלום הסתיים. חידוש: $price ₪';
  }

  @override
  String get bannerRenew => 'חדש';

  @override
  String get bannerFreeTitle => 'מצב חינמי';

  @override
  String get bannerFreeSubtitle => 'עד 3 משתתפים ו-5 ימים ללא עלות.';

  @override
  String get justNow => 'עכשיו';

  @override
  String minutesAgo(int count) {
    return 'לפני $count דק׳';
  }

  @override
  String hoursAgo(int count) {
    return 'לפני $count שע׳';
  }

  @override
  String daysAgo(int count) {
    return 'לפני $count ימים';
  }

  @override
  String get notifNewExpenseTitle => 'הוצאה חדשה';

  @override
  String notifNewExpenseBody(String payer, String group) {
    return '$payer הוסיף הוצאה ב$group';
  }

  @override
  String get notifSettlementRequestedTitle => 'בקשת תשלום';

  @override
  String get notifSettlementConfirmedTitle => 'תשלום אושר';

  @override
  String get notifMemberJoinedTitle => 'חבר חדש';

  @override
  String get notifGeneralTitle => 'התראה';

  @override
  String get markAllRead => 'סמן הכל כנקרא';

  @override
  String get noNotifications => 'אין התראות עדיין';

  @override
  String get noNotificationsHint =>
      'כשחברי הקבוצה יוסיפו הוצאות\nתקבל התראה כאן';

  @override
  String get errorLoadingNotifications => 'שגיאה בטעינת התראות';

  @override
  String get youLabel => 'אתה';

  @override
  String get adminLabel => 'מנהל';

  @override
  String get removeMember => 'הסר חבר';

  @override
  String removeMemberTitle(String name) {
    return 'הסרת $name';
  }

  @override
  String memberHasBalance(String name, String amount) {
    return 'ל$name יש יתרה פתוחה של $amount.\nכיצד לטפל?';
  }

  @override
  String get settleDebt => 'מסדיר את החוב';

  @override
  String get settleDebtDesc => 'יתרה תאופס ותרשם כהסדרה';

  @override
  String get redistributeDebt => 'חלק בין שאר החברים';

  @override
  String get redistributeDebtDesc => 'ההוצאות יחושבו מחדש';

  @override
  String get removeMemberConfirm => 'להסיר את החבר מהקבוצה?';

  @override
  String get remove => 'הסר';

  @override
  String memberRemovedSuccess(String name) {
    return '$name הוסר מהקבוצה';
  }

  @override
  String get errorRemovingMember => 'שגיאה בהסרת החבר';

  @override
  String get extendGroupTitle => 'הארכת הקבוצה';

  @override
  String get renewGroupTitle => 'חידוש הקבוצה';

  @override
  String get activateGroupTitle => 'הפעלת הקבוצה';

  @override
  String get paymentAmountLabel => 'סכום לתשלום';

  @override
  String get validityLabel => 'תוקף';

  @override
  String get participantsLabel => 'משתתפים';

  @override
  String get howToRecordPayment => 'כיצד לרשום את תשלום ההפעלה?';

  @override
  String get splitAmongAll => 'חלק על כל חברי הקבוצה';

  @override
  String get splitAmongAllDesc => 'תשלום ההפעלה יתחלק בין כל המשתתפים';

  @override
  String get payAlone => 'אני משלם לבד';

  @override
  String get payAloneDesc => 'ההוצאה נרשמת רק עלי';

  @override
  String get betaNoteActivation =>
      'בשלב הביתא ההפעלה מתבצעת ידנית על ידי המנהל. תשלום ישיר יתווסף בגרסה הבאה.';

  @override
  String get extendedSuccess => 'הקבוצה הוארכה בהצלחה 🎉';

  @override
  String get renewedSuccess => 'הקבוצה חודשה בהצלחה 🎉';

  @override
  String get activatedSuccess => 'הקבוצה הופעלה בהצלחה 🎉';

  @override
  String get errorTryAgain => 'שגיאה — נסה שוב';

  @override
  String extendBtnLabel(int price) {
    return 'הארך ב-7 ימים — $price ₪';
  }

  @override
  String renewBtnLabel(int price) {
    return 'חדש לחודש — $price ₪';
  }

  @override
  String activateBtnLabel(int price) {
    return 'הפעל קבוצה — $price ₪';
  }

  @override
  String get sevenDaysPlus => '+7 ימים';

  @override
  String get thirtyDays => '30 יום';

  @override
  String get expenseHint => 'לדוגמה: ארוחת ערב';

  @override
  String get expenseTitleRequired => 'נדרש תיאור';

  @override
  String get notesHint => 'הוסף הערה...';

  @override
  String get editExpense => 'עריכת הוצאה';

  @override
  String get errorUpdatingExpense => 'שגיאה בעדכון ההוצאה';

  @override
  String get saveChanges => 'שמור שינויים';

  @override
  String get selectPaidBy => 'בחר מי שילם';

  @override
  String get loginBtn => 'כניסה';

  @override
  String get welcomeTitle => 'ברוך הבא ל-ShareFlow';

  @override
  String get loginSubtitle => 'כנס לחשבון שלך';

  @override
  String get emailRequired => 'נדרש אימייל';

  @override
  String get passwordRequired => 'נדרשת סיסמה';

  @override
  String get wrongCredentials => 'אימייל או סיסמה שגויים';

  @override
  String get loginError => 'שגיאה בהתחברות, נסה שוב';

  @override
  String get orDivider => 'או';

  @override
  String get fullName => 'שם מלא';

  @override
  String get createAccount => 'צור חשבון חדש';

  @override
  String get fillDetails => 'מלא את הפרטים להמשך';

  @override
  String get nameRequired => 'נדרש שם';

  @override
  String get nameTooShort => 'שם חייב להיות לפחות 2 תווים';

  @override
  String get passwordHint => 'סיסמה (מינימום 8 תווים)';

  @override
  String get passwordTooShort => 'סיסמה חייבת להיות לפחות 8 תווים';

  @override
  String get passwordMismatch => 'הסיסמאות אינן תואמות';

  @override
  String get emailAlreadyRegistered => 'אימייל זה כבר רשום';

  @override
  String get registerError => 'שגיאה בהרשמה, נסה שוב';

  @override
  String get calculating => 'מחשב...';

  @override
  String get exchangeRateLabel => 'שער:';

  @override
  String get eventSummary => 'סיכום אירוע';

  @override
  String get participants => 'משתתפים';

  @override
  String get costPerParticipant => 'עלות לכל משתתף';

  @override
  String get requiredTransfers => '💸 העברות נדרשות';

  @override
  String get sendSummary => '📤 שלח סיכום';

  @override
  String get sendPushToAll => 'שלח התראה לכל החברים';

  @override
  String get sendPushSubtitle => 'Push notification לכל משתמשי הקבוצה';

  @override
  String get shareViaWhatsApp => 'שלח ב-WhatsApp';

  @override
  String get shareWhatsAppSubtitle => 'פתח WhatsApp עם טקסט הסיכום';

  @override
  String reminderSent(String name) {
    return 'תזכורת נשלחה ל-$name ✓';
  }

  @override
  String get errorSendingReminder => 'שגיאה בשליחת תזכורת';

  @override
  String get errorLoadingSummary => 'שגיאה בטעינת הסיכום';

  @override
  String get notificationSentToAll => 'התראה נשלחה לכל חברי הקבוצה ✓';

  @override
  String get errorSendingNotification => 'שגיאה בשליחת התראה';

  @override
  String sendExpenseSplit(String code, String link) {
    return 'הצטרף לקבוצה שלנו ב-ADL ShareFlow!\nקוד הזמנה: $code\nלינק: $link';
  }

  @override
  String get freeGroupLimitReachedTitle => 'הגעת למגבלת הקבוצות החינמיות';

  @override
  String get freeGroupLimitReachedBody =>
      'ניתן ליצור עד 3 קבוצות ללא תשלום. הקבוצה נוצרה, אך כדי להתחיל לעבוד בה יש להפעיל אותה.';

  @override
  String get activateGroupBtn => 'הפעל קבוצה';

  @override
  String get laterBtn => 'אחר כך';
}
