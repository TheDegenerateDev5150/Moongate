// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Moongate';

  @override
  String get languagePickerTitle => 'Choose your language';

  @override
  String get languagePickerSubtitle =>
      'You can change this any time from the menu.';

  @override
  String get languagePickerContinue => 'Continue';

  @override
  String get menuLanguage => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDone => 'Done';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonDisable => 'Disable';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsRemoveAllTitle => 'Remove all printers from this device';

  @override
  String get settingsRemoveAllSubtitle =>
      'Clears the local printer cache. Your Supabase account is kept so re-pairing works seamlessly.';

  @override
  String get settingsRemoveAllConfirmTitle => 'Remove all printers?';

  @override
  String get settingsRemoveAllConfirmBody =>
      'All paired printers will be removed from this device. You can re-add them by running MOONGATE_PAIR on the printer.';

  @override
  String get settingsRemoveAllConfirmAction => 'Remove all';

  @override
  String get dashboardAddPrinter => 'Add printer';

  @override
  String get dashboardRemovePrinter => 'Remove printer';

  @override
  String get dashboardMenuTooltip => 'Menu';

  @override
  String get dashboardRemovePrinterTitle => 'Remove printer?';

  @override
  String dashboardRemovePrinterBody(String name) {
    return 'Remove \"$name\" from Moongate?';
  }

  @override
  String get dashboardRemoveSupabaseUnreachable =>
      'Removed locally, but couldn’t reach Supabase. Run MOONGATE_RESET_OWNER on the Pi if re-pairing fails.';

  @override
  String get dashboardBackUpConfig => 'Back up config';

  @override
  String get dashboardBackUpConfigSubtitle =>
      'Save to a file before reinstalling';

  @override
  String get dashboardRestoreConfig => 'Restore config';

  @override
  String get dashboardRestoreConfigSubtitle => 'Load from a backup file';

  @override
  String get dashboardThemeHeading => 'Theme';

  @override
  String get dashboardThemeSystem => 'System default';

  @override
  String get dashboardThemeDark => 'Dark';

  @override
  String get dashboardThemeLight => 'Light';

  @override
  String get dashboardThemeCustom => 'Custom';

  @override
  String get dashboardCustomiseColours => 'Customise colours';

  @override
  String get dashboardCustomiseColoursSubtitle =>
      'Edit the five theme slots — HEX or palette';

  @override
  String get dashboardFontSizeHeading => 'Font size';

  @override
  String get dashboardLayoutHeading => 'Dashboard layout';

  @override
  String dashboardColumnCount(int count) {
    return '$count col';
  }

  @override
  String get dashboardRotateWithDevice => 'Rotate with device';

  @override
  String get dashboardRotateWithDeviceSubtitle =>
      'Unlocks landscape orientation';

  @override
  String get dashboardCameraFeedHeading => 'Dashboard camera feed';

  @override
  String get dashboardCameraFeedSubtitle =>
      'How often tiles refresh the camera. Lower rates use much less data.';

  @override
  String get dashboardAboutHeading => 'About';

  @override
  String get dashboardWhatsNew => 'What\'s new';

  @override
  String get dashboardWhatsNewSubtitle => 'Recent changes at a glance';

  @override
  String get dashboardHowPairingWorks => 'How pairing works';

  @override
  String get dashboardHowPairingWorksSubtitle =>
      'Pairing, reinstalling & restore';

  @override
  String get dashboardReportProblem => 'Report a problem';

  @override
  String get dashboardReportProblemSubtitle => 'Send a bug report or feedback';

  @override
  String get dashboardAppLock => 'App lock';

  @override
  String get dashboardAppLockOn => 'On — unlock required on launch';

  @override
  String get dashboardAppLockOff => 'Off';

  @override
  String get dashboardBuyMeCoffee => 'Buy me a coffee';

  @override
  String get dashboardBuyMeCoffeeSubtitle => 'Tip the dev via PayPal';

  @override
  String get dashboardSettings => 'Settings';

  @override
  String dashboardVersion(String version) {
    return 'Moongate v$version';
  }

  @override
  String get dashboardSaveBackupDialogTitle => 'Save Moongate backup';

  @override
  String get dashboardBackupFailed =>
      'Backup failed — could not save the file.';

  @override
  String dashboardBackupSuccess(int count) {
    return 'Backed up $count printer(s). This file can restore them on a new install — keep it private.';
  }

  @override
  String dashboardBackupSuccessListOnly(int count) {
    return 'Backed up $count printer(s) (list only — couldn’t reach the cloud for a restore code).';
  }

  @override
  String get dashboardInvalidBackupFile =>
      'Invalid backup file — please pick a Moongate config file.';

  @override
  String dashboardRestoreReconnected(int added, int count) {
    return '$added printer(s) restored — $count reconnected and coming back online.';
  }

  @override
  String dashboardRestoreNoneReconnected(int added) {
    return '$added printer(s) restored, but none reconnected — the backup’s restore code didn’t match any printers (it may be from an older backup, or already used). Re-pair them to bring them online.';
  }

  @override
  String dashboardRestoreListOnly(int added) {
    return '$added printer(s) restored (list only). Re-pair each printer to bring it online.';
  }

  @override
  String get dashboardRemoveSheetTitle => 'Remove a printer';

  @override
  String dashboardPrinterIdShort(String id) {
    return 'id $id…';
  }

  @override
  String get dashboardPairingHelpPairOnceTitle => 'Pair once';

  @override
  String get dashboardPairingHelpPairOnceBody =>
      'Scan the QR (or enter the GATE code) to add a printer — that link is saved in this app.';

  @override
  String get dashboardPairingHelpUpdatesTitle =>
      'App updates keep your printers';

  @override
  String get dashboardPairingHelpUpdatesBody =>
      'Updating Moongate never needs a re-pair.';

  @override
  String get dashboardPairingHelpReinstallTitle => 'Reinstalling or new phone?';

  @override
  String get dashboardPairingHelpReinstallBody =>
      'Back up first (Menu → Back up config), then Restore brings your printers back online — no re-pairing.';

  @override
  String get dashboardPairingHelpNoBackupTitle => 'No backup?';

  @override
  String get dashboardPairingHelpNoBackupBody =>
      'Run MOONGATE_RESET_OWNER on the printer\'s console, then pair again.';

  @override
  String get dashboardDontShowAgain => 'Don\'t show this again';

  @override
  String dashboardUpdateAvailable(String version) {
    return 'Update available — v$version';
  }

  @override
  String get dashboardUpdateLater => 'Later';

  @override
  String get dashboardUpdate => 'Update';

  @override
  String get dashboardEmptyTitle => 'No printers added yet';

  @override
  String get dashboardEmptyBody =>
      'Tap the button below to pair your first printer.';

  @override
  String get pairingTitle => 'Add Printer';

  @override
  String get pairingIntro =>
      'Run MOONGATE_PAIR in your Klipper console — scan the QR or type the GATE code shown on the console.';

  @override
  String get pairingNameLabel => 'Printer name';

  @override
  String get pairingNameHint => 'e.g. Voron 2.4';

  @override
  String get pairingScanButton => 'Scan QR code';

  @override
  String get pairingScanRecommended => 'Recommended — connects instantly';

  @override
  String get pairingOr => 'OR';

  @override
  String get pairingGateCodeLabel => 'GATE code';

  @override
  String get pairingGateCodeHint =>
      'Type the 8-digit code shown in your Klipper console.';

  @override
  String get pairingGateCodeValid => 'Code looks valid ✓';

  @override
  String get pairingGateCodeWarning =>
      'Alternative method. Without the QR, the printer can take a few minutes — occasionally up to ~10 — to come fully online on the dashboard. Scan the QR code above for an instant connection.';

  @override
  String get pairingCameraPermissionNeeded => 'Camera permission needed';

  @override
  String get pairingCameraUnavailable => 'Camera unavailable';

  @override
  String get pairingCancelScan => 'Cancel scan';

  @override
  String pairingQrScanned(String code) {
    return 'QR scanned — code $code';
  }

  @override
  String get pairingRescan => 'Rescan';

  @override
  String get pairingAdvancedTitle => 'Advanced — printer on a custom network?';

  @override
  String get pairingAdvancedBody =>
      'Most people can leave this blank. If your printer is behind a reverse proxy (Traefik, Caddy, NPM) or in Docker, enter the same address you use to open its web page (Mainsail / Fluidd) in a browser.';

  @override
  String get pairingAddressLabel => 'Printer address';

  @override
  String get pairingAddressHint => '192.168.1.50:7125';

  @override
  String get pairingPairButton => 'Pair printer';

  @override
  String get pairingRestoreHint =>
      'Reinstalling? Restore your saved printers from a backup file. You\'ll still re-pair each one to bring it online.';

  @override
  String get pairingImportButton => 'Import config from file';

  @override
  String get pairingReportButton => 'Trouble pairing? Send a report';

  @override
  String get pairingCameraPermissionTitle => 'Camera permission required';

  @override
  String get pairingCameraPermissionBody =>
      'Moongate needs camera access to scan QR codes.\n\nOpen Settings → Apps → Moongate → Permissions and enable Camera, then come back and try again.';

  @override
  String get pairingOpenSettings => 'Open Settings';

  @override
  String get pairingErrorNotMoongateQr =>
      'Not a Moongate QR code. Run MOONGATE_PAIR on the printer to generate one.';

  @override
  String get pairingErrorOldQr =>
      'This QR code is from an older Moongate version. Update the Pi to v0.3.0 first.';

  @override
  String get pairingErrorNoCode =>
      'Scan the QR code, or type the GATE code from the printer console.';

  @override
  String get pairingErrorBadAddress =>
      'That printer address doesn\'t look right — try e.g. 192.168.1.50:7125';

  @override
  String pairingErrorFailed(String error) {
    return 'Pairing failed: $error';
  }

  @override
  String get pairingImportInvalidFile =>
      'Invalid backup file — please pick a Moongate config file.';

  @override
  String get pairingImportNoNewPrinters =>
      'No new printers found in that file.';

  @override
  String pairingImportRestoredReconnected(int count, int reconnected) {
    return '$count printer(s) restored — $reconnected reconnected, coming back online.';
  }

  @override
  String pairingImportRestoredRepair(int count) {
    return '$count printer(s) restored — re-pair each Pi to bring it online.';
  }

  @override
  String get customThemeTitle => 'Custom theme';

  @override
  String get customThemeResetTooltip => 'Reset to defaults';

  @override
  String get customThemeResetConfirmTitle => 'Reset custom theme?';

  @override
  String get customThemeResetConfirmBody =>
      'All five colour slots will be reverted to the default purple-on-dark palette.';

  @override
  String get customThemeReset => 'Reset';

  @override
  String get customThemePreview => 'Preview';

  @override
  String get customThemeAccent => 'Accent';

  @override
  String get customThemeAccentDesc => 'Buttons, FAB, progress bars, links';

  @override
  String get customThemeBackground => 'Page background';

  @override
  String get customThemeBackgroundDesc => 'Behind every screen';

  @override
  String get customThemeSurface => 'Cards & tiles';

  @override
  String get customThemeSurfaceDesc => 'Dashboard tiles, sheets, drawer';

  @override
  String get customThemeText => 'Text';

  @override
  String get customThemeTextDesc => 'Body and heading text on surfaces';

  @override
  String get customThemeError => 'Error / Stop';

  @override
  String get customThemeErrorDesc => 'Destructive actions, error overlays';

  @override
  String get customThemePresets => 'Presets';

  @override
  String get customThemeInvalidHex => 'Not a valid hex colour';

  @override
  String get customThemeSamplePrinter => 'Sample printer';

  @override
  String get customThemePrinting => 'Printing';

  @override
  String get tilePauseFailed => 'Could not reach printer — pause failed';

  @override
  String get tileResumeFailed => 'Could not reach printer — resume failed';

  @override
  String get tileStopAgainToCancel => 'Press STOP again to cancel the print';

  @override
  String get tileLocal => 'Local';

  @override
  String get tileTunnel => 'Tunnel';

  @override
  String get tilePrinting => 'Printing';

  @override
  String get tilePaused => 'Paused';

  @override
  String get tileResume => 'Resume';

  @override
  String get tilePause => 'Pause';

  @override
  String get tileConfirmStop => 'Confirm stop';

  @override
  String get tileStopPrint => 'Stop print';

  @override
  String get tileFirmwareRestart => 'Firmware restart';

  @override
  String get tilePrintComplete => 'Print complete';

  @override
  String get tilePrintCancelled => 'Print cancelled';

  @override
  String get tilePrinterError => 'Printer error';

  @override
  String get tileKlipperStarting => 'Klipper starting';

  @override
  String get tileReady => 'Ready';

  @override
  String get tileOffline => 'Offline';

  @override
  String get tileStartingUp => 'Starting up…';

  @override
  String get tileConnected => 'Connected';

  @override
  String get tileConnecting => 'Connecting…';

  @override
  String get tilePrinterUnreachable => 'Printer unreachable';

  @override
  String get tileWaitingForHeartbeat => 'Waiting for first heartbeat';

  @override
  String get tilePrinterIdle => 'Printer idle';

  @override
  String get tileReachingPrinter => 'Reaching printer';

  @override
  String get tileRemoteReady => 'Remote access ready';

  @override
  String get tileRemoteConnecting => 'Remote connecting…';

  @override
  String get tileIdle => 'Idle';

  @override
  String get tileDone => 'Done';

  @override
  String get tileCancelled => 'Cancelled';

  @override
  String get tileError => 'Error';

  @override
  String get tileStarting => 'Starting';

  @override
  String get tileConnectingBadge => 'Connecting';

  @override
  String get appLockTitle => 'App lock';

  @override
  String get appLockIntro =>
      'Require a PIN — and optionally your fingerprint or face — before Moongate will open. The lock always appears when the app is started fresh.';

  @override
  String get appLockSubtitle => 'PIN required to open the app';

  @override
  String get appLockBiometricTitle => 'Biometric unlock';

  @override
  String get appLockBiometricSubtitle =>
      'Use fingerprint or face — PIN stays as a fallback';

  @override
  String get appLockChangePin => 'Change PIN';

  @override
  String get appLockAutoLock => 'Auto-lock';

  @override
  String get appLockPinUpdated => 'PIN updated';

  @override
  String get appLockChoosePinTitle => 'Choose a PIN';

  @override
  String get appLockChoosePinSubtitle => 'Enter 4–6 digits';

  @override
  String get appLockConfirmPinTitle => 'Confirm PIN';

  @override
  String get appLockPinsDontMatch => 'PINs don\'t match';

  @override
  String get appLockEnterCurrentPin => 'Enter current PIN';

  @override
  String get appLockTimeoutImmediately => 'Immediately';

  @override
  String get appLockTimeoutOneMinute => 'After 1 minute';

  @override
  String get appLockTimeoutFiveMinutes => 'After 5 minutes';

  @override
  String get appLockTimeoutFifteenMinutes => 'After 15 minutes';

  @override
  String get appLockTimeoutColdLaunch => 'Only on app launch';

  @override
  String get lockEnterPin => 'Enter your PIN';

  @override
  String get lockSubtitle => 'Moongate is locked';

  @override
  String lockTooManyAttempts(int seconds) {
    return 'Too many attempts. Try again in ${seconds}s';
  }

  @override
  String get lockWrongPin => 'Wrong PIN';

  @override
  String get lockUseBiometrics => 'Use biometrics';

  @override
  String get lockForgotPin => 'Forgot PIN?';

  @override
  String get lockBiometricReason => 'Unlock Moongate';

  @override
  String get lockResetTitle => 'Reset Moongate?';

  @override
  String get lockResetBody =>
      'This removes the app lock and clears the paired printers from this device so you can start over. Your printers are not deleted — re-pair them by running MOONGATE_PAIR on each one.';

  @override
  String get lockResetConfirm => 'Reset';

  @override
  String get pinContinue => 'Continue';

  @override
  String printerStartingUpRetry(int seconds) {
    return 'Printer is starting up. Retrying in ${seconds}s…';
  }

  @override
  String printerCouldNotReach(String error) {
    return 'Could not reach printer: $error';
  }

  @override
  String get printerAddressCleared => 'Custom address cleared';

  @override
  String get printerAddressUpdated => 'Printer address updated';

  @override
  String printerTunnelUnreachable(String description) {
    return 'Cloudflare tunnel unreachable.\n$description';
  }

  @override
  String get printerEdit => 'Edit printer';

  @override
  String get printerLocalNetwork => 'Local network';

  @override
  String get printerTunnelVia => 'Tunnel via Moongate';

  @override
  String get printerUnreachable => 'Printer unreachable';

  @override
  String get printerUseTunnel => 'Use tunnel';

  @override
  String get printerAddressInvalid => 'Try e.g. 192.168.1.50:7125';

  @override
  String get printerNameLabel => 'Printer name';

  @override
  String get printerAddressLabel => 'Printer address (advanced)';

  @override
  String get printerAddressHint => '192.168.1.50:7125';

  @override
  String get printerAddressHelper =>
      'Only for reverse-proxy / Docker setups. Leave blank to use automatic discovery.';

  @override
  String get feedbackTitle => 'Report a problem';

  @override
  String get feedbackTroublePairing => 'Trouble pairing?';

  @override
  String get feedbackDescription =>
      'Tell us what\'s happening. Your app version, device, network and printer details are attached automatically to help us track it down.';

  @override
  String get feedbackPairingDescription =>
      'Describe what happens when you try to add the printer. Your network + discovery details are attached automatically so we can see why it isn\'t connecting.';

  @override
  String get feedbackWhichPrinter => 'Which printer? (optional)';

  @override
  String get feedbackGeneralOption => 'General / not printer-specific';

  @override
  String get feedbackCommentLabel => 'What went wrong?';

  @override
  String get feedbackCommentHint =>
      'e.g. \"Printer shows Connected / idle but it\'s actually ready — opens fine when I tap the tile.\"';

  @override
  String get feedbackContactLabel => 'Email or contact (optional)';

  @override
  String get feedbackContactHint => 'Only if you want a reply';

  @override
  String get feedbackSending => 'Sending…';

  @override
  String get feedbackSend => 'Send report';

  @override
  String get feedbackSuccess => 'Thanks — your report was sent.';

  @override
  String get feedbackError =>
      'Couldn\'t send — check your connection and try again.';

  @override
  String get splashTagline => 'Klipper remote control';

  @override
  String get uiGuideTitle => 'Icon guide';

  @override
  String get uiGuideMenuSubtitle => 'What the dashboard icons mean';

  @override
  String get uiGuideIntro =>
      'A quick guide to the icons you\'ll see on the dashboard.';

  @override
  String get uiGuideSectionConnection => 'Connection';

  @override
  String get uiGuideSectionTemperatures => 'Temperatures';

  @override
  String get uiGuideSectionControls => 'Print controls';

  @override
  String get uiGuideSectionStatus => 'Status';

  @override
  String get uiGuideSectionWebcam => 'Camera & connection';

  @override
  String get uiGuideLocalTitle => 'Local network';

  @override
  String get uiGuideLocalDesc =>
      'Connected directly over your Wi-Fi — the fastest path.';

  @override
  String get uiGuideTunnelTitle => 'Remote (tunnel)';

  @override
  String get uiGuideTunnelDesc =>
      'Connected from anywhere through the secure Cloudflare tunnel.';

  @override
  String get uiGuideTunnelReadyTitle => 'Remote ready';

  @override
  String get uiGuideTunnelReadyDesc =>
      'The tunnel is up, so remote access is available.';

  @override
  String get uiGuideTunnelConnectingTitle => 'Remote connecting';

  @override
  String get uiGuideTunnelConnectingDesc =>
      'The remote tunnel is still establishing.';

  @override
  String get uiGuideHotendTitle => 'Hotend / nozzle';

  @override
  String get uiGuideHotendDesc => 'Current nozzle temperature.';

  @override
  String get uiGuideBedTitle => 'Heated bed';

  @override
  String get uiGuideBedDesc => 'Current bed temperature.';

  @override
  String get uiGuideChamberTitle => 'Chamber';

  @override
  String get uiGuideChamberDesc =>
      'Chamber temperature — shown only if your printer reports one.';

  @override
  String get uiGuideResumeTitle => 'Resume';

  @override
  String get uiGuideResumeDesc => 'Resume a paused print.';

  @override
  String get uiGuidePauseTitle => 'Pause';

  @override
  String get uiGuidePauseDesc => 'Pause the current print.';

  @override
  String get uiGuideStopTitle => 'Stop';

  @override
  String get uiGuideStopDesc => 'Cancel the print — tap twice to confirm.';

  @override
  String get uiGuideFirmwareRestartTitle => 'Firmware restart';

  @override
  String get uiGuideFirmwareRestartDesc =>
      'Restart Klipper when the printer is idle or in error.';

  @override
  String get uiGuideStatusReadyTitle => 'Ready / complete';

  @override
  String get uiGuideStatusReadyDesc =>
      'The printer is idle, or finished its last print.';

  @override
  String get uiGuideStatusCancelledTitle => 'Cancelled';

  @override
  String get uiGuideStatusCancelledDesc => 'The last print was cancelled.';

  @override
  String get uiGuideStatusErrorTitle => 'Error';

  @override
  String get uiGuideStatusErrorDesc =>
      'Klipper reported an error — open the printer for details.';

  @override
  String get uiGuideStatusStartingTitle => 'Starting up';

  @override
  String get uiGuideStatusStartingDesc =>
      'Klipper is starting; controls appear once it\'s ready.';

  @override
  String get uiGuideOfflineTitle => 'Offline';

  @override
  String get uiGuideOfflineDesc => 'The printer can\'t be reached right now.';

  @override
  String get uiGuideNoWebcamTitle => 'No camera';

  @override
  String get uiGuideNoWebcamDesc =>
      'No webcam snapshot is available for this printer.';

  @override
  String get uiGuideBack => 'Back to dashboard';

  @override
  String get printNotifTitle => 'Print notifications';

  @override
  String get printNotifSubtitle =>
      'Live progress and status while the app is in the background';

  @override
  String get printNotifPermissionNeeded =>
      'Allow notifications to turn this on.';

  @override
  String get printNotifPromptTitle => 'Get print notifications?';

  @override
  String get printNotifPromptBody =>
      'See live status for your printers — progress, temperatures, and alerts when a print starts, finishes or errors. You can change this any time in the menu.';

  @override
  String get printNotifPromptEnable => 'Turn on';

  @override
  String get printNotifPromptNotNow => 'Not now';

  @override
  String get printNotifWatching => 'Watching your printers…';

  @override
  String get printNotifNoPrinters => 'No printers';

  @override
  String get notifPollIntervalTitle => 'Update frequency';

  @override
  String get printAlertReady => 'Printer ready';

  @override
  String get printStatusReady => 'Ready';

  @override
  String get printStatusHeating => 'Heating';

  @override
  String get printStatusIdle => 'Idle';

  @override
  String get printStatusOffline => 'Offline';

  @override
  String get printStatusPaused => 'Paused';

  @override
  String get printStatusComplete => 'Complete';

  @override
  String get printStatusCancelled => 'Cancelled';

  @override
  String get printStatusError => 'Error';

  @override
  String get printStatusStartingUp => 'Starting up';

  @override
  String get printAlertStarted => 'Started printing';

  @override
  String get printAlertResumed => 'Resumed printing';

  @override
  String get printAlertPaused => 'Print paused';

  @override
  String get printAlertComplete => 'Print complete';

  @override
  String get printAlertCancelled => 'Print cancelled';

  @override
  String get printAlertError => 'Printer error';

  @override
  String get tileOpenFiles => 'Print a file';

  @override
  String get gcodeSheetTitle => 'Start a print';

  @override
  String get gcodeLoading => 'Loading files…';

  @override
  String get gcodeEmpty => 'No G-code files on this printer';

  @override
  String get gcodeError => 'Couldn\'t load files';

  @override
  String get gcodeStartButton => 'Start print';

  @override
  String get gcodeStartAction => 'Start';

  @override
  String get gcodeConfirmTitle => 'Start print?';

  @override
  String gcodeConfirmBody(String file) {
    return 'Start printing $file?';
  }

  @override
  String gcodeStarted(String file) {
    return 'Started printing $file';
  }

  @override
  String get gcodeStartFailed => 'Couldn\'t start the print';
}
