// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get updateDownloading => 'Baixando atualizaÃ§Ã£oâ€¦';

  @override
  String get updateOpeningInstaller => 'Abrindo o instaladorâ€¦';

  @override
  String get updateFailed =>
      'NÃ£o foi possÃ­vel concluir a atualizaÃ§Ã£o automaticamente.';

  @override
  String get updateOpenInBrowser => 'Abrir no navegador';

  @override
  String get lightingTitle => 'IluminaÃ§Ã£o';

  @override
  String get lightingMenuSubtitle =>
      'Controle a luz das suas impressoras a partir do painel';

  @override
  String get lightingBanner =>
      'Escolha quais impressoras tÃªm uma luz que vocÃª pode controlar. Para cada uma, ative e defina um par de macros de Ligar + Desligar, ou uma Ãºnica macro de Alternar. Opcionalmente, escolha uma fonte de estado para que a lÃ¢mpada mostre o estado real.';

  @override
  String get lightingNoPrinters =>
      'Ainda nÃ£o hÃ¡ impressoras para configurar.';

  @override
  String get lightingShowOnTile => 'Mostrar no cartÃ£o';

  @override
  String get lightingNeedMacro =>
      'Defina um par de Ligar + Desligar ou uma macro de Alternar para ativar.';

  @override
  String get lightingLoadFailed =>
      'NÃ£o foi possÃ­vel carregar as macros desta impressora (ela pode estar offline). Digite os nomes manualmente abaixo.';

  @override
  String get lightingOnMacro => 'Macro de luz LIGADA';

  @override
  String get lightingOffMacro => 'Macro de luz DESLIGADA';

  @override
  String get lightingToggleMacro => 'Macro de alternar';

  @override
  String get lightingToggleSection => 'Opcional - mÃ©todo de alternar';

  @override
  String get lightingStatusSource => 'Fonte de estado da luz';

  @override
  String get lightingStatusSourceHelp =>
      'Opcional. O objeto do Klipper que relata o estado da luz - p. ex., output_pin caselight (nÃ£o um pino bruto como PE3). Deixe em branco para apenas seguir seus toques.';

  @override
  String get lightingStatusHint => 'Exemplo: output_pin caselight';

  @override
  String get lightingNotSet => 'NÃ£o definido';

  @override
  String get lightingPickMacro => 'Selecione uma macro';

  @override
  String get lightingPickStatusSource => 'Selecione o pino de estado da luz';

  @override
  String get lightingManualHint => 'Digite o nome exato';

  @override
  String get lightingClear => 'Limpar';

  @override
  String get lightTurnOn => 'Ligar a luz';

  @override
  String get lightTurnOff => 'Desligar a luz';

  @override
  String get lightToggleFailed => 'NÃ£o foi possÃ­vel conectar Ã  impressora';

  @override
  String get powerTurnOn => 'Ligar';

  @override
  String get powerTurnOff => 'Desligar';

  @override
  String powerConfirmOn(String name) {
    return 'Ligar $name?';
  }

  @override
  String powerConfirmOff(String name) {
    return 'Desligar $name?';
  }

  @override
  String get powerToggleFailed =>
      'NÃ£o foi possÃ­vel alterar a energia da impressora';

  @override
  String get powerLockedWhilePrinting =>
      'NÃ£o Ã© possÃ­vel desligar enquanto imprime';

  @override
  String get globalPowerButtonTitle => 'BotÃ£o de energia global';

  @override
  String get globalPowerButtonSubtitle =>
      'Um botÃ£o na barra superior para ligar ou desligar toda a sua frota';

  @override
  String get globalPowerTooltip => 'Ligar/desligar todas as mÃ¡quinas';

  @override
  String get globalPowerSheetTitle => 'Ligar/desligar todas as mÃ¡quinas';

  @override
  String get globalPowerOnAll => 'Ligar todas';

  @override
  String get globalPowerSlideOff => 'deslize para desligar todas';

  @override
  String get globalPowerConfirmOnTitle => 'Ligar todas as mÃ¡quinas?';

  @override
  String get globalPowerConfirmOnBody =>
      'Isso liga todas as mÃ¡quinas que podemos alcanÃ§ar.';

  @override
  String get globalPowerPrintingNote =>
      'MÃ¡quinas que estÃ£o imprimindo sÃ£o mantidas ligadas';

  @override
  String get globalPowerStateWillSwitchOff => 'serÃ¡ desligada';

  @override
  String get globalPowerStateKeptPrinting => 'imprimindo, mantida ligada';

  @override
  String get globalPowerStateOffline => 'offline, ignorada';

  @override
  String get globalPowerStateOnOff => 'ligar / desligar';

  @override
  String get globalPowerStateOffOnly => 'apenas desligar';

  @override
  String get globalPowerStateOnOnly => 'apenas ligar';

  @override
  String get globalPowerStateToggleOnly => 'apenas alternar';

  @override
  String get globalPowerNothing =>
      'Nenhuma mÃ¡quina tem controle de energia configurado ainda';

  @override
  String globalPowerResultOn(int count, int total) {
    return 'Ligou $count de $total mÃ¡quinas';
  }

  @override
  String globalPowerResultOff(int count, int total) {
    return 'Desligou $count de $total mÃ¡quinas';
  }

  @override
  String get powerScreenTitle => 'Interruptor de energia avanÃ§ado';

  @override
  String get powerScreenBanner =>
      'Para impressoras cuja energia Ã© uma macro do Klipper em vez de um dispositivo de energia do Moonraker. Ative e defina uma macro de Desligar (o caso comum), uma macro de Ligar, ambas, ou uma Ãºnica de alternar. O botÃ£o de energia do cartÃ£o usa qualquer uma delas.';

  @override
  String get powerUseSwitch => 'Usar macros';

  @override
  String get powerNeedMacro =>
      'Defina pelo menos uma macro: uma macro de Desligar (ou Ligar), ou de alternar.';

  @override
  String get powerOnMacro => 'Macro de Ligar';

  @override
  String get powerOffMacro => 'Macro de Desligar';

  @override
  String get powerToggleSection => 'Ou uma Ãºnica macro de alternar';

  @override
  String get powerToggleMacro => 'Macro de alternar energia';

  @override
  String get powerToggleBulkNote =>
      'Uma macro de alternar aciona o botÃ£o de energia do cartÃ£o. Para Ligar/desligar todas as mÃ¡quinas, defina uma macro de Ligar e/ou Desligar.';

  @override
  String get powerMenuTitle => 'Interruptor de energia avanÃ§ado';

  @override
  String get powerMenuSubtitle =>
      'Controle a energia da impressora com uma macro';

  @override
  String get powerMacroTooltip => 'Energia';

  @override
  String powerMacroToggleConfirm(String name) {
    return 'Alternar a energia de $name?';
  }

  @override
  String powerMacroChooseTitle(String name) {
    return 'Alternar a energia de $name';
  }

  @override
  String lightChooseTitle(String name) {
    return 'Alternar a luz de $name';
  }

  @override
  String get tileOpacityTitle => 'Opacidade do cartÃ£o';

  @override
  String get tileOpacityDesc =>
      'O quÃ£o transparentes os cartÃµes sÃ£o (0-100), para que o fundo apareÃ§a. A transmissÃ£o da cÃ¢mera permanece sÃ³lida.';

  @override
  String get dashboardShowWebcams => 'Webcams';

  @override
  String get dashboardShowWebcamsSubtitle =>
      'Mostrar ou ocultar a webcam de cada impressora';

  @override
  String get updateNotesUnavailable =>
      'NÃ£o foi possÃ­vel carregar as novidades - verifique sua conexÃ£o ou veja no GitHub.';

  @override
  String get updateViewOnGithub => 'Ver no GitHub';

  @override
  String get cameraConfigTooltip => 'Definir URL da cÃ¢mera';

  @override
  String get cameraConfigTitle => 'CÃ¢mera personalizada';

  @override
  String get cameraConfigDescription =>
      'Mostra uma cÃ¢mera que nÃ£o estÃ¡ conectada ao Klipper - como um telefone antigo usado como webcam. Digite o endereÃ§o mostrado nas configuraÃ§Ãµes de webcam do Mainsail.';

  @override
  String get cameraConfigUrlLabel => 'URL da cÃ¢mera';

  @override
  String get cameraConfigRemoteNote =>
      'Funciona no Wi-Fi e remotamente atravÃ©s da sua impressora. Apenas cÃ¢meras na sua rede domÃ©stica (endereÃ§os privados) podem ser acessadas remotamente.';

  @override
  String get cameraConfigInvalid =>
      'Digite um endereÃ§o completo, p. ex., http://192.168.0.107:8080/video';

  @override
  String get cameraConfigUseDefault => 'Usar cÃ¢mera do Klipper';

  @override
  String get cameraConfigApply => 'Aplicar';

  @override
  String get dashboardShowCameraIcons => 'Ãcones de config. de cÃ¢mera';

  @override
  String get dashboardShowCameraIconsSubtitle =>
      'Mostrar a engrenagem em cada cÃ¢mera para definir uma URL personalizada';

  @override
  String get appTitle => 'Moongate';

  @override
  String get languagePickerTitle => 'Escolha o seu idioma';

  @override
  String get languagePickerSubtitle =>
      'VocÃª pode alterar isso a qualquer momento pelo menu.';

  @override
  String get languagePickerContinue => 'Continuar';

  @override
  String get menuLanguage => 'Idioma';

  @override
  String get languageSystemDefault => 'PadrÃ£o do sistema';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonOk => 'OK';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonDone => 'ConcluÃ­do';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonShowKeyboard => 'Mostrar teclado';

  @override
  String get dashboardSignInRetrying =>
      'Reconectando Ã  nuvem - o login estÃ¡ ocupado, tentando novamente. Suas impressoras voltarÃ£o automaticamente.';

  @override
  String get commonRemove => 'Remover';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonEnable => 'Ativar';

  @override
  String get commonDisable => 'Desativar';

  @override
  String get settingsTitle => 'ConfiguraÃ§Ãµes';

  @override
  String get settingsRemoveAllTitle =>
      'Remover todas as impressoras deste dispositivo';

  @override
  String get settingsRemoveAllSubtitle =>
      'Limpa o cache local de impressoras. Sua conta no Supabase Ã© mantida para que o novo pareamento funcione perfeitamente.';

  @override
  String get settingsRemoveAllConfirmTitle => 'Remover todas as impressoras?';

  @override
  String get settingsRemoveAllConfirmBody =>
      'Todas as impressoras pareadas serÃ£o removidas deste dispositivo. VocÃª pode adicionÃ¡-las novamente executando MOONGATE_PAIR na impressora.';

  @override
  String get settingsRemoveAllConfirmAction => 'Remover todas';

  @override
  String get dashboardAddPrinter => 'Adicionar impressora';

  @override
  String get dashboardRemovePrinter => 'Remover impressora';

  @override
  String get dashboardMenuTooltip => 'Menu';

  @override
  String get dashboardRemovePrinterTitle => 'Remover impressora?';

  @override
  String dashboardRemovePrinterBody(String name) {
    return 'Remover \"$name\" do Moongate?';
  }

  @override
  String get dashboardRemoveSupabaseUnreachable =>
      'Removida localmente, mas nÃ£o foi possÃ­vel alcanÃ§ar o Supabase. Execute MOONGATE_RESET_OWNER no Pi se o novo pareamento falhar.';

  @override
  String get dashboardBackUpConfig => 'Fazer backup da configuraÃ§Ã£o';

  @override
  String get dashboardBackUpConfigSubtitle =>
      'Salvar em um arquivo antes de reinstalar';

  @override
  String get dashboardRestoreConfig => 'Restaurar configuraÃ§Ã£o';

  @override
  String get dashboardRestoreConfigSubtitle =>
      'Carregar de um arquivo de backup';

  @override
  String get dashboardThemeHeading => 'Tema';

  @override
  String get dashboardThemeSystem => 'Cores do telefone';

  @override
  String get dashboardThemeDark => 'Escuro';

  @override
  String get dashboardThemeLight => 'Claro';

  @override
  String get dashboardThemeCustom => 'Personalizado';

  @override
  String get dashboardFontHeading => 'Fonte';

  @override
  String get fontStandard => 'PadrÃ£o';

  @override
  String get fontRounded => 'Arredondada';

  @override
  String get fontSerif => 'Com serifa';

  @override
  String get fontReadable => 'Alta legibilidade';

  @override
  String get dashboardCustomiseColours => 'Personalizar cores';

  @override
  String get dashboardCustomiseColoursSubtitle =>
      'Edite os cinco espaÃ§os de cores do tema - HEX ou paleta';

  @override
  String get dashboardFontSizeHeading => 'Tamanho de exibiÃ§Ã£o';

  @override
  String get dashboardLayoutHeading => 'Layout do painel';

  @override
  String dashboardColumnCount(int count) {
    return '$count col';
  }

  @override
  String get dashboardRotateWithDevice => 'Girar com o dispositivo';

  @override
  String get dashboardRotateWithDeviceSubtitle =>
      'Desbloqueia a orientaÃ§Ã£o paisagem';

  @override
  String get dashboardAutoArrange => 'Organizar automaticamente por status';

  @override
  String get dashboardAutoArrangeSubtitle =>
      'Classifique os cartÃµes por atividade. Desative para arrastar os cartÃµes para a sua prÃ³pria ordem.';

  @override
  String get dashboardShowButtons => 'Mostrar botÃµes do painel';

  @override
  String get dashboardShowButtonsSubtitle =>
      'Mostre os botÃµes de adicionar e reordenar na parte inferior. Adicione impressoras pelo menu quando estiverem ocultos.';

  @override
  String get dashboardReorderHint =>
      'Segure e arraste um cartÃ£o para reordenar';

  @override
  String get dashboardReorderStart => 'Reordenar';

  @override
  String get dashboardReorderDone => 'ConcluÃ­do';

  @override
  String get dashboardCameraFeedHeading => 'Feed da cÃ¢mera do painel';

  @override
  String get dashboardCameraFeedSubtitle =>
      'Com que frequÃªncia os cartÃµes atualizam a cÃ¢mera. Taxas menores usam muito menos dados.';

  @override
  String get cameraFeedsMenuTitle => 'Feeds de cÃ¢mera do painel';

  @override
  String get cameraFeedsMenuSubtitle => 'Taxas de feed local e do tÃºnel';

  @override
  String get cameraFeedsIntro =>
      'Com que frequÃªncia cada cartÃ£o atualiza sua cÃ¢mera. O Moongate usa a taxa Local enquanto vocÃª estÃ¡ no Wi-Fi (mesmo fora de casa), e a taxa do TÃºnel nos dados mÃ³veis - mantendo um feed rÃ¡pido no Wi-Fi e um mais leve no celular para economizar dados.';

  @override
  String get cameraFeedsLocalRate => 'Taxa de atualizaÃ§Ã£o do feed local';

  @override
  String get cameraFeedsTunnelRate => 'Taxa de atualizaÃ§Ã£o do feed do tÃºnel';

  @override
  String get dashboardAboutHeading => 'Sobre';

  @override
  String get dashboardWhatsNew => 'O que hÃ¡ de novo';

  @override
  String get dashboardWhatsNewSubtitle =>
      'MudanÃ§as recentes em um piscar de olhos';

  @override
  String get dashboardHowPairingWorks => 'Como funciona o pareamento';

  @override
  String get dashboardHowPairingWorksSubtitle =>
      'Pareamento, reinstalaÃ§Ã£o e restauraÃ§Ã£o';

  @override
  String get dashboardReportProblem => 'Relatar um problema';

  @override
  String get dashboardReportProblemSubtitle =>
      'Enviar um relatÃ³rio de bug ou feedback';

  @override
  String get dashboardAppLock => 'Bloqueio do app';

  @override
  String get dashboardAppLockOn => 'Ativado - requer desbloqueio ao iniciar';

  @override
  String get dashboardAppLockOff => 'Desativado';

  @override
  String get dashboardBuyMeCoffee => 'Pague-me um cafÃ©';

  @override
  String get dashboardBuyMeCoffeeSubtitle =>
      'DÃª uma gorjeta ao desenvolvedor via PayPal';

  @override
  String get dashboardDeleteData => 'Excluir meus dados';

  @override
  String get dashboardDeleteDataSubtitle =>
      'Apague sua conta e impressoras da nuvem';

  @override
  String get deleteDataConfirmTitle => 'Excluir meus dados?';

  @override
  String get deleteDataConfirmBody =>
      'Isso exclui permanentemente sua conta anÃ´nima e remove suas impressoras e configuraÃ§Ãµes de notificaÃ§Ã£o da nuvem. Suas impressoras precisarÃ£o ser pareadas novamente. Isso nÃ£o pode ser desfeito.';

  @override
  String get deleteDataDone => 'Seus dados foram excluÃ­dos';

  @override
  String get deleteDataError =>
      'NÃ£o foi possÃ­vel excluir seus dados. Por favor, tente novamente.';

  @override
  String get donationPromptTitle => 'Gostando do Moongate?';

  @override
  String get donationPromptBody =>
      'O Moongate Ã© um projeto paralelo gratuito que eu construo no meu tempo livre. Se Ã© Ãºtil para vocÃª, uma pequena gorjeta ajuda a mantÃª-lo - sem pressÃ£o, e eu nÃ£o perguntarei novamente.';

  @override
  String get donationPromptLater => 'Talvez mais tarde';

  @override
  String get dashboardSettings => 'ConfiguraÃ§Ãµes';

  @override
  String dashboardVersion(String version) {
    return 'Moongate v$version';
  }

  @override
  String get dashboardSaveBackupDialogTitle => 'Salvar backup do Moongate';

  @override
  String get dashboardBackupFailed =>
      'Falha no backup - nÃ£o foi possÃ­vel salvar o arquivo.';

  @override
  String dashboardBackupSuccess(int count) {
    return 'Backup feito de $count impressora(s). Este arquivo pode restaurÃ¡-las em uma nova instalaÃ§Ã£o - mantenha-o privado.';
  }

  @override
  String dashboardBackupSuccessListOnly(int count) {
    return 'Backup feito de $count impressora(s) (apenas a lista - nÃ£o foi possÃ­vel conectar Ã  nuvem para obter um cÃ³digo de restauraÃ§Ã£o).';
  }

  @override
  String get dashboardInvalidBackupFile =>
      'Arquivo de backup invÃ¡lido - por favor, escolha um arquivo de configuraÃ§Ã£o do Moongate.';

  @override
  String dashboardRestoreReconnected(int added, int count) {
    return '$added impressora(s) restaurada(s) - $count reconectada(s) e voltando a ficar online.';
  }

  @override
  String dashboardRestoreNoneReconnected(int added) {
    return '$added impressora(s) restaurada(s), mas nenhuma reconectada - o cÃ³digo de restauraÃ§Ã£o do backup nÃ£o correspondeu a nenhuma impressora (pode ser de um backup mais antigo, ou jÃ¡ usado). Pareie-as novamente para colocÃ¡-las online.';
  }

  @override
  String dashboardRestoreListOnly(int added) {
    return '$added impressora(s) restaurada(s) (apenas a lista). Pareie cada impressora novamente para colocÃ¡-la online.';
  }

  @override
  String get dashboardRestoreApplied =>
      'Painel restaurado para corresponder ao seu backup.';

  @override
  String get dashboardRestoreReplaceTitle => 'Substituir painel?';

  @override
  String dashboardRestoreReplaceBody(String names) {
    return 'Estas impressoras estÃ£o neste painel, mas nÃ£o no backup: $names. A restauraÃ§Ã£o irÃ¡ removÃª-las para que o painel corresponda exatamente ao backup. Elas permanecem pareadas - vocÃª pode adicionÃ¡-las novamente ou restaurÃ¡-las mais tarde.';
  }

  @override
  String get dashboardRestoreReplaceConfirm => 'Substituir';

  @override
  String get dashboardRemoveSheetTitle => 'Remover uma impressora';

  @override
  String dashboardPrinterIdShort(String id) {
    return 'id $idâ€¦';
  }

  @override
  String get dashboardPairingHelpPluginTitle =>
      'Primeiro: instale o plugin no Pi';

  @override
  String get dashboardPairingHelpPluginBody =>
      'O Moongate precisa que o plugin dele esteja em execuÃ§Ã£o na sua impressora Klipper antes que vocÃª possa parear. Se vocÃª ainda nÃ£o o instalou, abra o guia de inÃ­cio rÃ¡pido.';

  @override
  String get dashboardPairingHelpPluginAction =>
      'Abrir o guia de configuraÃ§Ã£o';

  @override
  String get dashboardPairingHelpPairOnceTitle => 'Pareie uma vez';

  @override
  String get dashboardPairingHelpPairOnceBody =>
      'Escaneie o QR (ou digite o cÃ³digo GATE) para adicionar uma impressora - esse link Ã© salvo neste app.';

  @override
  String get dashboardPairingHelpUpdatesTitle =>
      'AtualizaÃ§Ãµes do app mantÃªm suas impressoras';

  @override
  String get dashboardPairingHelpUpdatesBody =>
      'Atualizar o Moongate nunca requer parear novamente.';

  @override
  String get dashboardPairingHelpReinstallTitle =>
      'Reinstalando ou celular novo?';

  @override
  String get dashboardPairingHelpReinstallBody =>
      'FaÃ§a um backup primeiro (Menu â†’ Fazer backup da configuraÃ§Ã£o), depois Restaurar traz suas impressoras de volta online - sem parear novamente.';

  @override
  String get dashboardPairingHelpNoBackupTitle => 'Sem backup?';

  @override
  String get dashboardPairingHelpNoBackupBody =>
      'Execute MOONGATE_RESET_OWNER no console da impressora, e depois pareie novamente.';

  @override
  String get dashboardDontShowAgain => 'NÃ£o mostrar isso novamente';

  @override
  String dashboardUpdateAvailable(String version) {
    return 'AtualizaÃ§Ã£o disponÃ­vel - v$version';
  }

  @override
  String get dashboardUpdateLater => 'Mais tarde';

  @override
  String get dashboardUpdate => 'Atualizar';

  @override
  String get dashboardEmptyTitle => 'Nenhuma impressora adicionada ainda';

  @override
  String get dashboardEmptyBody =>
      'Toque no botÃ£o abaixo para parear sua primeira impressora.';

  @override
  String get pairingTitle => 'Adicionar Impressora';

  @override
  String get pairingIntro =>
      'Execute MOONGATE_PAIR no console do seu Klipper - escaneie o QR ou digite o cÃ³digo GATE mostrado no console.';

  @override
  String get pairingNameLabel => 'Nome da impressora';

  @override
  String get pairingNameHint => 'p. ex., Voron 2.4';

  @override
  String get pairingScanButton => 'Escanear cÃ³digo QR';

  @override
  String get pairingScanRecommended => 'Recomendado - conecta instantaneamente';

  @override
  String get pairingOr => 'OU';

  @override
  String get pairingGateCodeLabel => 'CÃ³digo GATE';

  @override
  String get pairingGateCodeHint =>
      'Digite o cÃ³digo de 8 dÃ­gitos mostrado no console do seu Klipper.';

  @override
  String get pairingGateCodeValid => 'O cÃ³digo parece vÃ¡lido âœ“';

  @override
  String get pairingGateCodeWarning =>
      'MÃ©todo alternativo. Sem o QR, a impressora pode levar atÃ© cerca de um minuto para ficar online - ela estÃ¡ aguardando o tÃºnel seguro conectar. Escaneie o cÃ³digo QR acima para uma conexÃ£o instantÃ¢nea.';

  @override
  String get pairingCameraPermissionNeeded =>
      'PermissÃ£o da cÃ¢mera necessÃ¡ria';

  @override
  String get pairingCameraUnavailable => 'CÃ¢mera indisponÃ­vel';

  @override
  String get pairingCancelScan => 'Cancelar escaneamento';

  @override
  String pairingQrScanned(String code) {
    return 'QR escaneado - cÃ³digo $code';
  }

  @override
  String get pairingRescan => 'Escanear novamente';

  @override
  String get pairingAdvancedTitle =>
      'AvanÃ§ado - impressora em uma rede personalizada?';

  @override
  String get pairingAdvancedBody =>
      'A maioria das pessoas pode deixar isso em branco. Se sua impressora estiver atrÃ¡s de um proxy reverso (Traefik, Caddy, NPM) ou no Docker, insira o mesmo endereÃ§o que vocÃª usa para abrir a pÃ¡gina web dela (Mainsail / Fluidd) em um navegador.';

  @override
  String get pairingAddressLabel => 'EndereÃ§o da impressora';

  @override
  String get pairingAddressHint => '192.168.1.50:7125';

  @override
  String get pairingPairButton => 'Parear impressora';

  @override
  String get pairingRestoreHint =>
      'Reinstalando? Restaure suas impressoras salvas de um arquivo de backup. VocÃª ainda precisarÃ¡ parear cada uma novamente para colocÃ¡-la online.';

  @override
  String get pairingImportButton => 'Importar configuraÃ§Ã£o de arquivo';

  @override
  String get pairingReportButton => 'Problemas ao parear? Enviar um relatÃ³rio';

  @override
  String get pairingCameraPermissionTitle =>
      'PermissÃ£o da cÃ¢mera necessÃ¡ria';

  @override
  String get pairingCameraPermissionBody =>
      'O Moongate precisa de acesso Ã  cÃ¢mera para escanear cÃ³digos QR.\n\nAbra ConfiguraÃ§Ãµes â†’ Apps â†’ Moongate â†’ PermissÃµes e ative a CÃ¢mera, depois volte e tente novamente.';

  @override
  String get pairingOpenSettings => 'Abrir ConfiguraÃ§Ãµes';

  @override
  String get pairingErrorNotMoongateQr =>
      'NÃ£o Ã© um cÃ³digo QR do Moongate. Execute MOONGATE_PAIR na impressora para gerar um.';

  @override
  String get pairingErrorOldQr =>
      'Este cÃ³digo QR Ã© de uma versÃ£o mais antiga do Moongate. Atualize o Pi para v0.3.0 primeiro.';

  @override
  String get pairingErrorNoCode =>
      'Escaneie o cÃ³digo QR, ou digite o cÃ³digo GATE a partir do console da impressora.';

  @override
  String get pairingErrorBadAddress =>
      'Esse endereÃ§o da impressora nÃ£o parece certo - tente p. ex., 192.168.1.50:7125';

  @override
  String pairingErrorFailed(String error) {
    return 'Falha no pareamento: $error';
  }

  @override
  String get pairingImportInvalidFile =>
      'Arquivo de backup invÃ¡lido - por favor, escolha um arquivo de configuraÃ§Ã£o do Moongate.';

  @override
  String get pairingImportNoNewPrinters =>
      'Nenhuma impressora nova encontrada nesse arquivo.';

  @override
  String pairingImportRestoredReconnected(int count, int reconnected) {
    return '$count impressora(s) restaurada(s) - $reconnected reconectada(s), voltando a ficar online.';
  }

  @override
  String pairingImportRestoredRepair(int count) {
    return '$count impressora(s) restaurada(s) - pareie cada Pi novamente para colocÃ¡-lo online.';
  }

  @override
  String get customThemeTitle => 'Tema personalizado';

  @override
  String get customThemeResetTooltip => 'Redefinir para os padrÃµes';

  @override
  String get customThemeResetConfirmTitle => 'Redefinir tema personalizado?';

  @override
  String get customThemeResetConfirmBody =>
      'Todos os cinco espaÃ§os de cores serÃ£o revertidos para a paleta padrÃ£o de roxo sobre escuro.';

  @override
  String get customThemeReset => 'Redefinir';

  @override
  String get customThemePreview => 'PrÃ©-visualizaÃ§Ã£o';

  @override
  String get customThemeAccent => 'Destaque';

  @override
  String get customThemeAccentDesc =>
      'BotÃµes, FAB, barras de progresso, links';

  @override
  String get customThemeBackground => 'Fundo da pÃ¡gina';

  @override
  String get customThemeBackgroundDesc => 'AtrÃ¡s de cada tela';

  @override
  String get customThemeSurface => 'CartÃµes e painÃ©is';

  @override
  String get customThemeSurfaceDesc =>
      'CartÃµes do painel, painÃ©is, menu lateral';

  @override
  String get customThemeText => 'Texto';

  @override
  String get customThemeTextDesc => 'Texto do corpo e tÃ­tulos em superfÃ­cies';

  @override
  String get customThemeError => 'Erro / Parar';

  @override
  String get customThemeErrorDesc =>
      'AÃ§Ãµes destrutivas, sobreposiÃ§Ãµes de erro';

  @override
  String get customThemeEstop => 'BotÃ£o de EMERGÃŠNCIA';

  @override
  String get customThemeEstopDesc => 'Anel e Ã­cone de parada de emergÃªncia';

  @override
  String get customThemePresets => 'PredefiniÃ§Ãµes';

  @override
  String get customThemeInvalidHex => 'NÃ£o Ã© uma cor hexadecimal vÃ¡lida';

  @override
  String get customThemeSamplePrinter => 'Impressora de exemplo';

  @override
  String get customThemePrinting => 'Imprimindo';

  @override
  String get tilePauseFailed =>
      'NÃ£o foi possÃ­vel alcanÃ§ar a impressora - falha ao pausar';

  @override
  String get tileResumeFailed =>
      'NÃ£o foi possÃ­vel alcanÃ§ar a impressora - falha ao retomar';

  @override
  String get tileStopAgainToCancel =>
      'Pressione PARAR novamente para cancelar a impressÃ£o';

  @override
  String get tileLocal => 'Local';

  @override
  String get tileTunnel => 'TÃºnel';

  @override
  String get tilePrinting => 'Imprimindo';

  @override
  String get tilePaused => 'Pausado';

  @override
  String get tileResume => 'Retomar';

  @override
  String get tilePause => 'Pausar';

  @override
  String get tileConfirmStop => 'Confirmar parada';

  @override
  String get tileStopPrint => 'Parar impressÃ£o';

  @override
  String get tileFirmwareRestart => 'Reiniciar firmware';

  @override
  String get tileEmergencyStop => 'Parada de emergÃªncia Â· toque duplo';

  @override
  String get tileEmergencyStopFailed =>
      'NÃ£o foi possÃ­vel alcanÃ§ar a impressora - falha na parada de emergÃªncia';

  @override
  String get tilePrintComplete => 'ImpressÃ£o concluÃ­da';

  @override
  String get tilePrintCancelled => 'ImpressÃ£o cancelada';

  @override
  String get tilePrinterError => 'Erro na impressora';

  @override
  String get tileKlipperStarting => 'Klipper iniciando';

  @override
  String get tileReady => 'Pronto';

  @override
  String get tileOffline => 'Offline';

  @override
  String get tileStartingUp => 'Iniciandoâ€¦';

  @override
  String get tileConnected => 'Conectado';

  @override
  String get tileConnecting => 'Conectandoâ€¦';

  @override
  String get tilePrinterUnreachable => 'Impressora inacessÃ­vel';

  @override
  String get tileWaitingForHeartbeat => 'Aguardando o primeiro sinal';

  @override
  String get tilePrinterIdle => 'Impressora inativa';

  @override
  String get tileReachingPrinter => 'AlcanÃ§ando a impressora';

  @override
  String get tileRemoteReady => 'Acesso remoto pronto';

  @override
  String get tileRemoteConnecting => 'Conectando remotamenteâ€¦';

  @override
  String get tileIdle => 'Inativo';

  @override
  String get tileDone => 'ConcluÃ­do';

  @override
  String get tileCancelled => 'Cancelado';

  @override
  String get tileClearJobTooltip => 'Limpar e definir como inativo';

  @override
  String get tileClearJobFailed => 'NÃ£o foi possÃ­vel redefinir a impressora';

  @override
  String get dashboardBackgroundTitle => 'Fundo do painel';

  @override
  String get dashboardBackgroundNone => 'Nenhum - cor do tema';

  @override
  String get dashboardBackgroundCustom => 'Imagem personalizada';

  @override
  String get dashboardBackgroundRemove => 'Remover fundo';

  @override
  String get dashboardBackgroundSet => 'Fundo atualizado';

  @override
  String get uiGuideSectionTileButtons => 'BotÃµes do cartÃ£o';

  @override
  String get uiGuideFilesTitle => 'Imprimir um arquivo';

  @override
  String get uiGuideFilesDesc =>
      'Navegue pelos arquivos G-code salvos na impressora e inicie um.';

  @override
  String get uiGuideMacrosTitle => 'Macros';

  @override
  String get uiGuideMacrosDesc =>
      'Execute uma das macros do Klipper da impressora.';

  @override
  String get uiGuidePowerTitle => 'Energia';

  @override
  String get uiGuidePowerDesc =>
      'Ligue ou desligue a impressora, quando ela tiver um dispositivo de energia.';

  @override
  String get uiGuideLightingTitle => 'IluminaÃ§Ã£o';

  @override
  String get uiGuideLightingDesc =>
      'Alterne a luz da impressora; a lÃ¢mpada brilha quando estÃ¡ acesa.';

  @override
  String get uiGuideCameraViewTitle => 'CÃ¢mera';

  @override
  String get uiGuideCameraViewDesc => 'Abra a cÃ¢mera ao vivo em tela cheia.';

  @override
  String get uiGuideCameraSetupTitle => 'ConfiguraÃ§Ã£o da cÃ¢mera';

  @override
  String get uiGuideCameraSetupDesc =>
      'Aponte um cartÃ£o para uma cÃ¢mera que nÃ£o estÃ¡ conectada ao Klipper.';

  @override
  String get uiGuideClearJobTitle => 'Limpar uma impressÃ£o concluÃ­da';

  @override
  String get uiGuideClearJobDesc =>
      'Toque no Ã— em um cartÃ£o ConcluÃ­do ou Cancelado para defini-lo de volta para Inativo.';

  @override
  String get tileError => 'Erro';

  @override
  String get tileStarting => 'Iniciando';

  @override
  String get tileConnectingBadge => 'Conectando';

  @override
  String get appLockTitle => 'Bloqueio do app';

  @override
  String get appLockIntro =>
      'Exija um PIN - e opcionalmente sua impressÃ£o digital ou rosto - antes que o Moongate seja aberto. O bloqueio sempre aparece quando o app Ã© iniciado novamente.';

  @override
  String get appLockSubtitle => 'PIN necessÃ¡rio para abrir o app';

  @override
  String get appLockBiometricTitle => 'Desbloqueio biomÃ©trico';

  @override
  String get appLockBiometricSubtitle =>
      'Use impressÃ£o digital ou rosto - o PIN fica como uma alternativa';

  @override
  String get appLockChangePin => 'Alterar PIN';

  @override
  String get appLockAutoLock => 'Bloqueio automÃ¡tico';

  @override
  String get appLockPinUpdated => 'PIN atualizado';

  @override
  String get appLockChoosePinTitle => 'Escolha um PIN';

  @override
  String get appLockChoosePinSubtitle => 'Digite de 4 a 6 dÃ­gitos';

  @override
  String get appLockConfirmPinTitle => 'Confirmar PIN';

  @override
  String get appLockPinsDontMatch => 'Os PINs nÃ£o coincidem';

  @override
  String get appLockEnterCurrentPin => 'Digite o PIN atual';

  @override
  String get appLockTimeoutImmediately => 'Imediatamente';

  @override
  String get appLockTimeoutOneMinute => 'ApÃ³s 1 minuto';

  @override
  String get appLockTimeoutFiveMinutes => 'ApÃ³s 5 minutos';

  @override
  String get appLockTimeoutFifteenMinutes => 'ApÃ³s 15 minutos';

  @override
  String get appLockTimeoutColdLaunch => 'Apenas ao iniciar o app';

  @override
  String get lockEnterPin => 'Digite seu PIN';

  @override
  String get lockSubtitle => 'O Moongate estÃ¡ bloqueado';

  @override
  String lockTooManyAttempts(int seconds) {
    return 'Muitas tentativas. Tente novamente em ${seconds}s';
  }

  @override
  String get lockWrongPin => 'PIN incorreto';

  @override
  String get lockUseBiometrics => 'Usar biometria';

  @override
  String get lockForgotPin => 'Esqueceu o PIN?';

  @override
  String get lockBiometricReason => 'Desbloquear Moongate';

  @override
  String get lockResetTitle => 'Redefinir Moongate?';

  @override
  String get lockResetBody =>
      'Isso remove o bloqueio do app e limpa as impressoras pareadas deste dispositivo para que vocÃª possa comeÃ§ar de novo. Suas impressoras nÃ£o sÃ£o excluÃ­das - pareie-as novamente executando MOONGATE_PAIR em cada uma.';

  @override
  String get lockResetConfirm => 'Redefinir';

  @override
  String get pinContinue => 'Continuar';

  @override
  String printerStartingUpRetry(int seconds) {
    return 'A impressora estÃ¡ iniciando. Tentando novamente em ${seconds}sâ€¦';
  }

  @override
  String printerCouldNotReach(String error) {
    return 'NÃ£o foi possÃ­vel alcanÃ§ar a impressora: $error';
  }

  @override
  String get printerAddressCleared => 'EndereÃ§o personalizado limpo';

  @override
  String get printerAddressUpdated => 'EndereÃ§o da impressora atualizado';

  @override
  String printerTunnelUnreachable(String description) {
    return 'TÃºnel da Cloudflare inacessÃ­vel.\n$description';
  }

  @override
  String get printerEdit => 'Editar impressora';

  @override
  String get printerLocalNetwork => 'Rede local';

  @override
  String get printerTunnelVia => 'TÃºnel via Moongate';

  @override
  String get printerCameraTooltip => 'CÃ¢mera';

  @override
  String get cameraConnecting => 'Conectando Ã  cÃ¢meraâ€¦';

  @override
  String get cameraNoCamera =>
      'Nenhuma cÃ¢mera configurada para esta impressora.';

  @override
  String get cameraHintBody =>
      'A webcam nÃ£o carregarÃ¡ remotamente aqui - abra a cÃ¢mera do Moongate.';

  @override
  String get cameraHintOpen => 'Abrir';

  @override
  String get printerUnreachable => 'Impressora inacessÃ­vel';

  @override
  String get printerUseTunnel => 'Usar tÃºnel';

  @override
  String get printerAddressInvalid => 'Tente p. ex., 192.168.1.50:7125';

  @override
  String get printerNameLabel => 'Nome da impressora';

  @override
  String get printerAddressLabel => 'EndereÃ§o da impressora (avanÃ§ado)';

  @override
  String get printerAddressHint => '192.168.1.50:7125';

  @override
  String get printerAddressHelper =>
      'Apenas para configuraÃ§Ãµes de proxy reverso / Docker. Deixe em branco para usar a descoberta automÃ¡tica.';

  @override
  String get feedbackTitle => 'Relatar um problema';

  @override
  String get feedbackTroublePairing => 'Problemas ao parear?';

  @override
  String get feedbackDescription =>
      'Conte-nos o que estÃ¡ acontecendo. A versÃ£o do seu app, o dispositivo, a rede e os detalhes da impressora sÃ£o anexados automaticamente para nos ajudar a rastrear o problema.';

  @override
  String get feedbackPairingDescription =>
      'Descreva o que acontece quando vocÃª tenta adicionar a impressora. Seus detalhes de rede e descoberta sÃ£o anexados automaticamente para que possamos ver por que ela nÃ£o estÃ¡ se conectando.';

  @override
  String get feedbackWhichPrinter => 'Qual impressora? (opcional)';

  @override
  String get feedbackGeneralOption =>
      'Geral / nÃ£o especÃ­fico de uma impressora';

  @override
  String get feedbackCommentLabel => 'O que deu errado?';

  @override
  String get feedbackCommentHint =>
      'p. ex., \"A impressora mostra Conectado / inativo, mas na verdade estÃ¡ pronta - abre normalmente quando toco no cartÃ£o.\"';

  @override
  String get feedbackContactLabel => 'Email ou contato (opcional)';

  @override
  String get feedbackContactHint => 'Apenas se vocÃª quiser uma resposta';

  @override
  String get feedbackSending => 'Enviandoâ€¦';

  @override
  String get feedbackSend => 'Enviar relatÃ³rio';

  @override
  String get feedbackSuccess => 'Obrigado - seu relatÃ³rio foi enviado.';

  @override
  String get feedbackError =>
      'NÃ£o foi possÃ­vel enviar - verifique sua conexÃ£o e tente novamente.';

  @override
  String get splashTagline => 'Controle remoto do Klipper';

  @override
  String get uiGuideTitle => 'Guia de Ã­cones';

  @override
  String get uiGuideMenuSubtitle => 'O que significam os Ã­cones do painel';

  @override
  String get uiGuideIntro =>
      'Um guia rÃ¡pido dos Ã­cones que vocÃª verÃ¡ no painel.';

  @override
  String get uiGuideSectionConnection => 'ConexÃ£o';

  @override
  String get uiGuideSectionTemperatures => 'Temperaturas';

  @override
  String get uiGuideSectionControls => 'Controles de impressÃ£o';

  @override
  String get uiGuideSectionStatus => 'Status';

  @override
  String get uiGuideSectionWebcam => 'CÃ¢mera e conexÃ£o';

  @override
  String get uiGuideLocalTitle => 'Rede local';

  @override
  String get uiGuideLocalDesc =>
      'Conectado diretamente pelo seu Wi-Fi - o caminho mais rÃ¡pido.';

  @override
  String get uiGuideTunnelTitle => 'Remoto (tÃºnel)';

  @override
  String get uiGuideTunnelDesc =>
      'Conectado de qualquer lugar atravÃ©s do tÃºnel seguro da Cloudflare.';

  @override
  String get uiGuideTunnelReadyTitle => 'Remoto pronto';

  @override
  String get uiGuideTunnelReadyDesc =>
      'O tÃºnel estÃ¡ ativo, entÃ£o o acesso remoto estÃ¡ disponÃ­vel.';

  @override
  String get uiGuideTunnelConnectingTitle => 'Conectando remotamente';

  @override
  String get uiGuideTunnelConnectingDesc =>
      'O tÃºnel remoto ainda estÃ¡ sendo estabelecido.';

  @override
  String get uiGuideHotendTitle => 'Hotend / bico';

  @override
  String get uiGuideHotendDesc => 'Temperatura atual do bico.';

  @override
  String get uiGuideBedTitle => 'Mesa aquecida';

  @override
  String get uiGuideBedDesc => 'Temperatura atual da mesa.';

  @override
  String get uiGuideChamberTitle => 'CÃ¢mara';

  @override
  String get uiGuideChamberDesc =>
      'Temperatura da cÃ¢mara - mostrada apenas se a sua impressora relatar uma.';

  @override
  String get uiGuideResumeTitle => 'Retomar';

  @override
  String get uiGuideResumeDesc => 'Retoma uma impressÃ£o pausada.';

  @override
  String get uiGuidePauseTitle => 'Pausar';

  @override
  String get uiGuidePauseDesc => 'Pausa a impressÃ£o atual.';

  @override
  String get uiGuideStopTitle => 'Parar';

  @override
  String get uiGuideStopDesc =>
      'Cancela a impressÃ£o - toque duas vezes para confirmar.';

  @override
  String get uiGuideEstopTitle => 'Parada de emergÃªncia';

  @override
  String get uiGuideEstopDesc =>
      'DÃª um toque duplo no triÃ¢ngulo vermelho para parar a impressora imediatamente (Klipper M112).';

  @override
  String get uiGuideFirmwareRestartTitle => 'Reiniciar firmware';

  @override
  String get uiGuideFirmwareRestartDesc =>
      'Reinicie o Klipper quando a impressora estiver inativa ou em erro.';

  @override
  String get uiGuideStatusReadyTitle => 'Pronto / concluÃ­do';

  @override
  String get uiGuideStatusReadyDesc =>
      'A impressora estÃ¡ inativa, ou terminou sua Ãºltima impressÃ£o.';

  @override
  String get uiGuideStatusCancelledTitle => 'Cancelado';

  @override
  String get uiGuideStatusCancelledDesc =>
      'A Ãºltima impressÃ£o foi cancelada.';

  @override
  String get uiGuideStatusErrorTitle => 'Erro';

  @override
  String get uiGuideStatusErrorDesc =>
      'O Klipper relatou um erro - abra a impressora para mais detalhes.';

  @override
  String get uiGuideStatusStartingTitle => 'Iniciando';

  @override
  String get uiGuideStatusStartingDesc =>
      'O Klipper estÃ¡ iniciando; os controles aparecem quando ele estiver pronto.';

  @override
  String get uiGuideOfflineTitle => 'Offline';

  @override
  String get uiGuideOfflineDesc =>
      'A impressora nÃ£o pode ser alcanÃ§ada no momento.';

  @override
  String get uiGuideNoWebcamTitle => 'Sem cÃ¢mera';

  @override
  String get uiGuideNoWebcamDesc =>
      'Nenhum instantÃ¢neo da webcam estÃ¡ disponÃ­vel para esta impressora.';

  @override
  String get uiGuideBack => 'Voltar ao painel';

  @override
  String get printNotifTitle => 'NotificaÃ§Ãµes de impressÃ£o';

  @override
  String get printNotifSubtitle =>
      'Progresso ao vivo e status enquanto o app estÃ¡ em segundo plano';

  @override
  String get printNotifPermissionNeeded =>
      'Permita as notificaÃ§Ãµes para ativar isso.';

  @override
  String get printNotifPromptTitle => 'Receber notificaÃ§Ãµes de impressÃ£o?';

  @override
  String get printNotifPromptBody =>
      'Veja o status ao vivo das suas impressoras - progresso, temperaturas e alertas quando uma impressÃ£o comeÃ§a, termina ou falha. VocÃª pode alterar isso a qualquer momento no menu.';

  @override
  String get printNotifPromptEnable => 'Ativar';

  @override
  String get printNotifPromptNotNow => 'Agora nÃ£o';

  @override
  String get printNotifWatching => 'Observando suas impressorasâ€¦';

  @override
  String get printNotifNoPrinters => 'Nenhuma impressora';

  @override
  String get printNotifNoneOnline => 'Nenhuma impressora online';

  @override
  String get notifOnlineOnlyTitle => 'Mostrar apenas dispositivos online';

  @override
  String get notifOnlineOnlySubtitle =>
      'Oculte mÃ¡quinas offline da notificaÃ§Ã£o de status';

  @override
  String get notifPollIntervalTitle => 'FrequÃªncia de atualizaÃ§Ã£o';

  @override
  String get notifContentTitle => 'ConteÃºdo da notificaÃ§Ã£o';

  @override
  String get notifContentSubtitle => 'Escolha e reordene o que Ã© mostrado';

  @override
  String get notifContentIntro =>
      'Escolha quais detalhes aparecem no cartÃ£o de notificaÃ§Ã£o de cada impressÃ£o, e arraste-os para a ordem que desejar.';

  @override
  String get notifContentPreview => 'VisualizaÃ§Ã£o';

  @override
  String get notifFieldProgress => 'Progresso';

  @override
  String get notifFieldRemaining => 'Tempo restante';

  @override
  String get notifFieldEta => 'Hora de tÃ©rmino';

  @override
  String get notifFieldHotend => 'Temp. do hotend';

  @override
  String get notifFieldBed => 'Temp. da mesa';

  @override
  String get printAlertReady => 'Impressora pronta';

  @override
  String get printStatusReady => 'Pronto';

  @override
  String get printStatusHeating => 'Aquecendo';

  @override
  String get printStatusIdle => 'Inativo';

  @override
  String get printStatusOffline => 'Offline';

  @override
  String get printStatusPaused => 'Pausado';

  @override
  String get printStatusComplete => 'ConcluÃ­do';

  @override
  String get printStatusCancelled => 'Cancelado';

  @override
  String get printStatusError => 'Erro';

  @override
  String get printStatusStartingUp => 'Iniciando';

  @override
  String get printStatusPrinting => 'Imprimindo';

  @override
  String get printNotifStarted => 'ImpressÃ£o iniciada';

  @override
  String get printNotifFinished => 'ConcluÃ­do';

  @override
  String get notifClearAction => 'Limpar';

  @override
  String get printAlertStarted => 'ComeÃ§ou a imprimir';

  @override
  String get printAlertResumed => 'ImpressÃ£o retomada';

  @override
  String get printAlertPaused => 'ImpressÃ£o pausada';

  @override
  String get printAlertComplete => 'ImpressÃ£o concluÃ­da';

  @override
  String get printAlertCancelled => 'ImpressÃ£o cancelada';

  @override
  String get printAlertError => 'Erro na impressora';

  @override
  String get tileOpenFiles => 'Imprimir um arquivo';

  @override
  String get gcodeSheetTitle => 'Iniciar uma impressÃ£o';

  @override
  String get gcodeLoading => 'Carregando arquivosâ€¦';

  @override
  String get gcodeEmpty => 'NÃ£o hÃ¡ arquivos G-code nesta impressora';

  @override
  String get gcodeError => 'NÃ£o foi possÃ­vel carregar os arquivos';

  @override
  String get gcodeStartButton => 'Iniciar impressÃ£o';

  @override
  String get gcodeStartAction => 'Iniciar';

  @override
  String get gcodeConfirmTitle => 'Iniciar impressÃ£o?';

  @override
  String gcodeConfirmBody(String file) {
    return 'Iniciar a impressÃ£o de $file?';
  }

  @override
  String gcodeStarted(String file) {
    return 'ImpressÃ£o de $file iniciada';
  }

  @override
  String get gcodeStartFailed => 'NÃ£o foi possÃ­vel iniciar a impressÃ£o';

  @override
  String get tileMacros => 'Macros';

  @override
  String get macrosSheetTitle => 'Macros';

  @override
  String get macrosLoading => 'Carregando macrosâ€¦';

  @override
  String get macrosError => 'NÃ£o foi possÃ­vel carregar as macros';

  @override
  String get macrosEmpty => 'Nenhuma macro nesta impressora';

  @override
  String get macroFavourite => 'Fixar no topo';

  @override
  String get macroUnfavourite => 'Desafixar';

  @override
  String get macroConfirmTitle => 'Executar macro?';

  @override
  String macroConfirmBody(String macro) {
    return 'Executar $macro nesta impressora?';
  }

  @override
  String get macroRunAction => 'Executar';

  @override
  String macroSent(String macro) {
    return 'Enviou $macro';
  }

  @override
  String macroFailed(String macro) {
    return 'NÃ£o foi possÃ­vel enviar $macro';
  }

  @override
  String get preheatTitle => 'Preaquecer';

  @override
  String get preheatHotend => 'Hotend';

  @override
  String get preheatBed => 'Mesa';

  @override
  String get preheatHint =>
      'Deixe uma caixa vazia para manter esse aquecedor inalterado.';

  @override
  String get preheatSoakLabel => 'Temporizador de aquecimento';

  @override
  String get preheatSoakHelp =>
      'Avise-me apÃ³s estes minutos. 0 = sem temporizador.';

  @override
  String get preheatMinutes => 'min';

  @override
  String get preheatSet => 'Definir';

  @override
  String get preheatNotifWarning =>
      'Os alertas de aquecimento exigem que as notificaÃ§Ãµes de impressÃ£o estejam ativadas.';

  @override
  String get preheatNotifEnable => 'Ativar';

  @override
  String preheatSetConfirm(String summary) {
    return 'Definido $summary';
  }

  @override
  String preheatSoakIn(int minutes) {
    return 'alerta de aquecimento em $minutes min';
  }

  @override
  String get preheatFailed => 'NÃ£o foi possÃ­vel definir as temperaturas';

  @override
  String get heatsoakDoneTitle => 'Aquecimento concluÃ­do';

  @override
  String heatsoakDoneBody(String printer) {
    return '$printer estÃ¡ na temperatura';
  }

  @override
  String get tutorialOfferTitle => 'Fazer um tour rÃ¡pido?';

  @override
  String get tutorialOfferBody =>
      'Gostaria de um passo a passo rÃ¡pido de como o Moongate funciona?';

  @override
  String get tutorialOfferDontRemind => 'NÃ£o me lembre novamente';

  @override
  String get tutorialOfferNo => 'NÃ£o, obrigado';

  @override
  String get tutorialOfferStart => 'Iniciar tutorial';

  @override
  String get tutorialMenuTitle => 'Tutorial do app';

  @override
  String get tutorialNext => 'PrÃ³ximo';

  @override
  String get tutorialDone => 'ConcluÃ­do';

  @override
  String get tutorialSkip => 'Fim';

  @override
  String get tutorialBack => 'Voltar';

  @override
  String get tutorialLocalBar =>
      'A barra de cores mostra como o Moongate estÃ¡ alcanÃ§ando esta impressora. Verde com um Ã­cone de Wi-Fi significa que vocÃª estÃ¡ na mesma rede, uma conexÃ£o local direta e rÃ¡pida.';

  @override
  String get tutorialTunnelBar =>
      'Laranja com um Ã­cone de nuvem significa que vocÃª estÃ¡ fora de casa, conectado de forma segura pela internet atravÃ©s do tÃºnel da sua impressora. O Moongate alterna entre os dois automaticamente.';

  @override
  String get tutorialRemoteBuilding =>
      'Quando vocÃª parea uma impressora pela primeira vez, o acesso remoto nÃ£o Ã© instantÃ¢neo. Este pequeno marcador de nuvem significa que o tÃºnel seguro ainda estÃ¡ sendo estabelecido em segundo plano. Assim que se transformar em uma nuvem verde com um visto, vocÃª poderÃ¡ alcanÃ§ar esta impressora de qualquer lugar.';

  @override
  String get tutorialHotend => 'Este Ã© o seu hotend, a temperatura do bico.';

  @override
  String get tutorialBed => 'E esta Ã© a mesa aquecida.';

  @override
  String get tutorialChamber =>
      'Se a sua impressora tiver um sensor de cÃ¢mara, a temperatura dele tambÃ©m serÃ¡ mostrada aqui.';

  @override
  String get tutorialTemps =>
      'Estas sÃ£o as temperaturas ao vivo: o hotend (bico), a mesa aquecida e - se a sua impressora tiver um sensor de cÃ¢mara - a cÃ¢mara.';

  @override
  String get tutorialEstop =>
      'Esta Ã© a parada de emergÃªncia. Ela precisa de um toque duplo para disparar, assim nÃ£o pode ser acionada por acidente, e interrompe a impressora imediatamente.';

  @override
  String get tutorialWebcam =>
      'Tocar na visualizaÃ§Ã£o da cÃ¢mera abre a interface completa da impressora, a tela ao vivo do Klipper.';

  @override
  String get tutorialPreheatPress =>
      'Pressione e segure o nome de uma impressora ou suas temperaturas para exibir o painel de preaquecimento.';

  @override
  String get tutorialPreheatSheet =>
      'Aqui vocÃª pode definir alvos para o hotend e a mesa, alÃ©m de um tempo opcional de aquecimento.';

  @override
  String get tutorialAddPrinter =>
      'Toque no botÃ£o de adiÃ§Ã£o a qualquer momento para adicionar outra impressora e pareÃ¡-la.';

  @override
  String get tutorialMenuIcon =>
      'Este Ã© o menu. VocÃª pode abri-lo a qualquer momento a partir daqui.';

  @override
  String get tutorialMenuPrinters =>
      'Adicione outra impressora, ou remova uma que vocÃª nÃ£o usa mais.';

  @override
  String get tutorialMenuBackup =>
      'FaÃ§a backup da sua configuraÃ§Ã£o em um arquivo, ou restaure-a em outro dispositivo.';

  @override
  String get tutorialMenuTheme =>
      'Escolha um tema de cores claro, escuro ou totalmente personalizado.';

  @override
  String get tutorialMenuDisplaySize =>
      'Arraste isso para deixar tudo maior ou menor de acordo com os seus olhos.';

  @override
  String get tutorialMenuColumns =>
      'Disponha suas impressoras em uma, duas ou trÃªs colunas.';

  @override
  String get tutorialMenuCameras =>
      'Defina com que frequÃªncia as cÃ¢meras sÃ£o atualizadas, e ligue ou desligue a cÃ¢mera de cada impressora.';

  @override
  String get tutorialMenuAbout =>
      'O que hÃ¡ de novo, como o pareamento funciona, um guia de Ã­cones e onde relatar um problema ficam todos aqui.';

  @override
  String get tutorialMenuSupport =>
      'Pagar um cafÃ© para mim ajuda a manter o Moongate gratuito para todos e de cÃ³digo aberto.';

  @override
  String get tutorialMenuSettings =>
      'ConfiguraÃ§Ãµes tem duas opÃ§Ãµes dentro: limpar todas as suas impressoras, ou excluir todos os seus dados e comeÃ§ar completamente do zero.';

  @override
  String get tutorialMenuLanguage =>
      'E vocÃª pode alterar o idioma do app aqui - o Moongate fala oito. Esse Ã© o tour, aproveite!';

  @override
  String get notifPauseTooltip => 'Pausar monitoramento';

  @override
  String get notifResumeTooltip => 'Retomar monitoramento';

  @override
  String get notifPausedSnack => 'Monitoramento de impressÃ£o pausado';

  @override
  String get notifResumedSnack => 'Monitoramento de impressÃ£o retomado';

  @override
  String get tutorialPauseButton =>
      'Isso pausa o monitoramento da impressÃ£o. Quando suas impressoras forem ficar desligadas por um tempo, toque nele para interromper as verificaÃ§Ãµes em segundo plano e economizar bateria; toque novamente para retomar.';
}
