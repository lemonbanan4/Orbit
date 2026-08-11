import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
    Locale('es'),
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @editProfileHeader.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileHeader;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayNameLabel;

  /// No description provided for @saveChangesButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChangesButton;

  /// No description provided for @enableConfetti.
  ///
  /// In en, this message translates to:
  /// **'Enable Confetti'**
  String get enableConfetti;

  /// No description provided for @soundEffectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sound Effects'**
  String get soundEffectsTitle;

  /// No description provided for @soundEffectsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play a chime when you complete a habit.'**
  String get soundEffectsSubtitle;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @accountHeader.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountHeader;

  /// No description provided for @nebulaThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Nebula Theme'**
  String get nebulaThemeTitle;

  /// No description provided for @focusInterestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Focus Interests'**
  String get focusInterestsTitle;

  /// No description provided for @focusInterestsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Steer your Daily Wisdom and AI coaching'**
  String get focusInterestsSubtitle;

  /// No description provided for @habitWidgetTitle.
  ///
  /// In en, this message translates to:
  /// **'Habit Widget'**
  String get habitWidgetTitle;

  /// No description provided for @habitWidgetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pin a habit to your home screen'**
  String get habitWidgetSubtitle;

  /// No description provided for @nebulaForgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Nebula Forge Analytics'**
  String get nebulaForgeTitle;

  /// No description provided for @proBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get proBadge;

  /// No description provided for @enableAllNotifsTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable All Notifications'**
  String get enableAllNotifsTitle;

  /// No description provided for @enableAllNotifsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Temporarily pause or resume All Orbit reminders.'**
  String get enableAllNotifsSubtitle;

  /// No description provided for @eveningSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Evening Summary'**
  String get eveningSummaryTitle;

  /// No description provided for @eveningSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get a daily digest of your completed habits.'**
  String get eveningSummarySubtitle;

  /// No description provided for @morningRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Morning Routine Reminders'**
  String get morningRemindersTitle;

  /// No description provided for @morningRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alarm reminders for your Morning routine.'**
  String get morningRemindersSubtitle;

  /// No description provided for @nightRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Night Routine Reminders'**
  String get nightRemindersTitle;

  /// No description provided for @nightRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Alarm reminders for your Night routine.'**
  String get nightRemindersSubtitle;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @manageSubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get manageSubscriptionTitle;

  /// No description provided for @manageSubscriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View, change, or cancel your Orbit Pro plan'**
  String get manageSubscriptionSubtitle;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutTitle;

  /// No description provided for @myDataHeader.
  ///
  /// In en, this message translates to:
  /// **'My Data'**
  String get myDataHeader;

  /// No description provided for @exportDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Export My Data'**
  String get exportDataTitle;

  /// No description provided for @exportDataPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing export...'**
  String get exportDataPreparing;

  /// No description provided for @exportDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Habit history, mood log, and intentions as CSVs'**
  String get exportDataSubtitle;

  /// No description provided for @spreadWordHeader.
  ///
  /// In en, this message translates to:
  /// **'Spread the Word'**
  String get spreadWordHeader;

  /// No description provided for @referFriendTitle.
  ///
  /// In en, this message translates to:
  /// **'Refer a Friend'**
  String get referFriendTitle;

  /// No description provided for @referFriendSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Give 30 Days Pro, Get 30 Days Pro'**
  String get referFriendSubtitle;

  /// No description provided for @redeemCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem Code'**
  String get redeemCodeTitle;

  /// No description provided for @reviewOrbitTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Orbit'**
  String get reviewOrbitTitle;

  /// No description provided for @reviewOrbitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us grow by leaving a review'**
  String get reviewOrbitSubtitle;

  /// No description provided for @contactSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupportTitle;

  /// No description provided for @contactSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Need help or have feedback?'**
  String get contactSupportSubtitle;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @redeemButton.
  ///
  /// In en, this message translates to:
  /// **'Redeem'**
  String get redeemButton;

  /// No description provided for @sendButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendButton;

  /// No description provided for @deleteAccountDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountDialogTitle;

  /// No description provided for @deleteAccountDialogContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to permanently delete your account? This action cannot be undone and will erase all your progress.'**
  String get deleteAccountDialogContent;

  /// No description provided for @redeemDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Redeem Invite Code'**
  String get redeemDialogTitle;

  /// No description provided for @redeemCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get redeemCodeHint;

  /// No description provided for @contactSupportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupportDialogTitle;

  /// No description provided for @contactSupportHint.
  ///
  /// In en, this message translates to:
  /// **'How can we help you?'**
  String get contactSupportHint;

  /// No description provided for @profileUpdatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedMessage;

  /// No description provided for @supportRequestSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Support request sent successfully!'**
  String get supportRequestSentMessage;

  /// No description provided for @redeemSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Success! You and your friend both got 30 days of Orbit Pro! 🎉'**
  String get redeemSuccessMessage;

  /// No description provided for @noDataToExportMessage.
  ///
  /// In en, this message translates to:
  /// **'No data yet to export — check back after your first daily reset.'**
  String get noDataToExportMessage;

  /// No description provided for @thankYouReviewMessage.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your support! 🌟'**
  String get thankYouReviewMessage;
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
