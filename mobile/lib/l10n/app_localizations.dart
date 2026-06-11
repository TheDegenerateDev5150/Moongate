import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

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
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('pl'),
    Locale('ru'),
    Locale('zh')
  ];

  /// The application name.
  ///
  /// In en, this message translates to:
  /// **'Moongate'**
  String get appTitle;

  /// Title of the first-run language selection prompt.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languagePickerTitle;

  /// Supporting text under the first-run language picker title.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time from the menu.'**
  String get languagePickerSubtitle;

  /// Button that confirms the selected language and closes the picker.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get languagePickerContinue;

  /// Drawer menu item that reopens the language picker.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get menuLanguage;

  /// Language option that follows the device's system language.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystemDefault;

  /// Generic Cancel button label, reused across dialogs.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Generic OK / acknowledge button label.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Generic Close button label.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Generic Save button label.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Generic Done button label.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Generic Retry button label.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Generic Remove button label.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// Generic Delete button label.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Generic Enable button label.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get commonEnable;

  /// Generic Disable button label.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get commonDisable;

  /// Title of the Settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Destructive action that clears every paired printer from this device.
  ///
  /// In en, this message translates to:
  /// **'Remove all printers from this device'**
  String get settingsRemoveAllTitle;

  /// Explains what the 'remove all printers' action does and does not delete.
  ///
  /// In en, this message translates to:
  /// **'Clears the local printer cache. Your Supabase account is kept so re-pairing works seamlessly.'**
  String get settingsRemoveAllSubtitle;

  /// Confirmation dialog title before removing all printers.
  ///
  /// In en, this message translates to:
  /// **'Remove all printers?'**
  String get settingsRemoveAllConfirmTitle;

  /// Confirmation dialog body. 'MOONGATE_PAIR' is a literal command name and must not be translated.
  ///
  /// In en, this message translates to:
  /// **'All paired printers will be removed from this device. You can re-add them by running MOONGATE_PAIR on the printer.'**
  String get settingsRemoveAllConfirmBody;

  /// Confirm button that removes all printers.
  ///
  /// In en, this message translates to:
  /// **'Remove all'**
  String get settingsRemoveAllConfirmAction;

  /// Drawer item, FAB tooltip, and empty-state button to start pairing a printer.
  ///
  /// In en, this message translates to:
  /// **'Add printer'**
  String get dashboardAddPrinter;

  /// Drawer item that opens the remove-a-printer sheet.
  ///
  /// In en, this message translates to:
  /// **'Remove printer'**
  String get dashboardRemovePrinter;

  /// Tooltip for the app bar button that opens the navigation drawer.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get dashboardMenuTooltip;

  /// Title of the confirm-removal dialog.
  ///
  /// In en, this message translates to:
  /// **'Remove printer?'**
  String get dashboardRemovePrinterTitle;

  /// Body of the confirm-removal dialog, naming the printer.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{name}\" from Moongate?'**
  String dashboardRemovePrinterBody(String name);

  /// Snackbar when a printer was removed locally but the cloud row could not be released.
  ///
  /// In en, this message translates to:
  /// **'Removed locally, but couldn’t reach Supabase. Run MOONGATE_RESET_OWNER on the Pi if re-pairing fails.'**
  String get dashboardRemoveSupabaseUnreachable;

  /// Drawer item to export the printer list to a file.
  ///
  /// In en, this message translates to:
  /// **'Back up config'**
  String get dashboardBackUpConfig;

  /// Subtitle for the back-up-config drawer item.
  ///
  /// In en, this message translates to:
  /// **'Save to a file before reinstalling'**
  String get dashboardBackUpConfigSubtitle;

  /// Drawer item to import a printer list from a backup file.
  ///
  /// In en, this message translates to:
  /// **'Restore config'**
  String get dashboardRestoreConfig;

  /// Subtitle for the restore-config drawer item.
  ///
  /// In en, this message translates to:
  /// **'Load from a backup file'**
  String get dashboardRestoreConfigSubtitle;

  /// Section heading for theme selection in the drawer.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get dashboardThemeHeading;

  /// Theme radio option: follow the system light/dark setting.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get dashboardThemeSystem;

  /// Theme radio option: dark theme.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dashboardThemeDark;

  /// Theme radio option: light theme.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get dashboardThemeLight;

  /// Theme radio option: custom colour theme.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get dashboardThemeCustom;

  /// Drawer item to open the custom colour editor.
  ///
  /// In en, this message translates to:
  /// **'Customise colours'**
  String get dashboardCustomiseColours;

  /// Subtitle for the customise-colours drawer item.
  ///
  /// In en, this message translates to:
  /// **'Edit the five theme slots — HEX or palette'**
  String get dashboardCustomiseColoursSubtitle;

  /// Section heading for the font-size slider in the drawer.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get dashboardFontSizeHeading;

  /// Section heading for dashboard layout options in the drawer.
  ///
  /// In en, this message translates to:
  /// **'Dashboard layout'**
  String get dashboardLayoutHeading;

  /// Segmented-button label for the dashboard grid column count (e.g. '2 col').
  ///
  /// In en, this message translates to:
  /// **'{count} col'**
  String dashboardColumnCount(int count);

  /// Switch title to allow landscape orientation.
  ///
  /// In en, this message translates to:
  /// **'Rotate with device'**
  String get dashboardRotateWithDevice;

  /// Subtitle for the rotate-with-device switch.
  ///
  /// In en, this message translates to:
  /// **'Unlocks landscape orientation'**
  String get dashboardRotateWithDeviceSubtitle;

  /// Section heading for the dashboard webcam refresh setting.
  ///
  /// In en, this message translates to:
  /// **'Dashboard camera feed'**
  String get dashboardCameraFeedHeading;

  /// Explanatory text under the dashboard camera feed heading.
  ///
  /// In en, this message translates to:
  /// **'How often tiles refresh the camera. Lower rates use much less data.'**
  String get dashboardCameraFeedSubtitle;

  /// Section heading for the About group in the drawer.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get dashboardAboutHeading;

  /// Drawer item and changelog dialog title showing recent changes.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get dashboardWhatsNew;

  /// Subtitle for the What's new drawer item.
  ///
  /// In en, this message translates to:
  /// **'Recent changes at a glance'**
  String get dashboardWhatsNewSubtitle;

  /// Drawer item and pairing-help dialog title.
  ///
  /// In en, this message translates to:
  /// **'How pairing works'**
  String get dashboardHowPairingWorks;

  /// Subtitle for the How pairing works drawer item.
  ///
  /// In en, this message translates to:
  /// **'Pairing, reinstalling & restore'**
  String get dashboardHowPairingWorksSubtitle;

  /// Drawer item to open the feedback / bug-report sheet.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get dashboardReportProblem;

  /// Subtitle for the Report a problem drawer item.
  ///
  /// In en, this message translates to:
  /// **'Send a bug report or feedback'**
  String get dashboardReportProblemSubtitle;

  /// Drawer item to open app-lock settings.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get dashboardAppLock;

  /// App-lock drawer subtitle when the lock is enabled.
  ///
  /// In en, this message translates to:
  /// **'On — unlock required on launch'**
  String get dashboardAppLockOn;

  /// App-lock drawer subtitle when the lock is disabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get dashboardAppLockOff;

  /// Drawer item that opens the PayPal donation link.
  ///
  /// In en, this message translates to:
  /// **'Buy me a coffee'**
  String get dashboardBuyMeCoffee;

  /// Subtitle for the Buy me a coffee drawer item.
  ///
  /// In en, this message translates to:
  /// **'Tip the dev via PayPal'**
  String get dashboardBuyMeCoffeeSubtitle;

  /// Drawer item that opens the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get dashboardSettings;

  /// App version footer in the drawer.
  ///
  /// In en, this message translates to:
  /// **'Moongate v{version}'**
  String dashboardVersion(String version);

  /// Title of the system Save File dialog when exporting a backup.
  ///
  /// In en, this message translates to:
  /// **'Save Moongate backup'**
  String get dashboardSaveBackupDialogTitle;

  /// Snackbar shown when saving the backup file fails.
  ///
  /// In en, this message translates to:
  /// **'Backup failed — could not save the file.'**
  String get dashboardBackupFailed;

  /// Snackbar after a successful backup that includes a restore code.
  ///
  /// In en, this message translates to:
  /// **'Backed up {count} printer(s). This file can restore them on a new install — keep it private.'**
  String dashboardBackupSuccess(int count);

  /// Snackbar after a backup when the cloud restore code could not be minted.
  ///
  /// In en, this message translates to:
  /// **'Backed up {count} printer(s) (list only — couldn’t reach the cloud for a restore code).'**
  String dashboardBackupSuccessListOnly(int count);

  /// Snackbar shown when the chosen restore file is not a valid Moongate backup.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup file — please pick a Moongate config file.'**
  String get dashboardInvalidBackupFile;

  /// Snackbar after restore when some printers reconnected via the restore code.
  ///
  /// In en, this message translates to:
  /// **'{added} printer(s) restored — {count} reconnected and coming back online.'**
  String dashboardRestoreReconnected(int added, int count);

  /// Snackbar after restore when a restore code was present but matched no printers.
  ///
  /// In en, this message translates to:
  /// **'{added} printer(s) restored, but none reconnected — the backup’s restore code didn’t match any printers (it may be from an older backup, or already used). Re-pair them to bring them online.'**
  String dashboardRestoreNoneReconnected(int added);

  /// Snackbar after restore when the backup had no restore code.
  ///
  /// In en, this message translates to:
  /// **'{added} printer(s) restored (list only). Re-pair each printer to bring it online.'**
  String dashboardRestoreListOnly(int added);

  /// Heading of the bottom sheet listing printers to remove.
  ///
  /// In en, this message translates to:
  /// **'Remove a printer'**
  String get dashboardRemoveSheetTitle;

  /// Subtitle showing a truncated printer id in the remove sheet.
  ///
  /// In en, this message translates to:
  /// **'id {id}…'**
  String dashboardPrinterIdShort(String id);

  /// Pairing-help item title: pairing only needs to happen once.
  ///
  /// In en, this message translates to:
  /// **'Pair once'**
  String get dashboardPairingHelpPairOnceTitle;

  /// Pairing-help item body for 'Pair once'.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR (or enter the GATE code) to add a printer — that link is saved in this app.'**
  String get dashboardPairingHelpPairOnceBody;

  /// Pairing-help item title: updating the app does not lose printers.
  ///
  /// In en, this message translates to:
  /// **'App updates keep your printers'**
  String get dashboardPairingHelpUpdatesTitle;

  /// Pairing-help item body for app updates.
  ///
  /// In en, this message translates to:
  /// **'Updating Moongate never needs a re-pair.'**
  String get dashboardPairingHelpUpdatesBody;

  /// Pairing-help item title about reinstalling or moving to a new phone.
  ///
  /// In en, this message translates to:
  /// **'Reinstalling or new phone?'**
  String get dashboardPairingHelpReinstallTitle;

  /// Pairing-help item body about backing up and restoring.
  ///
  /// In en, this message translates to:
  /// **'Back up first (Menu → Back up config), then Restore brings your printers back online — no re-pairing.'**
  String get dashboardPairingHelpReinstallBody;

  /// Pairing-help item title for the no-backup recovery path.
  ///
  /// In en, this message translates to:
  /// **'No backup?'**
  String get dashboardPairingHelpNoBackupTitle;

  /// Pairing-help item body for the no-backup recovery path. 'MOONGATE_RESET_OWNER' is a literal command name.
  ///
  /// In en, this message translates to:
  /// **'Run MOONGATE_RESET_OWNER on the printer\'s console, then pair again.'**
  String get dashboardPairingHelpNoBackupBody;

  /// Checkbox in the pairing-help dialog to stop it auto-showing on launch.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show this again'**
  String get dashboardDontShowAgain;

  /// Update banner text announcing a newer app version.
  ///
  /// In en, this message translates to:
  /// **'Update available — v{version}'**
  String dashboardUpdateAvailable(String version);

  /// Update banner button to dismiss the banner for now.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get dashboardUpdateLater;

  /// Update banner button that opens the APK download link.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get dashboardUpdate;

  /// Empty-state title shown when no printers are configured.
  ///
  /// In en, this message translates to:
  /// **'No printers added yet'**
  String get dashboardEmptyTitle;

  /// Empty-state body prompting the user to pair their first printer.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to pair your first printer.'**
  String get dashboardEmptyBody;

  /// AppBar title of the pair-a-printer screen.
  ///
  /// In en, this message translates to:
  /// **'Add Printer'**
  String get pairingTitle;

  /// Intro text at the top of the pairing screen. 'MOONGATE_PAIR' is a literal console command.
  ///
  /// In en, this message translates to:
  /// **'Run MOONGATE_PAIR in your Klipper console — scan the QR or type the GATE code shown on the console.'**
  String get pairingIntro;

  /// Label for the printer-name text field.
  ///
  /// In en, this message translates to:
  /// **'Printer name'**
  String get pairingNameLabel;

  /// Placeholder example inside the printer-name field. 'Voron 2.4' is a printer model name.
  ///
  /// In en, this message translates to:
  /// **'e.g. Voron 2.4'**
  String get pairingNameHint;

  /// Button that opens the camera to scan the pairing QR code.
  ///
  /// In en, this message translates to:
  /// **'Scan QR code'**
  String get pairingScanButton;

  /// Subtext under the Scan QR button promoting it as the fast path.
  ///
  /// In en, this message translates to:
  /// **'Recommended — connects instantly'**
  String get pairingScanRecommended;

  /// Divider label between the QR-scan option and the manual GATE-code option.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get pairingOr;

  /// Label above the manual pairing-code entry. 'GATE' is the literal code prefix.
  ///
  /// In en, this message translates to:
  /// **'GATE code'**
  String get pairingGateCodeLabel;

  /// Helper text prompting the user to enter the GATE code.
  ///
  /// In en, this message translates to:
  /// **'Type the 8-digit code shown in your Klipper console.'**
  String get pairingGateCodeHint;

  /// Confirmation shown once both GATE-code boxes are filled correctly.
  ///
  /// In en, this message translates to:
  /// **'Code looks valid ✓'**
  String get pairingGateCodeValid;

  /// Warning that the manual GATE-code path is slower than scanning the QR.
  ///
  /// In en, this message translates to:
  /// **'Alternative method. Without the QR, the printer can take a few minutes — occasionally up to ~10 — to come fully online on the dashboard. Scan the QR code above for an instant connection.'**
  String get pairingGateCodeWarning;

  /// Scanner overlay message when camera permission was denied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission needed'**
  String get pairingCameraPermissionNeeded;

  /// Scanner overlay message when the camera cannot be opened.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get pairingCameraUnavailable;

  /// Button that closes the QR scanner without pairing.
  ///
  /// In en, this message translates to:
  /// **'Cancel scan'**
  String get pairingCancelScan;

  /// Confirmation banner after a successful QR scan, showing the enrollment code.
  ///
  /// In en, this message translates to:
  /// **'QR scanned — code {code}'**
  String pairingQrScanned(String code);

  /// Button that discards the scanned code and reopens the scanner.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get pairingRescan;

  /// Expandable section title for entering a custom printer address.
  ///
  /// In en, this message translates to:
  /// **'Advanced — printer on a custom network?'**
  String get pairingAdvancedTitle;

  /// Explanation of when to use the advanced custom-address field. Traefik, Caddy, NPM, Docker, Mainsail, Fluidd are product names.
  ///
  /// In en, this message translates to:
  /// **'Most people can leave this blank. If your printer is behind a reverse proxy (Traefik, Caddy, NPM) or in Docker, enter the same address you use to open its web page (Mainsail / Fluidd) in a browser.'**
  String get pairingAdvancedBody;

  /// Label for the advanced custom-address text field.
  ///
  /// In en, this message translates to:
  /// **'Printer address'**
  String get pairingAddressLabel;

  /// Example IP:port placeholder; not translatable text.
  ///
  /// In en, this message translates to:
  /// **'192.168.1.50:7125'**
  String get pairingAddressHint;

  /// Primary button that submits the pairing request.
  ///
  /// In en, this message translates to:
  /// **'Pair printer'**
  String get pairingPairButton;

  /// Helper text above the restore-from-backup button.
  ///
  /// In en, this message translates to:
  /// **'Reinstalling? Restore your saved printers from a backup file. You\'ll still re-pair each one to bring it online.'**
  String get pairingRestoreHint;

  /// Button that opens a file picker to restore printers from a backup file.
  ///
  /// In en, this message translates to:
  /// **'Import config from file'**
  String get pairingImportButton;

  /// Button that opens the bug-report sheet pre-filled with the pairing state.
  ///
  /// In en, this message translates to:
  /// **'Trouble pairing? Send a report'**
  String get pairingReportButton;

  /// Title of the dialog shown when camera permission is permanently denied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission required'**
  String get pairingCameraPermissionTitle;

  /// Body of the permanently-denied camera-permission dialog.
  ///
  /// In en, this message translates to:
  /// **'Moongate needs camera access to scan QR codes.\n\nOpen Settings → Apps → Moongate → Permissions and enable Camera, then come back and try again.'**
  String get pairingCameraPermissionBody;

  /// Button that opens the OS app-settings page so the user can grant camera permission.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get pairingOpenSettings;

  /// Error when the scanned QR is not a Moongate pairing code.
  ///
  /// In en, this message translates to:
  /// **'Not a Moongate QR code. Run MOONGATE_PAIR on the printer to generate one.'**
  String get pairingErrorNotMoongateQr;

  /// Error when the scanned QR uses an unsupported older pairing format.
  ///
  /// In en, this message translates to:
  /// **'This QR code is from an older Moongate version. Update the Pi to v0.3.0 first.'**
  String get pairingErrorOldQr;

  /// Error when the user taps Pair without providing a QR scan or GATE code.
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code, or type the GATE code from the printer console.'**
  String get pairingErrorNoCode;

  /// Error when the advanced custom address cannot be parsed.
  ///
  /// In en, this message translates to:
  /// **'That printer address doesn\'t look right — try e.g. 192.168.1.50:7125'**
  String get pairingErrorBadAddress;

  /// Generic pairing failure message with the underlying error detail.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed: {error}'**
  String pairingErrorFailed(String error);

  /// Snackbar shown when the chosen restore file is not a valid Moongate backup.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup file — please pick a Moongate config file.'**
  String get pairingImportInvalidFile;

  /// Snackbar shown when a restore file contains no printers to add.
  ///
  /// In en, this message translates to:
  /// **'No new printers found in that file.'**
  String get pairingImportNoNewPrinters;

  /// Snackbar after restoring printers when some reconnected automatically.
  ///
  /// In en, this message translates to:
  /// **'{count} printer(s) restored — {reconnected} reconnected, coming back online.'**
  String pairingImportRestoredReconnected(int count, int reconnected);

  /// Snackbar after restoring printers when the user must re-pair each one.
  ///
  /// In en, this message translates to:
  /// **'{count} printer(s) restored — re-pair each Pi to bring it online.'**
  String pairingImportRestoredRepair(int count);

  /// Title of the custom-theme colour editor screen.
  ///
  /// In en, this message translates to:
  /// **'Custom theme'**
  String get customThemeTitle;

  /// Tooltip on the app-bar action that reverts all colour slots to defaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get customThemeResetTooltip;

  /// Title of the confirmation dialog before resetting the custom theme.
  ///
  /// In en, this message translates to:
  /// **'Reset custom theme?'**
  String get customThemeResetConfirmTitle;

  /// Body of the confirmation dialog explaining what resetting the custom theme does.
  ///
  /// In en, this message translates to:
  /// **'All five colour slots will be reverted to the default purple-on-dark palette.'**
  String get customThemeResetConfirmBody;

  /// Confirm button that resets the custom theme to defaults.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get customThemeReset;

  /// Section label above the live preview tile in the custom-theme editor.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get customThemePreview;

  /// Label for the accent colour slot.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get customThemeAccent;

  /// Description of where the accent colour is used.
  ///
  /// In en, this message translates to:
  /// **'Buttons, FAB, progress bars, links'**
  String get customThemeAccentDesc;

  /// Label for the page-background colour slot.
  ///
  /// In en, this message translates to:
  /// **'Page background'**
  String get customThemeBackground;

  /// Description of where the page-background colour is used.
  ///
  /// In en, this message translates to:
  /// **'Behind every screen'**
  String get customThemeBackgroundDesc;

  /// Label for the surface (cards and tiles) colour slot.
  ///
  /// In en, this message translates to:
  /// **'Cards & tiles'**
  String get customThemeSurface;

  /// Description of where the surface colour is used.
  ///
  /// In en, this message translates to:
  /// **'Dashboard tiles, sheets, drawer'**
  String get customThemeSurfaceDesc;

  /// Label for the text colour slot.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get customThemeText;

  /// Description of where the text colour is used.
  ///
  /// In en, this message translates to:
  /// **'Body and heading text on surfaces'**
  String get customThemeTextDesc;

  /// Label for the error/stop colour slot.
  ///
  /// In en, this message translates to:
  /// **'Error / Stop'**
  String get customThemeError;

  /// Description of where the error/stop colour is used.
  ///
  /// In en, this message translates to:
  /// **'Destructive actions, error overlays'**
  String get customThemeErrorDesc;

  /// Label above the grid of preset colours in the colour picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get customThemePresets;

  /// Inline error shown when the typed hex value is not a valid 6-digit colour.
  ///
  /// In en, this message translates to:
  /// **'Not a valid hex colour'**
  String get customThemeInvalidHex;

  /// Placeholder printer name shown in the custom-theme preview tile.
  ///
  /// In en, this message translates to:
  /// **'Sample printer'**
  String get customThemeSamplePrinter;

  /// Sample 'Printing' status label shown in the custom-theme preview tile.
  ///
  /// In en, this message translates to:
  /// **'Printing'**
  String get customThemePrinting;

  /// Snackbar shown when a pause command could not reach the printer.
  ///
  /// In en, this message translates to:
  /// **'Could not reach printer — pause failed'**
  String get tilePauseFailed;

  /// Snackbar shown when a resume command could not reach the printer.
  ///
  /// In en, this message translates to:
  /// **'Could not reach printer — resume failed'**
  String get tileResumeFailed;

  /// Snackbar prompting the user to tap stop a second time to confirm cancelling the print.
  ///
  /// In en, this message translates to:
  /// **'Press STOP again to cancel the print'**
  String get tileStopAgainToCancel;

  /// Connection label shown when the printer is reached over the local network.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get tileLocal;

  /// Connection label shown when the printer is reached over the remote tunnel.
  ///
  /// In en, this message translates to:
  /// **'Tunnel'**
  String get tileTunnel;

  /// Status label/badge shown while the printer is actively printing.
  ///
  /// In en, this message translates to:
  /// **'Printing'**
  String get tilePrinting;

  /// Status label/badge shown while the print is paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get tilePaused;

  /// Tooltip on the resume-print control button.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get tileResume;

  /// Tooltip on the pause-print control button.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get tilePause;

  /// Tooltip on the stop button when a second tap is required to confirm cancelling.
  ///
  /// In en, this message translates to:
  /// **'Confirm stop'**
  String get tileConfirmStop;

  /// Tooltip on the stop-print control button.
  ///
  /// In en, this message translates to:
  /// **'Stop print'**
  String get tileStopPrint;

  /// Tooltip on the firmware-restart button shown when the printer is idle.
  ///
  /// In en, this message translates to:
  /// **'Firmware restart'**
  String get tileFirmwareRestart;

  /// Idle-row label shown when the last print finished successfully.
  ///
  /// In en, this message translates to:
  /// **'Print complete'**
  String get tilePrintComplete;

  /// Idle-row label shown when the last print was cancelled.
  ///
  /// In en, this message translates to:
  /// **'Print cancelled'**
  String get tilePrintCancelled;

  /// Idle-row label shown when the printer is in an error state.
  ///
  /// In en, this message translates to:
  /// **'Printer error'**
  String get tilePrinterError;

  /// Idle-row label shown while Klipper firmware is starting up. 'Klipper' is a product name.
  ///
  /// In en, this message translates to:
  /// **'Klipper starting'**
  String get tileKlipperStarting;

  /// Idle-row label shown when the printer is ready and idle.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get tileReady;

  /// Label shown when the printer is unreachable on any path.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get tileOffline;

  /// Probe overlay label shown while the Pi has not yet sent its first heartbeat.
  ///
  /// In en, this message translates to:
  /// **'Starting up…'**
  String get tileStartingUp;

  /// Probe overlay label shown when the Pi is reachable but the printer is idle/waiting.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get tileConnected;

  /// Probe overlay label shown while the first poll is in flight.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get tileConnecting;

  /// Probe overlay sub-text shown when the printer is offline.
  ///
  /// In en, this message translates to:
  /// **'Printer unreachable'**
  String get tilePrinterUnreachable;

  /// Probe overlay sub-text shown while waiting for the Pi's first heartbeat.
  ///
  /// In en, this message translates to:
  /// **'Waiting for first heartbeat'**
  String get tileWaitingForHeartbeat;

  /// Probe overlay sub-text shown when the printer is reachable but idle.
  ///
  /// In en, this message translates to:
  /// **'Printer idle'**
  String get tilePrinterIdle;

  /// Probe overlay sub-text shown while the first poll is in flight.
  ///
  /// In en, this message translates to:
  /// **'Reaching printer'**
  String get tileReachingPrinter;

  /// Tooltip on the tunnel-status dot when remote access is available.
  ///
  /// In en, this message translates to:
  /// **'Remote access ready'**
  String get tileRemoteReady;

  /// Tooltip on the tunnel-status dot while the remote tunnel is still establishing.
  ///
  /// In en, this message translates to:
  /// **'Remote connecting…'**
  String get tileRemoteConnecting;

  /// Status badge shown when the printer is in standby/idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get tileIdle;

  /// Status badge shown when the print has completed.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tileDone;

  /// Status badge shown when the print was cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tileCancelled;

  /// Status badge shown when the printer is in an error state.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get tileError;

  /// Status badge shown while Klipper is reachable but still initialising.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get tileStarting;

  /// Status badge shown before the first poll completes.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get tileConnectingBadge;

  /// Title of the App lock settings screen and the master enable/disable switch.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLockTitle;

  /// Introductory paragraph explaining what the app lock does.
  ///
  /// In en, this message translates to:
  /// **'Require a PIN — and optionally your fingerprint or face — before Moongate will open. The lock always appears when the app is started fresh.'**
  String get appLockIntro;

  /// Subtitle under the App lock enable switch.
  ///
  /// In en, this message translates to:
  /// **'PIN required to open the app'**
  String get appLockSubtitle;

  /// Title of the biometric unlock toggle in App lock settings.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock'**
  String get appLockBiometricTitle;

  /// Subtitle under the biometric unlock toggle.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or face — PIN stays as a fallback'**
  String get appLockBiometricSubtitle;

  /// List tile that opens the change-PIN flow in App lock settings.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get appLockChangePin;

  /// Label for the auto-lock timeout setting and the title of its option picker dialog.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get appLockAutoLock;

  /// Snackbar confirmation shown after the PIN is successfully changed.
  ///
  /// In en, this message translates to:
  /// **'PIN updated'**
  String get appLockPinUpdated;

  /// Title of the sheet where the user enters a new PIN.
  ///
  /// In en, this message translates to:
  /// **'Choose a PIN'**
  String get appLockChoosePinTitle;

  /// Subtitle of the choose-PIN sheet. '4–6' is a digit-length range.
  ///
  /// In en, this message translates to:
  /// **'Enter 4–6 digits'**
  String get appLockChoosePinSubtitle;

  /// Title of the sheet where the user re-enters the PIN to confirm it.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get appLockConfirmPinTitle;

  /// Validation error shown when the confirmation PIN differs from the first entry.
  ///
  /// In en, this message translates to:
  /// **'PINs don\'t match'**
  String get appLockPinsDontMatch;

  /// Title of the sheet that asks the user to verify their existing PIN.
  ///
  /// In en, this message translates to:
  /// **'Enter current PIN'**
  String get appLockEnterCurrentPin;

  /// Auto-lock timeout option: re-lock as soon as the app is backgrounded.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get appLockTimeoutImmediately;

  /// Auto-lock timeout option: re-lock one minute after backgrounding.
  ///
  /// In en, this message translates to:
  /// **'After 1 minute'**
  String get appLockTimeoutOneMinute;

  /// Auto-lock timeout option: re-lock five minutes after backgrounding.
  ///
  /// In en, this message translates to:
  /// **'After 5 minutes'**
  String get appLockTimeoutFiveMinutes;

  /// Auto-lock timeout option: re-lock fifteen minutes after backgrounding.
  ///
  /// In en, this message translates to:
  /// **'After 15 minutes'**
  String get appLockTimeoutFifteenMinutes;

  /// Auto-lock timeout option: never re-lock a running app, only on a fresh launch.
  ///
  /// In en, this message translates to:
  /// **'Only on app launch'**
  String get appLockTimeoutColdLaunch;

  /// Title on the full-screen lock prompting the user to enter their PIN.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get lockEnterPin;

  /// Subtitle on the lock screen indicating the app is currently locked.
  ///
  /// In en, this message translates to:
  /// **'Moongate is locked'**
  String get lockSubtitle;

  /// Lockout countdown shown after too many wrong PIN attempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds}s'**
  String lockTooManyAttempts(int seconds);

  /// Error shown when an entered PIN is incorrect.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get lockWrongPin;

  /// Button on the lock screen that triggers the biometric prompt.
  ///
  /// In en, this message translates to:
  /// **'Use biometrics'**
  String get lockUseBiometrics;

  /// Link on the lock screen that starts the reset-app escape hatch.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get lockForgotPin;

  /// Reason string shown by the OS biometric dialog when unlocking the app.
  ///
  /// In en, this message translates to:
  /// **'Unlock Moongate'**
  String get lockBiometricReason;

  /// Title of the confirmation dialog for the 'Forgot PIN?' reset.
  ///
  /// In en, this message translates to:
  /// **'Reset Moongate?'**
  String get lockResetTitle;

  /// Body of the reset confirmation dialog. 'MOONGATE_PAIR' is a literal command name.
  ///
  /// In en, this message translates to:
  /// **'This removes the app lock and clears the paired printers from this device so you can start over. Your printers are not deleted — re-pair them by running MOONGATE_PAIR on each one.'**
  String get lockResetBody;

  /// Confirm button that resets the app from the 'Forgot PIN?' dialog.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get lockResetConfirm;

  /// Button under the PIN keypad that submits a variable-length PIN.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get pinContinue;

  /// Error-overlay text shown when the printer's remote access isn't up yet; auto-retries after the given number of seconds.
  ///
  /// In en, this message translates to:
  /// **'Printer is starting up. Retrying in {seconds}s…'**
  String printerStartingUpRetry(int seconds);

  /// Error-overlay text when fetching printer access fails. {error} is a technical error string.
  ///
  /// In en, this message translates to:
  /// **'Could not reach printer: {error}'**
  String printerCouldNotReach(String error);

  /// Snackbar confirming the custom printer address override was removed.
  ///
  /// In en, this message translates to:
  /// **'Custom address cleared'**
  String get printerAddressCleared;

  /// Snackbar confirming the custom printer address override was saved.
  ///
  /// In en, this message translates to:
  /// **'Printer address updated'**
  String get printerAddressUpdated;

  /// Error-overlay text when the WebView fails to load over the Cloudflare tunnel. 'Cloudflare' is a product name.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare tunnel unreachable.\n{description}'**
  String printerTunnelUnreachable(String description);

  /// Tooltip on the app-bar edit button and title of the edit-printer dialog.
  ///
  /// In en, this message translates to:
  /// **'Edit printer'**
  String get printerEdit;

  /// App-bar subtitle indicating the printer is loaded directly over the LAN.
  ///
  /// In en, this message translates to:
  /// **'Local network'**
  String get printerLocalNetwork;

  /// App-bar subtitle indicating the printer is loaded remotely through the Moongate tunnel.
  ///
  /// In en, this message translates to:
  /// **'Tunnel via Moongate'**
  String get printerTunnelVia;

  /// Heading on the full-screen error overlay when the printer cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Printer unreachable'**
  String get printerUnreachable;

  /// Button on the error overlay that retries loading via the tunnel instead of the LAN.
  ///
  /// In en, this message translates to:
  /// **'Use tunnel'**
  String get printerUseTunnel;

  /// Validation error under the printer-address field when the value can't be parsed.
  ///
  /// In en, this message translates to:
  /// **'Try e.g. 192.168.1.50:7125'**
  String get printerAddressInvalid;

  /// Label for the printer-name text field in the edit-printer dialog.
  ///
  /// In en, this message translates to:
  /// **'Printer name'**
  String get printerNameLabel;

  /// Label for the optional advanced printer-address override field.
  ///
  /// In en, this message translates to:
  /// **'Printer address (advanced)'**
  String get printerAddressLabel;

  /// Example IP:port placeholder; not translatable text.
  ///
  /// In en, this message translates to:
  /// **'192.168.1.50:7125'**
  String get printerAddressHint;

  /// Helper text under the advanced printer-address field explaining when to set it.
  ///
  /// In en, this message translates to:
  /// **'Only for reverse-proxy / Docker setups. Leave blank to use automatic discovery.'**
  String get printerAddressHelper;

  /// Title of the feedback bottom sheet when opened from the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get feedbackTitle;

  /// Title of the feedback bottom sheet when opened from the pairing screen.
  ///
  /// In en, this message translates to:
  /// **'Trouble pairing?'**
  String get feedbackTroublePairing;

  /// Explanatory text under the feedback title when opened from the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Tell us what\'s happening. Your app version, device, network and printer details are attached automatically to help us track it down.'**
  String get feedbackDescription;

  /// Explanatory text under the feedback title when opened from the pairing screen.
  ///
  /// In en, this message translates to:
  /// **'Describe what happens when you try to add the printer. Your network + discovery details are attached automatically so we can see why it isn\'t connecting.'**
  String get feedbackPairingDescription;

  /// Label for the optional dropdown selecting which printer the report concerns.
  ///
  /// In en, this message translates to:
  /// **'Which printer? (optional)'**
  String get feedbackWhichPrinter;

  /// Dropdown option for feedback not tied to a specific printer.
  ///
  /// In en, this message translates to:
  /// **'General / not printer-specific'**
  String get feedbackGeneralOption;

  /// Label for the main free-text feedback field.
  ///
  /// In en, this message translates to:
  /// **'What went wrong?'**
  String get feedbackCommentLabel;

  /// Example placeholder text shown in the main feedback field.
  ///
  /// In en, this message translates to:
  /// **'e.g. \"Printer shows Connected / idle but it\'s actually ready — opens fine when I tap the tile.\"'**
  String get feedbackCommentHint;

  /// Label for the optional contact field on the feedback sheet.
  ///
  /// In en, this message translates to:
  /// **'Email or contact (optional)'**
  String get feedbackContactLabel;

  /// Placeholder text in the optional contact field.
  ///
  /// In en, this message translates to:
  /// **'Only if you want a reply'**
  String get feedbackContactHint;

  /// Send-button label while the feedback report is being submitted.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get feedbackSending;

  /// Send-button label on the feedback sheet.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get feedbackSend;

  /// Snackbar confirming the feedback report was submitted.
  ///
  /// In en, this message translates to:
  /// **'Thanks — your report was sent.'**
  String get feedbackSuccess;

  /// Snackbar shown when submitting the feedback report fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send — check your connection and try again.'**
  String get feedbackError;

  /// Tagline under the MOONGATE wordmark on the splash screen. 'Klipper' is a product name.
  ///
  /// In en, this message translates to:
  /// **'Klipper remote control'**
  String get splashTagline;

  /// Title of the icon-guide screen and its drawer menu entry.
  ///
  /// In en, this message translates to:
  /// **'Icon guide'**
  String get uiGuideTitle;

  /// Subtitle for the icon-guide drawer menu entry.
  ///
  /// In en, this message translates to:
  /// **'What the dashboard icons mean'**
  String get uiGuideMenuSubtitle;

  /// Introductory line at the top of the icon-guide screen.
  ///
  /// In en, this message translates to:
  /// **'A quick guide to the icons you\'ll see on the dashboard.'**
  String get uiGuideIntro;

  /// Section header for connection icons.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get uiGuideSectionConnection;

  /// Section header for temperature icons.
  ///
  /// In en, this message translates to:
  /// **'Temperatures'**
  String get uiGuideSectionTemperatures;

  /// Section header for print-control icons.
  ///
  /// In en, this message translates to:
  /// **'Print controls'**
  String get uiGuideSectionControls;

  /// Section header for status icons.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get uiGuideSectionStatus;

  /// Section header for camera and connection-state icons.
  ///
  /// In en, this message translates to:
  /// **'Camera & connection'**
  String get uiGuideSectionWebcam;

  /// Icon-guide entry title for the local-network (Wi-Fi) connection icon.
  ///
  /// In en, this message translates to:
  /// **'Local network'**
  String get uiGuideLocalTitle;

  /// Icon-guide description for the local-network connection icon.
  ///
  /// In en, this message translates to:
  /// **'Connected directly over your Wi-Fi — the fastest path.'**
  String get uiGuideLocalDesc;

  /// Icon-guide entry title for the remote/tunnel connection icon.
  ///
  /// In en, this message translates to:
  /// **'Remote (tunnel)'**
  String get uiGuideTunnelTitle;

  /// Icon-guide description for the remote/tunnel connection icon. 'Cloudflare' is a product name.
  ///
  /// In en, this message translates to:
  /// **'Connected from anywhere through the secure Cloudflare tunnel.'**
  String get uiGuideTunnelDesc;

  /// Icon-guide entry title for the tunnel-ready icon.
  ///
  /// In en, this message translates to:
  /// **'Remote ready'**
  String get uiGuideTunnelReadyTitle;

  /// Icon-guide description for the tunnel-ready icon.
  ///
  /// In en, this message translates to:
  /// **'The tunnel is up, so remote access is available.'**
  String get uiGuideTunnelReadyDesc;

  /// Icon-guide entry title for the tunnel-connecting icon.
  ///
  /// In en, this message translates to:
  /// **'Remote connecting'**
  String get uiGuideTunnelConnectingTitle;

  /// Icon-guide description for the tunnel-connecting icon.
  ///
  /// In en, this message translates to:
  /// **'The remote tunnel is still establishing.'**
  String get uiGuideTunnelConnectingDesc;

  /// Icon-guide entry title for the hotend temperature icon.
  ///
  /// In en, this message translates to:
  /// **'Hotend / nozzle'**
  String get uiGuideHotendTitle;

  /// Icon-guide description for the hotend temperature icon.
  ///
  /// In en, this message translates to:
  /// **'Current nozzle temperature.'**
  String get uiGuideHotendDesc;

  /// Icon-guide entry title for the heated-bed temperature icon.
  ///
  /// In en, this message translates to:
  /// **'Heated bed'**
  String get uiGuideBedTitle;

  /// Icon-guide description for the heated-bed temperature icon.
  ///
  /// In en, this message translates to:
  /// **'Current bed temperature.'**
  String get uiGuideBedDesc;

  /// Icon-guide entry title for the chamber temperature icon.
  ///
  /// In en, this message translates to:
  /// **'Chamber'**
  String get uiGuideChamberTitle;

  /// Icon-guide description for the chamber temperature icon.
  ///
  /// In en, this message translates to:
  /// **'Chamber temperature — shown only if your printer reports one.'**
  String get uiGuideChamberDesc;

  /// Icon-guide entry title for the resume-print control.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get uiGuideResumeTitle;

  /// Icon-guide description for the resume-print control.
  ///
  /// In en, this message translates to:
  /// **'Resume a paused print.'**
  String get uiGuideResumeDesc;

  /// Icon-guide entry title for the pause-print control.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get uiGuidePauseTitle;

  /// Icon-guide description for the pause-print control.
  ///
  /// In en, this message translates to:
  /// **'Pause the current print.'**
  String get uiGuidePauseDesc;

  /// Icon-guide entry title for the stop-print control.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get uiGuideStopTitle;

  /// Icon-guide description for the stop-print control.
  ///
  /// In en, this message translates to:
  /// **'Cancel the print — tap twice to confirm.'**
  String get uiGuideStopDesc;

  /// Icon-guide entry title for the firmware-restart control.
  ///
  /// In en, this message translates to:
  /// **'Firmware restart'**
  String get uiGuideFirmwareRestartTitle;

  /// Icon-guide description for the firmware-restart control. 'Klipper' is a product name.
  ///
  /// In en, this message translates to:
  /// **'Restart Klipper when the printer is idle or in error.'**
  String get uiGuideFirmwareRestartDesc;

  /// Icon-guide entry title for the ready/complete status icon.
  ///
  /// In en, this message translates to:
  /// **'Ready / complete'**
  String get uiGuideStatusReadyTitle;

  /// Icon-guide description for the ready/complete status icon.
  ///
  /// In en, this message translates to:
  /// **'The printer is idle, or finished its last print.'**
  String get uiGuideStatusReadyDesc;

  /// Icon-guide entry title for the cancelled status icon.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get uiGuideStatusCancelledTitle;

  /// Icon-guide description for the cancelled status icon.
  ///
  /// In en, this message translates to:
  /// **'The last print was cancelled.'**
  String get uiGuideStatusCancelledDesc;

  /// Icon-guide entry title for the error status icon.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get uiGuideStatusErrorTitle;

  /// Icon-guide description for the error status icon. 'Klipper' is a product name.
  ///
  /// In en, this message translates to:
  /// **'Klipper reported an error — open the printer for details.'**
  String get uiGuideStatusErrorDesc;

  /// Icon-guide entry title for the starting-up status icon.
  ///
  /// In en, this message translates to:
  /// **'Starting up'**
  String get uiGuideStatusStartingTitle;

  /// Icon-guide description for the starting-up status icon. 'Klipper' is a product name.
  ///
  /// In en, this message translates to:
  /// **'Klipper is starting; controls appear once it\'s ready.'**
  String get uiGuideStatusStartingDesc;

  /// Icon-guide entry title for the offline icon.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get uiGuideOfflineTitle;

  /// Icon-guide description for the offline icon.
  ///
  /// In en, this message translates to:
  /// **'The printer can\'t be reached right now.'**
  String get uiGuideOfflineDesc;

  /// Icon-guide entry title for the no-webcam icon.
  ///
  /// In en, this message translates to:
  /// **'No camera'**
  String get uiGuideNoWebcamTitle;

  /// Icon-guide description for the no-webcam icon.
  ///
  /// In en, this message translates to:
  /// **'No webcam snapshot is available for this printer.'**
  String get uiGuideNoWebcamDesc;

  /// Button at the bottom of the icon-guide popup that closes it and returns to the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Back to dashboard'**
  String get uiGuideBack;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'de',
        'en',
        'es',
        'fr',
        'it',
        'pl',
        'ru',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'pl':
      return AppLocalizationsPl();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
