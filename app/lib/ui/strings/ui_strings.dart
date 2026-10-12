// User-visible strings of the new UI, in pt-BR. Widgets never hard-code
// copy. English identifiers, pt-BR values, no em dashes.
// See docs/ui/UI_SPEC.md 7 (wireframes) and AGENTS.md 5.
/// Copy deck for the new UI.
class UiStrings {
  /// Private constructor: this class only holds string constants.
  const UiStrings._();

  // Navigation and shell.

  /// Início tab.
  static const String navHome = 'Início';

  /// Linhas tab.
  static const String navLines = 'Linhas';

  /// Ajustes tab.
  static const String navSettings = 'Ajustes';

  /// App wordmark shown on Início.
  static const String wordmark = 'pontual';

  /// App tagline (UI_SPEC 14), shown on Sobre.
  static const String tagline = 'Seu ônibus, na hora.';

  /// Offline banner.
  static const String offlineBanner = 'Sem conexão. Mostrando dados salvos.';

  /// Generic back action, for screen readers.
  static const String back = 'Voltar';

  /// Close action.
  static const String close = 'Fechar';

  /// Retry action.
  static const String retry = 'Tentar de novo';

  /// Cancel action.
  static const String cancel = 'Cancelar';

  /// Confirm action.
  static const String ok = 'Entendi';

  // Certainty.

  /// Live certainty label.
  static const String certaintyLive = 'Ao vivo';

  /// Predicted certainty label.
  static const String certaintyPredicted = 'Previsão';

  /// Scheduled certainty label.
  static const String certaintyScheduled = 'Horário';

  /// Stale certainty label.
  static const String certaintyStale = 'Sem sinal';

  /// Info affordance on every non-live certainty.
  static const String certaintyHow = 'Como calculamos isso?';

  /// Explanation for a scheduled value.
  static const String certaintyHowScheduled =
      'Este horário vem da tabela da linha. Não é uma posição medida: o '
      'ônibus pode estar atrasado ou adiantado.';

  /// Explanation for a stale value.
  static const String certaintyHowStale =
      'Este ônibus parou de enviar posição. O tempo mostrado é a idade da '
      'última posição recebida.';

  /// Explanation for a predicted value.
  static const String certaintyHowPredicted =
      'Esta é uma estimativa feita com as posições mais recentes e o ritmo '
      'normal desta linha neste horário. Não é uma garantia.';

  // Home.

  /// Greeting in the morning.
  static const String greetingMorning = 'Bom dia';

  /// Greeting in the afternoon.
  static const String greetingAfternoon = 'Boa tarde';

  /// Greeting at night.
  static const String greetingEvening = 'Boa noite';

  /// Fixed subtitle under the greeting.
  static const String homeSubtitle = 'Para onde vamos?';

  /// Search field hint.
  static const String searchHint = 'Buscar linha ou bairro';

  /// Shortcuts section header.
  static const String homeShortcuts = 'Seus atalhos';

  /// Next-buses feed header (UI_SPEC 13.3).
  static const String saindoAgora = 'Saindo agora';

  /// Add shortcut card label.
  static const String addShortcut = 'Adicionar';

  /// Live now section header.
  static const String homeLiveNow = 'Ao vivo agora';

  /// Link to the full live list.
  static const String homeLiveAll = 'Ver todas ao vivo';

  /// Recents section header.
  static const String homeRecents = 'Recentes';

  /// Clear recents action.
  static const String homeRecentsClear = 'Limpar';

  /// All lines link row.
  static const String homeAllLines = 'Todas as linhas';

  /// Trailing action of the all lines row.
  static const String homeAllLinesGo = 'Ver';

  /// Empty state when nothing is sharing.
  static const String homeNoLive = 'Nenhum ônibus compartilhando agora.';

  /// Sharing hint under the empty state.
  static const String homeNoLiveHint =
      'Quem está no ônibus pode tocar em "Estou no ônibus" e a posição '
      'aparece aqui, sem cadastro.';

  /// Empty state action to the timetables.
  static const String seeTimetable = 'Ver horários';

  /// Live summary chip, for example "3 ao vivo".
  static const String liveCount = 'ao vivo';

  /// Live summary chip when nothing is sharing. Neutral wording: no
  /// green dot reads as live while nothing is live.
  static const String homeLiveNone = 'Nenhum ao vivo';

  /// Live summary chip while the app is offline.
  static const String homeOffline = 'Offline';

  /// Trust line under the empty live card, with a lock icon.
  static const String homeTrust =
      'Anônimo. Sua localização só é usada enquanto você compartilha.';

  /// Shortcut card state when the timetable has no more departures today.
  static const String homeNoMoreToday = 'Sem mais saídas hoje';

  /// Tomorrow hint under the no-more-today state, for example
  /// "Amanhã 06:10".
  static String homeTomorrowAt(String hhmm) => 'Amanhã $hhmm';

  /// Shortcut card state when the line has no usable timetable.
  static const String homeNoTime = 'Sem horário';

  /// Muted hint under the no-timetable state.
  static const String homeNoTimeHint =
      'Nenhum horário cadastrado para esta linha.';

  /// Toast after clearing the recent lines, with an undo action.
  static const String homeRecentsCleared = 'Recentes apagados.';

  /// Welcome card title.
  static const String welcomeTitle = 'Veja onde o ônibus está';

  /// Welcome card body.
  static const String welcomeBody =
      'Quem está dentro compartilha a posição, de forma anônima. Sem '
      'cadastro, sem anúncios.';

  /// Welcome card privacy link.
  static const String welcomePrivacy = 'Como funciona a privacidade';

  /// Coachmark pointing at the dock.
  static const String coachmark = 'Toque aqui quando estiver no ônibus.';

  // Search screen.

  /// Search field clear action.
  static const String searchClear = 'Limpar busca';

  /// Recent searches group.
  static const String searchRecents = 'Recentes';

  /// Suggestions group.
  static const String searchSuggestions = 'Sugestões';

  /// Lines group header.
  static const String searchLines = 'Linhas';

  /// No results title.
  static const String searchEmptyTitle = 'Nada encontrado';

  /// No results tip.
  static const String searchEmptyTip =
      'Tente o nome do bairro ou o código da linha.';

  // Lines screen.

  /// Lines screen title.
  static const String linesTitle = 'Linhas';

  /// Line count summary, for example "21 linhas".
  static const String linesCount = 'linhas';

  /// Timetable count suffix, for example "9 com horários".
  static const String linesWithTimes = 'com horários';

  /// Muted status of a line without timetable data.
  static const String linesNoTimetable = 'Sem horários ainda';

  /// Friendly detail for a line without timetable data.
  static const String linesNoTimetableBody =
      'Ainda não temos os horários desta linha. Se você estiver nesse '
      'ônibus, toque em Estou no ônibus para aparecer ao vivo.';

  /// All filter.
  static const String filterAll = 'Todas';

  /// Live filter.
  static const String filterLive = 'Ao vivo';

  /// Favorites filter.
  static const String filterFavorites = 'Favoritas';

  /// Live count suffix on a line row, for example "1 ao vivo".
  static const String oneLive = 'ao vivo';

  /// Next departure prefix on a line row.
  static const String nextDeparture = 'Próx.';

  /// Empty state for the live filter.
  static const String linesNoLive = 'Nenhuma linha ao vivo agora.';

  /// Empty state for the favorites filter.
  static const String linesNoFavorites = 'Toque na estrela para favoritar.';

  /// Subtitle of a line with no live tracking and no terminals.
  static const String onlyTimetable = 'Só horários';

  /// Star toggle action label.
  static const String favorite = 'Favoritar';

  /// Star remove action label.
  static const String unfavorite = 'Remover dos favoritos';

  /// Row action opening a line.
  static const String openLine = 'Abrir linha';

  // Line screen.

  /// Agora tab.
  static const String tabNow = 'Agora';

  /// Horários tab.
  static const String tabTimetable = 'Horários';

  /// Next departure hero.
  static const String nextDepartureHero = 'Próxima saída';

  /// Vehicles now section header.
  static const String vehiclesNow = 'Ônibus agora';

  /// Next departures section header.
  static const String nextDepartures = 'Próximas saídas';

  /// Line not found state.
  static const String lineNotFound = 'Linha não encontrada';

  /// Non shareable line note.
  static const String lineNoTracking =
      'Esta linha ainda não tem rastreamento ao vivo. Veja os horários.';

  /// Map loading placeholder.
  static const String mapLoading = 'Carregando mapa';

  /// Old position chip on the line screen.
  static const String lastPosition = 'Última posição';

  /// Data saver map button.
  static const String seeOnMap = 'Ver no mapa';

  /// Follow vehicle action.
  static const String follow = 'Seguir';

  /// Following vehicle chip.
  static const String following = 'Seguindo';

  /// Stop following vehicle.
  static const String stopFollowing = 'Parar de seguir';

  /// Recenter action.
  static const String recenter = 'Recentralizar';

  /// Attribution chip label.
  static const String attribution = '© OpenStreetMap contributors';

  /// Stale chip on the map.
  static const String noSignal = 'Sem sinal';

  /// Ship marker sheet header count, for example "2 ônibus".
  static const String vehicles = 'ônibus';

  // Timetable.

  /// Weekday day type.
  static const String dayWeekday = 'Dias úteis';

  /// Saturday day type.
  static const String daySaturday = 'Sábado';

  /// Sunday and holidays day type.
  static const String daySunday = 'Dom/Feriados';

  /// Origin selector label.
  static const String originLabel = 'Saída de';

  /// Empty timetable state.
  static const String timetableEmpty =
      'Sem horários cadastrados para este dia.';

  /// Timetable footnote.
  static const String timetableFootnote =
      'Horários não oficiais. Atualizado em ';

  /// Sources link in the footnote.
  static const String sources = 'Fontes';

  // Trip flow.

  /// Dock idle label.
  static const String dockIdle = 'Estou no ônibus';

  /// Dock idle label on a shareable line screen.
  static const String dockIdleOnLine = 'Estou neste ônibus';

  /// Dock starting label.
  static const String dockStarting = 'Iniciando…';

  /// Dock active label prefix.
  static const String dockSharing = 'Compartilhando';

  /// Dock reconnect label.
  static const String dockReconnecting = 'Sem conexão. Tentando de novo';

  /// Dock GPS off label.
  static const String dockGpsOff = 'GPS desligado';

  /// Line chooser sheet title.
  static const String chooseLineTitle = 'Em qual linha você está?';

  /// Consent sheet title.
  static const String consentTitle = 'Compartilhar sua localização';

  /// Consent sheet body.
  static const String consentBody =
      'Para mostrar onde o ônibus está, coletamos a localização do seu '
      'celular enquanto a viagem estiver ativa, inclusive com a tela '
      'bloqueada ou o app em segundo plano (no Android).';

  /// Consent sheet body variant for the web.
  static const String consentBodyWeb =
      'Para mostrar onde o ônibus está, coletamos a localização do seu '
      'celular enquanto esta página estiver aberta.';

  /// Consent bullet: purpose.
  static const String consentBulletPurpose =
      'Só serve para posicionar o ônibus';

  /// Consent bullet: no identity.
  static const String consentBulletNoIdentity =
      'Não é ligada a nome, e-mail ou telefone';

  /// Consent bullet: deletion.
  static const String consentBulletDeleted = 'É apagada quando a viagem acaba';

  /// Consent bullet: others see the bus.
  static const String consentBulletOthers =
      'Outros veem o ônibus, não quem está nele. Se só você compartilha, a '
      'posição do ônibus é a sua.';

  /// Consent bullet: user control.
  static const String consentBulletControl = 'Você encerra quando quiser';

  /// Consent accept action.
  static const String consentAccept = 'Aceitar e continuar';

  /// Consent decline action.
  static const String consentDecline = 'Agora não';

  /// Privacy policy link inside the consent sheet.
  static const String privacyPolicy = 'Política de Privacidade';

  /// Permission pre-prompt body.
  static const String permissionPrompt =
      'Para compartilhar, o Pontual precisa da localização enquanto o app '
      'estiver em uso. Não pedimos localização "o tempo todo".';

  /// Permission pre-prompt action.
  static const String permissionContinue = 'Continuar';

  /// Permission denied message.
  static const String permissionDenied =
      'Sem permissão de localização. Sem ela não dá para compartilhar a '
      'viagem.';

  /// Permission permanently denied action.
  static const String openSettings = 'Abrir ajustes';

  /// Location services off message.
  static const String locationOff = 'Ative a localização do aparelho.';

  /// Web location failure message.
  static const String locationOffWeb =
      'O navegador não conseguiu a sua posição. Verifique se a localização '
      'do aparelho está ligada.';

  /// Web unblock retry action.
  static const String alreadyAllowed = 'Já permiti, tentar de novo';

  /// Notification permission note on Android.
  static const String notificationNote =
      'Sem a notificação, o Android pode encerrar o compartilhamento. '
      'Recomendamos permitir.';

  /// Unsupported context message.
  static const String unsupported =
      'Seu navegador não permite compartilhar a localização aqui.';

  /// Chrome and Edge unblock steps.
  static const String unblockChromium =
      'Toque no cadeado ao lado do endereço > Permissões > Localização > '
      'Permitir. Depois toque em Tentar de novo.';

  /// Safari unblock steps.
  static const String unblockSafari =
      'Toque em aA na barra de endereço > Ajustes do site > Localização > '
      'Permitir.';

  /// Firefox unblock steps.
  static const String unblockFirefox =
      'Toque no cadeado > Permissões > Localização > Permitir.';

  /// Unknown browser unblock steps.
  static const String unblockGeneric =
      'Abra as permissões do site no navegador e permita a localização.';

  /// Trip screen title.
  static const String tripTitle = 'Compartilhando viagem';

  /// Trip hero headline.
  static const String tripHero = 'Você está ajudando quem espera o ônibus';

  /// Trip minimize action.
  static const String tripMinimize = 'Minimizar';

  /// Connection row label.
  static const String connection = 'Conexão';

  /// Connection row value when connected.
  static const String connected = 'Conectado';

  /// GPS row label.
  static const String gps = 'GPS';

  /// GPS row value when good.
  static const String gpsGood = 'Bom';

  /// Device row label.
  static const String device = 'Seu celular';

  /// Leader role copy.
  static const String roleLeader = 'Enviando com mais frequência';

  /// Leader explanation.
  static const String roleLeaderHint =
      'Revezamos a cada poucos minutos para poupar a bateria de todos.';

  /// Follower role copy.
  static const String roleFollower = 'Modo economia';

  /// Follower explanation.
  static const String roleFollowerHint =
      'Modo economia: outras pessoas também compartilham.';

  /// Waiting role copy.
  static const String roleWaiting = 'Aguardando o ônibus sair…';

  /// Offline role copy.
  static const String roleOffline =
      'Sem conexão. Vamos retomar assim que voltar.';

  /// Android battery tip.
  static const String batteryTip =
      'Se parar sozinho, defina a bateria do app como "Sem restrições".';

  /// Share start failed: could not reach the server.
  static const String shareNoConnection =
      'Sem conexão com o servidor. Verifique a internet e tente de novo.';

  /// Share start failed: no location fix within the wait window.
  static const String shareNoGps =
      'Não conseguimos sua localização. Vá para um lugar aberto e tente de novo.';

  /// Share start failed: server rate or capacity limits.
  static const String shareBusy =
      'Muita gente tentando agora. Aguarde um pouco e tente de novo.';

  /// Share start failed: too many people sharing at once (UI_SPEC 14).
  static const String capacity =
      'Muitas pessoas compartilhando agora. Tente em instantes.';

  /// Share start failed: fix outside the served area.
  static const String shareOutsideArea =
      'Você está fora da área atendida pelo Pontual.';

  /// Share start failed: anything else.
  static const String shareStartFailed =
      'Não foi possível iniciar a viagem. Tente de novo.';

  /// Progress sheet title while starting a trip.
  static const String shareProgressTitle = 'Iniciando viagem';

  /// Progress phase: device location services check.
  static const String sharePhaseServices = 'Verificando aparelho';

  /// Progress phase: remote flags fetch.
  static const String sharePhaseConfig = 'Buscando configuração';

  /// Progress phase: consent sheet.
  static const String sharePhaseConsent = 'Consentimento';

  /// Progress phase: system permission.
  static const String sharePhasePermission = 'Permissão do sistema';

  /// Progress phase: device registration.
  static const String sharePhaseRegister = 'Registrando aparelho';

  /// Progress phase: first GPS fix wait.
  static const String sharePhaseGps = 'Aguardando GPS';

  /// Progress phase: trip start request.
  static const String sharePhaseStart = 'Iniciando viagem';

  /// Progress sheet cancel action.
  static const String shareProgressCancel = 'Cancelar';

  /// Progress sheet retry action after a failure.
  static const String shareProgressRetry = 'Tentar de novo';

  /// Progress sheet close action after a failure.
  static const String shareProgressClose = 'Fechar';

  /// Progress sheet expandable technical details title.
  static const String shareProgressDetails = 'Detalhes técnicos';

  /// GPS wait hint shown under the active GPS phase.
  static const String shareGpsTip =
      'Vá para um lugar aberto, com vista para o céu.';

  /// Web trip note about battery: the screen stays on.
  static const String webWakeNote =
      'A tela fica ligada durante a viagem. Baixe o brilho para economizar bateria.';

  /// Shown when the browser cannot hold a wake lock.
  static const String webWakeUnsupported =
      'Este navegador não mantém a tela ligada. Deixe o brilho no máximo e não troque de aba.';

  /// Shown while a web trip is paused for a hidden page.
  static const String webHiddenPaused =
      'Tela oculta: compartilhamento pausado. Volte para esta aba para continuar.';

  /// iOS install hint title.
  static const String installHintTitle = 'Instale o Pontual';

  /// iOS install hint steps for the Safari share sheet.
  static const String installHintBody =
      'No Safari, toque em Compartilhar e depois em "Adicionar à Tela de Início" para abrir como app.';

  /// iOS install hint dismiss button.
  static const String installHintDismiss = 'Entendi';

  /// Android app download title.
  static const String androidAppTitle = 'Use o app Android';

  /// Android app download body.
  static const String androidAppBody =
      'Para compartilhar com a tela desligada e economizar bateria, '
      'baixe o app direto do GitHub. O mapa continua aqui no navegador.';

  /// Android app download action.
  static const String androidAppDownload = 'Baixar app';

  /// Web keep open banner.
  static const String webKeepOpen =
      'Mantenha esta tela aberta e o celular desbloqueado.';

  /// Web brightness tip.
  static const String webBrightness =
      'A tela fica ligada durante a viagem. Baixe o brilho para economizar '
      'bateria.';

  /// End trip action.
  static const String endTrip = 'Desci - encerrar viagem';

  /// End card title.
  static const String endTitle = 'Viagem encerrada. Obrigado por ajudar!';

  /// End card action.
  static const String endBack = 'Voltar às linhas';

  /// Automatic end reason: idle.
  static const String endIdle =
      'Encerramos porque o celular ficou parado por 10 minutos.';

  /// Automatic end reason: walking timeout.
  static const String endWalking =
      'Encerramos porque parecia que você já tinha descido.';

  /// Automatic end reason: maximum duration.
  static const String endMax = 'Encerramos por tempo máximo ou falta de sinal.';

  /// Automatic end reason: GPS off.
  static const String endGps =
      'Encerramos porque a localização ficou desligada.';

  /// Automatic end reason: permission removed.
  static const String endPermission =
      'Encerramos porque a permissão de localização foi removida.';

  /// Automatic end reason: inconsistent data.
  static const String endAbuse =
      'Encerramos por envios de localização inconsistentes.';

  /// Automatic end reason: server maintenance.
  static const String endServer = 'Serviço em manutenção. Tente mais tarde.';

  /// Local kudos counter prefix.
  static const String kudosPrefix = 'Você já ajudou';

  /// Local kudos counter suffix.
  static const String kudosSuffix = 'viagens';

  // Future features (flagged off, UI_SPEC 13-14).

  /// Alerts sheet title.
  static const String alertTitle = 'Avisar quando faltar';

  /// Alerts sheet save action.
  static const String alertSave = 'Salvar';

  /// In-app banner when a saved alert rule fires for this line (D30).
  /// Local only: the bus is live on this line right now.
  static const String alertFiring =
      'Alerta: tem ônibus desta linha agora na rota.';

  /// Line history tab.
  static const String tabHistory = 'Histórico';

  /// Reliability card text for a typical delay in minutes.
  static String typicalDelayOf(int minutes) =>
      'Costuma atrasar cerca de $minutes min neste horário';

  /// Prediction confidence levels.
  static const String confLow = 'Confiança baixa';

  /// Prediction confidence levels.
  static const String confMid = 'Confiança média';

  /// Prediction confidence levels.
  static const String confHigh = 'Confiança alta';

  /// Returns the confidence label for [level] 0 to 2.
  static String confidenceLabel(int level) {
    if (level <= 0) {
      return confLow;
    }
    if (level == 1) {
      return confMid;
    }
    return confHigh;
  }

  /// Recent pace phrases shown next to the confidence meter (UI_SPEC 14).
  static const String paceFaster =
      'Ritmo recente deste ônibus: um pouco mais rápido que o normal';

  /// Recent pace phrases shown next to the confidence meter (UI_SPEC 14).
  static const String paceNormal =
      'Ritmo recente deste ônibus: dentro do normal';

  /// Recent pace phrases shown next to the confidence meter (UI_SPEC 14).
  static const String paceSlower =
      'Ritmo recente deste ônibus: um pouco mais lento que o normal';

  /// Prediction explanation sheet title (UI_SPEC 14).
  static const String predictionInfoTitle = 'Como calculamos';

  /// One-paragraph estimate explanation (UI_SPEC 14).
  static const String predictionInfoBody =
      'A previsão usa as posições mais recentes e o ritmo habitual desta '
      'linha neste horário. Ela é uma estimativa, não uma posição ao vivo, '
      'e pode mudar.';

  /// Walking prompt title.
  static const String walkingTitle = 'Você ainda está no ônibus?';

  /// Walking prompt confirm.
  static const String walkingYes = 'Sim, continuar';

  /// Walking prompt decline.
  static const String walkingNo = 'Desci';

  // Settings, privacy, about.

  /// Settings title.
  static const String settingsTitle = 'Ajustes';

  /// Appearance section.
  static const String sectionAppearance = 'Aparência';

  /// Sharing section.
  static const String sectionSharing = 'Compartilhamento';

  /// Theme row.
  static const String theme = 'Tema';

  /// System theme option.
  static const String themeSystem = 'Sistema';

  /// Light theme option.
  static const String themeLight = 'Claro';

  /// Dark theme option.
  static const String themeDark = 'Escuro';

  /// Data saver row.
  static const String dataSaver = 'Economia de dados';

  /// Data saver description.
  static const String dataSaverHint =
      'Abre a linha em lista primeiro e só carrega o mapa quando você pedir.';

  /// Reduce animations row.
  static const String reduceMotion = 'Reduzir animações';

  /// How sharing works row.
  static const String howSharing = 'Como funciona';

  /// Battery tips row.
  static const String batteryTips = 'Dicas de bateria';

  /// Privacy entry row.
  static const String privacyData = 'Privacidade e dados';

  /// About entry row.
  static const String about = 'Sobre o Pontual';

  /// Install row.
  static const String install = 'Instalar';

  /// Version row prefix.
  static const String versionPrefix = 'versão';

  /// Timetable date prefix.
  static const String timetablesPrefix = 'Horários: ';

  /// Delete my data action.
  static const String privacyDelete = 'Apagar meus dados';

  /// Delete confirmation title.
  static const String privacyDeleteTitle = 'Apagar meus dados?';

  /// Delete confirmation body.
  static const String privacyDeleteBody =
      'Isso encerra sua viagem, apaga os dados ligados a este aparelho no '
      'servidor e reinicia o app.';

  /// Delete confirm action.
  static const String privacyConfirmDelete = 'Apagar';

  /// Offline delete message.
  static const String privacyOffline =
      'Sem conexão. Tente novamente quando estiver online.';

  /// Revoke consent action.
  static const String privacyRevoke = 'Revogar consentimento';

  /// Revoke confirmation.
  static const String privacyRevoked =
      'Consentimento revogado. Vamos pedir de novo na próxima viagem.';

  /// Terms row.
  static const String privacyTerms = 'Termos de Uso';

  /// Collection summary title.
  static const String privacyCollectsTitle = 'O que coletamos';

  /// Contact row.
  static const String contactUs = 'Falar com a gente';

  /// Six-line collection summary mirroring the data inventory. The legacy
  /// screen owned this copy; the new privacy center is its only reader now.
  static const List<String> collectsSummary = <String>[
    'Aparelho anônimo: um código aleatório, sem nome ou e-mail.',
    'Versão do consentimento que você aceitou e quando.',
    'Durante a viagem: posição, velocidade e bateria (só na memória).',
    'Ao descer, a posição some na hora. Sem histórico.',
    'Quem só olha o mapa não cria registro nenhum.',
    'Nunca: nome, e-mail, telefone, fotos ou microfone.',
  ];

  /// OSM copyright page opened by the attribution chip and the about row.
  static const String osmCopyrightUrl =
      'https://www.openstreetmap.org/copyright';

  /// Public source repository. Matches the git remote of this project.
  static const String repoUrl =
      'https://github.com/EduLGFon/pontual-bus-tracking';

  /// About disclaimer.
  static const String aboutDisclaimer =
      'App independente e não oficial. Não é da Viação São Gabriel nem da '
      'Prefeitura de São Mateus.';

  /// About sources title.
  static const String aboutSourcesTitle = 'Fontes dos dados';

  /// About source line.
  static const String aboutSourceLines =
      'Linhas e horários: transcritos de páginas públicas (onibus.online). '
      'Horários não oficiais e podem mudar sem aviso.';

  /// Attribution row.
  static const String aboutOsm = 'Mapa: © OpenStreetMap contributors';

  /// Licences row.
  static const String aboutLicences = 'Licenças de código aberto';

  /// Repository row.
  static const String aboutRepo = 'Código-fonte';

  // System states.

  /// Maintenance title.
  static const String maintenanceTitle = 'Serviço em manutenção';

  /// Maintenance body.
  static const String maintenanceBody = 'Os horários continuam disponíveis.';

  /// Update required title.
  static const String updateTitle = 'Atualize o app para continuar.';

  /// Update action on Android.
  static const String updateAction = 'Atualizar';

  /// Update action on web.
  static const String reloadAction = 'Recarregar';

  /// Server unavailable title.
  static const String serverDownTitle = 'Servidor indisponível no momento.';

  /// Server unavailable body.
  static const String serverDownBody = 'Tente de novo em instantes.';

  /// Not found title.
  static const String notFoundTitle = 'Página não encontrada';

  /// Generic error body.
  static const String genericError = 'Algo deu errado. Tente de novo.';

  /// Undo action used by toasts.
  static const String undo = 'Desfazer';
}
