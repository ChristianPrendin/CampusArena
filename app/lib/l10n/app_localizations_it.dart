// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'CampusArena';

  @override
  String get playButtonLabel => 'Gioca';

  @override
  String get sportPingPong => 'Ping Pong';

  @override
  String get sportFoosball => 'Calcio balilla';

  @override
  String get eloLabel => 'ELO';

  @override
  String get rankPlaceholder => '—';

  @override
  String matchesPlayedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partite giocate',
      one: '1 partita giocata',
      zero: 'Nessuna partita giocata',
    );
    return '$_temp0';
  }

  @override
  String get recentMatchesTitle => 'Partite recenti';

  @override
  String get noRecentMatches =>
      'Nessuna partita — scansiona il codice QR di una struttura per giocare la tua prima partita classificata.';

  @override
  String vsOpponents(String opponents) {
    return 'vs $opponents';
  }

  @override
  String get matchWon => 'Vinta';

  @override
  String get matchLost => 'Persa';

  @override
  String get matchStateDisputed => 'Contestata';

  @override
  String get matchStateUnconfirmed => 'Non confermata';

  @override
  String get matchStateAbandoned => 'Abbandonata';

  @override
  String get dashboardLoadError => 'Impossibile caricare la dashboard.';

  @override
  String get retryButtonLabel => 'Riprova';

  @override
  String get eloRatingLabel => 'Punteggio ELO';

  @override
  String get assistantCardTitle => 'Assistente Arena';

  @override
  String get assistantCardSubtitle => 'Chiedi di tavoli liberi, code ed ELO';

  @override
  String get chatbotTitle => 'Assistente Arena';

  @override
  String get chatbotComingSoon => 'L\'Assistente Arena arriverà presto.';

  @override
  String get homeTab => 'Home';

  @override
  String get mapTab => 'Mappa';

  @override
  String get leaderboardsTab => 'Classifiche';

  @override
  String get profileTab => 'Profilo';

  @override
  String get landingTagline =>
      'Traccia il tuo ELO, scala la classifica del campus e domina a ping pong e calciobalilla al PoliMi.';

  @override
  String get splashTagline => 'Domina il tavolo.';

  @override
  String get logIn => 'Accedi';

  @override
  String get register => 'Registrati';

  @override
  String get signIn => 'Accedi';

  @override
  String get createAccount => 'Crea Account';

  @override
  String get completeProfileTitle => 'Completa il profilo';

  @override
  String get completeProfileMessage =>
      'Il tuo account non ha ancora un profilo. Scegli un nome e uno username per completare la configurazione.';

  @override
  String get completeProfileButton => 'Completa';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get togglePasswordVisibility => 'Mostra/nascondi password';

  @override
  String get nameLabel => 'Nome Completo';

  @override
  String get usernameLabel => 'Nome Utente';

  @override
  String get degreeProgramLabel => 'Corso di Laurea';

  @override
  String get degreeProgramHint => 'Seleziona il tuo corso di laurea';

  @override
  String get forgotPasswordLink => 'Password dimenticata?';

  @override
  String get forgotPasswordTitle => 'Reimposta Password';

  @override
  String get forgotPasswordInstructions =>
      'Inserisci la tua email e ti invieremo un link per reimpostare la password.';

  @override
  String get sendResetLink => 'Invia Link di Reset';

  @override
  String get passwordResetSent =>
      'Se l\'email è registrata, è stato inviato un link per il reset.';

  @override
  String get noAccountPromptPrefix => 'Non hai un account?';

  @override
  String get haveAccountPromptPrefix => 'Hai già un account?';

  @override
  String get fieldRequired => 'Questo campo è obbligatorio';

  @override
  String get invalidEmail => 'Inserisci un indirizzo email valido';

  @override
  String get invalidUsername =>
      '3–20 lettere minuscole, numeri o trattini bassi';

  @override
  String get passwordTooShort =>
      'La password deve contenere almeno 6 caratteri';

  @override
  String get authErrorGeneric => 'Qualcosa è andato storto. Riprova.';

  @override
  String get authErrorInvalidCredentials => 'Email o password non corretti.';

  @override
  String get authErrorEmailInUse => 'Esiste già un account con questa email.';

  @override
  String get authErrorInvalidEmail => 'L\'indirizzo email non è valido.';

  @override
  String get authErrorWeakPassword => 'Scegli una password più sicura.';

  @override
  String get authErrorNetwork => 'Errore di rete. Controlla la connessione.';

  @override
  String get authErrorUsernameTaken => 'Questo nome utente è già in uso.';

  @override
  String get tutorialSkip => 'Salta';

  @override
  String get tutorialNext => 'Avanti';

  @override
  String get tutorialDone => 'Inizia';

  @override
  String get tutorialSlide1Title => 'Gioca partite classificate';

  @override
  String get tutorialSlide1Body =>
      'Scansiona il codice QR di una struttura per il check-in e registrare la partita.';

  @override
  String get tutorialSlide2Title => 'Scala le classifiche';

  @override
  String get tutorialSlide2Body =>
      'Ogni vittoria aggiorna il tuo ELO. Compete tra sport e corsi di laurea.';

  @override
  String get tutorialSlide3Title => 'Entra in coda';

  @override
  String get tutorialSlide3Body =>
      'Guarda lo stato delle strutture sulla mappa e prenota il tuo posto in fila.';

  @override
  String get degAerospace => 'Ingegneria Aerospaziale';

  @override
  String get degArchitecture => 'Architettura';

  @override
  String get degBiomedical => 'Ingegneria Biomedica';

  @override
  String get degChemical => 'Ingegneria Chimica';

  @override
  String get degCivil => 'Ingegneria Civile';

  @override
  String get degComputer => 'Ingegneria Informatica';

  @override
  String get degDesign => 'Design';

  @override
  String get degElectrical => 'Ingegneria Elettrica';

  @override
  String get degElectronic => 'Ingegneria Elettronica';

  @override
  String get degEnergy => 'Ingegneria Energetica';

  @override
  String get degManagement => 'Ingegneria Gestionale';

  @override
  String get degMathematical => 'Ingegneria Matematica';

  @override
  String get degMechanical => 'Ingegneria Meccanica';

  @override
  String get degTelecom => 'Ingegneria delle Telecomunicazioni';

  @override
  String get degUrban => 'Urbanistica';

  @override
  String get weatherLabel => 'Meteo';

  @override
  String weatherTemperature(String value) {
    return '$value°';
  }

  @override
  String weatherPrecipitation(String value) {
    return '$value mm';
  }

  @override
  String weatherWind(String value) {
    return '$value km/h';
  }

  @override
  String get weatherUnavailable => 'Meteo non disponibile';

  @override
  String get weatherRetry => 'Riprova';

  @override
  String get forecastLabel => 'Previsioni';

  @override
  String get queueJoin => 'Entra in coda';

  @override
  String get queueLeave => 'Esci dalla coda';

  @override
  String get queueRetry => 'Riprova';

  @override
  String queuePositionCounter(int position, int total) {
    return 'Sei il #$position di $total';
  }

  @override
  String get queueYoureNext => 'Tocca a te';

  @override
  String get queueError =>
      'Impossibile aggiornare la coda. Controlla la connessione.';

  @override
  String get queueTableReadyTitle => 'Il tuo tavolo è pronto';

  @override
  String get queueTableReadyBody =>
      'Sei il primo in fila — vai subito al tavolo.';

  @override
  String get queueTableReadyDismiss => 'Chiudi';

  @override
  String get availabilityDisclaimerShort =>
      'Basato solo sull\'attività dell\'app — il tavolo potrebbe essere occupato da giocatori esterni. Nessuna prenotazione.';

  @override
  String get availabilityDisclaimerFull =>
      'La disponibilità riflette solo l\'attività su CampusArena. Un tavolo indicato come libero potrebbe comunque essere usato da persone che non giocano tramite l\'app. CampusArena non è un servizio di prenotazione — non è possibile riservare un posto.';

  @override
  String get queuePriorityTitle => 'C\'è qualcuno prima di te';

  @override
  String queuePriorityBody(int position, int frontPosition) {
    return 'Sei il #$position in coda e tocca al #$frontPosition. Lascia giocare prima chi ti precede.';
  }

  @override
  String get queuePriorityProceed => 'Prendi comunque';

  @override
  String get queuePriorityCancel => 'Aspetta il turno';

  @override
  String get chatbotIntroDisclaimer =>
      'La disponibilità riflette solo l\'attività su CampusArena. Un tavolo indicato come libero potrebbe comunque essere usato da persone che non giocano tramite l\'app. CampusArena non è un servizio di prenotazione — non è possibile riservare un posto.';

  @override
  String get mapAttribution => '© Contributori di OpenStreetMap';

  @override
  String get mapViewList => 'Lista';

  @override
  String get facilityListSortedByProximity => 'Ordinati per vicinanza';

  @override
  String distanceMeters(int meters) {
    return '$meters m';
  }

  @override
  String distanceKilometers(double kilometers) {
    final intl.NumberFormat kilometersNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String kilometersString = kilometersNumberFormat.format(kilometers);

    return '$kilometersString km';
  }

  @override
  String get facilityStatusFree => 'Libero';

  @override
  String get facilityStatusOccupied => 'Occupato';

  @override
  String get facilityStatusQueued => 'In coda';

  @override
  String get facilityOutdoorLabel => 'All\'aperto';

  @override
  String get facilityPlayersLabel => 'Giocatori';

  @override
  String get facilityMatchDurationLabel => 'Durata partita';

  @override
  String facilityDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get facilityValuePlaceholder => '—';

  @override
  String get facilityKingOfTable => 'Re del Tavolo';

  @override
  String facilityKingWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vittorie',
      one: '1 vittoria',
    );
    return '$_temp0';
  }

  @override
  String get facilityNoKing => 'Ancora nessun Re del Tavolo';

  @override
  String get facilityLoadError => 'Impossibile caricare gli impianti.';

  @override
  String get facilityListEmpty => 'Ancora nessun impianto sul campus.';

  @override
  String get mapRecenterTooltip => 'Centra sulla mia posizione';

  @override
  String get locationUnavailable => 'Posizione non disponibile.';

  @override
  String get qrScanTitle => 'Inquadra il QR del tavolo';

  @override
  String get qrScanHint => 'Punta la fotocamera sul codice QR del tavolo';

  @override
  String get qrEnterManually => 'Inserisci il codice manualmente';

  @override
  String get qrManualEntryTitle => 'Inserisci il codice del tavolo';

  @override
  String get qrManualEntryLabel => 'Codice tavolo';

  @override
  String get qrManualEntrySubmit => 'Check-in';

  @override
  String get qrGpsWarning =>
      'Sembri lontano da questo tavolo — check-in comunque consentito';

  @override
  String qrCheckInButton(String facility) {
    return 'Check-in a $facility';
  }

  @override
  String get matchSetupTitle => 'Imposta partita';

  @override
  String matchSetupSubtitle(String facility) {
    return 'Scegli il tipo di partita, poi fai il check-in a $facility.';
  }

  @override
  String get matchModeLabel => 'Tipo di partita';

  @override
  String get matchModeSingles => 'Singolo';

  @override
  String get matchModeDoubles => 'Doppio';

  @override
  String get matchTeamLabel => 'La tua squadra';

  @override
  String get matchTeam1 => 'Squadra 1';

  @override
  String get matchTeam2 => 'Squadra 2';

  @override
  String get matchPickSideTitle => 'Scegli la squadra';

  @override
  String get matchPickSideBody =>
      'Scegli una squadra per unirti a questa partita di doppio.';

  @override
  String get matchSideFull => 'Al completo';

  @override
  String get matchWaitingPlayersBody =>
      'Chiedi agli altri di scansionare il QR del tavolo e scegliere una squadra.';

  @override
  String get qrInvalidCode =>
      'Il codice non corrisponde a nessun tavolo. Controllalo e riprova.';

  @override
  String get qrCheckInError =>
      'Impossibile avviare la partita. Controlla la connessione e riprova.';

  @override
  String get qrTableBusy =>
      'Questo tavolo ha già una partita in corso. Aspetta che finisca.';

  @override
  String qrSportMismatch(String sport) {
    return 'Questo tavolo non è per $sport. Scansiona un tavolo da $sport per giocare la tua sfida.';
  }

  @override
  String get leaveMatchTitle => 'Lasciare la partita?';

  @override
  String get leaveMatchMessage =>
      'Uscendo ora la partita viene abbandonata per entrambi i giocatori e il tavolo viene liberato.';

  @override
  String get leaveMatchConfirm => 'Lascia';

  @override
  String get leaveMatchCancel => 'Resta';

  @override
  String get matchLiveBadge => 'Live';

  @override
  String get matchVs => 'VS';

  @override
  String get matchRecordResult => 'Registra risultato';

  @override
  String matchEloValue(int elo) {
    return '$elo ELO';
  }

  @override
  String get matchWaitingOpponentTitle => 'In attesa dell\'avversario';

  @override
  String get matchWaitingOpponentBody =>
      'Chiedi al tuo avversario di inquadrare il QR di questo tavolo per unirsi.';

  @override
  String get matchResultSubmittedStatus =>
      'Risultato inviato — in attesa di conferma';

  @override
  String get matchConfirmedStatus => 'Risultato confermato';

  @override
  String get matchDisputedStatus => 'Risultato contestato';

  @override
  String get matchEndedStatus => 'Partita terminata';

  @override
  String get matchLoadError => 'Impossibile caricare la partita.';

  @override
  String get matchClose => 'Chiudi';

  @override
  String get matchReviewResult => 'Rivedi risultato';

  @override
  String get matchViewStatus => 'Vedi stato';

  @override
  String get matchViewSummary => 'Vedi riepilogo';

  @override
  String get resultEnterScoreTitle => 'Inserisci punteggio';

  @override
  String get resultSideYou => 'Tu';

  @override
  String get resultSideOpponent => 'Avversario';

  @override
  String get resultSideOpponents => 'Avversari';

  @override
  String resultSetLabel(int number) {
    return 'Set $number';
  }

  @override
  String get resultAddSet => 'Aggiungi set';

  @override
  String get resultGoalsLabel => 'Gol';

  @override
  String get resultSubmit => 'Invia risultato';

  @override
  String get resultInvalidHint =>
      'Inserisci un punteggio completo per inviare.';

  @override
  String get resultConfirmTitle => 'Conferma risultato';

  @override
  String resultSubmittedBy(String name) {
    return 'Inviato da $name';
  }

  @override
  String get resultSetsLabel => 'Set';

  @override
  String get resultWaitingConfirm =>
      'In attesa della conferma dell\'avversario…';

  @override
  String get resultDispute => 'Contesta';

  @override
  String get resultConfirm => 'Conferma';

  @override
  String get resultDisputeDialogTitle => 'Contestare questo risultato?';

  @override
  String get resultDisputeDialogBody =>
      'La partita sarà contrassegnata come contestata senza variazioni di punteggio. L\'azione non è reversibile.';

  @override
  String get resultDisputeDialogCancel => 'Annulla';

  @override
  String get resultVictoryTitle => 'Vittoria!';

  @override
  String get resultDefeatTitle => 'Sconfitta';

  @override
  String get resultNewRank => 'Nuova posizione nel campus';

  @override
  String resultRankValue(int rank) {
    return '#$rank';
  }

  @override
  String get resultDone => 'Fatto';

  @override
  String get resultClosedDisputedTitle => 'Risultato contestato';

  @override
  String get resultClosedDisputedBody =>
      'Questo risultato è stato contestato, quindi non è stata applicata alcuna variazione di punteggio.';

  @override
  String get resultClosedUnconfirmedTitle => 'Non confermato in tempo';

  @override
  String get resultClosedUnconfirmedBody =>
      'L\'avversario non ha mai confermato, quindi la partita è scaduta senza variazioni di punteggio.';

  @override
  String get resultClosedAbandonedTitle => 'Partita abbandonata';

  @override
  String get resultClosedAbandonedBody =>
      'Questa partita è stata abbandonata prima di registrare un risultato.';

  @override
  String get resultErrorTitle => 'Qualcosa è andato storto';

  @override
  String get resultErrorBody => 'Controlla la connessione e riprova.';

  @override
  String get resultRetry => 'Riprova';

  @override
  String get leaderboardSearchHint => 'Cerca giocatori';

  @override
  String get leaderboardScopeGlobal => 'Globale';

  @override
  String get leaderboardScopeFriends => 'Amici';

  @override
  String get leaderboardScopeMyCourse => 'Il mio corso';

  @override
  String get leaderboardThisIsYou => 'Sei tu!';

  @override
  String get leaderboardYourRank => 'La tua posizione';

  @override
  String get leaderboardYou => 'Tu';

  @override
  String get leaderboardEmpty =>
      'Ancora nessun giocatore in classifica — gioca una partita per entrarci.';

  @override
  String get leaderboardNoPlayers => 'Nessun giocatore trovato.';

  @override
  String get leaderboardLoadError => 'Impossibile caricare la classifica.';

  @override
  String get profileSettingsTooltip => 'Impostazioni';

  @override
  String profileIdentityLine(String username, String degreeProgram) {
    return '@$username · $degreeProgram';
  }

  @override
  String get profileEloTrendTitle => 'Andamento ELO';

  @override
  String get profileTrendEmpty =>
      'Le partite confermate tracceranno qui il tuo ELO.';

  @override
  String profileTrendTooltipPoint(int elo, String date) {
    return '$elo · $date';
  }

  @override
  String get profileStatGames => 'Partite';

  @override
  String get profileStatWins => 'Vittorie';

  @override
  String get profileStatLosses => 'Sconfitte';

  @override
  String get profileStatWinRate => '% Vittorie';

  @override
  String get profileStatStreak => 'Serie';

  @override
  String get profileStatBest => 'Record';

  @override
  String profileWinRateValue(int percent) {
    return '$percent%';
  }

  @override
  String get profileBlackBeastTitle => 'Bestia Nera';

  @override
  String get profileFavoriteVictimTitle => 'Vittima Preferita';

  @override
  String profileHeadToHeadTally(int wins, int losses) {
    return '${wins}V–${losses}S';
  }

  @override
  String get profileMatchHistoryTitle => 'Cronologia partite';

  @override
  String get profileHistoryEmpty =>
      'Nessuna partita — le partite concluse appariranno qui.';

  @override
  String get profileLoadError => 'Impossibile caricare il profilo.';

  @override
  String get teamProfileTitle => 'Squadra';

  @override
  String get teamProfileLoadError => 'Impossibile caricare la squadra.';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsPreferencesSection => 'Preferenze';

  @override
  String get settingsChangePassword => 'Cambia password';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsNotifications => 'Notifiche';

  @override
  String get settingsNotificationsUnavailable =>
      'Non disponibile su questo dispositivo';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get languageEnglishShort => 'EN';

  @override
  String get languageItalianShort => 'IT';

  @override
  String get settingsLogout => 'Esci';

  @override
  String settingsVersion(String version) {
    return 'CampusArena · v$version';
  }

  @override
  String settingsPasswordResetSent(String email) {
    return 'Email di reset password inviata a $email.';
  }

  @override
  String get settingsPasswordResetError =>
      'Impossibile inviare l\'email di reset. Controlla la connessione e riprova.';

  @override
  String get settingsPrivacyTitle => 'Privacy';

  @override
  String get settingsPrivacyIntro =>
      'Ecco cosa CampusArena memorizza su di te.';

  @override
  String get settingsPrivacyProfile =>
      'Profilo: nome, username, email e corso di laurea.';

  @override
  String get settingsPrivacyMatches =>
      'Risultati delle partite: punteggi e avversari delle partite ranked che giochi.';

  @override
  String get settingsPrivacyRatings =>
      'Punteggi: il tuo ELO e la posizione nel campus per ogni sport.';

  @override
  String get settingsPrivacyLocation =>
      'Posizione: un controllo di distanza una tantum al check-in in una struttura — mai un tracciamento continuo.';

  @override
  String get settingsPrivacySharing =>
      'CampusArena non condivide i tuoi dati con terze parti.';

  @override
  String get friendsTitle => 'Amici';

  @override
  String get friendsAddSectionTitle => 'Aggiungi un amico';

  @override
  String get friendsSearchHint => 'Cerca per username';

  @override
  String get friendsSearchHelper =>
      'Cerca giocatori per username, poi tocca Aggiungi.';

  @override
  String get friendsAddButton => 'Aggiungi';

  @override
  String get friendsAddedLabel => 'Aggiunto';

  @override
  String get friendsYouLabel => 'Tu';

  @override
  String friendsHandle(String username) {
    return '@$username';
  }

  @override
  String get friendsEmptyTitle => 'Ancora nessun amico';

  @override
  String get friendsEmptyBody =>
      'Cerca un giocatore per username qui sopra per iniziare la tua classifica privata.';

  @override
  String get friendsLoadError => 'Impossibile caricare i tuoi amici.';

  @override
  String get friendsRemoveTooltip => 'Rimuovi amico';

  @override
  String get friendsRemoveTitle => 'Rimuovere l\'amico?';

  @override
  String friendsRemoveMessage(String name) {
    return 'Rimuovere $name dai tuoi amici?';
  }

  @override
  String get friendsRemoveConfirm => 'Rimuovi';

  @override
  String get friendsRemoveCancel => 'Annulla';

  @override
  String friendsAddedSnack(String username) {
    return '$username aggiunto ai tuoi amici.';
  }

  @override
  String friendsSearchEmpty(String query) {
    return 'Nessun giocatore corrisponde a “$query”.';
  }

  @override
  String get friendsSearchFailed => 'Impossibile cercare al momento. Riprova.';

  @override
  String get friendsAddFailedSnack =>
      'Impossibile aggiungere l\'amico. Riprova.';

  @override
  String get tournamentCreateTitle => 'Crea torneo';

  @override
  String get tournamentNameLabel => 'Nome torneo';

  @override
  String get tournamentSportLabel => 'Sport';

  @override
  String get tournamentFacilityLabel => 'Struttura';

  @override
  String get tournamentMaxLabel => 'Max partecipanti';

  @override
  String get tournamentDeadlineLabel => 'Scadenza iscrizioni';

  @override
  String get tournamentScheduleLabel => 'Orario previsto';

  @override
  String get tournamentPickPrompt => 'Seleziona';

  @override
  String get tournamentCreateButton => 'Crea';

  @override
  String get tournamentNameRequired => 'Inserisci un nome per il torneo';

  @override
  String get tournamentFacilityRequired => 'Seleziona una struttura';

  @override
  String get tournamentScheduleRequired => 'Seleziona un orario previsto';

  @override
  String get tournamentDeadlineFuture => 'La scadenza deve essere nel futuro';

  @override
  String get tournamentDeadlineBeforeSchedule =>
      'La scadenza deve essere entro l\'orario previsto';

  @override
  String get tournamentCreateError => 'Impossibile creare il torneo. Riprova.';

  @override
  String get tournamentLoadError => 'Impossibile caricare il torneo.';

  @override
  String get tournamentRegistrationOpenTitle => 'Iscrizioni aperte';

  @override
  String get tournamentRegistrationOpenBody =>
      'Il tabellone apparirà una volta chiuse le iscrizioni alla scadenza, o prima se si riempie.';

  @override
  String get tournamentCancelledTitle => 'Torneo annullato';

  @override
  String get tournamentCancelledBody =>
      'Non si sono iscritti abbastanza giocatori prima della scadenza.';

  @override
  String tournamentCompletedBanner(String name) {
    return '$name ha vinto il torneo!';
  }

  @override
  String get bracketBye => 'BYE';

  @override
  String get roundOf32 => 'Sedicesimi';

  @override
  String get roundOf16 => 'Ottavi';

  @override
  String get roundQuarterfinal => 'Quarti';

  @override
  String get roundSemifinal => 'Semifinali';

  @override
  String get roundFinal => 'Finale';

  @override
  String get tournamentsTitle => 'Tornei';

  @override
  String get tournamentsTooltip => 'Tornei';

  @override
  String get tournamentsUpcoming => 'Prossimi';

  @override
  String get tournamentsOngoing => 'In corso';

  @override
  String get tournamentsEmptyTitle => 'Ancora nessun torneo';

  @override
  String get tournamentsEmptyBody =>
      'I nuovi tornei per questo sport appariranno qui.';

  @override
  String get tournamentsLoadError => 'Impossibile caricare i tornei.';

  @override
  String get tournamentToday => 'Oggi';

  @override
  String get tournamentTomorrow => 'Domani';

  @override
  String get tournamentRegister => 'Iscriviti';

  @override
  String get tournamentRegistered => 'Iscritto';

  @override
  String get tournamentFull => 'Completo';

  @override
  String get tournamentStatusRegistering => 'Iscrizioni';

  @override
  String get tournamentStatusSeeded => 'Sorteggiato';

  @override
  String get tournamentStatusActive => 'In corso';

  @override
  String get tournamentStatusCompleted => 'Concluso';

  @override
  String get tournamentStatusCancelled => 'Annullato';

  @override
  String get tournamentRegisteredSnack => 'Iscrizione confermata.';

  @override
  String get tournamentRegisterError => 'Iscrizione non riuscita. Riprova.';

  @override
  String get tournamentStandings => 'Classifica';

  @override
  String get tournamentOrganizerControls => 'Controlli organizzatore';

  @override
  String get tournamentAdvanceSlot => 'Avanza slot';

  @override
  String get tournamentMarkForfeit => 'Segna forfait';

  @override
  String get tournamentBracket => 'Tabellone';

  @override
  String get tournamentDetailError => 'Impossibile caricare questo torneo.';

  @override
  String get tournamentCancelAction => 'Annulla torneo';

  @override
  String get tournamentCancelTitle => 'Annullare questo torneo?';

  @override
  String get tournamentCancelBody =>
      'I giocatori iscritti verranno avvisati dell\'annullamento. L\'operazione è irreversibile.';

  @override
  String get tournamentCancelConfirm => 'Annulla torneo';

  @override
  String get tournamentCancelDismiss => 'Mantieni';

  @override
  String get tournamentForfeitTitle => 'Segna un giocatore come ritirato';

  @override
  String get tournamentAdvanceTitle => 'Avanza uno slot';

  @override
  String tournamentAdvancePickWinner(String slot) {
    return 'Chi ha vinto $slot?';
  }

  @override
  String tournamentSlotVs(String playerA, String playerB) {
    return '$playerA vs $playerB';
  }

  @override
  String get tournamentNoPlayableSlots => 'Nessuno slot pronto per avanzare.';

  @override
  String get tournamentNoAliveParticipants =>
      'Nessun giocatore attivo da ritirare.';

  @override
  String get challengePendingTitle => 'Sfida in sospeso';

  @override
  String challengeChallengedYou(String sport) {
    return 'ti ha sfidato a $sport';
  }

  @override
  String get challengeAccept => 'Accetta';

  @override
  String get challengeDecline => 'Rifiuta';

  @override
  String get challengeAcceptTooltip => 'Accetta la sfida';

  @override
  String get challengeDeclineTooltip => 'Rifiuta la sfida';

  @override
  String get challengeButtonTooltip => 'Sfida';

  @override
  String challengeSheetTitle(String name) {
    return 'Sfida $name';
  }

  @override
  String get challengeSheetPickSport => 'Scegli uno sport';

  @override
  String get challengeSheetSend => 'Invia sfida';

  @override
  String challengeSentSnack(String name) {
    return 'Sfida inviata a $name.';
  }

  @override
  String get challengeErrorDuplicate =>
      'Hai già una sfida in sospeso con questa persona per questo sport.';

  @override
  String get challengeErrorNotFriends => 'Puoi sfidare solo gli amici.';

  @override
  String get challengeErrorGeneric => 'Impossibile inviare la sfida. Riprova.';

  @override
  String get challengeActionExpired => 'Questa sfida è scaduta.';

  @override
  String get challengeActionUnavailable =>
      'Impossibile rispondere ora. Controlla la connessione e riprova.';

  @override
  String get challengeActionNoLongerAvailable =>
      'Questa sfida non è più disponibile.';

  @override
  String challengeReceivedSnack(String name) {
    return 'Nuova sfida da $name.';
  }

  @override
  String get challengeOutgoingSectionTitle => 'Inviate';

  @override
  String challengeOutgoingLabel(String name) {
    return 'vs $name';
  }

  @override
  String get challengeStatusWaiting => 'In attesa';

  @override
  String get challengeStatusAccepted => 'Accettata';

  @override
  String get challengeStatusDeclined => 'Rifiutata';

  @override
  String get challengeStatusExpired => 'Scaduta';

  @override
  String get challengePlayerFallback => 'Un giocatore';

  @override
  String get challengeScreenTitle => 'Sfida';

  @override
  String challengeWaitingTitle(String name) {
    return 'In attesa di $name';
  }

  @override
  String get challengeWaitingBody => 'Vedrà la tua sfida nell\'app.';

  @override
  String get challengeScanToPlay => 'Scansiona per giocare';

  @override
  String get challengeAcceptedCta =>
      'Sfida accettata — scansiona il QR del tavolo per iniziare.';

  @override
  String get challengeNotFound => 'Sfida non trovata.';

  @override
  String get challengeLoadError => 'Impossibile caricare questa sfida.';

  @override
  String get achievement_first_victory_name => 'Prima Vittoria';

  @override
  String get achievement_first_victory_desc =>
      'Vinci la tua prima partita competitiva.';

  @override
  String get achievement_streak_5_name => 'Inarrestabile';

  @override
  String get achievement_streak_5_desc =>
      'Vinci 5 partite competitive di fila.';

  @override
  String get achievement_giant_slayer_name => 'Ammazzagiganti';

  @override
  String get achievement_giant_slayer_desc =>
      'Batti un avversario con 200+ ELO più di te.';

  @override
  String get achievement_explorer_name => 'Esploratore';

  @override
  String get achievement_explorer_desc =>
      'Gioca almeno una volta in ogni struttura del campus.';

  @override
  String get achievement_tournament_champion_name => 'Campione';

  @override
  String get achievement_tournament_champion_desc =>
      'Vinci un torneo ufficiale.';

  @override
  String get achievement_workaholic_name => 'Stakanovista';

  @override
  String get achievement_workaholic_desc => 'Gioca 15 partite in un solo mese.';

  @override
  String get profileAchievementsTitle => 'Obiettivi';

  @override
  String achievementUnlockedOn(String date) {
    return 'Sbloccato il $date';
  }

  @override
  String achievementUnlockHint(String description) {
    return 'Sblocca con: $description';
  }

  @override
  String get achievementUnlockHeadline => 'Obiettivo sbloccato!';

  @override
  String get chatbotClearChat => 'Cancella chat';

  @override
  String get chatbotSettingsTooltip => 'Impostazioni assistente';

  @override
  String get chatbotGreeting =>
      'Ciao! Chiedimi dei tavoli liberi, dei tornei di oggi, dell\'ELO o della tua posizione in coda.';

  @override
  String get chatbotInputHint => 'Chiedi all\'Assistente Arena...';

  @override
  String get chatbotSend => 'Invia';

  @override
  String get chatbotLimitedModeBadge =>
      'Modalità limitata - solo risposte di base';

  @override
  String get chatbotErrorMessage =>
      'Non sono riuscito a contattare l\'assistente — mostro risposte di base.';

  @override
  String get chatbotRetry => 'Riprova';

  @override
  String get chatbotChipEmptyTables => 'Quali tavoli sono liberi?';

  @override
  String get chatbotChipTournamentsToday => 'Tornei di oggi';

  @override
  String get chatbotChipHowElo => 'Come funziona l\'ELO?';

  @override
  String get chatbotChipQueuePosition => 'Dove sono in coda?';

  @override
  String get chatbotOpenMap => 'Apri Mappa';

  @override
  String get chatbotViewTournament => 'Visualizza';

  @override
  String get chatbotDismissBanner => 'Chiudi';

  @override
  String get chatbotHomeEntryTitle => 'Assistente Arena';

  @override
  String get chatbotHomeEntrySubtitle => 'Chiedi su tavoli, tornei ed ELO';

  @override
  String get tutorialSlide3Disclaimer =>
      'La disponibilità riflette solo l\'attività dell\'app — non è una garanzia in tempo reale, né una prenotazione.';

  @override
  String get chatbotSettingsTitle => 'Impostazioni Assistente';

  @override
  String get chatbotSettingsProviderLabel => 'Provider';

  @override
  String get chatbotSettingsApiKeyLabel => 'Chiave API';

  @override
  String get chatbotSettingsModelLabel => 'Modello';

  @override
  String get chatbotSettingsShowKey => 'Mostra chiave API';

  @override
  String get chatbotSettingsHideKey => 'Nascondi chiave API';

  @override
  String get chatbotSettingsTestConnection => 'Testa Connessione';

  @override
  String get chatbotSettingsSave => 'Salva';

  @override
  String get chatbotSettingsSaved => 'Impostazioni assistente salvate';

  @override
  String get chatbotSettingsTestSuccess => 'Connessione riuscita';

  @override
  String get chatbotSettingsTestFailurePrefix => 'Connessione fallita:';

  @override
  String get chatbotSettingsNoKeyBanner =>
      'Nessuna chiave API configurata — l\'assistente risponde in modalità limitata. Aggiungi una chiave per abilitare le risposte AI complete.';

  @override
  String get chatbotSettingsResetModelPrompt =>
      'Ripristinare il campo modello al valore predefinito di questo provider?';

  @override
  String get chatbotSettingsResetModelYes => 'Ripristina';

  @override
  String get chatbotSettingsResetModelNo => 'Mantieni';

  @override
  String get chatbotErrorInvalidApiKey =>
      'Questa chiave API è stata rifiutata. Controllala e riprova.';

  @override
  String get chatbotErrorRateLimited =>
      'Il provider sta limitando le richieste in questo momento. Riprova tra poco.';

  @override
  String get chatbotErrorNetwork =>
      'Impossibile raggiungere la rete. Controlla la connessione e riprova.';

  @override
  String get chatbotErrorMissingApiKey => 'Aggiungi prima una chiave API.';

  @override
  String get chatbotErrorGeneric =>
      'Qualcosa è andato storto contattando l\'assistente.';

  @override
  String get chatbotErrorTimeout =>
      'L\'assistente ha impiegato troppo tempo a rispondere. Riprova.';

  @override
  String get chatbotAnswerNoFreeTables =>
      'Al momento nessun tavolo risulta libero in base all\'attività dell\'app.';

  @override
  String chatbotAnswerFreeTables(String names) {
    return 'Liberi adesso: $names.';
  }

  @override
  String get chatbotAnswerNoTournaments =>
      'Non ci sono tornei in programma per oggi.';

  @override
  String chatbotAnswerTournamentsToday(String names) {
    return 'Tornei di oggi: $names.';
  }

  @override
  String get chatbotAnswerQueueNone => 'Al momento non sei in nessuna coda.';

  @override
  String chatbotAnswerQueuePosition(int position, String facility) {
    return 'Sei in posizione $position nella coda per $facility.';
  }

  @override
  String get chatbotAnswerEloExplainer =>
      'Su CampusArena ogni giocatore parte da 1200 di ELO. Dopo ogni partita confermata, il vincitore guadagna punti e chi perde ne perde, in base alla differenza di ELO tra i due giocatori (battere un avversario più forte vale più che battere uno più debole). Il fattore K (quanto una singola partita può spostare il tuo punteggio) è 32 per le prime 10 partite in uno sport, poi scende a 16 una volta consolidato. I punteggi sono calcolati separatamente per ogni sport (Ping Pong, Calcio Balilla). I punteggi possono anche decadere gradualmente dopo una lunga inattività.';

  @override
  String chatbotAnswerYourElo(int elo, int matches) {
    return 'Il tuo ELO attuale a Ping Pong è $elo dopo $matches partite.';
  }

  @override
  String chatbotAnswerYourEloRanked(int elo, int rank, int matches) {
    return 'Il tuo ELO attuale a Ping Pong è $elo, in posizione #$rank, dopo $matches partite.';
  }

  @override
  String get chatbotAnswerGeneral =>
      'Posso aiutarti con tavoli liberi, tornei di oggi, ELO e la tua posizione in coda. Prova una delle domande suggerite qui sotto, oppure chiedimi direttamente.';
}
