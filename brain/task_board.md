# CampusArena — Unified Task Board

> **Team:** A · B · C
> **Status:** `[ ]` todo · `[/]` in progress · `[x]` done
> **Priority tiers:** 🔴 Spine (must ship) · 🟡 Strong (should ship) · 🟢 Stretch (if time permits)

---

## Phase Overview

| Phase |
|---|
| **0 — Foundation** |
| **1 — Core Infra & Auth** |
| **2 — Nav Shell & Core Screens** |
| **3 — Map, Queue & Weather** |
| **4 — Match Flow & ELO Engine** |
| **5 — Leaderboards & Profile** |
| **6 — Tournaments & Challenges** |
| **7 — Polish, Testing & Ship** |

> [!IMPORTANT]
> Phases 0–4 are the critical path. If any of those slip, cut from Phase 6 Stretch items first, then Phase 5 Strong items. Never cut Spine tasks.
> **Arena Assistant cut line (🟡):** if Phase 4 slips, drop the LLM — C2 ships as the rule-based intent matcher only, keeping C1 + C3. That still demos both flagship queries ("empty tables", "tournaments today") off seeded data, with the disclaimer.

---

## Phase 0 — Foundation *(all three)*

> [!NOTE]
> Everything here is done together or in a short huddle. No one moves to Phase 1 until Phase 0 is green.

### 🔴 Spine

- [x] **Huddle:** assign Vertical A / B / C to the three people. Agree git workflow: `develop`-based flow (feature/fix branches off `develop`, `main` for deliverable releases), merge cadence, who reviews whose PRs
- [x] **Lock Firestore schema** (collections + fields): `users`, `ratings`, `facilities` (with nested `queue` subcollection), `matches`, `tournaments` (with nested `participants` subcollection), `challenges`, `achievementDefs`
- [x] **Flutter project scaffold** — `flutter create`, configure `pubspec.yaml` with all dependencies (`flutter_bloc`, `go_router`, `fl_chart`, `mobile_scanner`, `geolocator`, `intl`, etc.), directory structure: `lib/core/`, `lib/features/`, `lib/models/`, `lib/repositories/`, `lib/routing/`
- [x] **Material 3 ThemeData** — seeded color scheme, typography, component themes
- [x] **ARB scaffolding** — `app_en.arb`, `app_it.arb` with `flutter_localizations` + `intl` wired in `MaterialApp.router`
- [x] **Firebase project** — create project, register Android + iOS apps, `google-services.json` / `GoogleService-Info.plist`, enable Auth (email/password), create Firestore, enable FCM (Android only, no APNs due to free Apple Dev account)
- [x] **`go_router` skeleton** — `StatefulShellRoute` with 4 bottom-nav tab stubs + one example Cubit

### 🟡 Strong

- [x] **Design document diagrams** — use-case diagram (actors × features), architecture diagram (client / Firebase / external APIs), match-flow state machine, queue sequence diagram, navigation flow diagram
- [x] **FCM end-to-end test** — one real push to an Android physical device (added some temp code, tested and then removed)

---

## Phase 1 — Core Infrastructure & Auth

### 🔴 Spine — Data Models *(A)*
- [x] `UserModel` (uid, name, username, email, degreeProgram, language, pushTokens, friendUids, badges, onboardingComplete, disputeCount, disputePenaltyUntil, createdAt)
- [x] `RatingModel` (ratingId, ownerType, ownerId, memberUids, sportId, degreeProgram, elo, matchesPlayed, lastMatchAt)
- [x] `FacilityModel` (facilityId, name, sportId, coordinates GeoPoint, qrCode, fallbackCode, isOutdoor, status, currentMatchId, kingOfTableUid, kingOfTableWins, queueTailPosition, freedAt)
- [x] `QueueEntryModel` (userId, position, joinedAt)
- [x] `MatchModel` (matchId, facilityId, sportId, mode, playerUids, team1PairId, team2PairId, state, submittedByUid, result, eloBefore, eloDeltas, tournamentId, tournamentRound, gpsDistanceMeters, startedAt, confirmedAt)
- [x] `TournamentModel` (tournamentId, name, sportId, facilityId, organizerId, maxParticipants, status, bracket, winnerUid, eloMultiplier, registrationDeadline, scheduledAt, createdAt)
- [x] `TournamentParticipantModel` (uid, seed, eliminated)
- [x] `ChallengeModel` (challengeId, fromUserId, toUserId, sportId, status, matchId, createdAt, respondedAt)

### 🔴 Spine — Repository Layer *(B)*

- [x] `AuthRepository` — wraps Firebase Auth (signIn, signUp, signOut, resetPassword, authStateChanges stream)
- [x] `UserRepository` — CRUD on `users/{uid}` (create, get, update, stream)
- [x] `FacilityRepository` — read facilities, stream status, update status
- [x] `MatchRepository` — create match, submit result, confirm, dispute, stream active match
- [x] `QueueRepository` — join (Firestore transaction), leave, stream queue, get position
- [x] `TournamentRepository` — CRUD tournaments, manage bracket, stream
- [x] `RatingRepository` — owns the whole `ratings` collection (user + pair): deterministic `ratingId`/`pairId`, seed user ratings at registration, get/stream ratings, get-or-create pair rating, update ELO, leaderboard query. *(Absorbs the originally-planned `PairRepository`; pair ELO is just `ownerType = pair` in this collection.)*

### 🔴 Spine — Auth Flow UI + State *(C)*

- [x] `AuthCubit` — states: initial, loading, authenticated, unauthenticated, error
- [x] Splash screen (check auth state on launch)
- [x] Landing page (Register / Log In)
- [x] Login screen with form validation
- [x] Registration screen (name, email, password, degree-program dropdown from fixed list)
- [x] Forgot Password screen
- [x] Wire auth screens to `AuthCubit` + `AuthRepository`

---

## Phase 2 — Navigation Shell & Core Screens

### 🔴 Spine — Routing & Navigation Shell *(A)*

- [x] `GoRouter` with `StatefulShellRoute` (4 tabs: Home, Map, Leaderboards, Profile)
- [x] Route constants and path parameters (`/play/court/:id`, `/challenge/:id`)
- [x] `NavigationBar` ↔ `NavigationRail` switch at 600dp via `LayoutBuilder`
- [x] Auth guard (redirect unauthenticated → login)

### 🔴 Spine — Profile Setup & Onboarding *(B)*

- [x] ~~Profile setup screen: avatar picker, permission requests (camera, GPS)~~ — removed: the chosen preset avatar was never displayed (identity avatars are used everywhere) and the permissions are already requested contextually by the scanner and map
- [x] Mini-tutorial screen (skippable animated walkthrough, re-accessible from settings)
- [x] `OnboardingCubit` — persist `onboardingComplete` to Firestore when the tutorial finishes
- [x] First-launch detection logic (new users → onboarding, returning users → skip)

### 🔴 Spine — Home / Dashboard Tab *(C)*

- [x] `DashboardCubit` — load current user ELO, rank, recent matches; persist the selected sport
- [x] Sport selector chips (Ping Pong / Foosball) — single selection persisted in the cubit, driving the hero card and the history filter *(realigned to `docs/design`; the earlier "show all sports at once, no selector" simplification is reverted)*
- [x] ELO + campus-rank hero card for the selected sport *(rank via `RatingRepository.getUserRank` count aggregation)*
- [x] "Play" button (placeholder snackbar; QR scan flow lands in Phase 4/B)
- [x] Recent match history list (last 5 terminal-state matches for the selected sport)
- [x] Arena Assistant entry card → `/chatbot` route (stub screen until Phase 6 C3)
- [x] Tablet ≥600dp split-view: ELO summary and recent activity side by side *(pulled forward from Phase 7B)*

---

## Phase 3 — Facility Map, Queue & Weather

### 🔴 Spine — Facility Map *(A)*

- [x] OpenStreetMap integration via `flutter_map` with campus center + initial zoom
- [x] `FacilityCubit` — stream all facilities, emit real-time status changes
- [x] Color-coded map markers (green / red / yellow) bound to facility status
- [x] Tap marker → facility detail card overlay (current players, match duration, "King of the Table") — **must include the availability disclaimer footer** (`availabilityDisclaimerShort`; exact copy in `project_description.md` §3.10)

### 🔴 Spine — Queue System *(B)*

- [x] `QueueCubit` — join, leave, stream position, handle "table freed" events
- [x] "Join Queue" button on facility detail card
- [x] Real-time queue position display (live counter per facility)
- [x] Soft enforcement logic: priority warning UI when non-front user scans
- [x] Client-local table-freed alert when front-of-queue: the player's own facility listener detects `status → free`, surfacing an in-app banner + haptic (no server, so no targeted FCM push — per the Spark-Tier Trust Boundary)

### 🔴 Spine — Weather Integration *(C)*

- [x] `WeatherRepository` — fetch current conditions from Open-Meteo REST API by facility coordinates
- [x] `WeatherCubit` — load weather for a given facility, cache in memory
- [x] Weather snippet widget on outdoor facility detail cards (temp, precipitation, wind)

### 🟡 Strong

- [x] *(A)* Tablet split-view layout: map + facility list side-by-side (≥600dp)
- [x] *(A)* **(Assistant C4)** Disclaimer ARB keys in both `app_en.arb`/`app_it.arb` (`availabilityDisclaimerShort`, `availabilityDisclaimerFull`, `chatbotIntroDisclaimer`; exact copy in `project_description.md` §3.10) — the facility detail card consumes the short key from the start
- [x] *(A)* User-location dot + "center on my location" button on the map (`geolocator`, best-effort: hidden/no-op when permission is denied) — *added during Phase 3; the dot is in `map.png`, the recenter button is a deliberate addition with no design counterpart*
- [x] *(C)* Forecast widget for outdoor tournament views (scheduled timeslot forecast)
- [x] *(C)* Conditional display: only render weather widgets when `facility.isOutdoor == true`

---

## Phase 4 — Match Flow & ELO Engine

### 🔴 Spine — ELO Engine *(A)*

- [x] Pure Dart `EloCalculator`: expected score formula, rating update, K-factor logic (K=32 if <10 matches, else K=16)
- [x] Inactivity decay function (lazy at read time, erode only gains above 1200)
- [x] Unit tests for ELO edge cases (provisional switch, decay, ties)

### 🔴 Spine — QR Check-In & Active Match *(B)*

- [x] QR scan screen using `mobile_scanner` (camera viewfinder + scan feedback)
- [x] Manual fallback code entry (text input for printed alphanumeric code)
- [x] `MatchCubit` — active match lifecycle (idle → scanned → waiting_opponent → active → result_submitted → confirmed/disputed)
- [x] GPS soft-check on scan: log distance via `geolocator`, show warning if beyond threshold, never block
- [x] Active match screen: live timer, player names/ELOs, "Record Result" button
- [x] Deep link handling: `/play/court/:id` → match flow

### 🔴 Spine — Result Entry & Confirmation *(C)*

- [x] `ScoringStrategy` interface: `validateResult()`, `getResultWidget()`, `computeMatchOutcome()`
- [x] `PingPongScoringStrategy` (set-based scoring)
- [x] `FoosballScoringStrategy` (goal-count scoring)
- [x] `ScoringStrategyFactory` — `sportId` → concrete strategy
- [x] Result input screen (sport-specific score entry via strategy widget)
- [x] Opponent confirmation screen (confirm / dispute)
- [x] Match summary screen (ELO delta animation, updated rank)
- [x] Firestore atomic transaction: write result + update ELOs + update facility status in one batch
- [x] Unconfirmed / Abandoned / Disputed handling (no ELO change, facility freed)

> [!IMPORTANT]
> **Phase 4 Transaction Rule:** `confirmResult` must be a single atomic transaction. Do not call `RatingRepository.updateElo` separately after confirming the match. The two ratings doc updates must be folded directly into the match confirmation transaction to prevent desyncs between match history and ratings.

> [!NOTE]
> **ELO engine is merged and waiting to be wired (B→C handoff).** `EloCalculator.computeUpdate({eloA, matchesPlayedA, eloB, matchesPlayedB, outcomeA, multiplier})` (`core/elo/elo_calculator.dart`) returns per-side deltas and new ELOs; it is pure and side-effect-free. `MatchRepository.confirmResult` (Vertical B) already accepts `eloBefore`/`eloDeltas` maps and persists them verbatim inside its transaction — it never computes them. **4C owns the compute-and-supply layer:** read both entities' ratings, call `computeUpdate`, and pass the results into `confirmResult` (folding the ratings-doc writes into that same transaction per the rule above). Until this lands, confirming a match persists `null` ELO, so history renders no delta.

### 🟡 Strong

- [x] *(A)* Tournament ELO multiplier (μ=1.5 configurable)
- [x] *(A)* Doubles ELO: resolve pair → compute update on pair entity
- [x] *(A)* Doubles `pairId` logic + unit test
- [x] *(A)* Lazy inactivity decay unit tests

---

## Phase 5 — Leaderboards & Profile Stats

### 🔴 Spine — Leaderboards *(A)*

- [x] `LeaderboardCubit` — query top 100 by sport, by degree program, by friends
- [x] Global ranking list view (top-100 cap)
- [x] Filter chips: per-sport, friends-only, degree program (course rivalry)
- [x] Search bar to find any registered player

### 🔴 Spine — Player Profile & Stats *(B)*

- [x] `ProfileCubit` — load full stats, ELO history, achievements
- [x] ELO trend graph using `fl_chart` (line chart over time, per sport)
- [x] Stats display: total games, wins, losses, win rate, current/all-time streak
- [x] Full match history log (scrollable list: opponent, score, date, facility)

### 🔴 Spine — Friends & Settings *(C)*

- [x] `FriendsCubit` — add by username, remove, stream friends list
- [x] Add-friend UI (username search + add button)
- [x] Friends list screen (filter source for leaderboards)
- [x] Settings screen: change password, notification preferences, language toggle (EN/IT), privacy
- [x] Logout flow

### 🟡 Strong

- [x] *(A)* Tapping a player row → view their public profile stats *(navigation + `/profile/:uid` identity stub shipped with the leaderboard; the stats body lands with 5B profile-stats)*
- [x] *(B)* Isolate-based chart data computation for long match histories
- [x] *(B)* "Black Beast" and "Favorite Victim" labels (≥3-match gate)

### 🟡 Strong — Arena Assistant core *(whoever is lightest-loaded, parallel — branch `feature/[X]-assistant-core`)*

- [x] **(D1)** UI design system (incl. Assistant screen) → committed to `docs/design/`
- [x] **(C1)** `ChatbotToolsService` — read-only tools over existing repositories (`getEmptyTables`, `getTournamentsToday`, `getFacilityStatus`, `getMyQueuePosition`, `getMyEloAndRank`, `getLeaderboardTop`), typed result objects, every query bounded (`limit ≤ 25`), no direct Firestore access — unit tests with mocked repos
- [x] **(C1)** One-shot repo methods: `FacilityRepository.getFacilitiesByStatus()`, `TournamentRepository.getTournamentsInWindow()` (+ composite index in `app/firestore.indexes.json` if the window query needs one)
- [x] **(C2)** `ChatbotRepository` — LLM function calling (free-tier provider per Decision Log; add its SDK or HTTP dep to `pubspec.yaml`, key via `--dart-define=ASSISTANT_API_KEY`), system prompt distilled from `project_description.md` + user language, disclaimer appended **in code** whenever an availability tool fired — never trusted to the LLM
- [x] **(C2)** `RuleBasedIntentMatcher` deterministic fallback (keyword → tool → templated ARB answer) for LLM error / quota / offline, with localized "limited mode" notice — tests incl. airplane-mode path

---

## Phase 6 — Tournaments & Challenges

### 🔴 Spine — Tournament System *(A)*

- [x] Create tournament form: sport, facility, max participants, registration deadline
- [x] `TournamentCubit` — lifecycle (registration → seeded → in_progress → completed)
- [x] Automatic bye assignment for non-power-of-2 counts
- [x] Live bracket view widget (single-elimination tree with visual byes)

### 🔴 Spine — Tournament Management *(B)*

- [x] Tournament browser screen (upcoming + ongoing, filterable by sport)
- [x] Tournament detail / profile page (participants, standings, schedule)
- [x] Organiser controls: manually advance slots, mark forfeits
- [x] Tournament match result flow (reuse match flow with tournament context)
  - *Entry point deviation: the Home AppBar trophy button is the only tournaments entry (team decision: no 5th nav tab, no Home body card). No design counterpart — precedent: the map recenter button (§ Phase 3).*

### 🟡 Strong — Direct Challenges *(C — branch `feature/C-challenges`, PR #21)*

- [x] `ChallengeCubit` — send challenge (friends only), accept, decline
- [x] Challenge notification (deep link `/challenge/:id`)
  - *Spark-tier deviation: no FCM push (no server sender on Spark). The "you were challenged" alert is client-local — the recipient's own incoming stream detects a new pending challenge and raises an in-app SnackBar + haptic while foregrounded. The `/challenge/:id` deep link is kept working for a future Blaze-tier sender to target. Mirrors the queue-ready alert pattern (§ Phase 3).*
- [x] Incoming challenge UI (accept / decline prompt)
  - *Respond failures are surfaced with distinct copy (expired vs offline/transient vs no-longer-pending) rather than one blanket message; a truly expired challenge leaves the inbox on the lazy-expiry write.*
- [x] Challenge list in Dashboard or Profile (pending / recent)
  - *Design deviation: no dedicated challenge mockup in `docs/design/screenshots/`; the pending card + sport-pick sheet extend the `home.png` / `friends.png` patterns. No design counterpart — precedent: the map recenter button (§ Phase 3) and the tournaments trophy entry (this phase).*
- [x] Wire accepted challenge → standard QR check-in match flow (accepted state → scan-to-play CTA)

### 🟡 Strong

- [x] *(A)* Bracket re-seeding at deadline if registration doesn't fill
- [x] *(B)* Apply tournament ELO multiplier on confirmed tournament match results

### 🟡 Strong — Arena Assistant UI *(C — branch `feature/C-assistant-ui`)*

- [x] **(C3)** `ChatCubit` (initial-with-chips / sending / awaitingTools / answered / error) + chat screen per `docs/design/`: message bubbles, typing indicator, suggested-question chips, facility/tournament answer cards with disclaimer footer, first-open disclaimer banner, error/retry, offline "limited mode" pill
- [x] **(C3)** `/chatbot` route (auth-guarded, outside the shell) + Home entry point wiring + provide `ChatbotRepository` in `main.dart`
- [x] **(C3)** Remaining chatbot ARB keys EN+IT (`chatbotTitle`, `chatbotHint`, chips, error/limited-mode strings)
- [x] **(C4)** One disclaimer line in the mini-tutorial's map step (`mini_tutorial_screen.dart`)
- [x] **(C3)** Widget tests: chips send queries; disclaimer banner visible on first open; facility card shows disclaimer footer; error state offers retry; both locales render

---

## Phase 7 — Polish, Testing & Ship

> [!WARNING]
> This is the final window. No new features. Only integration, testing, polish, and delivery prep.

### 🔴 Spine — Cross-Vertical Integration *(all three)*

- [x] Integration pass — verify 3 shared contracts hold in practice (cross-vertical tests in `app/test/integration/`):
  1. Match document shape mid-confirmation (match vertical writes, profile/history reads)
  2. Facility status field flips busy/free (match vertical writes, map listens)
  3. Queue position write (queue owns the transaction, check-in checks it)
- [x] **(Assistant)** E2E pass against real tournament/facility data (post-Phase-6): both flagship queries truthful, disclaimer visible
- [x] Check Firebase usage against Spark (free-tier) limits

### 🔴 Spine — Localization Pass *(A)*

- [x] Audit all screens for hardcoded strings → move to ARB files
- [x] Complete `app_it.arb` Italian translations
- [x] Test both locales end-to-end (switch language in settings, verify all screens)

### 🔴 Spine — Testing Campaign *(B)*

- [x] Unit tests: ELO calculator, scoring strategies, pair ID generation, queue ordering
- [x] Widget tests: auth forms, leaderboard filters, match confirmation flow, bracket rendering
- [x] Verify CI pipeline (`flutter_ci.yml`): lint + analyze + test on push/PR *(analyze runs `--fatal-infos --fatal-warnings`, which subsumes the lint rules)*

### 🔴 Spine — Design Doc & Demo *(C)*

- [x] Finalize design document: final architecture diagrams, screenshot catalog, test-case matrix, proofread `main.tex`
- [x] Firestore seeding script (campus facilities with coordinates, QR codes, `isOutdoor` flags)
- [x] Demo dataset (seed users with match histories for leaderboard/stats demo) — **(Assistant C5)** include mixed facility statuses + ≥1 tournament scheduled "today" so both flagship chatbot queries return non-empty answers
- [x] Demo script + rehearsal — **(Assistant C5)** include 2 scripted Assistant exchanges (the flagship queries: "What tables are empty?", "Tournaments today") with visible disclaimer; rehearse the airplane-mode fallback
- [x] Final README update (build/run instructions incl. `--dart-define=ASSISTANT_API_KEY=...`, project overview)

### 🟡 Strong — Achievements *(A)*

- [x] Define achievement models and conditions (First Victory, 5-Win Streak, Giant Slayer, Explorer, Tournament Champion, Workaholic)
- [x] Client-side achievement evaluation logic within confirmed match transaction
- [x] Achievement badge display on profile screen

### 🟡 Strong — Responsive Polish *(B)*

- [x] Dashboard tablet split-view (ELO summary + recent activity side-by-side, ≥600dp) *(landed in Phase 2C, line 108)*
- [x] Audit all screens for tablet correctness (constrained width, centered content) *(constrained/centered pattern applied across screens; verified on-device, iPad + phone)*
- [x] Material 3 theme consistency review *(all surfaces source `ColorScheme.fromSeed` roles; the chatbot facility-status card now reuses the canonical `facilityStatusColor` helper instead of raw `Colors.*`)*
- [x] Micro-animation polish: ELO delta, scan feedback, queue transitions *(ELO count-up in result summary; haptic scan-lock confirmation on QR capture; `AnimatedSize` + counter cross-fade on queue position changes)*

### 🟢 Stretch

- [x] *(C)* Integration tests: full match flow (scan → result → confirm → ELO update) using `fake_cloud_firestore`
- [x] *(A)* Screen mockups / wireframes (Figma exports) in design document

---

## Assignment Summary

| Phase | A | B | C |
|---|---|---|---|
| **0 — Foundation** | *shared* | *shared* | *shared* |
| **1 — Core Infra** | Data models (8) | Repository layer (7) | Auth flow UI + Cubit |
| **2 — Nav & Screens** | Routing shell, breakpoints | Onboarding + profile setup | Dashboard tab |
| **3 — Map & Queue** | Facility map + markers | Queue system + FCM | Weather integration |
| **4 — Match & ELO** | ELO engine + tests | QR scan + match lifecycle | Scoring strategies + result flow |
| **5 — Leaderboards** | Leaderboard tab + filters | Profile stats + charts | Friends + settings |
| **6 — Tournaments** | Tournament creation + bracket | Tournament mgmt + browser | Direct challenges + Assistant UI |
| **7 — Ship** | Localization + achievements | Testing + responsive polish | Design doc + demo + seeding (incl. Assistant) |

> **Arena Assistant ownership:** core (C1+C2) lands in the Phase-5 window by whoever is lightest-loaded; UI (C3) is C's in Phase 6; seeding/demo (C5) folds into C's Phase-7 tasks; the disclaimer keys (C4) ride with A's Phase-3 facility card.

---

## Feature Branch Map

One branch + one PR per feature; naming per `git_workflow.md`.

| Phase | A | B | C |
|---|---|---|---|
| 2C | — | — | `feature/C-dashboard` *(exists — finish it)* |
| 3 | `feature/A-facility-map` | `feature/B-queue-system` | `feature/C-weather` |
| 4 | `feature/A-elo-engine` | `feature/B-qr-match-flow` | `feature/C-result-flow` |
| 5 | `feature/A-leaderboards` | `feature/B-profile-stats` | `feature/C-friends-settings` · `feature/[X]-assistant-core` (lightest-loaded) |
| 6 | `feature/A-tournament-bracket` | `feature/B-tournament-mgmt` | `feature/C-assistant-ui` · `feature/C-challenges` |
| 7 | `feature/A-l10n-polish` | `feature/B-test-campaign` | `feature/C-seed-demo` |

---

## Shared Contracts (cross-vertical boundaries)

These are the integration surfaces where two verticals touch. Each pair must agree on the exact Firestore document shape and Cubit state contract before coding starts.

| Contract | Writer | Reader | Fields |
|---|---|---|---|
| Match document mid-confirmation | Match vertical | Profile/History vertical | `matchId`, `state`, `playerUids`, `result`, `eloDeltas` |
| Facility status flip | Match vertical | Map vertical | `facilities/{id}.status`, `facilities/{id}.currentMatchId` |
| Queue position | Queue vertical | Check-in flow | `facilities/{facilityId}/queue/{uid}.position` |

---

*CampusArena — 3 people, ship it.*
