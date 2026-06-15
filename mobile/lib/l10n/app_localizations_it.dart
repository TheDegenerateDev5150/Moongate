// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get updateNotesUnavailable =>
      'Impossibile caricare le novità — controlla la connessione o consultale su GitHub.';

  @override
  String get updateViewOnGithub => 'Vedi su GitHub';

  @override
  String get cameraConfigTooltip => 'Imposta URL della telecamera';

  @override
  String get cameraConfigTitle => 'Telecamera personalizzata';

  @override
  String get cameraConfigDescription =>
      'Mostra una telecamera non collegata a Klipper, come un vecchio telefono usato come webcam. Inserisci l\'indirizzo indicato nelle impostazioni webcam di Mainsail.';

  @override
  String get cameraConfigUrlLabel => 'URL della telecamera';

  @override
  String get cameraConfigRemoteNote =>
      'Funziona in Wi-Fi e da remoto tramite la stampante. Da remoto sono raggiungibili solo le telecamere della tua rete domestica (indirizzi privati).';

  @override
  String get cameraConfigInvalid =>
      'Inserisci un indirizzo completo, es. http://192.168.0.107:8080/video';

  @override
  String get cameraConfigUseDefault => 'Usa la telecamera Klipper';

  @override
  String get cameraConfigApply => 'Applica';

  @override
  String get dashboardShowCameraIcons => 'Icone config. telecamera';

  @override
  String get dashboardShowCameraIconsSubtitle =>
      'Mostra l\'ingranaggio su ogni telecamera per impostare un URL personalizzato';

  @override
  String get appTitle => 'Moongate';

  @override
  String get languagePickerTitle => 'Scegli la tua lingua';

  @override
  String get languagePickerSubtitle =>
      'Puoi cambiarla in qualsiasi momento dal menu.';

  @override
  String get languagePickerContinue => 'Continua';

  @override
  String get menuLanguage => 'Lingua';

  @override
  String get languageSystemDefault => 'Predefinita di sistema';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonOk => 'OK';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonDone => 'Fatto';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonShowKeyboard => 'Mostra tastiera';

  @override
  String get dashboardSignInRetrying =>
      'Riconnessione al cloud — l\'accesso è occupato, nuovo tentativo. Le tue stampanti torneranno automaticamente.';

  @override
  String get commonRemove => 'Rimuovi';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonEnable => 'Attiva';

  @override
  String get commonDisable => 'Disattiva';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsRemoveAllTitle =>
      'Rimuovi tutte le stampanti da questo dispositivo';

  @override
  String get settingsRemoveAllSubtitle =>
      'Cancella la cache locale delle stampanti. Il tuo account Supabase viene mantenuto, così il nuovo abbinamento avviene senza problemi.';

  @override
  String get settingsRemoveAllConfirmTitle => 'Rimuovere tutte le stampanti?';

  @override
  String get settingsRemoveAllConfirmBody =>
      'Tutte le stampanti abbinate verranno rimosse da questo dispositivo. Puoi aggiungerle di nuovo eseguendo MOONGATE_PAIR sulla stampante.';

  @override
  String get settingsRemoveAllConfirmAction => 'Rimuovi tutte';

  @override
  String get dashboardAddPrinter => 'Aggiungi stampante';

  @override
  String get dashboardRemovePrinter => 'Rimuovi stampante';

  @override
  String get dashboardMenuTooltip => 'Menu';

  @override
  String get dashboardRemovePrinterTitle => 'Rimuovere la stampante?';

  @override
  String dashboardRemovePrinterBody(String name) {
    return 'Rimuovere \"$name\" da Moongate?';
  }

  @override
  String get dashboardRemoveSupabaseUnreachable =>
      'Rimossa localmente, ma impossibile raggiungere Supabase. Esegui MOONGATE_RESET_OWNER sul Pi se il nuovo abbinamento non riesce.';

  @override
  String get dashboardBackUpConfig => 'Backup configurazione';

  @override
  String get dashboardBackUpConfigSubtitle =>
      'Salva su file prima di reinstallare';

  @override
  String get dashboardRestoreConfig => 'Ripristina configurazione';

  @override
  String get dashboardRestoreConfigSubtitle => 'Carica da un file di backup';

  @override
  String get dashboardThemeHeading => 'Tema';

  @override
  String get dashboardThemeSystem => 'Predefinito di sistema';

  @override
  String get dashboardThemeDark => 'Scuro';

  @override
  String get dashboardThemeLight => 'Chiaro';

  @override
  String get dashboardThemeCustom => 'Personalizzato';

  @override
  String get dashboardCustomiseColours => 'Personalizza colori';

  @override
  String get dashboardCustomiseColoursSubtitle =>
      'Modifica i cinque slot del tema — HEX o tavolozza';

  @override
  String get dashboardFontSizeHeading => 'Dimensione carattere';

  @override
  String get dashboardLayoutHeading => 'Layout dashboard';

  @override
  String dashboardColumnCount(int count) {
    return '$count col';
  }

  @override
  String get dashboardRotateWithDevice => 'Ruota con il dispositivo';

  @override
  String get dashboardRotateWithDeviceSubtitle =>
      'Sblocca l\'orientamento orizzontale';

  @override
  String get dashboardAutoArrange => 'Disponi automaticamente per stato';

  @override
  String get dashboardAutoArrangeSubtitle =>
      'Ordina i riquadri per attività. Disattiva per trascinarli nel tuo ordine.';

  @override
  String get dashboardReorderHint =>
      'Tieni premuto e trascina un riquadro per riordinare';

  @override
  String get dashboardCameraFeedHeading => 'Feed camera dashboard';

  @override
  String get dashboardCameraFeedSubtitle =>
      'Con quale frequenza i riquadri aggiornano la camera. Frequenze più basse usano molti meno dati.';

  @override
  String get dashboardAboutHeading => 'Informazioni';

  @override
  String get dashboardWhatsNew => 'Novità';

  @override
  String get dashboardWhatsNewSubtitle => 'Le modifiche recenti in breve';

  @override
  String get dashboardHowPairingWorks => 'Come funziona l\'abbinamento';

  @override
  String get dashboardHowPairingWorksSubtitle =>
      'Abbinamento, reinstallazione e ripristino';

  @override
  String get dashboardReportProblem => 'Segnala un problema';

  @override
  String get dashboardReportProblemSubtitle =>
      'Invia una segnalazione di bug o un feedback';

  @override
  String get dashboardAppLock => 'Blocco app';

  @override
  String get dashboardAppLockOn => 'Attivo — sblocco richiesto all\'avvio';

  @override
  String get dashboardAppLockOff => 'Disattivato';

  @override
  String get dashboardBuyMeCoffee => 'Offrimi un caffè';

  @override
  String get dashboardBuyMeCoffeeSubtitle =>
      'Lascia una mancia allo sviluppatore via PayPal';

  @override
  String get dashboardSettings => 'Impostazioni';

  @override
  String dashboardVersion(String version) {
    return 'Moongate v$version';
  }

  @override
  String get dashboardSaveBackupDialogTitle => 'Salva backup Moongate';

  @override
  String get dashboardBackupFailed =>
      'Backup non riuscito — impossibile salvare il file.';

  @override
  String dashboardBackupSuccess(int count) {
    return 'Backup di $count stampante/i eseguito. Questo file può ripristinarle su una nuova installazione — tienilo privato.';
  }

  @override
  String dashboardBackupSuccessListOnly(int count) {
    return 'Backup di $count stampante/i eseguito (solo elenco — impossibile raggiungere il cloud per un codice di ripristino).';
  }

  @override
  String get dashboardInvalidBackupFile =>
      'File di backup non valido — seleziona un file di configurazione Moongate.';

  @override
  String dashboardRestoreReconnected(int added, int count) {
    return '$added stampante/i ripristinata/e — $count riconnessa/e e in ritorno online.';
  }

  @override
  String dashboardRestoreNoneReconnected(int added) {
    return '$added stampante/i ripristinata/e, ma nessuna riconnessa — il codice di ripristino del backup non corrisponde ad alcuna stampante (potrebbe provenire da un backup più vecchio o essere già stato usato). Riabbinale per riportarle online.';
  }

  @override
  String dashboardRestoreListOnly(int added) {
    return '$added stampante/i ripristinata/e (solo elenco). Riabbina ogni stampante per riportarla online.';
  }

  @override
  String get dashboardRemoveSheetTitle => 'Rimuovi una stampante';

  @override
  String dashboardPrinterIdShort(String id) {
    return 'id $id…';
  }

  @override
  String get dashboardPairingHelpPairOnceTitle => 'Abbina una sola volta';

  @override
  String get dashboardPairingHelpPairOnceBody =>
      'Scansiona il QR (o inserisci il codice GATE) per aggiungere una stampante — quel collegamento viene salvato in questa app.';

  @override
  String get dashboardPairingHelpUpdatesTitle =>
      'Gli aggiornamenti dell\'app mantengono le stampanti';

  @override
  String get dashboardPairingHelpUpdatesBody =>
      'Aggiornare Moongate non richiede mai un nuovo abbinamento.';

  @override
  String get dashboardPairingHelpReinstallTitle =>
      'Reinstallazione o nuovo telefono?';

  @override
  String get dashboardPairingHelpReinstallBody =>
      'Fai prima un backup (Menu → Backup configurazione), poi Ripristina riporta le stampanti online — senza riabbinamento.';

  @override
  String get dashboardPairingHelpNoBackupTitle => 'Nessun backup?';

  @override
  String get dashboardPairingHelpNoBackupBody =>
      'Esegui MOONGATE_RESET_OWNER nella console della stampante, poi abbina di nuovo.';

  @override
  String get dashboardDontShowAgain => 'Non mostrare più';

  @override
  String dashboardUpdateAvailable(String version) {
    return 'Aggiornamento disponibile — v$version';
  }

  @override
  String get dashboardUpdateLater => 'Più tardi';

  @override
  String get dashboardUpdate => 'Aggiorna';

  @override
  String get dashboardEmptyTitle => 'Nessuna stampante ancora aggiunta';

  @override
  String get dashboardEmptyBody =>
      'Tocca il pulsante qui sotto per abbinare la tua prima stampante.';

  @override
  String get pairingTitle => 'Aggiungi stampante';

  @override
  String get pairingIntro =>
      'Esegui MOONGATE_PAIR nella console Klipper — scansiona il QR o digita il codice GATE mostrato nella console.';

  @override
  String get pairingNameLabel => 'Nome stampante';

  @override
  String get pairingNameHint => 'es. Voron 2.4';

  @override
  String get pairingScanButton => 'Scansiona codice QR';

  @override
  String get pairingScanRecommended => 'Consigliato — si connette all\'istante';

  @override
  String get pairingOr => 'OPPURE';

  @override
  String get pairingGateCodeLabel => 'Codice GATE';

  @override
  String get pairingGateCodeHint =>
      'Digita il codice a 8 cifre mostrato nella tua console Klipper.';

  @override
  String get pairingGateCodeValid => 'Il codice sembra valido ✓';

  @override
  String get pairingGateCodeWarning =>
      'Metodo alternativo. Senza il QR, la stampante può impiegare fino a circa un minuto per connettersi — sta aspettando la connessione del tunnel sicuro. Scansiona il codice QR qui sopra per una connessione istantanea.';

  @override
  String get pairingCameraPermissionNeeded =>
      'Autorizzazione fotocamera necessaria';

  @override
  String get pairingCameraUnavailable => 'Fotocamera non disponibile';

  @override
  String get pairingCancelScan => 'Annulla scansione';

  @override
  String pairingQrScanned(String code) {
    return 'QR scansionato — codice $code';
  }

  @override
  String get pairingRescan => 'Scansiona di nuovo';

  @override
  String get pairingAdvancedTitle =>
      'Avanzate — stampante su una rete personalizzata?';

  @override
  String get pairingAdvancedBody =>
      'La maggior parte delle persone può lasciare vuoto questo campo. Se la tua stampante è dietro un reverse proxy (Traefik, Caddy, NPM) o in Docker, inserisci lo stesso indirizzo che usi per aprire la sua pagina web (Mainsail / Fluidd) nel browser.';

  @override
  String get pairingAddressLabel => 'Indirizzo stampante';

  @override
  String get pairingAddressHint => '192.168.1.50:7125';

  @override
  String get pairingPairButton => 'Abbina stampante';

  @override
  String get pairingRestoreHint =>
      'Stai reinstallando? Ripristina le stampanti salvate da un file di backup. Dovrai comunque riabbinare ognuna per riportarla online.';

  @override
  String get pairingImportButton => 'Importa configurazione da file';

  @override
  String get pairingReportButton =>
      'Problemi con l\'abbinamento? Invia una segnalazione';

  @override
  String get pairingCameraPermissionTitle =>
      'Autorizzazione fotocamera richiesta';

  @override
  String get pairingCameraPermissionBody =>
      'Moongate ha bisogno dell\'accesso alla fotocamera per scansionare i codici QR.\n\nApri Impostazioni → App → Moongate → Autorizzazioni e attiva la Fotocamera, poi torna e riprova.';

  @override
  String get pairingOpenSettings => 'Apri Impostazioni';

  @override
  String get pairingErrorNotMoongateQr =>
      'Non è un codice QR Moongate. Esegui MOONGATE_PAIR sulla stampante per generarne uno.';

  @override
  String get pairingErrorOldQr =>
      'Questo codice QR proviene da una versione precedente di Moongate. Aggiorna prima il Pi alla v0.3.0.';

  @override
  String get pairingErrorNoCode =>
      'Scansiona il codice QR o digita il codice GATE dalla console della stampante.';

  @override
  String get pairingErrorBadAddress =>
      'Quell\'indirizzo della stampante non sembra corretto — prova ad es. 192.168.1.50:7125';

  @override
  String pairingErrorFailed(String error) {
    return 'Abbinamento non riuscito: $error';
  }

  @override
  String get pairingImportInvalidFile =>
      'File di backup non valido — seleziona un file di configurazione Moongate.';

  @override
  String get pairingImportNoNewPrinters =>
      'Nessuna nuova stampante trovata in quel file.';

  @override
  String pairingImportRestoredReconnected(int count, int reconnected) {
    return '$count stampante/i ripristinata/e — $reconnected riconnessa/e, in ritorno online.';
  }

  @override
  String pairingImportRestoredRepair(int count) {
    return '$count stampante/i ripristinata/e — riabbina ogni Pi per riportarlo online.';
  }

  @override
  String get customThemeTitle => 'Tema personalizzato';

  @override
  String get customThemeResetTooltip => 'Ripristina valori predefiniti';

  @override
  String get customThemeResetConfirmTitle =>
      'Ripristinare il tema personalizzato?';

  @override
  String get customThemeResetConfirmBody =>
      'Tutti e cinque gli slot dei colori verranno riportati alla tavolozza predefinita viola su sfondo scuro.';

  @override
  String get customThemeReset => 'Ripristina';

  @override
  String get customThemePreview => 'Anteprima';

  @override
  String get customThemeAccent => 'Colore principale';

  @override
  String get customThemeAccentDesc =>
      'Pulsanti, FAB, barre di avanzamento, link';

  @override
  String get customThemeBackground => 'Sfondo pagina';

  @override
  String get customThemeBackgroundDesc => 'Dietro ogni schermata';

  @override
  String get customThemeSurface => 'Schede e riquadri';

  @override
  String get customThemeSurfaceDesc =>
      'Riquadri dashboard, fogli, menu laterale';

  @override
  String get customThemeText => 'Testo';

  @override
  String get customThemeTextDesc =>
      'Testo del corpo e dei titoli sulle superfici';

  @override
  String get customThemeError => 'Errore / Stop';

  @override
  String get customThemeErrorDesc => 'Azioni distruttive, overlay di errore';

  @override
  String get customThemePresets => 'Preimpostazioni';

  @override
  String get customThemeInvalidHex => 'Non è un colore esadecimale valido';

  @override
  String get customThemeSamplePrinter => 'Stampante di esempio';

  @override
  String get customThemePrinting => 'In stampa';

  @override
  String get tilePauseFailed =>
      'Impossibile raggiungere la stampante — pausa non riuscita';

  @override
  String get tileResumeFailed =>
      'Impossibile raggiungere la stampante — ripresa non riuscita';

  @override
  String get tileStopAgainToCancel =>
      'Premi di nuovo STOP per annullare la stampa';

  @override
  String get tileLocal => 'Locale';

  @override
  String get tileTunnel => 'Tunnel';

  @override
  String get tilePrinting => 'In stampa';

  @override
  String get tilePaused => 'In pausa';

  @override
  String get tileResume => 'Riprendi';

  @override
  String get tilePause => 'Pausa';

  @override
  String get tileConfirmStop => 'Conferma stop';

  @override
  String get tileStopPrint => 'Ferma stampa';

  @override
  String get tileFirmwareRestart => 'Riavvio firmware';

  @override
  String get tilePrintComplete => 'Stampa completata';

  @override
  String get tilePrintCancelled => 'Stampa annullata';

  @override
  String get tilePrinterError => 'Errore stampante';

  @override
  String get tileKlipperStarting => 'Avvio di Klipper';

  @override
  String get tileReady => 'Pronta';

  @override
  String get tileOffline => 'Offline';

  @override
  String get tileStartingUp => 'Avvio in corso…';

  @override
  String get tileConnected => 'Connessa';

  @override
  String get tileConnecting => 'Connessione…';

  @override
  String get tilePrinterUnreachable => 'Stampante irraggiungibile';

  @override
  String get tileWaitingForHeartbeat => 'In attesa del primo heartbeat';

  @override
  String get tilePrinterIdle => 'Stampante inattiva';

  @override
  String get tileReachingPrinter => 'Contatto con la stampante';

  @override
  String get tileRemoteReady => 'Accesso remoto pronto';

  @override
  String get tileRemoteConnecting => 'Connessione remota…';

  @override
  String get tileIdle => 'Inattiva';

  @override
  String get tileDone => 'Fatto';

  @override
  String get tileCancelled => 'Annullata';

  @override
  String get tileError => 'Errore';

  @override
  String get tileStarting => 'Avvio';

  @override
  String get tileConnectingBadge => 'Connessione';

  @override
  String get appLockTitle => 'Blocco app';

  @override
  String get appLockIntro =>
      'Richiede un PIN — e facoltativamente l\'impronta digitale o il volto — prima che Moongate si apra. Il blocco compare sempre quando l\'app viene avviata da zero.';

  @override
  String get appLockSubtitle => 'PIN richiesto per aprire l\'app';

  @override
  String get appLockBiometricTitle => 'Sblocco biometrico';

  @override
  String get appLockBiometricSubtitle =>
      'Usa impronta digitale o volto — il PIN resta come riserva';

  @override
  String get appLockChangePin => 'Cambia PIN';

  @override
  String get appLockAutoLock => 'Blocco automatico';

  @override
  String get appLockPinUpdated => 'PIN aggiornato';

  @override
  String get appLockChoosePinTitle => 'Scegli un PIN';

  @override
  String get appLockChoosePinSubtitle => 'Inserisci 4–6 cifre';

  @override
  String get appLockConfirmPinTitle => 'Conferma PIN';

  @override
  String get appLockPinsDontMatch => 'I PIN non corrispondono';

  @override
  String get appLockEnterCurrentPin => 'Inserisci il PIN attuale';

  @override
  String get appLockTimeoutImmediately => 'Immediatamente';

  @override
  String get appLockTimeoutOneMinute => 'Dopo 1 minuto';

  @override
  String get appLockTimeoutFiveMinutes => 'Dopo 5 minuti';

  @override
  String get appLockTimeoutFifteenMinutes => 'Dopo 15 minuti';

  @override
  String get appLockTimeoutColdLaunch => 'Solo all\'avvio dell\'app';

  @override
  String get lockEnterPin => 'Inserisci il tuo PIN';

  @override
  String get lockSubtitle => 'Moongate è bloccata';

  @override
  String lockTooManyAttempts(int seconds) {
    return 'Troppi tentativi. Riprova tra $seconds s';
  }

  @override
  String get lockWrongPin => 'PIN errato';

  @override
  String get lockUseBiometrics => 'Usa la biometria';

  @override
  String get lockForgotPin => 'PIN dimenticato?';

  @override
  String get lockBiometricReason => 'Sblocca Moongate';

  @override
  String get lockResetTitle => 'Reimpostare Moongate?';

  @override
  String get lockResetBody =>
      'Questo rimuove il blocco app e cancella le stampanti abbinate da questo dispositivo per ricominciare da capo. Le tue stampanti non vengono eliminate — riabbinale eseguendo MOONGATE_PAIR su ciascuna.';

  @override
  String get lockResetConfirm => 'Reimposta';

  @override
  String get pinContinue => 'Continua';

  @override
  String printerStartingUpRetry(int seconds) {
    return 'La stampante si sta avviando. Nuovo tentativo tra $seconds s…';
  }

  @override
  String printerCouldNotReach(String error) {
    return 'Impossibile raggiungere la stampante: $error';
  }

  @override
  String get printerAddressCleared => 'Indirizzo personalizzato cancellato';

  @override
  String get printerAddressUpdated => 'Indirizzo stampante aggiornato';

  @override
  String printerTunnelUnreachable(String description) {
    return 'Tunnel Cloudflare irraggiungibile.\n$description';
  }

  @override
  String get printerEdit => 'Modifica stampante';

  @override
  String get printerLocalNetwork => 'Rete locale';

  @override
  String get printerTunnelVia => 'Tunnel tramite Moongate';

  @override
  String get printerCameraTooltip => 'Telecamera';

  @override
  String get cameraConnecting => 'Connessione alla telecamera…';

  @override
  String get cameraNoCamera =>
      'Nessuna telecamera configurata per questa stampante.';

  @override
  String get cameraHintBody =>
      'La webcam non si carica qui da remoto — apri la telecamera Moongate.';

  @override
  String get cameraHintOpen => 'Apri';

  @override
  String get printerUnreachable => 'Stampante irraggiungibile';

  @override
  String get printerUseTunnel => 'Usa il tunnel';

  @override
  String get printerAddressInvalid => 'Prova ad es. 192.168.1.50:7125';

  @override
  String get printerNameLabel => 'Nome stampante';

  @override
  String get printerAddressLabel => 'Indirizzo stampante (avanzato)';

  @override
  String get printerAddressHint => '192.168.1.50:7125';

  @override
  String get printerAddressHelper =>
      'Solo per configurazioni con reverse proxy / Docker. Lascia vuoto per usare il rilevamento automatico.';

  @override
  String get feedbackTitle => 'Segnala un problema';

  @override
  String get feedbackTroublePairing => 'Problemi con l\'abbinamento?';

  @override
  String get feedbackDescription =>
      'Raccontaci cosa sta succedendo. La versione dell\'app, il dispositivo, la rete e i dettagli della stampante vengono allegati automaticamente per aiutarci a individuare il problema.';

  @override
  String get feedbackPairingDescription =>
      'Descrivi cosa succede quando provi ad aggiungere la stampante. I dettagli di rete e rilevamento vengono allegati automaticamente così possiamo capire perché non si connette.';

  @override
  String get feedbackWhichPrinter => 'Quale stampante? (facoltativo)';

  @override
  String get feedbackGeneralOption =>
      'Generale / non specifico di una stampante';

  @override
  String get feedbackCommentLabel => 'Cosa è andato storto?';

  @override
  String get feedbackCommentHint =>
      'es. \"La stampante mostra Connessa / inattiva ma in realtà è pronta — si apre correttamente quando tocco il riquadro.\"';

  @override
  String get feedbackContactLabel => 'Email o contatto (facoltativo)';

  @override
  String get feedbackContactHint => 'Solo se desideri una risposta';

  @override
  String get feedbackSending => 'Invio in corso…';

  @override
  String get feedbackSend => 'Invia segnalazione';

  @override
  String get feedbackSuccess => 'Grazie — la tua segnalazione è stata inviata.';

  @override
  String get feedbackError =>
      'Invio non riuscito — controlla la connessione e riprova.';

  @override
  String get splashTagline => 'Controllo remoto Klipper';

  @override
  String get uiGuideTitle => 'Guida alle icone';

  @override
  String get uiGuideMenuSubtitle => 'Cosa significano le icone della dashboard';

  @override
  String get uiGuideIntro =>
      'Una guida rapida alle icone che vedrai nella dashboard.';

  @override
  String get uiGuideSectionConnection => 'Connessione';

  @override
  String get uiGuideSectionTemperatures => 'Temperature';

  @override
  String get uiGuideSectionControls => 'Controlli di stampa';

  @override
  String get uiGuideSectionStatus => 'Stato';

  @override
  String get uiGuideSectionWebcam => 'Camera e connessione';

  @override
  String get uiGuideLocalTitle => 'Rete locale';

  @override
  String get uiGuideLocalDesc =>
      'Connessa direttamente tramite il tuo Wi-Fi — il percorso più veloce.';

  @override
  String get uiGuideTunnelTitle => 'Remoto (tunnel)';

  @override
  String get uiGuideTunnelDesc =>
      'Connessa da qualsiasi luogo tramite il tunnel sicuro Cloudflare.';

  @override
  String get uiGuideTunnelReadyTitle => 'Remoto pronto';

  @override
  String get uiGuideTunnelReadyDesc =>
      'Il tunnel è attivo, quindi l\'accesso remoto è disponibile.';

  @override
  String get uiGuideTunnelConnectingTitle => 'Connessione remota';

  @override
  String get uiGuideTunnelConnectingDesc =>
      'Il tunnel remoto si sta ancora stabilendo.';

  @override
  String get uiGuideHotendTitle => 'Hotend / ugello';

  @override
  String get uiGuideHotendDesc => 'Temperatura attuale dell\'ugello.';

  @override
  String get uiGuideBedTitle => 'Piano riscaldato';

  @override
  String get uiGuideBedDesc => 'Temperatura attuale del piano.';

  @override
  String get uiGuideChamberTitle => 'Camera';

  @override
  String get uiGuideChamberDesc =>
      'Temperatura della camera — mostrata solo se la tua stampante ne riporta una.';

  @override
  String get uiGuideResumeTitle => 'Riprendi';

  @override
  String get uiGuideResumeDesc => 'Riprende una stampa in pausa.';

  @override
  String get uiGuidePauseTitle => 'Pausa';

  @override
  String get uiGuidePauseDesc => 'Mette in pausa la stampa corrente.';

  @override
  String get uiGuideStopTitle => 'Stop';

  @override
  String get uiGuideStopDesc =>
      'Annulla la stampa — tocca due volte per confermare.';

  @override
  String get uiGuideFirmwareRestartTitle => 'Riavvio firmware';

  @override
  String get uiGuideFirmwareRestartDesc =>
      'Riavvia Klipper quando la stampante è inattiva o in errore.';

  @override
  String get uiGuideStatusReadyTitle => 'Pronta / completata';

  @override
  String get uiGuideStatusReadyDesc =>
      'La stampante è inattiva o ha terminato l\'ultima stampa.';

  @override
  String get uiGuideStatusCancelledTitle => 'Annullata';

  @override
  String get uiGuideStatusCancelledDesc =>
      'L\'ultima stampa è stata annullata.';

  @override
  String get uiGuideStatusErrorTitle => 'Errore';

  @override
  String get uiGuideStatusErrorDesc =>
      'Klipper ha segnalato un errore — apri la stampante per i dettagli.';

  @override
  String get uiGuideStatusStartingTitle => 'Avvio in corso';

  @override
  String get uiGuideStatusStartingDesc =>
      'Klipper si sta avviando; i controlli compaiono quando è pronta.';

  @override
  String get uiGuideOfflineTitle => 'Offline';

  @override
  String get uiGuideOfflineDesc =>
      'La stampante non può essere raggiunta in questo momento.';

  @override
  String get uiGuideNoWebcamTitle => 'Nessuna camera';

  @override
  String get uiGuideNoWebcamDesc =>
      'Nessuna istantanea della webcam è disponibile per questa stampante.';

  @override
  String get uiGuideBack => 'Torna alla dashboard';

  @override
  String get printNotifTitle => 'Notifiche di stampa';

  @override
  String get printNotifSubtitle =>
      'Avanzamento e stato in tempo reale mentre l\'app è in background';

  @override
  String get printNotifPermissionNeeded =>
      'Consenti le notifiche per attivarlo.';

  @override
  String get printNotifPromptTitle => 'Ricevere le notifiche di stampa?';

  @override
  String get printNotifPromptBody =>
      'Vedi lo stato in tempo reale delle tue stampanti — avanzamento, temperature e avvisi quando una stampa inizia, finisce o va in errore. Puoi cambiarlo in qualsiasi momento dal menu.';

  @override
  String get printNotifPromptEnable => 'Attiva';

  @override
  String get printNotifPromptNotNow => 'Non ora';

  @override
  String get printNotifWatching => 'Monitoraggio delle stampanti…';

  @override
  String get printNotifNoPrinters => 'Nessuna stampante';

  @override
  String get notifPollIntervalTitle => 'Frequenza di aggiornamento';

  @override
  String get printAlertReady => 'Stampante pronta';

  @override
  String get printStatusReady => 'Pronta';

  @override
  String get printStatusHeating => 'In riscaldamento';

  @override
  String get printStatusIdle => 'Inattiva';

  @override
  String get printStatusOffline => 'Offline';

  @override
  String get printStatusPaused => 'In pausa';

  @override
  String get printStatusComplete => 'Completata';

  @override
  String get printStatusCancelled => 'Annullata';

  @override
  String get printStatusError => 'Errore';

  @override
  String get printStatusStartingUp => 'Avvio…';

  @override
  String get printAlertStarted => 'Stampa avviata';

  @override
  String get printAlertResumed => 'Stampa ripresa';

  @override
  String get printAlertPaused => 'Stampa in pausa';

  @override
  String get printAlertComplete => 'Stampa completata';

  @override
  String get printAlertCancelled => 'Stampa annullata';

  @override
  String get printAlertError => 'Errore stampante';

  @override
  String get tileOpenFiles => 'Stampa un file';

  @override
  String get gcodeSheetTitle => 'Avvia una stampa';

  @override
  String get gcodeLoading => 'Caricamento file…';

  @override
  String get gcodeEmpty => 'Nessun file G-code su questa stampante';

  @override
  String get gcodeError => 'Impossibile caricare i file';

  @override
  String get gcodeStartButton => 'Avvia stampa';

  @override
  String get gcodeStartAction => 'Avvia';

  @override
  String get gcodeConfirmTitle => 'Avviare la stampa?';

  @override
  String gcodeConfirmBody(String file) {
    return 'Stampare $file?';
  }

  @override
  String gcodeStarted(String file) {
    return 'Stampa di $file avviata';
  }

  @override
  String get gcodeStartFailed => 'Impossibile avviare la stampa';
}
