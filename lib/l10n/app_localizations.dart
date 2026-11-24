import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('id'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Bulk DL'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get navQueue;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @disclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'Bulk DL is only a download tool. Download only content you have the right to keep, and follow the law and each site\'s terms. You are responsible for your use and for copyright. DRM-protected content is not supported.'**
  String get disclaimerBody;

  /// No description provided for @disclaimerOk.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get disclaimerOk;

  /// No description provided for @homeIntro.
  ///
  /// In en, this message translates to:
  /// **'Download files, videos, or whole playlists from any link.'**
  String get homeIntro;

  /// No description provided for @linkLabel.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get linkLabel;

  /// No description provided for @linkHint.
  ///
  /// In en, this message translates to:
  /// **'https://...  (several allowed, one per line)'**
  String get linkHint;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @modeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get modeAuto;

  /// No description provided for @modeSingle.
  ///
  /// In en, this message translates to:
  /// **'Single'**
  String get modeSingle;

  /// No description provided for @modePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get modePlaylist;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @analyzeAndDownload.
  ///
  /// In en, this message translates to:
  /// **'Analyze & download'**
  String get analyzeAndDownload;

  /// No description provided for @viewVideos.
  ///
  /// In en, this message translates to:
  /// **'View {count} videos'**
  String viewVideos(int count);

  /// No description provided for @maxQuality.
  ///
  /// In en, this message translates to:
  /// **'Maximum quality'**
  String get maxQuality;

  /// No description provided for @recentTitle.
  ///
  /// In en, this message translates to:
  /// **'Recently used'**
  String get recentTitle;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @msgPasteLink.
  ///
  /// In en, this message translates to:
  /// **'Paste a link starting with http:// or https://'**
  String get msgPasteLink;

  /// No description provided for @msgAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing {count} links...'**
  String msgAnalyzing(int count);

  /// No description provided for @msgFound.
  ///
  /// In en, this message translates to:
  /// **'{count} videos found...'**
  String msgFound(int count);

  /// No description provided for @msgIsPlaylist.
  ///
  /// In en, this message translates to:
  /// **'This link is a playlist — choose Auto or Playlist mode'**
  String get msgIsPlaylist;

  /// No description provided for @msgVideoCount.
  ///
  /// In en, this message translates to:
  /// **'{count} videos'**
  String msgVideoCount(int count);

  /// No description provided for @msgQueued.
  ///
  /// In en, this message translates to:
  /// **'{count} added to queue'**
  String msgQueued(int count);

  /// No description provided for @msgNothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get msgNothingFound;

  /// No description provided for @sizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'size unknown'**
  String get sizeUnknown;

  /// No description provided for @noLink.
  ///
  /// In en, this message translates to:
  /// **'no link'**
  String get noLink;

  /// No description provided for @downloadN.
  ///
  /// In en, this message translates to:
  /// **'Download {count}'**
  String downloadN(int count);

  /// No description provided for @downloadNSize.
  ///
  /// In en, this message translates to:
  /// **'Download {count} · {size}'**
  String downloadNSize(int count, String size);

  /// No description provided for @downloadNSizeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Download {count} · {size} (+{unknown} ?)'**
  String downloadNSizeUnknown(int count, String size, int unknown);

  /// No description provided for @downloadNUnknown.
  ///
  /// In en, this message translates to:
  /// **'Download {count} (+{unknown} ?)'**
  String downloadNUnknown(int count, int unknown);

  /// No description provided for @bgStatus.
  ///
  /// In en, this message translates to:
  /// **'{active} downloading, {waiting} waiting · {percent}%{extra}'**
  String bgStatus(int active, int waiting, String percent, String extra);

  /// No description provided for @pickerCalcSizes.
  ///
  /// In en, this message translates to:
  /// **'Calculate size'**
  String get pickerCalcSizes;

  /// No description provided for @pickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search title'**
  String get pickerSearch;

  /// No description provided for @pickerAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get pickerAll;

  /// No description provided for @pickerNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get pickerNone;

  /// No description provided for @pickerSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String pickerSelected(int count);

  /// No description provided for @alreadyDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Already downloaded'**
  String get alreadyDownloaded;

  /// No description provided for @queueTitle.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queueTitle;

  /// No description provided for @queueClearFinished.
  ///
  /// In en, this message translates to:
  /// **'Clear finished'**
  String get queueClearFinished;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queueEmpty;

  /// No description provided for @queueAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get queueAdd;

  /// No description provided for @queueCounts.
  ///
  /// In en, this message translates to:
  /// **'{active} downloading · {waiting} waiting'**
  String queueCounts(int active, int waiting);

  /// No description provided for @queuePausedWifi.
  ///
  /// In en, this message translates to:
  /// **'Paused: waiting for Wi-Fi'**
  String get queuePausedWifi;

  /// No description provided for @taskWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get taskWaiting;

  /// No description provided for @taskPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get taskPreparing;

  /// No description provided for @taskDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskDone;

  /// No description provided for @taskFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String taskFailed(String error);

  /// No description provided for @taskCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get taskCanceled;

  /// No description provided for @taskCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get taskCancel;

  /// No description provided for @taskRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get taskRetry;

  /// No description provided for @taskOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get taskOpen;

  /// No description provided for @taskShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get taskShare;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get settingsDownloads;

  /// No description provided for @settingsParallel.
  ///
  /// In en, this message translates to:
  /// **'Parallel downloads'**
  String get settingsParallel;

  /// No description provided for @settingsWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only'**
  String get settingsWifiOnly;

  /// No description provided for @settingsWifiOnlySub.
  ///
  /// In en, this message translates to:
  /// **'Pause downloads on mobile data'**
  String get settingsWifiOnlySub;

  /// No description provided for @settingsSaveLocation.
  ///
  /// In en, this message translates to:
  /// **'Save location'**
  String get settingsSaveLocation;

  /// No description provided for @settingsSaveLocationSub.
  ///
  /// In en, this message translates to:
  /// **'Movies / Music / Pictures / Download → BulkDL folder'**
  String get settingsSaveLocationSub;

  /// No description provided for @settingsNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settingsNetwork;

  /// No description provided for @settingsDns.
  ///
  /// In en, this message translates to:
  /// **'DNS'**
  String get settingsDns;

  /// No description provided for @settingsCookies.
  ///
  /// In en, this message translates to:
  /// **'Login cookie per site'**
  String get settingsCookies;

  /// No description provided for @settingsCookiesNone.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get settingsCookiesNone;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsDynamic.
  ///
  /// In en, this message translates to:
  /// **'Dynamic color'**
  String get settingsDynamic;

  /// No description provided for @settingsDynamicSub.
  ///
  /// In en, this message translates to:
  /// **'Follow wallpaper colors (Android 12+). Off = default green'**
  String get settingsDynamicSub;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get langSystem;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Indonesia'**
  String get langIndonesian;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @aboutText.
  ///
  /// In en, this message translates to:
  /// **'Download only content you have the right to keep. You are responsible for your use and for copyright.'**
  String get aboutText;

  /// No description provided for @dnsHelp.
  ///
  /// In en, this message translates to:
  /// **'DNS-over-HTTPS helps when your ISP blocks sites via DNS. It cannot bypass IP/SNI blocks.'**
  String get dnsHelp;

  /// No description provided for @dnsTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get dnsTesting;

  /// No description provided for @dnsOk.
  ///
  /// In en, this message translates to:
  /// **'OK via {provider}: {ip}'**
  String dnsOk(String provider, String ip);

  /// No description provided for @dnsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String dnsFailed(String error);

  /// No description provided for @cookieTitle.
  ///
  /// In en, this message translates to:
  /// **'Login cookie'**
  String get cookieTitle;

  /// No description provided for @cookieHelp.
  ///
  /// In en, this message translates to:
  /// **'Paste the Cookie header from a logged-in browser so HD links open. Stored only on this device and sent only to that site.'**
  String get cookieHelp;

  /// No description provided for @cookieHost.
  ///
  /// In en, this message translates to:
  /// **'Host (e.g. www.site.com)'**
  String get cookieHost;

  /// No description provided for @cookieLabel.
  ///
  /// In en, this message translates to:
  /// **'Cookie'**
  String get cookieLabel;
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
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
