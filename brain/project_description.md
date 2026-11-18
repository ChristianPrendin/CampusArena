# CampusArena
**DIMA Project — Design and Implementation of Mobile Applications**
*Politecnico di Milano · Team of 3 · Cross-Platform (Flutter)*

> **Purpose of this file:** living project-context document. It reflects all scope and technical decisions made so far and is intended to bring a new contributor up to speed quickly. Where a decision was deliberately made (or deliberately *cut*), it is stated as such so the reasoning isn't lost.

---

## 0. Decision Log (quick reference)

Key decisions made during planning, so context isn't buried in prose:

- **Sports at launch:** Ping Pong + Foosball only. Padel is a stretch goal. **3v3 Basketball is cut from implementation** (squad-of-3 pairing model + 6-player test/demo logistics are too costly for the timeline), but the data model stays squad-size-agnostic so it remains a documented future extension.
- **QR check-in:** primary mechanism, plus a short printed **alphanumeric fallback code** per facility for manual entry if the camera/sticker fails. Camera-based scene/location recognition was considered and **rejected** (operational problem, not a software one; fragile in a live demo; no extra rubric value).
- **GPS:** a **soft, non-blocking** check. Distance from facility is logged for audit and a warning shows if far outside threshold, but it **never blocks check-in** (indoor/covered GPS drift would otherwise risk failing the graded demo). Anti-cheat rests on QR presence + opponent confirmation.
- **ELO:** start 1200; K=32 while `matchesPlayed < 10` (this *is* the "provisional" phase — no separate flag needed), then K=16; inactivity decay computed **lazily at read time** (no scheduled Cloud Function needed). The project is expected to stay within Firebase's free (Spark) tier given the scale of a campus-only user base.
- **Spark-Tier Trust Boundary:** Due to the lack of a Blaze plan, Cloud Functions are replaced with client-side evaluations (for achievements) and lazy transitions (for facility timeouts). We accept client-side trust for user-owned cosmetic updates (badges) as a standard serverless compromise. Competitive updates (ELO) remain secured because they require live opponent confirmation and are written in transactions.
- **Doubles:** a pair is its own rated entity (deterministic `pairId` from sorted UIDs), not an average of singles ratings.
- **Result disputes & Griefer Mitigation:** `Disputed` status → no ELO change, both notified, **no in-app appeal**. However, players who abuse this feature (≥3 disputes) receive a 7-day cooldown where their dispute attempts are silently intercepted, forcing the match to `confirmed` to protect the ELO economy.
- **Match timeouts:** `Unconfirmed` (opponent never responds) and `Abandoned` (no result ever submitted) both resolve without ELO change and free the facility.
- **Tournaments:** **single-elimination only** (round-robin deferred to future work); automatic bye assignment for non-power-of-2 counts; organizer manually advances slots and marks forfeits; if registration doesn't fill, **proceed with a smaller re-seeded bracket** at the deadline.
- **Queue:** **soft enforcement** — front-of-queue player gets priority scanning; others get a "someone's ahead of you" warning but aren't hard-blocked. Position assigned inside a Firestore transaction to survive concurrent joins.
- **Direct challenges:** **friends only** (no "nearby player" discovery — would require continuous location tracking and brushes the social-network line). **No in-app scheduling fields** — accept/decline only; players coordinate offline and start via normal QR check-in. Challenges carry **no weather** info.
- **Friends:** minimal — add-by-username for a **private leaderboard filter only**. No profile visiting, no activity feed, no messaging. Kept narrow deliberately to stay clear of "social network."
- **Degree-program leaderboard:** kept, framed as **course rivalry** (e.g. CS vs Architecture) — competitive, not social. Collected at registration from a **fixed dropdown list** of Polimi programs (not free text, which would fragment the leaderboard).
- **"Black Beast" / "Favorite Victim":** require a **minimum sample size** (≥3 matches vs that specific opponent) before the label appears, to avoid noisy early-game labels.
- **Local persistence:** **SQLite dropped entirely.** Firestore's built-in offline persistence already covers cached reads offline. Offline match write-and-sync was **rejected** (server-authoritative ELO + offline local computation = a distributed-consistency problem that undermines the "Proof of Play" integrity story). Ranked matches require connectivity (QR scan + live opponent confirmation need it anyway).
- **State management:** **Cubit** (`flutter_bloc`), no event layer. Chosen over Riverpod/Provider because the team is learning from zero either way, so the in-class exposure + TA familiarity + testability (a direct rubric win) outweigh Riverpod's marginally gentler learning curve.
- **Navigation:** **go_router** for primary + deep-linkable routes (QR `/play/court/:id`, push `/challenge/:id`); bare `Navigator` for transient routes (dialogs, modals); `StatefulShellRoute` for the bottom-nav tabs so each tab keeps its own stack.
- **Design language:** **Material**, themed with **Material 3** (single consistent design language across platforms; no adaptive Cupertino theme). Optional `.adaptive` widgets only if time allows.
- **Internationalisation:** **English + Italian** via `flutter_localizations` + `intl` + ARB files. Set up from the start; never hardcode user-facing strings. Only UI chrome is translated (not player names/ELO values); use `intl` plural/number/date formatting.
- **Weather:** driven by a per-facility **`isOutdoor` flag** (some Ping Pong tables are outdoors). Current conditions show on **outdoor-facility detail cards**; a **forecast** shows on **tournaments involving outdoor facilities** (tournaments have a real scheduled time; challenges no longer do). Indoor facilities show no weather.
- **"Multiple threads" rubric line:** Dart `async`/`await` + `Future`s for lightweight I/O (Firestore listeners, GPS, weather, network), and a real **Isolate** for genuinely CPU-heavy work (e.g. building ELO-trend chart data from long match history) so the requirement is satisfied unambiguously by actual parallelism, not just async I/O.
- **Facility provisioning:** facilities are **seeded manually** (script / one-off Firestore writes). No in-app admin UI — not worth building for a handful of campus tables.
- **Arena Assistant (AI chatbot):** a read-only in-app Q&A assistant on a full-screen `/chatbot` route opened from Home — deliberately **not** a 5th nav tab, and strictly user↔assistant (no user↔user messaging), keeping the "no social network" line intact. It answers only from (a) live app data via a **read-only tool layer over the existing repositories** and (b) static app knowledge in its system prompt. It never writes to Firestore and never performs actions — shortcuts are deep links ("Open Map"), not chatbot-executed writes. Priority tier 🟡 with its own cut line: if time slips, drop the LLM and ship the rule-based intent matcher only; never displace Spine tasks. Full spec in §3.10.
- **Chatbot LLM:** a **free-tier LLM API with function/tool calling** — exact provider chosen at implementation time (any free tier with a Dart SDK or plain REST interface works) — called **directly from the client**, since the Spark tier means no server proxy. The API key ships in the client via `--dart-define=ASSISTANT_API_KEY` (never committed): an accepted trust-boundary compromise for a graded course demo, documented like the Spark-tier one. A deterministic keyword-intent fallback covers LLM downtime, quota exhaustion, and offline ("limited mode").
- **No chat persistence:** conversation history is session-only (Cubit state). No new Firestore collections → zero schema/rules/quota impact.
- **Availability disclaimer (business rule):** every availability answer and availability UI must state that "empty" reflects app activity only and that CampusArena is not a booking service. Appended **in code** whenever an availability tool fired — never left to the LLM. Exact copy + mandatory placements in §3.10.

---

## 1. Project Overview

CampusArena is a cross-platform mobile application that digitizes, tracks, and gamifies amateur sports activity across the university campus. Born from the original PoliPONG concept — an app to manage and rank ping pong matches at Polytechnic tables — it has grown into a multi-sport competitive platform. **At launch it supports Ping Pong and Foosball, with Padel as a stretch goal; 3v3 Basketball is documented as a future extension but not implemented.**

The core goal is a dynamic ELO-based ranking system for campus players, inspired by platforms like Chess.com but adapted for physical, on-site facilities. The app is a utility for matchmaking, facility management, and official score-keeping — **not a social network.**

---

## 2. Design Philosophy

### 2.1 Facility-Centric, Not User-Centric
To comply with the course's "no social networks" guideline, CampusArena is built around physical sports infrastructure rather than user profiles or social feeds. No posts, no timelines, no general messaging. Every interaction is tied to a real physical location (a table, a court) and a competitive event (a match, a tournament).

### 2.2 "Proof of Play" Integrity
Every ranked match requires a Proof of Play:
* Players scan a physical **QR code** on the table/court to start a ranked session (with a printed alphanumeric fallback code if scanning fails).
* The app records the user's **GPS location** as a soft, non-blocking audit signal confirming physical presence.
* Integrity rests primarily on physical QR presence + **opponent confirmation** of the result, making remote score manipulation impractical.

#### 2.2.1 Trust Boundary & Serverless Compromise
Because the project runs strictly on the free Firebase Spark tier, we cannot deploy server-side triggers (Cloud Functions) for achievements. 
* **Cosmetic Data**: The client is trusted to write to its own `users/{uid}/badges` map. Cheating badges does not affect ELO, queues, or matchmaking. Firestore Security Rules enforce that badge IDs must be valid references and timestamps match `request.time`.
* **Competitive Data**: ELO changes require write-access to the match document. Since the match document requires both players to confirm/dispute the result, scoring remains tamper-resistant despite a serverless backend.

### 2.3 Multi-Sport Architecture
Each sport has its own independent ELO rating per user; a win in Ping Pong only affects the Ping Pong ELO. The schema is structured to add sports — or larger squad sizes — without migration.

---

## 3. Core Features

### 3.1 ELO Scoring & Ranking System
* **Starting ELO:** 1200 per sport.
* **Point Exchange:** standard ELO expected-score formula; the winner gains what the loser loses, scaled by the rating difference.
* **Provisional phase:** the first 10 matches on a rating use a higher K-factor (32) for faster convergence, dropping to K=16 afterward. This single mechanism *is* the provisional-score feature — no separate flag.
* **Inactivity Decay:** after 30 days idle on a rating, ELO decays gradually (eroding only gains above the 1200 baseline), computed lazily at read time.
* **Doubles Mode:** a pair is its own rated entity with a shared team ELO (deterministic `pairId`), on a separate doubles leaderboard.

### 3.2 Real-Time Facility Map
* **Interactive Map:** live status of every registered table/court.
* **Color-Coded Status Pins:**
  * 🟢 **Green** — Free and available
  * 🔴 **Red** — Occupied (shows who is playing and for how long)
  * 🟡 **Yellow** — Someone is in the queue
* **Detail Card Overlay:** tapping a pin shows current players, match duration, the "King of the Table" (most wins at that location), a **Join Queue** button, and — **for outdoor facilities only** — **current weather conditions** (temperature, precipitation, wind) fetched for that facility's coordinates, so players can judge outdoor usability before heading over.

### 3.3 Queue System & Notifications
* **Digital Queue:** join a queue for an occupied table.
* **Soft Enforcement:** the front-of-queue player gets priority to scan/check in when the table frees up; others aren't hard-blocked but see a "someone's ahead of you" warning.
* **Table-Ready Alert:** the front-of-queue player is alerted when the table frees up. On the Spark tier there is no server to send a targeted push, so this is a **client-local alert**: that player's own facility listener detects `status → free` and raises an in-app notification (fires while the app is foregrounded). The `pushTokens` field is retained for a future Blaze-tier sender but is not exercised.
* **Queue Tracking:** position is visible in real time and updates live for everyone watching that facility.

### 3.4 Active Match Flow (QR Check-In)
1. Player taps **Play**.
2. App scans the QR code (or accepts the manual fallback code). If the table was `free` for >5 minutes, the check-in transaction atomically purges any missing front-of-queue users.
3. GPS distance is logged (non-blocking).
4. Table status flips to **Busy** immediately on the map for all users.
5. A match timer starts on both players' screens.
6. One player submits the result; the **other confirms** it in-app.
7. On confirmation, ELO updates **atomically** in real time. On dispute → `Disputed`, no ELO change, both notified (unless the disputer is serving a 7-day griefer penalty, in which case the match is forced to `confirmed`). On timeouts → `Unconfirmed` / `Abandoned`, no ELO change, facility freed.

### 3.5 Tournament Mode
* **Creation:** any user can create a **single-elimination** tournament for a sport (round-robin deferred), with a max participant count and registration deadline.
* **Bracket Management:** automatic bye assignment for non-power-of-2 counts; the organizer manually advances slots and marks no-shows as forfeits. If registration doesn't fill, the tournament proceeds with a **smaller re-seeded bracket** at the deadline.
* **Live Standings:** a live leaderboard tracks remaining/eliminated participants.
* **ELO Multiplier:** winning a tournament awards a configurable, larger ELO bonus than a standard match.
* **Weather Forecast:** for tournaments involving **outdoor** facilities, a projected forecast is shown for the scheduled timeslot (rain/wind advisories).

### 3.6 Player Profiles & Advanced Statistics
* Current ELO per sport and overall campus rank.
* Interactive ELO trend graph over time.
* Total games, wins, losses, win rate.
* Longest winning streak (current and all-time).
* Detailed match history (opponent, score, date, location).
* Fun stats: **"Black Beast"** (most-frequent conqueror) and **"Favorite Victim"** (most-beaten opponent), each shown only after **≥3 matches** against that specific opponent.

### 3.7 Leaderboards
* **Global Campus Ranking:** top 100.
* **Per-Sport Ranking:** filter by Ping Pong, Foosball, etc.
* **Course Rivalry Ranking:** filter by degree program (e.g. CS vs Architecture), from a fixed program list chosen at registration.
* **Friends Ranking:** a private leaderboard among added friends — a filter only, no other social features.
* **Search Function:** find any registered player.

### 3.8 Direct Challenges
* **Friends only:** send a challenge to a friend for a given sport (no "nearby player" discovery).
* **Accept / Decline:** the recipient responds via push notification. **No in-app scheduling** — players coordinate offline and start via normal QR check-in. No weather attached.

### 3.9 Achievements & Badges
Evaluated client-side within the atomic Firestore transaction confirming a match (maintaining write integrity):
* 🏆 **First Victory** — win your first ranked match.
* 🔥 **5-Win Streak** — win 5 in a row.
* 👑 **Giant Slayer** — beat an opponent 200+ ELO above you.
* 🗺️ **Explorer** — play at least once on every table on campus.
* 🏅 **Tournament Champion** — win an official tournament.
* 📅 **Workaholic** — play 10 games in a single month.

### 3.10 Arena Assistant (AI Chatbot)

An in-app assistant answering app questions ("What tables are empty?", "What tournaments are on today?", "How does ELO work?") on a full-screen `/chatbot` route opened from the Home tab.

* **Read-only by construction:** a `ChatbotToolsService` exposes bounded one-shot tools — `getEmptyTables()`, `getTournamentsToday()`, `getFacilityStatus(name)`, `getMyQueuePosition()`, `getMyEloAndRank(sport)`, `getLeaderboardTop(sport, n)` — built on the existing repositories. No direct Firestore access from the chatbot vertical, no writes, `.limit()` on every query (≤ 25), single-shot reads only (no listeners), soft per-session cap (~30 messages) as a Spark quota guard. Tools return typed result objects so the UI can render cards.
* **Orchestration:** a `ChatbotRepository` builds the system prompt (app FAQ distilled from this document + the user's language + the mandatory disclaimer instruction), sends the user message with tool schemas to the LLM (function calling), executes the requested tool, and returns a grounded answer. Answers are grounded **only** in tool results — low temperature, and the system prompt forbids inventing facilities. A `RuleBasedIntentMatcher` (keyword → tool → templated ARB answer) is the deterministic fallback whenever the LLM errors, hits quota, or the device is offline.
* **"Today"** for tournaments = device-local calendar day against `scheduledAt`; `registering`/`active` tournaments are listed as additional context.
* **UI:** message bubbles, typing indicator, suggested-question chips ("What tables are empty?", "Tournaments today", "How does ELO work?", "Where am I in the queue?"), rich answer cards (facility availability, tournament), error bubble with retry, offline "limited mode" pill, first-open disclaimer banner.
* **Data dependency, not code dependency:** availability answers are only as truthful as `facility.status`, which the Phase-4 match flow writes; the Phase-7 demo seed guarantees non-empty answers regardless.

#### Availability Disclaimer (mandatory business rule)

"Empty/free" reflects **app activity only** — CampusArena is not a booking service. ARB keys: `availabilityDisclaimerFull`, `availabilityDisclaimerShort`, `chatbotIntroDisclaimer`.

* **EN full:** *"Availability shows CampusArena activity only. A table marked as empty may still be in use by people who aren't playing through the app. CampusArena is not a booking service — spots can't be reserved."*
* **EN short (card footers):** *"Based on app activity only — the table may be in use by non-app players. Not a reservation."*
* **IT full:** *"La disponibilità riflette solo l'attività su CampusArena. Un tavolo indicato come libero potrebbe comunque essere usato da persone che non giocano tramite l'app. CampusArena non è un servizio di prenotazione — non è possibile riservare un posto."*
* **IT short:** *"Basato solo sull'attività dell'app — il tavolo potrebbe essere occupato da giocatori esterni. Nessuna prenotazione."*

**Placements (all mandatory):** (1) chatbot first-open info banner (full copy via `chatbotIntroDisclaimer`); (2) footer of **every** chatbot availability answer/card (short copy) — appended in code whenever an availability tool fired, never trusted to the LLM; (3) map/list facility detail card, under the status row (short copy); (4) one line in the mini-tutorial's map step.

---

## 4. Technical Architecture

### 4.1 Cross-Platform Framework
**Flutter (Dart):** single codebase for Android and iOS (note: iOS push notifications disabled due to free Apple Developer account tier). **Material** design language, themed with **Material 3** for a consistent look & feel across platforms (no adaptive Cupertino theme; optional `.adaptive` widgets only if time permits).

### 4.2 Backend & External Services
The app's "more than just Firebase" story rests on genuine external integrations, not a second local database:

| Service / Dependency | Purpose |
| --- | --- |
| **Firebase Auth** | User registration and login |
| **Firebase Firestore** | Cloud real-time database (matches, table status, queues, ratings); built-in offline persistence covers cached reads |
| **Firebase Cloud Messaging (FCM)** | Push notifications for Android (queue alerts, challenge requests, tournament updates) |
| **Flutter Map / OpenStreetMap** | Interactive campus facility map (completely free, no billing or API keys required) |
| **Weather API** (Open-Meteo, no key required) | Current conditions for outdoor facilities; forecasts for outdoor tournaments |
| **QR Code Scanner** (`mobile_scanner`) | Hardware-integrated table check-in — "Proof of Play" |
| **Geolocator / GPS** | Soft, non-blocking presence audit at check-in |
| **`go_router`** | Declarative routing + deep linking via path parameters |
| **Chart Library** (`fl_chart`) | ELO trend graphs and statistics visualizations |
| **LLM API** (free tier, provider TBD at implementation) | Arena Assistant natural-language understanding via function calling over the read-only chatbot tool layer; key wired via `--dart-define=ASSISTANT_API_KEY`, deterministic rule-based fallback when unavailable |
| **`flutter_localizations` + `intl`** | English/Italian internationalisation |

*(SQLite was considered and dropped — see Decision Log.)*

### 4.3 Concurrency
Mainly Dart `async`/`await` + `Future`s, which keep I/O off the UI thread:
* Real-time Firestore listeners (table status, active match, queue position)
* GPS polling during active-match validation
* Weather fetching (async HTTP, cached in memory)
* ELO recalculation after result submission
* Profile/stats loading (match history, advanced statistics)

For genuinely CPU-heavy work, a real **Isolate** is used (e.g. building ELO-trend chart data from long match history) so the "multiple threads" requirement is satisfied by actual parallelism, not just async I/O.

### 4.4 Multi-Device Support & Responsive Layouts
* **Adaptive Constraints:** `LayoutBuilder` to resize between phone and tablet aspect ratios.
* **Sizing/Orientation:** `MediaQuery.sizeOf` and orientation checks at runtime.
* **On Smartphones:** bottom navigation bar with 4 tabs; compact map with a slide-up panel.
* **On Tablets:** split-view layout (map + list/details), mirroring the Trenitalia pattern from the course slides.
* **Scope:** tablet split-view is executed well on **two screens** (Facility Map and Home/Dashboard); other screens are made to look correct on a larger canvas (constrained width, centered content) rather than getting bespoke tablet layouts.

### 4.5 State Management Architecture
* **Ephemeral state:** managed locally via **state hoisting** (parents own current index, form inputs, toggles; data down, callbacks up).
* **App state:** **Cubit** (`flutter_bloc`), no event layer — unidirectional, testable state for auth workflows, active-match sessions, and global queue state, consumed via `BlocBuilder`.

### 4.6 Navigation & Routing Architecture
* **Declarative (`go_router`):** primary routes and path parameters (`/play/court/:id` for scanned QR values, `/challenge/:id` for push-alert targets); robust deep linking. The 4-tab bottom nav is nested via a `StatefulShellRoute` so each tab keeps its own stack/state.
* **Imperative (`Navigator`):** transient routes (dialog popups, modal dismissals via `Navigator.pop`).
* **Structural:** `Drawer` for secondary global controls (profile settings, tutorials).

### 4.7 Offline Behaviour
No separate local database. **Firestore's built-in offline persistence** caches reads so leaderboards, profile, and recent data remain viewable offline, and queues writes when connectivity drops. **Ranked matches require connectivity** by design — QR check-in and live opponent confirmation need it, and keeping ELO computation server-authoritative preserves the "Proof of Play" integrity model.

---

## 5. Screen Flow

### Auth & Onboarding (5 screens)
1. **Splash / Loading Screen**
2. **Landing Page** — Register or Log In
3. **Authentication** — 3a. Login · 3b. Registration (name, email, password, **degree program from fixed list**) · 3c. Forgot Password
4. **Mini-Tutorial** — quick animated walkthrough (skippable, re-accessible later). Camera/GPS permissions are requested contextually at first use (scanner, map), not up front.
5. **Main Hub** (entry point)

### Main Hub — Bottom Navigation Bar (4 Tabs)

#### Tab 1 — Home / Dashboard
* Sport selector (switch active sports)
* Current ELO and campus rank for the selected sport
* Play button (triggers QR scan flow)
* Recent match history (last 5)
* Arena Assistant entry point (opens the full-screen `/chatbot` route)

#### Tab 2 — Map & Facilities
* Toggle between Interactive Map and List View (sorted by proximity)
* Color-coded pins per table/court
* Tap a pin → **Queue & Facility detail screen**: occupancy/queue status, **weather snippet (outdoor facilities only)**, Join Queue option
* "King of the Table" badge per pin

#### Tab 3 — Leaderboards
* Top 100 global ranking
* Filters: sport / friends / **degree program (course rivalry)**
* Search bar

#### Tab 4 — Profile & Stats
* Avatar, nickname, current ELO per sport
* Interactive ELO trend graph
* Detailed stats (win rate, streak, Black Beast, Favorite Victim)
* Achievements and badges
* Match history log
* Settings (change password, notification preferences, privacy, language)

### Active Match Screens
* **QR Scan Screen** — camera view with scan feedback + "enter code manually" fallback
* **Active Game Screen** — live timer, player names and ELO, "Record Result" button
* **Result Input Screen** — final score (sets/points)
* **Opponent Confirmation Screen** — confirm / dispute
* **Match Summary Screen** — ELO delta animation, updated rank, optional share

### Tournament Screens
* Tournament browser (upcoming + ongoing)
* Create Tournament form
* Live bracket view (byes shown explicitly; outdoor tournaments show forecast)
* Tournament profile page

### Arena Assistant (full-screen route — not a 5th tab)
* Chat screen — greeting bubble, dismissible first-open disclaimer banner, suggested-question chips, message bubbles with rich answer cards (facility availability, tournaments), typing indicator, input bar, offline "limited mode" pill

---

## 6. Course Compliance Summary

| Requirement | How CampusArena Satisfies It |
| --- | --- |
| **Significant number of screens** | 20+ screens across onboarding, main hub, active match, tournaments, and profiles, routed via `go_router` + `StatefulShellRoute` |
| **Multiple threads** | Async I/O (Firestore listeners, GPS, weather, ELO recompute, stats loading) off the UI thread, plus an Isolate for CPU-heavy chart-data work |
| **External services beyond Firebase** | OpenStreetMap (flutter_map), Open-Meteo Weather API, `mobile_scanner` QR hardware integration, GPS geolocator, free-tier LLM API (Arena Assistant) — five genuine non-Firebase integrations |
| **Look & feel** | Consistent Material 3 theme; responsive for phone and tablet; English/Italian localisation |
| **Multi-device support** | Adaptive split-view via `LayoutBuilder` + `MediaQuery`, executed on Map and Dashboard |
| **Test campaign** | Unit tests (ELO logic, provisional K switch, decay, pair-ID, queue transaction) and widget tests (`testWidgets`/`WidgetTester`, mocked Cubits) |
| **Design & Test document** | Architecture diagrams, Firestore schema, external-API integration details, state machine, test-case matrices |
| **No social network** | Interaction restricted to facility check-ins and competitive events; friends are a leaderboard filter only; the Arena Assistant is user↔assistant only — no user↔user messaging |
| **More than just Firebase** | Map SDK, Weather API, QR hardware integration, GPS, LLM API — real external interaction, not just storage |
| **No business app** | Campus-community utility; no profit agreements, no marketplace clone |
| **Team of 3** | Workload split across UI, state/integration, and real-time backend |

---

## 7. Development Plan

The phased development plan — 8 phases from Foundation to Ship, with per-phase owners, priority tiers, and cut rules — lives in `task_board.md`.

---
*CampusArena — turning campus sports into a competitive experience.*