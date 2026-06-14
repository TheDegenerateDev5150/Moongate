// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Moongate';

  @override
  String get languagePickerTitle => 'Choisissez votre langue';

  @override
  String get languagePickerSubtitle =>
      'Vous pouvez la modifier à tout moment depuis le menu.';

  @override
  String get languagePickerContinue => 'Continuer';

  @override
  String get menuLanguage => 'Langue';

  @override
  String get languageSystemDefault => 'Langue du système';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonOk => 'OK';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonShowKeyboard => 'Afficher le clavier';

  @override
  String get dashboardSignInRetrying =>
      'Reconnexion au cloud — la connexion est occupée, nouvelle tentative. Vos imprimantes reviendront automatiquement.';

  @override
  String get commonRemove => 'Retirer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonEnable => 'Activer';

  @override
  String get commonDisable => 'Désactiver';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsRemoveAllTitle =>
      'Retirer toutes les imprimantes de cet appareil';

  @override
  String get settingsRemoveAllSubtitle =>
      'Vide le cache local des imprimantes. Votre compte Supabase est conservé pour que le réappairage se fasse sans difficulté.';

  @override
  String get settingsRemoveAllConfirmTitle =>
      'Retirer toutes les imprimantes ?';

  @override
  String get settingsRemoveAllConfirmBody =>
      'Toutes les imprimantes appairées seront retirées de cet appareil. Vous pourrez les rajouter en exécutant MOONGATE_PAIR sur l\'imprimante.';

  @override
  String get settingsRemoveAllConfirmAction => 'Tout retirer';

  @override
  String get dashboardAddPrinter => 'Ajouter une imprimante';

  @override
  String get dashboardRemovePrinter => 'Retirer une imprimante';

  @override
  String get dashboardMenuTooltip => 'Menu';

  @override
  String get dashboardRemovePrinterTitle => 'Retirer l\'imprimante ?';

  @override
  String dashboardRemovePrinterBody(String name) {
    return 'Retirer « $name » de Moongate ?';
  }

  @override
  String get dashboardRemoveSupabaseUnreachable =>
      'Retirée localement, mais Supabase est injoignable. Exécutez MOONGATE_RESET_OWNER sur le Pi si le réappairage échoue.';

  @override
  String get dashboardBackUpConfig => 'Sauvegarder la config';

  @override
  String get dashboardBackUpConfigSubtitle =>
      'Enregistrer dans un fichier avant de réinstaller';

  @override
  String get dashboardRestoreConfig => 'Restaurer la config';

  @override
  String get dashboardRestoreConfigSubtitle =>
      'Charger depuis un fichier de sauvegarde';

  @override
  String get dashboardThemeHeading => 'Thème';

  @override
  String get dashboardThemeSystem => 'Thème du système';

  @override
  String get dashboardThemeDark => 'Sombre';

  @override
  String get dashboardThemeLight => 'Clair';

  @override
  String get dashboardThemeCustom => 'Personnalisé';

  @override
  String get dashboardCustomiseColours => 'Personnaliser les couleurs';

  @override
  String get dashboardCustomiseColoursSubtitle =>
      'Modifier les cinq emplacements du thème — HEX ou palette';

  @override
  String get dashboardFontSizeHeading => 'Taille de police';

  @override
  String get dashboardLayoutHeading => 'Disposition du tableau de bord';

  @override
  String dashboardColumnCount(int count) {
    return '$count col.';
  }

  @override
  String get dashboardRotateWithDevice => 'Pivoter avec l\'appareil';

  @override
  String get dashboardRotateWithDeviceSubtitle =>
      'Déverrouille l\'orientation paysage';

  @override
  String get dashboardCameraFeedHeading => 'Flux caméra du tableau de bord';

  @override
  String get dashboardCameraFeedSubtitle =>
      'Fréquence de rafraîchissement de la caméra sur les tuiles. Une fréquence plus basse consomme beaucoup moins de données.';

  @override
  String get dashboardAboutHeading => 'À propos';

  @override
  String get dashboardWhatsNew => 'Nouveautés';

  @override
  String get dashboardWhatsNewSubtitle =>
      'Les changements récents en un coup d\'œil';

  @override
  String get dashboardHowPairingWorks => 'Comment fonctionne l\'appairage';

  @override
  String get dashboardHowPairingWorksSubtitle =>
      'Appairage, réinstallation et restauration';

  @override
  String get dashboardReportProblem => 'Signaler un problème';

  @override
  String get dashboardReportProblemSubtitle =>
      'Envoyer un rapport de bug ou un retour';

  @override
  String get dashboardAppLock => 'Verrouillage de l\'app';

  @override
  String get dashboardAppLockOn =>
      'Activé — déverrouillage requis au lancement';

  @override
  String get dashboardAppLockOff => 'Désactivé';

  @override
  String get dashboardBuyMeCoffee => 'Offrez-moi un café';

  @override
  String get dashboardBuyMeCoffeeSubtitle =>
      'Soutenez le développeur via PayPal';

  @override
  String get dashboardSettings => 'Paramètres';

  @override
  String dashboardVersion(String version) {
    return 'Moongate v$version';
  }

  @override
  String get dashboardSaveBackupDialogTitle =>
      'Enregistrer la sauvegarde Moongate';

  @override
  String get dashboardBackupFailed =>
      'Échec de la sauvegarde — impossible d\'enregistrer le fichier.';

  @override
  String dashboardBackupSuccess(int count) {
    return '$count imprimante(s) sauvegardée(s). Ce fichier permet de les restaurer sur une nouvelle installation — gardez-le confidentiel.';
  }

  @override
  String dashboardBackupSuccessListOnly(int count) {
    return '$count imprimante(s) sauvegardée(s) (liste uniquement — le cloud était injoignable pour générer un code de restauration).';
  }

  @override
  String get dashboardInvalidBackupFile =>
      'Fichier de sauvegarde non valide — veuillez choisir un fichier de config Moongate.';

  @override
  String dashboardRestoreReconnected(int added, int count) {
    return '$added imprimante(s) restaurée(s) — $count reconnectée(s) et bientôt en ligne.';
  }

  @override
  String dashboardRestoreNoneReconnected(int added) {
    return '$added imprimante(s) restaurée(s), mais aucune reconnectée — le code de restauration de la sauvegarde ne correspond à aucune imprimante (il provient peut-être d\'une ancienne sauvegarde, ou a déjà été utilisé). Réappairez-les pour les remettre en ligne.';
  }

  @override
  String dashboardRestoreListOnly(int added) {
    return '$added imprimante(s) restaurée(s) (liste uniquement). Réappairez chaque imprimante pour la remettre en ligne.';
  }

  @override
  String get dashboardRemoveSheetTitle => 'Retirer une imprimante';

  @override
  String dashboardPrinterIdShort(String id) {
    return 'id $id…';
  }

  @override
  String get dashboardPairingHelpPairOnceTitle => 'Appairer une seule fois';

  @override
  String get dashboardPairingHelpPairOnceBody =>
      'Scannez le QR (ou saisissez le code GATE) pour ajouter une imprimante — ce lien est enregistré dans cette app.';

  @override
  String get dashboardPairingHelpUpdatesTitle =>
      'Les mises à jour conservent vos imprimantes';

  @override
  String get dashboardPairingHelpUpdatesBody =>
      'Mettre à jour Moongate ne nécessite jamais de réappairage.';

  @override
  String get dashboardPairingHelpReinstallTitle =>
      'Réinstallation ou nouveau téléphone ?';

  @override
  String get dashboardPairingHelpReinstallBody =>
      'Sauvegardez d\'abord (Menu → Sauvegarder la config), puis Restaurer remet vos imprimantes en ligne — sans réappairage.';

  @override
  String get dashboardPairingHelpNoBackupTitle => 'Pas de sauvegarde ?';

  @override
  String get dashboardPairingHelpNoBackupBody =>
      'Exécutez MOONGATE_RESET_OWNER dans la console de l\'imprimante, puis appairez à nouveau.';

  @override
  String get dashboardDontShowAgain => 'Ne plus afficher';

  @override
  String dashboardUpdateAvailable(String version) {
    return 'Mise à jour disponible — v$version';
  }

  @override
  String get dashboardUpdateLater => 'Plus tard';

  @override
  String get dashboardUpdate => 'Mettre à jour';

  @override
  String get dashboardEmptyTitle => 'Aucune imprimante ajoutée';

  @override
  String get dashboardEmptyBody =>
      'Touchez le bouton ci-dessous pour appairer votre première imprimante.';

  @override
  String get pairingTitle => 'Ajouter une imprimante';

  @override
  String get pairingIntro =>
      'Exécutez MOONGATE_PAIR dans votre console Klipper — scannez le QR ou saisissez le code GATE affiché dans la console.';

  @override
  String get pairingNameLabel => 'Nom de l\'imprimante';

  @override
  String get pairingNameHint => 'ex. Voron 2.4';

  @override
  String get pairingScanButton => 'Scanner le QR code';

  @override
  String get pairingScanRecommended => 'Recommandé — connexion instantanée';

  @override
  String get pairingOr => 'OU';

  @override
  String get pairingGateCodeLabel => 'Code GATE';

  @override
  String get pairingGateCodeHint =>
      'Saisissez le code à 8 chiffres affiché dans votre console Klipper.';

  @override
  String get pairingGateCodeValid => 'Le code semble valide ✓';

  @override
  String get pairingGateCodeWarning =>
      'Méthode alternative. Sans le QR, l\'imprimante peut mettre jusqu\'à une minute environ à se connecter — elle attend l\'établissement du tunnel sécurisé. Scannez le QR code ci-dessus pour une connexion instantanée.';

  @override
  String get pairingCameraPermissionNeeded => 'Autorisation caméra requise';

  @override
  String get pairingCameraUnavailable => 'Caméra indisponible';

  @override
  String get pairingCancelScan => 'Annuler le scan';

  @override
  String pairingQrScanned(String code) {
    return 'QR scanné — code $code';
  }

  @override
  String get pairingRescan => 'Rescanner';

  @override
  String get pairingAdvancedTitle =>
      'Avancé — imprimante sur un réseau personnalisé ?';

  @override
  String get pairingAdvancedBody =>
      'La plupart des utilisateurs peuvent laisser ce champ vide. Si votre imprimante est derrière un reverse proxy (Traefik, Caddy, NPM) ou dans Docker, saisissez l\'adresse que vous utilisez pour ouvrir sa page web (Mainsail / Fluidd) dans un navigateur.';

  @override
  String get pairingAddressLabel => 'Adresse de l\'imprimante';

  @override
  String get pairingAddressHint => '192.168.1.50:7125';

  @override
  String get pairingPairButton => 'Appairer l\'imprimante';

  @override
  String get pairingRestoreHint =>
      'Réinstallation ? Restaurez vos imprimantes enregistrées depuis un fichier de sauvegarde. Vous devrez tout de même réappairer chacune pour la remettre en ligne.';

  @override
  String get pairingImportButton => 'Importer la config depuis un fichier';

  @override
  String get pairingReportButton =>
      'Problème d\'appairage ? Envoyer un rapport';

  @override
  String get pairingCameraPermissionTitle => 'Autorisation caméra requise';

  @override
  String get pairingCameraPermissionBody =>
      'Moongate a besoin d\'accéder à la caméra pour scanner les QR codes.\n\nOuvrez Paramètres → Applications → Moongate → Autorisations et activez Caméra, puis revenez et réessayez.';

  @override
  String get pairingOpenSettings => 'Ouvrir les paramètres';

  @override
  String get pairingErrorNotMoongateQr =>
      'Ce n\'est pas un QR code Moongate. Exécutez MOONGATE_PAIR sur l\'imprimante pour en générer un.';

  @override
  String get pairingErrorOldQr =>
      'Ce QR code provient d\'une ancienne version de Moongate. Mettez d\'abord le Pi à jour vers la v0.3.0.';

  @override
  String get pairingErrorNoCode =>
      'Scannez le QR code, ou saisissez le code GATE depuis la console de l\'imprimante.';

  @override
  String get pairingErrorBadAddress =>
      'Cette adresse d\'imprimante semble incorrecte — essayez par ex. 192.168.1.50:7125';

  @override
  String pairingErrorFailed(String error) {
    return 'Échec de l\'appairage : $error';
  }

  @override
  String get pairingImportInvalidFile =>
      'Fichier de sauvegarde non valide — veuillez choisir un fichier de config Moongate.';

  @override
  String get pairingImportNoNewPrinters =>
      'Aucune nouvelle imprimante trouvée dans ce fichier.';

  @override
  String pairingImportRestoredReconnected(int count, int reconnected) {
    return '$count imprimante(s) restaurée(s) — $reconnected reconnectée(s), bientôt en ligne.';
  }

  @override
  String pairingImportRestoredRepair(int count) {
    return '$count imprimante(s) restaurée(s) — réappairez chaque Pi pour le remettre en ligne.';
  }

  @override
  String get customThemeTitle => 'Thème personnalisé';

  @override
  String get customThemeResetTooltip => 'Réinitialiser aux valeurs par défaut';

  @override
  String get customThemeResetConfirmTitle =>
      'Réinitialiser le thème personnalisé ?';

  @override
  String get customThemeResetConfirmBody =>
      'Les cinq emplacements de couleur seront rétablis à la palette violet sur fond sombre par défaut.';

  @override
  String get customThemeReset => 'Réinitialiser';

  @override
  String get customThemePreview => 'Aperçu';

  @override
  String get customThemeAccent => 'Accent';

  @override
  String get customThemeAccentDesc =>
      'Boutons, FAB, barres de progression, liens';

  @override
  String get customThemeBackground => 'Arrière-plan des pages';

  @override
  String get customThemeBackgroundDesc => 'Derrière chaque écran';

  @override
  String get customThemeSurface => 'Cartes et tuiles';

  @override
  String get customThemeSurfaceDesc =>
      'Tuiles du tableau de bord, feuilles, menu latéral';

  @override
  String get customThemeText => 'Texte';

  @override
  String get customThemeTextDesc =>
      'Texte du corps et des titres sur les surfaces';

  @override
  String get customThemeError => 'Erreur / Arrêt';

  @override
  String get customThemeErrorDesc =>
      'Actions destructrices, superpositions d\'erreur';

  @override
  String get customThemePresets => 'Préréglages';

  @override
  String get customThemeInvalidHex => 'Couleur hexadécimale non valide';

  @override
  String get customThemeSamplePrinter => 'Imprimante d\'exemple';

  @override
  String get customThemePrinting => 'Impression';

  @override
  String get tilePauseFailed =>
      'Imprimante injoignable — échec de la mise en pause';

  @override
  String get tileResumeFailed => 'Imprimante injoignable — échec de la reprise';

  @override
  String get tileStopAgainToCancel =>
      'Appuyez à nouveau sur STOP pour annuler l\'impression';

  @override
  String get tileLocal => 'Local';

  @override
  String get tileTunnel => 'Tunnel';

  @override
  String get tilePrinting => 'Impression';

  @override
  String get tilePaused => 'En pause';

  @override
  String get tileResume => 'Reprendre';

  @override
  String get tilePause => 'Pause';

  @override
  String get tileConfirmStop => 'Confirmer l\'arrêt';

  @override
  String get tileStopPrint => 'Arrêter l\'impression';

  @override
  String get tileFirmwareRestart => 'Redémarrage du firmware';

  @override
  String get tilePrintComplete => 'Impression terminée';

  @override
  String get tilePrintCancelled => 'Impression annulée';

  @override
  String get tilePrinterError => 'Erreur de l\'imprimante';

  @override
  String get tileKlipperStarting => 'Démarrage de Klipper';

  @override
  String get tileReady => 'Prête';

  @override
  String get tileOffline => 'Hors ligne';

  @override
  String get tileStartingUp => 'Démarrage…';

  @override
  String get tileConnected => 'Connectée';

  @override
  String get tileConnecting => 'Connexion…';

  @override
  String get tilePrinterUnreachable => 'Imprimante injoignable';

  @override
  String get tileWaitingForHeartbeat => 'En attente du premier signal';

  @override
  String get tilePrinterIdle => 'Imprimante inactive';

  @override
  String get tileReachingPrinter => 'Connexion à l\'imprimante';

  @override
  String get tileRemoteReady => 'Accès distant prêt';

  @override
  String get tileRemoteConnecting => 'Connexion distante…';

  @override
  String get tileIdle => 'Inactive';

  @override
  String get tileDone => 'Terminée';

  @override
  String get tileCancelled => 'Annulée';

  @override
  String get tileError => 'Erreur';

  @override
  String get tileStarting => 'Démarrage';

  @override
  String get tileConnectingBadge => 'Connexion';

  @override
  String get appLockTitle => 'Verrouillage de l\'app';

  @override
  String get appLockIntro =>
      'Exiger un code PIN — et éventuellement votre empreinte ou votre visage — avant l\'ouverture de Moongate. Le verrouillage apparaît toujours lorsque l\'app est lancée à neuf.';

  @override
  String get appLockSubtitle => 'Code PIN requis pour ouvrir l\'app';

  @override
  String get appLockBiometricTitle => 'Déverrouillage biométrique';

  @override
  String get appLockBiometricSubtitle =>
      'Utiliser l\'empreinte ou le visage — le PIN reste un recours';

  @override
  String get appLockChangePin => 'Modifier le code PIN';

  @override
  String get appLockAutoLock => 'Verrouillage automatique';

  @override
  String get appLockPinUpdated => 'Code PIN mis à jour';

  @override
  String get appLockChoosePinTitle => 'Choisir un code PIN';

  @override
  String get appLockChoosePinSubtitle => 'Saisissez 4 à 6 chiffres';

  @override
  String get appLockConfirmPinTitle => 'Confirmer le code PIN';

  @override
  String get appLockPinsDontMatch => 'Les codes PIN ne correspondent pas';

  @override
  String get appLockEnterCurrentPin => 'Saisir le code PIN actuel';

  @override
  String get appLockTimeoutImmediately => 'Immédiatement';

  @override
  String get appLockTimeoutOneMinute => 'Après 1 minute';

  @override
  String get appLockTimeoutFiveMinutes => 'Après 5 minutes';

  @override
  String get appLockTimeoutFifteenMinutes => 'Après 15 minutes';

  @override
  String get appLockTimeoutColdLaunch => 'Uniquement au lancement de l\'app';

  @override
  String get lockEnterPin => 'Saisissez votre code PIN';

  @override
  String get lockSubtitle => 'Moongate est verrouillé';

  @override
  String lockTooManyAttempts(int seconds) {
    return 'Trop de tentatives. Réessayez dans $seconds s';
  }

  @override
  String get lockWrongPin => 'Code PIN incorrect';

  @override
  String get lockUseBiometrics => 'Utiliser la biométrie';

  @override
  String get lockForgotPin => 'Code PIN oublié ?';

  @override
  String get lockBiometricReason => 'Déverrouiller Moongate';

  @override
  String get lockResetTitle => 'Réinitialiser Moongate ?';

  @override
  String get lockResetBody =>
      'Cela supprime le verrouillage de l\'app et efface les imprimantes appairées de cet appareil pour repartir de zéro. Vos imprimantes ne sont pas supprimées — réappairez-les en exécutant MOONGATE_PAIR sur chacune.';

  @override
  String get lockResetConfirm => 'Réinitialiser';

  @override
  String get pinContinue => 'Continuer';

  @override
  String printerStartingUpRetry(int seconds) {
    return 'L\'imprimante démarre. Nouvelle tentative dans $seconds s…';
  }

  @override
  String printerCouldNotReach(String error) {
    return 'Imprimante injoignable : $error';
  }

  @override
  String get printerAddressCleared => 'Adresse personnalisée effacée';

  @override
  String get printerAddressUpdated => 'Adresse de l\'imprimante mise à jour';

  @override
  String printerTunnelUnreachable(String description) {
    return 'Tunnel Cloudflare injoignable.\n$description';
  }

  @override
  String get printerEdit => 'Modifier l\'imprimante';

  @override
  String get printerLocalNetwork => 'Réseau local';

  @override
  String get printerTunnelVia => 'Tunnel via Moongate';

  @override
  String get printerUnreachable => 'Imprimante injoignable';

  @override
  String get printerUseTunnel => 'Utiliser le tunnel';

  @override
  String get printerAddressInvalid => 'Essayez par ex. 192.168.1.50:7125';

  @override
  String get printerNameLabel => 'Nom de l\'imprimante';

  @override
  String get printerAddressLabel => 'Adresse de l\'imprimante (avancé)';

  @override
  String get printerAddressHint => '192.168.1.50:7125';

  @override
  String get printerAddressHelper =>
      'Uniquement pour les configurations reverse proxy / Docker. Laissez vide pour utiliser la découverte automatique.';

  @override
  String get feedbackTitle => 'Signaler un problème';

  @override
  String get feedbackTroublePairing => 'Problème d\'appairage ?';

  @override
  String get feedbackDescription =>
      'Dites-nous ce qui se passe. La version de votre app, votre appareil, votre réseau et les détails de l\'imprimante sont joints automatiquement pour nous aider à identifier le problème.';

  @override
  String get feedbackPairingDescription =>
      'Décrivez ce qui se passe lorsque vous essayez d\'ajouter l\'imprimante. Vos détails de réseau et de découverte sont joints automatiquement afin que nous puissions voir pourquoi la connexion échoue.';

  @override
  String get feedbackWhichPrinter => 'Quelle imprimante ? (facultatif)';

  @override
  String get feedbackGeneralOption => 'Général / non lié à une imprimante';

  @override
  String get feedbackCommentLabel => 'Qu\'est-ce qui n\'a pas fonctionné ?';

  @override
  String get feedbackCommentHint =>
      'ex. « L\'imprimante affiche Connectée / inactive mais elle est en réalité prête — elle s\'ouvre normalement quand je touche la tuile. »';

  @override
  String get feedbackContactLabel => 'E-mail ou contact (facultatif)';

  @override
  String get feedbackContactHint => 'Uniquement si vous souhaitez une réponse';

  @override
  String get feedbackSending => 'Envoi…';

  @override
  String get feedbackSend => 'Envoyer le rapport';

  @override
  String get feedbackSuccess => 'Merci — votre rapport a été envoyé.';

  @override
  String get feedbackError =>
      'Envoi impossible — vérifiez votre connexion et réessayez.';

  @override
  String get splashTagline => 'Contrôle à distance pour Klipper';

  @override
  String get uiGuideTitle => 'Guide des icônes';

  @override
  String get uiGuideMenuSubtitle =>
      'La signification des icônes du tableau de bord';

  @override
  String get uiGuideIntro =>
      'Un guide rapide des icônes que vous verrez sur le tableau de bord.';

  @override
  String get uiGuideSectionConnection => 'Connexion';

  @override
  String get uiGuideSectionTemperatures => 'Températures';

  @override
  String get uiGuideSectionControls => 'Commandes d\'impression';

  @override
  String get uiGuideSectionStatus => 'État';

  @override
  String get uiGuideSectionWebcam => 'Caméra et connexion';

  @override
  String get uiGuideLocalTitle => 'Réseau local';

  @override
  String get uiGuideLocalDesc =>
      'Connecté directement via votre Wi-Fi — le chemin le plus rapide.';

  @override
  String get uiGuideTunnelTitle => 'À distance (tunnel)';

  @override
  String get uiGuideTunnelDesc =>
      'Connecté depuis n\'importe où via le tunnel Cloudflare sécurisé.';

  @override
  String get uiGuideTunnelReadyTitle => 'Accès distant prêt';

  @override
  String get uiGuideTunnelReadyDesc =>
      'Le tunnel est actif, l\'accès distant est donc disponible.';

  @override
  String get uiGuideTunnelConnectingTitle => 'Connexion distante';

  @override
  String get uiGuideTunnelConnectingDesc =>
      'Le tunnel distant est encore en cours d\'établissement.';

  @override
  String get uiGuideHotendTitle => 'Tête chauffante / buse';

  @override
  String get uiGuideHotendDesc => 'Température actuelle de la buse.';

  @override
  String get uiGuideBedTitle => 'Plateau chauffant';

  @override
  String get uiGuideBedDesc => 'Température actuelle du plateau.';

  @override
  String get uiGuideChamberTitle => 'Caisson';

  @override
  String get uiGuideChamberDesc =>
      'Température du caisson — affichée uniquement si votre imprimante en signale une.';

  @override
  String get uiGuideResumeTitle => 'Reprendre';

  @override
  String get uiGuideResumeDesc => 'Reprendre une impression en pause.';

  @override
  String get uiGuidePauseTitle => 'Pause';

  @override
  String get uiGuidePauseDesc => 'Mettre l\'impression en cours en pause.';

  @override
  String get uiGuideStopTitle => 'Arrêter';

  @override
  String get uiGuideStopDesc =>
      'Annuler l\'impression — touchez deux fois pour confirmer.';

  @override
  String get uiGuideFirmwareRestartTitle => 'Redémarrage du firmware';

  @override
  String get uiGuideFirmwareRestartDesc =>
      'Redémarrer Klipper lorsque l\'imprimante est inactive ou en erreur.';

  @override
  String get uiGuideStatusReadyTitle => 'Prête / terminée';

  @override
  String get uiGuideStatusReadyDesc =>
      'L\'imprimante est inactive, ou a terminé sa dernière impression.';

  @override
  String get uiGuideStatusCancelledTitle => 'Annulée';

  @override
  String get uiGuideStatusCancelledDesc =>
      'La dernière impression a été annulée.';

  @override
  String get uiGuideStatusErrorTitle => 'Erreur';

  @override
  String get uiGuideStatusErrorDesc =>
      'Klipper a signalé une erreur — ouvrez l\'imprimante pour plus de détails.';

  @override
  String get uiGuideStatusStartingTitle => 'Démarrage';

  @override
  String get uiGuideStatusStartingDesc =>
      'Klipper démarre ; les commandes apparaissent une fois qu\'il est prêt.';

  @override
  String get uiGuideOfflineTitle => 'Hors ligne';

  @override
  String get uiGuideOfflineDesc =>
      'L\'imprimante est injoignable pour le moment.';

  @override
  String get uiGuideNoWebcamTitle => 'Pas de caméra';

  @override
  String get uiGuideNoWebcamDesc =>
      'Aucun instantané de webcam n\'est disponible pour cette imprimante.';

  @override
  String get uiGuideBack => 'Retour au tableau de bord';

  @override
  String get printNotifTitle => 'Notifications d\'impression';

  @override
  String get printNotifSubtitle =>
      'Progression et statut en direct lorsque l\'application est en arrière-plan';

  @override
  String get printNotifPermissionNeeded =>
      'Autorisez les notifications pour activer ceci.';

  @override
  String get printNotifPromptTitle =>
      'Recevoir les notifications d\'impression ?';

  @override
  String get printNotifPromptBody =>
      'Voyez le statut en direct de vos imprimantes — progression, températures et alertes au démarrage, à la fin ou en cas d\'erreur d\'une impression. Vous pouvez changer cela à tout moment dans le menu.';

  @override
  String get printNotifPromptEnable => 'Activer';

  @override
  String get printNotifPromptNotNow => 'Plus tard';

  @override
  String get printNotifWatching => 'Surveillance de vos imprimantes…';

  @override
  String get printNotifNoPrinters => 'Aucune imprimante';

  @override
  String get notifPollIntervalTitle => 'Fréquence de mise à jour';

  @override
  String get printAlertReady => 'Imprimante prête';

  @override
  String get printStatusReady => 'Prête';

  @override
  String get printStatusHeating => 'Chauffe';

  @override
  String get printStatusIdle => 'Inactive';

  @override
  String get printStatusOffline => 'Hors ligne';

  @override
  String get printStatusPaused => 'En pause';

  @override
  String get printStatusComplete => 'Terminée';

  @override
  String get printStatusCancelled => 'Annulée';

  @override
  String get printStatusError => 'Erreur';

  @override
  String get printStatusStartingUp => 'Démarrage…';

  @override
  String get printAlertStarted => 'Impression démarrée';

  @override
  String get printAlertResumed => 'Impression reprise';

  @override
  String get printAlertPaused => 'Impression en pause';

  @override
  String get printAlertComplete => 'Impression terminée';

  @override
  String get printAlertCancelled => 'Impression annulée';

  @override
  String get printAlertError => 'Erreur d\'imprimante';

  @override
  String get tileOpenFiles => 'Imprimer un fichier';

  @override
  String get gcodeSheetTitle => 'Démarrer une impression';

  @override
  String get gcodeLoading => 'Chargement des fichiers…';

  @override
  String get gcodeEmpty => 'Aucun fichier G-code sur cette imprimante';

  @override
  String get gcodeError => 'Impossible de charger les fichiers';

  @override
  String get gcodeStartButton => 'Lancer l\'impression';

  @override
  String get gcodeStartAction => 'Démarrer';

  @override
  String get gcodeConfirmTitle => 'Lancer l\'impression ?';

  @override
  String gcodeConfirmBody(String file) {
    return 'Lancer l\'impression de $file ?';
  }

  @override
  String gcodeStarted(String file) {
    return 'Impression de $file lancée';
  }

  @override
  String get gcodeStartFailed => 'Impossible de lancer l\'impression';
}
