import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he')
  ];

  /// No description provided for @appName.
  ///
  /// In he, this message translates to:
  /// **'ADL ShareFlow'**
  String get appName;

  /// No description provided for @login.
  ///
  /// In he, this message translates to:
  /// **'כניסה'**
  String get login;

  /// No description provided for @register.
  ///
  /// In he, this message translates to:
  /// **'הרשמה'**
  String get register;

  /// No description provided for @logout.
  ///
  /// In he, this message translates to:
  /// **'יציאה'**
  String get logout;

  /// No description provided for @email.
  ///
  /// In he, this message translates to:
  /// **'אימייל'**
  String get email;

  /// No description provided for @password.
  ///
  /// In he, this message translates to:
  /// **'סיסמה'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In he, this message translates to:
  /// **'אימות סיסמה'**
  String get confirmPassword;

  /// No description provided for @displayName.
  ///
  /// In he, this message translates to:
  /// **'שם מלא'**
  String get displayName;

  /// No description provided for @continueWithGoogle.
  ///
  /// In he, this message translates to:
  /// **'המשך עם Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In he, this message translates to:
  /// **'המשך עם Apple'**
  String get continueWithApple;

  /// No description provided for @forgotPassword.
  ///
  /// In he, this message translates to:
  /// **'שכחתי סיסמה'**
  String get forgotPassword;

  /// No description provided for @dontHaveAccount.
  ///
  /// In he, this message translates to:
  /// **'אין לך חשבון?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In he, this message translates to:
  /// **'כבר יש לך חשבון?'**
  String get alreadyHaveAccount;

  /// No description provided for @groups.
  ///
  /// In he, this message translates to:
  /// **'קבוצות'**
  String get groups;

  /// No description provided for @myGroups.
  ///
  /// In he, this message translates to:
  /// **'הקבוצות שלי'**
  String get myGroups;

  /// No description provided for @createGroup.
  ///
  /// In he, this message translates to:
  /// **'קבוצה חדשה'**
  String get createGroup;

  /// No description provided for @groupName.
  ///
  /// In he, this message translates to:
  /// **'שם הקבוצה'**
  String get groupName;

  /// No description provided for @baseCurrency.
  ///
  /// In he, this message translates to:
  /// **'מטבע בסיס'**
  String get baseCurrency;

  /// No description provided for @category.
  ///
  /// In he, this message translates to:
  /// **'קטגוריה'**
  String get category;

  /// No description provided for @members.
  ///
  /// In he, this message translates to:
  /// **'חברים'**
  String get members;

  /// No description provided for @inviteLink.
  ///
  /// In he, this message translates to:
  /// **'קישור הזמנה'**
  String get inviteLink;

  /// No description provided for @expenses.
  ///
  /// In he, this message translates to:
  /// **'הוצאות'**
  String get expenses;

  /// No description provided for @addExpense.
  ///
  /// In he, this message translates to:
  /// **'הוצאה חדשה'**
  String get addExpense;

  /// No description provided for @title.
  ///
  /// In he, this message translates to:
  /// **'כותרת'**
  String get title;

  /// No description provided for @amount.
  ///
  /// In he, this message translates to:
  /// **'סכום'**
  String get amount;

  /// No description provided for @currency.
  ///
  /// In he, this message translates to:
  /// **'מטבע'**
  String get currency;

  /// No description provided for @paidBy.
  ///
  /// In he, this message translates to:
  /// **'שילם'**
  String get paidBy;

  /// No description provided for @splitBetween.
  ///
  /// In he, this message translates to:
  /// **'חלוקה בין'**
  String get splitBetween;

  /// No description provided for @date.
  ///
  /// In he, this message translates to:
  /// **'תאריך'**
  String get date;

  /// No description provided for @notes.
  ///
  /// In he, this message translates to:
  /// **'הערות'**
  String get notes;

  /// No description provided for @balances.
  ///
  /// In he, this message translates to:
  /// **'חשבון'**
  String get balances;

  /// No description provided for @settlements.
  ///
  /// In he, this message translates to:
  /// **'הסדרות'**
  String get settlements;

  /// No description provided for @settleUp.
  ///
  /// In he, this message translates to:
  /// **'הסדר חוב'**
  String get settleUp;

  /// No description provided for @youOwe.
  ///
  /// In he, this message translates to:
  /// **'אתה חייב'**
  String get youOwe;

  /// No description provided for @owesYou.
  ///
  /// In he, this message translates to:
  /// **'חייב לך'**
  String get owesYou;

  /// No description provided for @settled.
  ///
  /// In he, this message translates to:
  /// **'מסודר'**
  String get settled;

  /// No description provided for @profile.
  ///
  /// In he, this message translates to:
  /// **'פרופיל'**
  String get profile;

  /// No description provided for @notifications.
  ///
  /// In he, this message translates to:
  /// **'התראות'**
  String get notifications;

  /// No description provided for @scanReceipt.
  ///
  /// In he, this message translates to:
  /// **'סרוק קבלה'**
  String get scanReceipt;

  /// No description provided for @confirm.
  ///
  /// In he, this message translates to:
  /// **'אישור'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In he, this message translates to:
  /// **'ביטול'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In he, this message translates to:
  /// **'שמור'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In he, this message translates to:
  /// **'מחק'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In he, this message translates to:
  /// **'ערוך'**
  String get edit;

  /// No description provided for @share.
  ///
  /// In he, this message translates to:
  /// **'שתף'**
  String get share;

  /// No description provided for @loading.
  ///
  /// In he, this message translates to:
  /// **'טוען...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In he, this message translates to:
  /// **'שגיאה'**
  String get error;

  /// No description provided for @tryAgain.
  ///
  /// In he, this message translates to:
  /// **'נסה שוב'**
  String get tryAgain;

  /// No description provided for @noExpenses.
  ///
  /// In he, this message translates to:
  /// **'אין הוצאות עדיין'**
  String get noExpenses;

  /// No description provided for @noGroups.
  ///
  /// In he, this message translates to:
  /// **'אין קבוצות עדיין'**
  String get noGroups;

  /// No description provided for @categoryApartment.
  ///
  /// In he, this message translates to:
  /// **'דירה'**
  String get categoryApartment;

  /// No description provided for @categoryTrip.
  ///
  /// In he, this message translates to:
  /// **'טיול'**
  String get categoryTrip;

  /// No description provided for @categoryVehicle.
  ///
  /// In he, this message translates to:
  /// **'רכב'**
  String get categoryVehicle;

  /// No description provided for @categoryEvent.
  ///
  /// In he, this message translates to:
  /// **'אירוע'**
  String get categoryEvent;

  /// No description provided for @categoryOther.
  ///
  /// In he, this message translates to:
  /// **'אחר'**
  String get categoryOther;

  /// No description provided for @free.
  ///
  /// In he, this message translates to:
  /// **'חינמי'**
  String get free;

  /// No description provided for @pro.
  ///
  /// In he, this message translates to:
  /// **'Pro'**
  String get pro;

  /// No description provided for @helloUser.
  ///
  /// In he, this message translates to:
  /// **'שלום, {name} 👋'**
  String helloUser(String name);

  /// No description provided for @joinGroup.
  ///
  /// In he, this message translates to:
  /// **'הצטרף לקבוצה'**
  String get joinGroup;

  /// No description provided for @errorLoadingGroups.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בטעינת הקבוצות'**
  String get errorLoadingGroups;

  /// No description provided for @alreadyMember.
  ///
  /// In he, this message translates to:
  /// **'כבר חבר בקבוצה זו'**
  String get alreadyMember;

  /// No description provided for @invalidCode.
  ///
  /// In he, this message translates to:
  /// **'קוד לא תקין — בדוק ונסה שוב'**
  String get invalidCode;

  /// No description provided for @splitExpenses.
  ///
  /// In he, this message translates to:
  /// **'חלוקת הוצאות'**
  String get splitExpenses;

  /// No description provided for @howToJoin.
  ///
  /// In he, this message translates to:
  /// **'כיצד תרצה להצטרף?'**
  String get howToJoin;

  /// No description provided for @howShouldNewMemberJoin.
  ///
  /// In he, this message translates to:
  /// **'כיצד החבר החדש יצטרף לחלוקת ההוצאות?'**
  String get howShouldNewMemberJoin;

  /// No description provided for @includePastExpenses.
  ///
  /// In he, this message translates to:
  /// **'כולל הוצאות עבר'**
  String get includePastExpenses;

  /// No description provided for @splitAll.
  ///
  /// In he, this message translates to:
  /// **'חלק את כל ההוצאות'**
  String get splitAll;

  /// No description provided for @fromNowOn.
  ///
  /// In he, this message translates to:
  /// **'רק מעכשיו והלאה'**
  String get fromNowOn;

  /// No description provided for @notChargedPast.
  ///
  /// In he, this message translates to:
  /// **'לא מחויב בהוצאות עד כה'**
  String get notChargedPast;

  /// No description provided for @enterInviteCode.
  ///
  /// In he, this message translates to:
  /// **'הכנס את קוד ההזמנה שקיבלת'**
  String get enterInviteCode;

  /// No description provided for @join.
  ///
  /// In he, this message translates to:
  /// **'הצטרף'**
  String get join;

  /// No description provided for @noGroupsDescription.
  ///
  /// In he, this message translates to:
  /// **'צור קבוצה חדשה עם חברים,\nשותפים לדירה, או בני משפחה'**
  String get noGroupsDescription;

  /// No description provided for @joinWithCode.
  ///
  /// In he, this message translates to:
  /// **'הצטרף עם קוד הזמנה'**
  String get joinWithCode;

  /// No description provided for @memberCount.
  ///
  /// In he, this message translates to:
  /// **'{count} חברים'**
  String memberCount(int count);

  /// No description provided for @stateActive.
  ///
  /// In he, this message translates to:
  /// **'פעיל'**
  String get stateActive;

  /// No description provided for @stateFree.
  ///
  /// In he, this message translates to:
  /// **'חינמי'**
  String get stateFree;

  /// No description provided for @stateNeedsActivation.
  ///
  /// In he, this message translates to:
  /// **'דרושה הפעלה'**
  String get stateNeedsActivation;

  /// No description provided for @stateExpired.
  ///
  /// In he, this message translates to:
  /// **'פג תוקף'**
  String get stateExpired;

  /// No description provided for @stateReadOnly.
  ///
  /// In he, this message translates to:
  /// **'קריאה בלבד'**
  String get stateReadOnly;

  /// No description provided for @stateClosed.
  ///
  /// In he, this message translates to:
  /// **'סגורה'**
  String get stateClosed;

  /// No description provided for @closeGroup.
  ///
  /// In he, this message translates to:
  /// **'סגור קבוצה'**
  String get closeGroup;

  /// No description provided for @groupClosedSuccess.
  ///
  /// In he, this message translates to:
  /// **'הקבוצה נסגרה בהצלחה 🔒'**
  String get groupClosedSuccess;

  /// No description provided for @errorClosingGroup.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בסגירת הקבוצה'**
  String get errorClosingGroup;

  /// No description provided for @unsettledDebts.
  ///
  /// In he, this message translates to:
  /// **'חובות שטרם הוסדרו'**
  String get unsettledDebts;

  /// No description provided for @closeGroupConfirm.
  ///
  /// In he, this message translates to:
  /// **'האם אתה בטוח שברצונך לסגור את הקבוצה?\nלאחר הסגירה לא ניתן יהיה להוסיף הוצאות חדשות.'**
  String get closeGroupConfirm;

  /// No description provided for @unsettledDebtsTitle.
  ///
  /// In he, this message translates to:
  /// **'טרם הוסדרו כלל החובות בקבוצה:'**
  String get unsettledDebtsTitle;

  /// No description provided for @closeAnywayNote.
  ///
  /// In he, this message translates to:
  /// **'ניתן לסגור בכל זאת, אך החובות יישארו ללא הסדרה.'**
  String get closeAnywayNote;

  /// No description provided for @closeAnywayBtn.
  ///
  /// In he, this message translates to:
  /// **'סגור בכל זאת'**
  String get closeAnywayBtn;

  /// No description provided for @inviteFriends.
  ///
  /// In he, this message translates to:
  /// **'הזמן חברים'**
  String get inviteFriends;

  /// No description provided for @inviteCode.
  ///
  /// In he, this message translates to:
  /// **'קוד הזמנה'**
  String get inviteCode;

  /// No description provided for @codeCopied.
  ///
  /// In he, this message translates to:
  /// **'הקוד הועתק!'**
  String get codeCopied;

  /// No description provided for @copyCode.
  ///
  /// In he, this message translates to:
  /// **'העתק קוד'**
  String get copyCode;

  /// No description provided for @copyLink.
  ///
  /// In he, this message translates to:
  /// **'העתק לינק'**
  String get copyLink;

  /// No description provided for @linkCopied.
  ///
  /// In he, this message translates to:
  /// **'הקישור הועתק!'**
  String get linkCopied;

  /// No description provided for @sendViaWhatsApp.
  ///
  /// In he, this message translates to:
  /// **'שלח ב-WhatsApp'**
  String get sendViaWhatsApp;

  /// No description provided for @sendEmailInviteTitle.
  ///
  /// In he, this message translates to:
  /// **'שלח הזמנה במייל'**
  String get sendEmailInviteTitle;

  /// No description provided for @invalidEmail.
  ///
  /// In he, this message translates to:
  /// **'נא להזין כתובת אימייל תקינה'**
  String get invalidEmail;

  /// No description provided for @errorLoadingInvite.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בטעינת קישור הזמנה'**
  String get errorLoadingInvite;

  /// No description provided for @inviteSentTo.
  ///
  /// In he, this message translates to:
  /// **'הזמנה נשלחה ל-{email} ✉️'**
  String inviteSentTo(String email);

  /// No description provided for @errorSendingInvite.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בשליחת ההזמנה'**
  String get errorSendingInvite;

  /// No description provided for @language.
  ///
  /// In he, this message translates to:
  /// **'שפה / Language'**
  String get language;

  /// No description provided for @hebrew.
  ///
  /// In he, this message translates to:
  /// **'עברית'**
  String get hebrew;

  /// No description provided for @english.
  ///
  /// In he, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @defaultCurrency.
  ///
  /// In he, this message translates to:
  /// **'מטבע ברירת מחדל'**
  String get defaultCurrency;

  /// No description provided for @paymentReminders.
  ///
  /// In he, this message translates to:
  /// **'תזכורות תשלום'**
  String get paymentReminders;

  /// No description provided for @setReminderFrequency.
  ///
  /// In he, this message translates to:
  /// **'הגדר תדירות ופלטפורמה'**
  String get setReminderFrequency;

  /// No description provided for @paymentDetails.
  ///
  /// In he, this message translates to:
  /// **'פרטי תשלום'**
  String get paymentDetails;

  /// No description provided for @confirmLogout.
  ///
  /// In he, this message translates to:
  /// **'האם אתה בטוח שברצונך לצאת?'**
  String get confirmLogout;

  /// No description provided for @chooseCurrency.
  ///
  /// In he, this message translates to:
  /// **'בחר מטבע ברירת מחדל'**
  String get chooseCurrency;

  /// No description provided for @summarizeEvent.
  ///
  /// In he, this message translates to:
  /// **'סכם אירוע'**
  String get summarizeEvent;

  /// No description provided for @sendSummaryToMembers.
  ///
  /// In he, this message translates to:
  /// **'שלח סיכום וחלוקת עלויות לחברים'**
  String get sendSummaryToMembers;

  /// No description provided for @expenseDescription.
  ///
  /// In he, this message translates to:
  /// **'תיאור ההוצאה'**
  String get expenseDescription;

  /// No description provided for @expenseDescriptionHint.
  ///
  /// In he, this message translates to:
  /// **'לדוגמה: ארוחת ערב'**
  String get expenseDescriptionHint;

  /// No description provided for @saveExpense.
  ///
  /// In he, this message translates to:
  /// **'שמור הוצאה'**
  String get saveExpense;

  /// No description provided for @errorAddingExpense.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בהוספת הוצאה'**
  String get errorAddingExpense;

  /// No description provided for @descriptionRequired.
  ///
  /// In he, this message translates to:
  /// **'נדרש תיאור'**
  String get descriptionRequired;

  /// No description provided for @amountRequired.
  ///
  /// In he, this message translates to:
  /// **'נדרש סכום'**
  String get amountRequired;

  /// No description provided for @invalidAmount.
  ///
  /// In he, this message translates to:
  /// **'סכום לא תקין'**
  String get invalidAmount;

  /// No description provided for @catFood.
  ///
  /// In he, this message translates to:
  /// **'אוכל'**
  String get catFood;

  /// No description provided for @catTravel.
  ///
  /// In he, this message translates to:
  /// **'טיול'**
  String get catTravel;

  /// No description provided for @catHousing.
  ///
  /// In he, this message translates to:
  /// **'דיור'**
  String get catHousing;

  /// No description provided for @catTransport.
  ///
  /// In he, this message translates to:
  /// **'תחבורה'**
  String get catTransport;

  /// No description provided for @catEntertainment.
  ///
  /// In he, this message translates to:
  /// **'בידור'**
  String get catEntertainment;

  /// No description provided for @catShopping.
  ///
  /// In he, this message translates to:
  /// **'קניות'**
  String get catShopping;

  /// No description provided for @catUtilities.
  ///
  /// In he, this message translates to:
  /// **'חשבונות'**
  String get catUtilities;

  /// No description provided for @catOther.
  ///
  /// In he, this message translates to:
  /// **'אחר'**
  String get catOther;

  /// No description provided for @closedBadge.
  ///
  /// In he, this message translates to:
  /// **'🔒 סגורה'**
  String get closedBadge;

  /// No description provided for @groupExpensesCount.
  ///
  /// In he, this message translates to:
  /// **'בקבוצה \"{name}\" יש כבר {count} הוצאות.'**
  String groupExpensesCount(String name, int count);

  /// No description provided for @youPaid.
  ///
  /// In he, this message translates to:
  /// **'שילמת'**
  String get youPaid;

  /// No description provided for @paidByPerson.
  ///
  /// In he, this message translates to:
  /// **'שילם {name}'**
  String paidByPerson(String name);

  /// No description provided for @yourShare.
  ///
  /// In he, this message translates to:
  /// **'החלק שלך:'**
  String get yourShare;

  /// No description provided for @noExpensesHint.
  ///
  /// In he, this message translates to:
  /// **'לחץ על \"הוצאה חדשה\" להוסיף'**
  String get noExpensesHint;

  /// No description provided for @errorLoadingExpenses.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בטעינת הוצאות'**
  String get errorLoadingExpenses;

  /// No description provided for @groupBalances.
  ///
  /// In he, this message translates to:
  /// **'חשבון הקבוצה'**
  String get groupBalances;

  /// No description provided for @groupTotalExpenses.
  ///
  /// In he, this message translates to:
  /// **'סך הוצאות הקבוצה'**
  String get groupTotalExpenses;

  /// No description provided for @expensesCountLabel.
  ///
  /// In he, this message translates to:
  /// **'הוצאות'**
  String get expensesCountLabel;

  /// No description provided for @owesYouLabel.
  ///
  /// In he, this message translates to:
  /// **'חייבים לך'**
  String get owesYouLabel;

  /// No description provided for @balanceSettled.
  ///
  /// In he, this message translates to:
  /// **'מסודר ✅'**
  String get balanceSettled;

  /// No description provided for @owesLabel.
  ///
  /// In he, this message translates to:
  /// **'חייב'**
  String get owesLabel;

  /// No description provided for @owesHimLabel.
  ///
  /// In he, this message translates to:
  /// **'חייבים לו'**
  String get owesHimLabel;

  /// No description provided for @errorLoadingBalances.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בטעינת חשבון'**
  String get errorLoadingBalances;

  /// No description provided for @paidByHint.
  ///
  /// In he, this message translates to:
  /// **'בחר מי שילם'**
  String get paidByHint;

  /// No description provided for @errorLoadingMembers.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בטעינת חברים'**
  String get errorLoadingMembers;

  /// No description provided for @optionalNotes.
  ///
  /// In he, this message translates to:
  /// **'הערות (אופציונלי)'**
  String get optionalNotes;

  /// No description provided for @addNotesHint.
  ///
  /// In he, this message translates to:
  /// **'הוסף הערה...'**
  String get addNotesHint;

  /// No description provided for @addExpenseBtn.
  ///
  /// In he, this message translates to:
  /// **'הוסף הוצאה'**
  String get addExpenseBtn;

  /// No description provided for @scanReceiptDescription.
  ///
  /// In he, this message translates to:
  /// **'חסוך זמן — מלא אוטומטית מקבלה'**
  String get scanReceiptDescription;

  /// No description provided for @receiptScanned.
  ///
  /// In he, this message translates to:
  /// **'הקבלה נסרקה — ניתן לעדכן את הנתונים'**
  String get receiptScanned;

  /// No description provided for @rescan.
  ///
  /// In he, this message translates to:
  /// **'סרוק שוב'**
  String get rescan;

  /// No description provided for @groupTypeOngoing.
  ///
  /// In he, this message translates to:
  /// **'שוטף'**
  String get groupTypeOngoing;

  /// No description provided for @groupTypeEvent.
  ///
  /// In he, this message translates to:
  /// **'אירוע'**
  String get groupTypeEvent;

  /// No description provided for @newGroup.
  ///
  /// In he, this message translates to:
  /// **'קבוצה חדשה'**
  String get newGroup;

  /// No description provided for @activityType.
  ///
  /// In he, this message translates to:
  /// **'סוג פעילות'**
  String get activityType;

  /// No description provided for @sevenDays.
  ///
  /// In he, this message translates to:
  /// **'7 ימים'**
  String get sevenDays;

  /// No description provided for @monthly.
  ///
  /// In he, this message translates to:
  /// **'חודשי'**
  String get monthly;

  /// No description provided for @eventTypeDesc.
  ///
  /// In he, this message translates to:
  /// **'מתאים לטיולים, אירועים, ומפגשים — עד 25 משתתפים'**
  String get eventTypeDesc;

  /// No description provided for @ongoingTypeDesc.
  ///
  /// In he, this message translates to:
  /// **'מתאים לדירות שותפים, משרדים — חיוב חודשי'**
  String get ongoingTypeDesc;

  /// No description provided for @groupNameHint.
  ///
  /// In he, this message translates to:
  /// **'לדוגמה: דירה ברחוב הרצל'**
  String get groupNameHint;

  /// No description provided for @groupNameRequired.
  ///
  /// In he, this message translates to:
  /// **'נדרש שם לקבוצה'**
  String get groupNameRequired;

  /// No description provided for @groupDescription.
  ///
  /// In he, this message translates to:
  /// **'תיאור (אופציונלי)'**
  String get groupDescription;

  /// No description provided for @groupDescriptionHint.
  ///
  /// In he, this message translates to:
  /// **'הוסף תיאור קצר...'**
  String get groupDescriptionHint;

  /// No description provided for @errorCreatingGroup.
  ///
  /// In he, this message translates to:
  /// **'שגיאה ביצירת הקבוצה'**
  String get errorCreatingGroup;

  /// No description provided for @createGroupBtn.
  ///
  /// In he, this message translates to:
  /// **'צור קבוצה'**
  String get createGroupBtn;

  /// No description provided for @bannerLimitedTitle.
  ///
  /// In he, this message translates to:
  /// **'נדרשת הפעלה'**
  String get bannerLimitedTitle;

  /// No description provided for @bannerLimitedSubtitle.
  ///
  /// In he, this message translates to:
  /// **'הקבוצה הגיעה למגבלת החינם. עלות הפעלה: {price} ₪'**
  String bannerLimitedSubtitle(int price);

  /// No description provided for @bannerActivate.
  ///
  /// In he, this message translates to:
  /// **'הפעל'**
  String get bannerActivate;

  /// No description provided for @bannerExpiredTitle.
  ///
  /// In he, this message translates to:
  /// **'פג תוקף הקבוצה'**
  String get bannerExpiredTitle;

  /// No description provided for @bannerExpiredSubtitle.
  ///
  /// In he, this message translates to:
  /// **'לא ניתן להוסיף הוצאות. הארכה: 15 ₪ ל-7 ימים נוספים.'**
  String get bannerExpiredSubtitle;

  /// No description provided for @bannerExtend.
  ///
  /// In he, this message translates to:
  /// **'הארך'**
  String get bannerExtend;

  /// No description provided for @bannerReadOnlyTitle.
  ///
  /// In he, this message translates to:
  /// **'קריאה בלבד'**
  String get bannerReadOnlyTitle;

  /// No description provided for @bannerReadOnlySubtitle.
  ///
  /// In he, this message translates to:
  /// **'פרק הזמן שבתשלום הסתיים. חידוש: {price} ₪'**
  String bannerReadOnlySubtitle(int price);

  /// No description provided for @bannerRenew.
  ///
  /// In he, this message translates to:
  /// **'חדש'**
  String get bannerRenew;

  /// No description provided for @bannerFreeTitle.
  ///
  /// In he, this message translates to:
  /// **'מצב חינמי'**
  String get bannerFreeTitle;

  /// No description provided for @bannerFreeSubtitle.
  ///
  /// In he, this message translates to:
  /// **'עד 3 משתתפים ו-5 ימים ללא עלות.'**
  String get bannerFreeSubtitle;

  /// No description provided for @justNow.
  ///
  /// In he, this message translates to:
  /// **'עכשיו'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In he, this message translates to:
  /// **'לפני {count} דק׳'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In he, this message translates to:
  /// **'לפני {count} שע׳'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In he, this message translates to:
  /// **'לפני {count} ימים'**
  String daysAgo(int count);

  /// No description provided for @notifNewExpenseTitle.
  ///
  /// In he, this message translates to:
  /// **'הוצאה חדשה'**
  String get notifNewExpenseTitle;

  /// No description provided for @notifNewExpenseBody.
  ///
  /// In he, this message translates to:
  /// **'{payer} הוסיף הוצאה ב{group}'**
  String notifNewExpenseBody(String payer, String group);

  /// No description provided for @notifSettlementRequestedTitle.
  ///
  /// In he, this message translates to:
  /// **'בקשת תשלום'**
  String get notifSettlementRequestedTitle;

  /// No description provided for @notifSettlementConfirmedTitle.
  ///
  /// In he, this message translates to:
  /// **'תשלום אושר'**
  String get notifSettlementConfirmedTitle;

  /// No description provided for @notifMemberJoinedTitle.
  ///
  /// In he, this message translates to:
  /// **'חבר חדש'**
  String get notifMemberJoinedTitle;

  /// No description provided for @notifGeneralTitle.
  ///
  /// In he, this message translates to:
  /// **'התראה'**
  String get notifGeneralTitle;

  /// No description provided for @markAllRead.
  ///
  /// In he, this message translates to:
  /// **'סמן הכל כנקרא'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In he, this message translates to:
  /// **'אין התראות עדיין'**
  String get noNotifications;

  /// No description provided for @noNotificationsHint.
  ///
  /// In he, this message translates to:
  /// **'כשחברי הקבוצה יוסיפו הוצאות\nתקבל התראה כאן'**
  String get noNotificationsHint;

  /// No description provided for @errorLoadingNotifications.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בטעינת התראות'**
  String get errorLoadingNotifications;

  /// No description provided for @youLabel.
  ///
  /// In he, this message translates to:
  /// **'אתה'**
  String get youLabel;

  /// No description provided for @adminLabel.
  ///
  /// In he, this message translates to:
  /// **'מנהל'**
  String get adminLabel;

  /// No description provided for @removeMember.
  ///
  /// In he, this message translates to:
  /// **'הסר חבר'**
  String get removeMember;

  /// No description provided for @removeMemberTitle.
  ///
  /// In he, this message translates to:
  /// **'הסרת {name}'**
  String removeMemberTitle(String name);

  /// No description provided for @memberHasBalance.
  ///
  /// In he, this message translates to:
  /// **'ל{name} יש יתרה פתוחה של {amount}.\nכיצד לטפל?'**
  String memberHasBalance(String name, String amount);

  /// No description provided for @settleDebt.
  ///
  /// In he, this message translates to:
  /// **'מסדיר את החוב'**
  String get settleDebt;

  /// No description provided for @settleDebtDesc.
  ///
  /// In he, this message translates to:
  /// **'יתרה תאופס ותרשם כהסדרה'**
  String get settleDebtDesc;

  /// No description provided for @redistributeDebt.
  ///
  /// In he, this message translates to:
  /// **'חלק בין שאר החברים'**
  String get redistributeDebt;

  /// No description provided for @redistributeDebtDesc.
  ///
  /// In he, this message translates to:
  /// **'ההוצאות יחושבו מחדש'**
  String get redistributeDebtDesc;

  /// No description provided for @removeMemberConfirm.
  ///
  /// In he, this message translates to:
  /// **'להסיר את החבר מהקבוצה?'**
  String get removeMemberConfirm;

  /// No description provided for @remove.
  ///
  /// In he, this message translates to:
  /// **'הסר'**
  String get remove;

  /// No description provided for @memberRemovedSuccess.
  ///
  /// In he, this message translates to:
  /// **'{name} הוסר מהקבוצה'**
  String memberRemovedSuccess(String name);

  /// No description provided for @errorRemovingMember.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בהסרת החבר'**
  String get errorRemovingMember;

  /// No description provided for @extendGroupTitle.
  ///
  /// In he, this message translates to:
  /// **'הארכת הקבוצה'**
  String get extendGroupTitle;

  /// No description provided for @renewGroupTitle.
  ///
  /// In he, this message translates to:
  /// **'חידוש הקבוצה'**
  String get renewGroupTitle;

  /// No description provided for @activateGroupTitle.
  ///
  /// In he, this message translates to:
  /// **'הפעלת הקבוצה'**
  String get activateGroupTitle;

  /// No description provided for @paymentAmountLabel.
  ///
  /// In he, this message translates to:
  /// **'סכום לתשלום'**
  String get paymentAmountLabel;

  /// No description provided for @validityLabel.
  ///
  /// In he, this message translates to:
  /// **'תוקף'**
  String get validityLabel;

  /// No description provided for @participantsLabel.
  ///
  /// In he, this message translates to:
  /// **'משתתפים'**
  String get participantsLabel;

  /// No description provided for @howToRecordPayment.
  ///
  /// In he, this message translates to:
  /// **'כיצד לרשום את תשלום ההפעלה?'**
  String get howToRecordPayment;

  /// No description provided for @splitAmongAll.
  ///
  /// In he, this message translates to:
  /// **'חלק על כל חברי הקבוצה'**
  String get splitAmongAll;

  /// No description provided for @splitAmongAllDesc.
  ///
  /// In he, this message translates to:
  /// **'תשלום ההפעלה יתחלק בין כל המשתתפים'**
  String get splitAmongAllDesc;

  /// No description provided for @pay.
  ///
  /// In he, this message translates to:
  /// **'שלם'**
  String get pay;

  /// No description provided for @payAlone.
  ///
  /// In he, this message translates to:
  /// **'אני משלם לבד'**
  String get payAlone;

  /// No description provided for @payAloneDesc.
  ///
  /// In he, this message translates to:
  /// **'ההוצאה נרשמת רק עלי'**
  String get payAloneDesc;

  /// No description provided for @betaNoteActivation.
  ///
  /// In he, this message translates to:
  /// **'בשלב הביתא ההפעלה מתבצעת ידנית על ידי המנהל. תשלום ישיר יתווסף בגרסה הבאה.'**
  String get betaNoteActivation;

  /// No description provided for @extendedSuccess.
  ///
  /// In he, this message translates to:
  /// **'הקבוצה הוארכה בהצלחה 🎉'**
  String get extendedSuccess;

  /// No description provided for @renewedSuccess.
  ///
  /// In he, this message translates to:
  /// **'הקבוצה חודשה בהצלחה 🎉'**
  String get renewedSuccess;

  /// No description provided for @activatedSuccess.
  ///
  /// In he, this message translates to:
  /// **'הקבוצה הופעלה בהצלחה 🎉'**
  String get activatedSuccess;

  /// No description provided for @errorTryAgain.
  ///
  /// In he, this message translates to:
  /// **'שגיאה — נסה שוב'**
  String get errorTryAgain;

  /// No description provided for @extendBtnLabel.
  ///
  /// In he, this message translates to:
  /// **'הארך ב-7 ימים — {price} ₪'**
  String extendBtnLabel(int price);

  /// No description provided for @renewBtnLabel.
  ///
  /// In he, this message translates to:
  /// **'חדש לחודש — {price} ₪'**
  String renewBtnLabel(int price);

  /// No description provided for @activateBtnLabel.
  ///
  /// In he, this message translates to:
  /// **'הפעל קבוצה — {price} ₪'**
  String activateBtnLabel(int price);

  /// No description provided for @sevenDaysPlus.
  ///
  /// In he, this message translates to:
  /// **'+7 ימים'**
  String get sevenDaysPlus;

  /// No description provided for @thirtyDays.
  ///
  /// In he, this message translates to:
  /// **'30 יום'**
  String get thirtyDays;

  /// No description provided for @expenseHint.
  ///
  /// In he, this message translates to:
  /// **'לדוגמה: ארוחת ערב'**
  String get expenseHint;

  /// No description provided for @expenseTitleRequired.
  ///
  /// In he, this message translates to:
  /// **'נדרש תיאור'**
  String get expenseTitleRequired;

  /// No description provided for @notesHint.
  ///
  /// In he, this message translates to:
  /// **'הוסף הערה...'**
  String get notesHint;

  /// No description provided for @editExpense.
  ///
  /// In he, this message translates to:
  /// **'עריכת הוצאה'**
  String get editExpense;

  /// No description provided for @errorUpdatingExpense.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בעדכון ההוצאה'**
  String get errorUpdatingExpense;

  /// No description provided for @saveChanges.
  ///
  /// In he, this message translates to:
  /// **'שמור שינויים'**
  String get saveChanges;

  /// No description provided for @selectPaidBy.
  ///
  /// In he, this message translates to:
  /// **'בחר מי שילם'**
  String get selectPaidBy;

  /// No description provided for @loginBtn.
  ///
  /// In he, this message translates to:
  /// **'כניסה'**
  String get loginBtn;

  /// No description provided for @welcomeTitle.
  ///
  /// In he, this message translates to:
  /// **'ברוך הבא ל-ADL ShareFlow'**
  String get welcomeTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In he, this message translates to:
  /// **'כנס לחשבון שלך'**
  String get loginSubtitle;

  /// No description provided for @emailRequired.
  ///
  /// In he, this message translates to:
  /// **'נדרש אימייל'**
  String get emailRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In he, this message translates to:
  /// **'נדרשת סיסמה'**
  String get passwordRequired;

  /// No description provided for @wrongCredentials.
  ///
  /// In he, this message translates to:
  /// **'אימייל או סיסמה שגויים'**
  String get wrongCredentials;

  /// No description provided for @loginError.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בהתחברות, נסה שוב'**
  String get loginError;

  /// No description provided for @orDivider.
  ///
  /// In he, this message translates to:
  /// **'או'**
  String get orDivider;

  /// No description provided for @fullName.
  ///
  /// In he, this message translates to:
  /// **'שם מלא'**
  String get fullName;

  /// No description provided for @createAccount.
  ///
  /// In he, this message translates to:
  /// **'צור חשבון חדש'**
  String get createAccount;

  /// No description provided for @fillDetails.
  ///
  /// In he, this message translates to:
  /// **'מלא את הפרטים להמשך'**
  String get fillDetails;

  /// No description provided for @nameRequired.
  ///
  /// In he, this message translates to:
  /// **'נדרש שם'**
  String get nameRequired;

  /// No description provided for @nameTooShort.
  ///
  /// In he, this message translates to:
  /// **'שם חייב להיות לפחות 2 תווים'**
  String get nameTooShort;

  /// No description provided for @passwordHint.
  ///
  /// In he, this message translates to:
  /// **'סיסמה (מינימום 8 תווים)'**
  String get passwordHint;

  /// No description provided for @passwordTooShort.
  ///
  /// In he, this message translates to:
  /// **'סיסמה חייבת להיות לפחות 8 תווים'**
  String get passwordTooShort;

  /// No description provided for @passwordMismatch.
  ///
  /// In he, this message translates to:
  /// **'הסיסמאות אינן תואמות'**
  String get passwordMismatch;

  /// No description provided for @emailAlreadyRegistered.
  ///
  /// In he, this message translates to:
  /// **'אימייל זה כבר רשום'**
  String get emailAlreadyRegistered;

  /// No description provided for @registerError.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בהרשמה, נסה שוב'**
  String get registerError;

  /// No description provided for @calculating.
  ///
  /// In he, this message translates to:
  /// **'מחשב...'**
  String get calculating;

  /// No description provided for @exchangeRateLabel.
  ///
  /// In he, this message translates to:
  /// **'שער:'**
  String get exchangeRateLabel;

  /// No description provided for @eventSummary.
  ///
  /// In he, this message translates to:
  /// **'סיכום אירוע'**
  String get eventSummary;

  /// No description provided for @participants.
  ///
  /// In he, this message translates to:
  /// **'משתתפים'**
  String get participants;

  /// No description provided for @costPerParticipant.
  ///
  /// In he, this message translates to:
  /// **'עלות לכל משתתף'**
  String get costPerParticipant;

  /// No description provided for @requiredTransfers.
  ///
  /// In he, this message translates to:
  /// **'💸 העברות נדרשות'**
  String get requiredTransfers;

  /// No description provided for @allSettled.
  ///
  /// In he, this message translates to:
  /// **'הכל מסודר! אין העברות נדרשות'**
  String get allSettled;

  /// No description provided for @sendSummary.
  ///
  /// In he, this message translates to:
  /// **'📤 שלח סיכום'**
  String get sendSummary;

  /// No description provided for @sendPushToAll.
  ///
  /// In he, this message translates to:
  /// **'שלח התראה לכל החברים'**
  String get sendPushToAll;

  /// No description provided for @sendPushSubtitle.
  ///
  /// In he, this message translates to:
  /// **'Push notification לכל משתמשי הקבוצה'**
  String get sendPushSubtitle;

  /// No description provided for @shareViaWhatsApp.
  ///
  /// In he, this message translates to:
  /// **'שלח ב-WhatsApp'**
  String get shareViaWhatsApp;

  /// No description provided for @shareWhatsAppSubtitle.
  ///
  /// In he, this message translates to:
  /// **'פתח WhatsApp עם טקסט הסיכום'**
  String get shareWhatsAppSubtitle;

  /// No description provided for @reminderSent.
  ///
  /// In he, this message translates to:
  /// **'תזכורת נשלחה ל-{name} ✓'**
  String reminderSent(String name);

  /// No description provided for @errorSendingReminder.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בשליחת תזכורת'**
  String get errorSendingReminder;

  /// No description provided for @errorLoadingSummary.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בטעינת הסיכום'**
  String get errorLoadingSummary;

  /// No description provided for @notificationSentToAll.
  ///
  /// In he, this message translates to:
  /// **'התראה נשלחה לכל חברי הקבוצה ✓'**
  String get notificationSentToAll;

  /// No description provided for @errorSendingNotification.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בשליחת התראה'**
  String get errorSendingNotification;

  /// No description provided for @sendExpenseSplit.
  ///
  /// In he, this message translates to:
  /// **'הצטרף לקבוצה שלנו \"{groupName}\" ב-ADL ShareFlow!\nקוד הזמנה: {code}\nלינק: {link}'**
  String sendExpenseSplit(String groupName, String code, String link);

  /// No description provided for @freeGroupLimitReachedTitle.
  ///
  /// In he, this message translates to:
  /// **'הגעת למגבלת הקבוצות החינמיות'**
  String get freeGroupLimitReachedTitle;

  /// No description provided for @freeGroupLimitReachedBody.
  ///
  /// In he, this message translates to:
  /// **'ניתן ליצור עד 3 קבוצות ללא תשלום. הקבוצה נוצרה, אך כדי להתחיל לעבוד בה יש להפעיל אותה.'**
  String get freeGroupLimitReachedBody;

  /// No description provided for @activateGroupBtn.
  ///
  /// In he, this message translates to:
  /// **'הפעל קבוצה'**
  String get activateGroupBtn;

  /// No description provided for @laterBtn.
  ///
  /// In he, this message translates to:
  /// **'אחר כך'**
  String get laterBtn;

  /// No description provided for @comingSoon.
  ///
  /// In he, this message translates to:
  /// **'בקרוב'**
  String get comingSoon;

  /// No description provided for @settingsSaved.
  ///
  /// In he, this message translates to:
  /// **'הגדרות נשמרו ✓'**
  String get settingsSaved;

  /// No description provided for @settingsSaveError.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בשמירת ההגדרות'**
  String get settingsSaveError;

  /// No description provided for @enableReminders.
  ///
  /// In he, this message translates to:
  /// **'הפעל תזכורות אוטומטיות'**
  String get enableReminders;

  /// No description provided for @enableRemindersSubtitle.
  ///
  /// In he, this message translates to:
  /// **'קבל/שלח תזכורות על תשלומים פתוחים'**
  String get enableRemindersSubtitle;

  /// No description provided for @reminderFrequency.
  ///
  /// In he, this message translates to:
  /// **'תדירות שליחה'**
  String get reminderFrequency;

  /// No description provided for @reminderPlatforms.
  ///
  /// In he, this message translates to:
  /// **'פלטפורמות'**
  String get reminderPlatforms;

  /// No description provided for @inAppNotification.
  ///
  /// In he, this message translates to:
  /// **'התראה באפליקציה'**
  String get inAppNotification;

  /// No description provided for @whatsappMessage.
  ///
  /// In he, this message translates to:
  /// **'הודעה ישירה ב-WhatsApp'**
  String get whatsappMessage;

  /// No description provided for @reminderInfo.
  ///
  /// In he, this message translates to:
  /// **'תזכורות אוטומטיות יישלחו לחייבים עד שהתשלום יסומן כבוצע.'**
  String get reminderInfo;

  /// No description provided for @freqNone.
  ///
  /// In he, this message translates to:
  /// **'ללא'**
  String get freqNone;

  /// No description provided for @freqNoneDesc.
  ///
  /// In he, this message translates to:
  /// **'לא לשלוח תזכורות אוטומטיות'**
  String get freqNoneDesc;

  /// No description provided for @freqManual.
  ///
  /// In he, this message translates to:
  /// **'ידנית בלבד'**
  String get freqManual;

  /// No description provided for @freqManualDesc.
  ///
  /// In he, this message translates to:
  /// **'רק בלחיצת כפתור מהאפליקציה'**
  String get freqManualDesc;

  /// No description provided for @freqDaily.
  ///
  /// In he, this message translates to:
  /// **'כל יום'**
  String get freqDaily;

  /// No description provided for @freqDailyDesc.
  ///
  /// In he, this message translates to:
  /// **'שליחה יומית'**
  String get freqDailyDesc;

  /// No description provided for @freqEvery2Days.
  ///
  /// In he, this message translates to:
  /// **'כל יומיים'**
  String get freqEvery2Days;

  /// No description provided for @freqEvery2DaysDesc.
  ///
  /// In he, this message translates to:
  /// **'שליחה כל יומיים'**
  String get freqEvery2DaysDesc;

  /// No description provided for @freqWeekly.
  ///
  /// In he, this message translates to:
  /// **'שבועי'**
  String get freqWeekly;

  /// No description provided for @freqWeeklyDesc.
  ///
  /// In he, this message translates to:
  /// **'פעם בשבוע'**
  String get freqWeeklyDesc;

  /// No description provided for @freqBiweekly.
  ///
  /// In he, this message translates to:
  /// **'דו-שבועי'**
  String get freqBiweekly;

  /// No description provided for @freqBiweeklyDesc.
  ///
  /// In he, this message translates to:
  /// **'פעם בשבועיים'**
  String get freqBiweeklyDesc;

  /// No description provided for @paymentDetailsSaved.
  ///
  /// In he, this message translates to:
  /// **'פרטי התשלום עודכנו ✓'**
  String get paymentDetailsSaved;

  /// No description provided for @paymentDetailsSaveError.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בשמירת הפרטים'**
  String get paymentDetailsSaveError;

  /// No description provided for @bitPayboxSubtitle.
  ///
  /// In he, this message translates to:
  /// **'מספר טלפון לקבלת תשלום'**
  String get bitPayboxSubtitle;

  /// No description provided for @bankTransfer.
  ///
  /// In he, this message translates to:
  /// **'העברה בנקאית'**
  String get bankTransfer;

  /// No description provided for @bankTransferSubtitle.
  ///
  /// In he, this message translates to:
  /// **'פרטי חשבון בנק לקבלת העברות'**
  String get bankTransferSubtitle;

  /// No description provided for @saveDetails.
  ///
  /// In he, this message translates to:
  /// **'שמור פרטים'**
  String get saveDetails;

  /// No description provided for @bankNameHint.
  ///
  /// In he, this message translates to:
  /// **'שם הבנק (לדוגמה: הפועלים)'**
  String get bankNameHint;

  /// No description provided for @bankBranchHint.
  ///
  /// In he, this message translates to:
  /// **'סניף'**
  String get bankBranchHint;

  /// No description provided for @bankAccountHint.
  ///
  /// In he, this message translates to:
  /// **'מספר חשבון'**
  String get bankAccountHint;

  /// No description provided for @paymentPrivacyNote.
  ///
  /// In he, this message translates to:
  /// **'הפרטים מוצגים לחברי הקבוצה בלבד לצורך הסדרת חובות'**
  String get paymentPrivacyNote;

  /// No description provided for @cannotOpenApp.
  ///
  /// In he, this message translates to:
  /// **'לא ניתן לפתוח את האפליקציה'**
  String get cannotOpenApp;

  /// No description provided for @errorOpeningApp.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בפתיחת האפליקציה'**
  String get errorOpeningApp;

  /// No description provided for @sendPayment.
  ///
  /// In he, this message translates to:
  /// **'שלח תשלום'**
  String get sendPayment;

  /// No description provided for @payTo.
  ///
  /// In he, this message translates to:
  /// **'לתשלום ל{name}'**
  String payTo(String name);

  /// No description provided for @choosePaymentMethod.
  ///
  /// In he, this message translates to:
  /// **'בחר אמצעי תשלום'**
  String get choosePaymentMethod;

  /// No description provided for @noPaymentDetails.
  ///
  /// In he, this message translates to:
  /// **'המקבל עדיין לא הגדיר פרטי תשלום.'**
  String get noPaymentDetails;

  /// No description provided for @noPaymentDetailsHint.
  ///
  /// In he, this message translates to:
  /// **'בקש ממנו להוסיף מספר טלפון לBit/PayBox או פרטי בנק בפרופיל שלו.'**
  String get noPaymentDetailsHint;

  /// No description provided for @copyAll.
  ///
  /// In he, this message translates to:
  /// **'העתק הכל'**
  String get copyAll;

  /// No description provided for @bankDetailsCopied.
  ///
  /// In he, this message translates to:
  /// **'פרטי הבנק הועתקו'**
  String get bankDetailsCopied;

  /// No description provided for @bankLabel.
  ///
  /// In he, this message translates to:
  /// **'בנק'**
  String get bankLabel;

  /// No description provided for @branchLabel.
  ///
  /// In he, this message translates to:
  /// **'סניף'**
  String get branchLabel;

  /// No description provided for @accountLabel.
  ///
  /// In he, this message translates to:
  /// **'חשבון'**
  String get accountLabel;

  /// No description provided for @amountLabel.
  ///
  /// In he, this message translates to:
  /// **'סכום'**
  String get amountLabel;

  /// No description provided for @forCredit.
  ///
  /// In he, this message translates to:
  /// **'לזכות'**
  String get forCredit;

  /// No description provided for @pickFromGallery.
  ///
  /// In he, this message translates to:
  /// **'בחר מהגלריה'**
  String get pickFromGallery;

  /// No description provided for @takePhoto.
  ///
  /// In he, this message translates to:
  /// **'צלם קבלה'**
  String get takePhoto;

  /// No description provided for @sendReminderTo.
  ///
  /// In he, this message translates to:
  /// **'שלח תזכורת ל{name}'**
  String sendReminderTo(String name);

  /// No description provided for @qrCodeTitle.
  ///
  /// In he, this message translates to:
  /// **'קוד QR'**
  String get qrCodeTitle;

  /// No description provided for @qrCodeSubtitle.
  ///
  /// In he, this message translates to:
  /// **'הראה לחבר לסרוק'**
  String get qrCodeSubtitle;

  /// No description provided for @scanQrCode.
  ///
  /// In he, this message translates to:
  /// **'סרוק QR'**
  String get scanQrCode;

  /// No description provided for @scanQrSubtitle.
  ///
  /// In he, this message translates to:
  /// **'כוון את המצלמה לקוד QR של הקבוצה'**
  String get scanQrSubtitle;

  /// No description provided for @qrScanSuccess.
  ///
  /// In he, this message translates to:
  /// **'קוד נסרק בהצלחה!'**
  String get qrScanSuccess;

  /// No description provided for @qrScanError.
  ///
  /// In he, this message translates to:
  /// **'לא ניתן לקרוא את קוד ה-QR'**
  String get qrScanError;

  /// No description provided for @noCameraPermission.
  ///
  /// In he, this message translates to:
  /// **'נדרשת הרשאת מצלמה'**
  String get noCameraPermission;

  /// No description provided for @openSettings.
  ///
  /// In he, this message translates to:
  /// **'פתח הגדרות'**
  String get openSettings;

  /// No description provided for @showQrCode.
  ///
  /// In he, this message translates to:
  /// **'הצג QR'**
  String get showQrCode;

  /// No description provided for @aboutTitle.
  ///
  /// In he, this message translates to:
  /// **'אודות ADL ShareFlow'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In he, this message translates to:
  /// **'גרסה {version}'**
  String aboutVersion(String version);

  /// No description provided for @contactUs.
  ///
  /// In he, this message translates to:
  /// **'צור קשר'**
  String get contactUs;

  /// No description provided for @contactSubtitle.
  ///
  /// In he, this message translates to:
  /// **'שאלות, בעיות וכל שאר'**
  String get contactSubtitle;

  /// No description provided for @adlProjects.
  ///
  /// In he, this message translates to:
  /// **'ADL Projects'**
  String get adlProjects;

  /// No description provided for @adlProjectsSubtitle.
  ///
  /// In he, this message translates to:
  /// **'עוד פרויקטים של ADL'**
  String get adlProjectsSubtitle;

  /// No description provided for @suggestions.
  ///
  /// In he, this message translates to:
  /// **'הצעות ושיפורים'**
  String get suggestions;

  /// No description provided for @suggestionsSubtitle.
  ///
  /// In he, this message translates to:
  /// **'ספר לנו מה אפשר לשפר'**
  String get suggestionsSubtitle;

  /// No description provided for @proPlanTitle.
  ///
  /// In he, this message translates to:
  /// **'תוכנית Pro'**
  String get proPlanTitle;

  /// No description provided for @proPlanSubtitle.
  ///
  /// In he, this message translates to:
  /// **'בקרוב — ניתוחים, סטטיסטיקות ועוד'**
  String get proPlanSubtitle;

  /// No description provided for @appSection.
  ///
  /// In he, this message translates to:
  /// **'אפליקציה'**
  String get appSection;

  /// No description provided for @paymentMethodSubtitle.
  ///
  /// In he, this message translates to:
  /// **'Bit, PayBox, העברה בנקאית'**
  String get paymentMethodSubtitle;

  /// No description provided for @pricingSection.
  ///
  /// In he, this message translates to:
  /// **'תמחור'**
  String get pricingSection;

  /// No description provided for @estimatedCost.
  ///
  /// In he, this message translates to:
  /// **'עלות משוערת'**
  String get estimatedCost;

  /// No description provided for @upToParticipants.
  ///
  /// In he, this message translates to:
  /// **'עד {count} חברים'**
  String upToParticipants(int count);

  /// No description provided for @aboveParticipants.
  ///
  /// In he, this message translates to:
  /// **'{count}+ חברים'**
  String aboveParticipants(int count);

  /// No description provided for @freeTierLabel.
  ///
  /// In he, this message translates to:
  /// **'חינם — עד 3 חברים'**
  String get freeTierLabel;

  /// No description provided for @freeIncluded.
  ///
  /// In he, this message translates to:
  /// **'חינמי: עד 3 חברים ו-5 ימים'**
  String get freeIncluded;

  /// No description provided for @createGroupFree.
  ///
  /// In he, this message translates to:
  /// **'צור קבוצה — חינם'**
  String get createGroupFree;

  /// No description provided for @createGroupPaid.
  ///
  /// In he, this message translates to:
  /// **'צור קבוצה — {price} ₪'**
  String createGroupPaid(int price);

  /// No description provided for @durationDays.
  ///
  /// In he, this message translates to:
  /// **'{days} ימים'**
  String durationDays(int days);

  /// No description provided for @durationMonth.
  ///
  /// In he, this message translates to:
  /// **'חודש'**
  String get durationMonth;

  /// No description provided for @tierUpgradeRequired.
  ///
  /// In he, this message translates to:
  /// **'נדרש שדרוג תוכנית'**
  String get tierUpgradeRequired;

  /// No description provided for @tierUpgradeSubtitle.
  ///
  /// In he, this message translates to:
  /// **'הקבוצה גדלה — נדרש תשלום של {price} ₪ לשדרוג'**
  String tierUpgradeSubtitle(int price);

  /// No description provided for @tierUpgradeBtn.
  ///
  /// In he, this message translates to:
  /// **'שדרג עכשיו'**
  String get tierUpgradeBtn;

  /// No description provided for @upgradeTierTitle.
  ///
  /// In he, this message translates to:
  /// **'שדרוג תוכנית'**
  String get upgradeTierTitle;

  /// No description provided for @upgradeTierDesc.
  ///
  /// In he, this message translates to:
  /// **'מספר המשתתפים עלה לרמה גבוהה יותר. יש לשלם את ההפרש כדי להמשיך.'**
  String get upgradeTierDesc;

  /// No description provided for @upgradeBtnLabel.
  ///
  /// In he, this message translates to:
  /// **'שדרג — {price} ₪'**
  String upgradeBtnLabel(int price);

  /// No description provided for @upgradedSuccess.
  ///
  /// In he, this message translates to:
  /// **'התוכנית שודרגה בהצלחה 🎉'**
  String get upgradedSuccess;

  /// No description provided for @errorUpgradingTier.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בשדרוג התוכנית'**
  String get errorUpgradingTier;

  /// No description provided for @periodicSettlement.
  ///
  /// In he, this message translates to:
  /// **'התחשבנות תקופית'**
  String get periodicSettlement;

  /// No description provided for @manualSettlement.
  ///
  /// In he, this message translates to:
  /// **'ידנית / אקראית'**
  String get manualSettlement;

  /// No description provided for @manualSettlementDesc.
  ///
  /// In he, this message translates to:
  /// **'סוגרים חשבון כשרוצים'**
  String get manualSettlementDesc;

  /// No description provided for @automaticPeriodic.
  ///
  /// In he, this message translates to:
  /// **'תקופתית אוטומטית'**
  String get automaticPeriodic;

  /// No description provided for @automaticPeriodicDesc.
  ///
  /// In he, this message translates to:
  /// **'דוח נשלח אוטומטית וניתן לסמן חובות כשולמו'**
  String get automaticPeriodicDesc;

  /// No description provided for @settlementFrequency.
  ///
  /// In he, this message translates to:
  /// **'תדירות התחשבנות'**
  String get settlementFrequency;

  /// No description provided for @periodWeekly.
  ///
  /// In he, this message translates to:
  /// **'שבועי'**
  String get periodWeekly;

  /// No description provided for @periodBiweekly.
  ///
  /// In he, this message translates to:
  /// **'דו-שבועי'**
  String get periodBiweekly;

  /// No description provided for @periodMonthly.
  ///
  /// In he, this message translates to:
  /// **'חודשי'**
  String get periodMonthly;

  /// No description provided for @periodBimonthly.
  ///
  /// In he, this message translates to:
  /// **'דו-חודשי'**
  String get periodBimonthly;

  /// No description provided for @periodQuarterly.
  ///
  /// In he, this message translates to:
  /// **'רבעוני'**
  String get periodQuarterly;

  /// No description provided for @periodSemiannual.
  ///
  /// In he, this message translates to:
  /// **'חצי-שנתי'**
  String get periodSemiannual;

  /// No description provided for @periodAnnual.
  ///
  /// In he, this message translates to:
  /// **'שנתי'**
  String get periodAnnual;

  /// No description provided for @settlePeriodBtn.
  ///
  /// In he, this message translates to:
  /// **'סכם תקופה'**
  String get settlePeriodBtn;

  /// No description provided for @settlePeriodNext.
  ///
  /// In he, this message translates to:
  /// **'הבא: {date}'**
  String settlePeriodNext(String date);

  /// No description provided for @settlePeriodCreateReport.
  ///
  /// In he, this message translates to:
  /// **'סגור תקופה וצור דוח'**
  String get settlePeriodCreateReport;

  /// No description provided for @settlePeriodDialogTitle.
  ///
  /// In he, this message translates to:
  /// **'סיכום תקופה'**
  String get settlePeriodDialogTitle;

  /// No description provided for @settlePeriodConfirmMsg.
  ///
  /// In he, this message translates to:
  /// **'האם לסכם את התקופה הנוכחית?\n\nדוח יישלח לכל חברי הקבוצה והתקופה תתאפס.'**
  String get settlePeriodConfirmMsg;

  /// No description provided for @settlePeriodSuccess.
  ///
  /// In he, this message translates to:
  /// **'התקופה סוכמה בהצלחה! דוח נשלח לחברי הקבוצה'**
  String get settlePeriodSuccess;

  /// No description provided for @errorSettlingPeriod.
  ///
  /// In he, this message translates to:
  /// **'שגיאה בסיכום תקופה'**
  String get errorSettlingPeriod;

  /// No description provided for @previousPeriodReports.
  ///
  /// In he, this message translates to:
  /// **'דוחות תקופות קודמות'**
  String get previousPeriodReports;

  /// No description provided for @periodLabel.
  ///
  /// In he, this message translates to:
  /// **'תקופה #{number}'**
  String periodLabel(int number);

  /// No description provided for @allDebtsPaid.
  ///
  /// In he, this message translates to:
  /// **'כל החובות שולמו ✓'**
  String get allDebtsPaid;

  /// No description provided for @openDebtsCount.
  ///
  /// In he, this message translates to:
  /// **'{count} חובות פתוחים'**
  String openDebtsCount(int count);

  /// No description provided for @openDebtCount.
  ///
  /// In he, this message translates to:
  /// **'חוב פתוח 1'**
  String get openDebtCount;

  /// No description provided for @noDebtsBalanced.
  ///
  /// In he, this message translates to:
  /// **'כל החשבונות מאוזנים — אין חובות'**
  String get noDebtsBalanced;

  /// No description provided for @markAsPaid.
  ///
  /// In he, this message translates to:
  /// **'שולם ✓'**
  String get markAsPaid;

  /// No description provided for @currentPeriodExpenses.
  ///
  /// In he, this message translates to:
  /// **'הוצאות תקופה נוכחית'**
  String get currentPeriodExpenses;

  /// No description provided for @periodSince.
  ///
  /// In he, this message translates to:
  /// **'מתאריך {date}'**
  String periodSince(String date);

  /// No description provided for @openDebtsGroupClosed.
  ///
  /// In he, this message translates to:
  /// **'חובות פתוחים — הקבוצה סגורה'**
  String get openDebtsGroupClosed;

  /// No description provided for @groupClosedUnpaidDebts.
  ///
  /// In he, this message translates to:
  /// **'הקבוצה סגורה אך יש חובות שטרם שולמו'**
  String get groupClosedUnpaidDebts;

  /// No description provided for @requiredTransfersTitle.
  ///
  /// In he, this message translates to:
  /// **'העברות נדרשות'**
  String get requiredTransfersTitle;

  /// No description provided for @transferNeeded.
  ///
  /// In he, this message translates to:
  /// **'{from} צריך להעביר ל-{to}'**
  String transferNeeded(String from, String to);

  /// No description provided for @deleteGroup.
  ///
  /// In he, this message translates to:
  /// **'מחק קבוצה'**
  String get deleteGroup;

  /// No description provided for @deleteGroupDialogTitle.
  ///
  /// In he, this message translates to:
  /// **'מחיקת קבוצה'**
  String get deleteGroupDialogTitle;

  /// No description provided for @deleteGroupConfirm.
  ///
  /// In he, this message translates to:
  /// **'האם למחוק לצמיתות את הקבוצה \"{name}\"?\n\nכל ההוצאות, היתרות וההיסטוריה יימחקו ולא ניתן יהיה לשחזרם.'**
  String deleteGroupConfirm(String name);

  /// No description provided for @deleteGroupPermanently.
  ///
  /// In he, this message translates to:
  /// **'מחק לצמיתות'**
  String get deleteGroupPermanently;

  /// No description provided for @groupDeletedSuccess.
  ///
  /// In he, this message translates to:
  /// **'הקבוצה נמחקה בהצלחה'**
  String get groupDeletedSuccess;

  /// No description provided for @errorDeletingGroup.
  ///
  /// In he, this message translates to:
  /// **'שגיאה במחיקת הקבוצה'**
  String get errorDeletingGroup;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
