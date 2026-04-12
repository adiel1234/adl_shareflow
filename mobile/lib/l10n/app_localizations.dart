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
  /// **'ShareFlow'**
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
  /// **'יתרות'**
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
