# CampusArena User Manual

CampusArena is the mobile app for competitive ping pong and foosball at Politecnico di Milano. It tracks your matches at real campus tables, gives you an ELO rating per sport, and lets you compete on leaderboards, join queues for busy tables, play tournaments, and challenge friends. This manual walks you through every task in the app, from creating an account to reading a tournament bracket.

Screenshots referenced in this manual are in `docs/design/screenshots/` in the repository. Where a screenshot helps, its filename is given in parentheses, for example (home.png).

One rule to keep in mind throughout: CampusArena is not a booking service. When the app shows a table as free, that means no one is playing through the app. Someone who is not using CampusArena may still be at the table, and you cannot reserve a spot. The app repeats this disclaimer wherever availability is shown.

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [The Four Tabs](#2-the-four-tabs)
3. [Playing a Ranked Match](#3-playing-a-ranked-match)
4. [The Digital Queue](#4-the-digital-queue)
5. [Tournaments](#5-tournaments)
6. [Friends](#6-friends)
7. [Direct Challenges](#7-direct-challenges)
8. [Arena Assistant](#8-arena-assistant)
9. [Achievements](#9-achievements)
10. [Language and Appearance](#10-language-and-appearance)
11. [Settings](#11-settings)
12. [Permissions: What the App Asks For and Why](#12-permissions-what-the-app-asks-for-and-why)
13. [Quick Troubleshooting](#13-quick-troubleshooting)

## 1. Getting Started

### 1.1 First Launch

When you open the app you see a short splash screen (splash.png) followed by the landing page (landing.png), which offers two options: Register and Log In.

### 1.2 Creating an Account

1. Tap **Register** on the landing page (register.png).
2. Enter your name, email address, and a password.
3. Pick your **degree program** from the dropdown list. This is a fixed list of Polimi programs, not free text. Your choice powers the course rivalry leaderboard (Computer Science vs Architecture, for example), so pick the program you actually belong to.
4. Confirm to create the account.

Your username handle is unique across the app. Other players will find you by it when adding friends.

If you already have an account, tap **Log In** instead (login.png). If you forgot your password, use the **Forgot Password** link on the login screen and the app sends a reset email to your address.

### 1.3 The Mini Tutorial

After registering, the app takes you through a quick animated walkthrough of the main features (tutorial.png). Its three slides cover playing ranked matches via QR check-in, climbing the ELO leaderboards, and joining the queue with live facility status on the map — including the availability disclaimer. You can skip it at any point with the skip control. After the tutorial you land in the main app.

The app does not have a separate avatar or permissions setup step. Permissions are requested only when a feature first needs them — most notably the camera, which the app asks for the first time you start the QR check-in flow. See [section 12](#12-permissions-what-the-app-asks-for-and-why) for exactly what is asked and why. You can decline and grant it later from your device settings, but the QR check-in flow needs the camera.

## 2. The Four Tabs

The main screen has a bottom navigation bar with four tabs. Each tab keeps its own navigation history, so switching tabs never loses your place. On tablets the bottom bar is replaced by a navigation rail on the side, and the Home and Map screens use a wider split layout (hometablet.png).

### 2.1 Home (Dashboard)

The Home tab (home.png) is your launchpad:

- **Sport selector:** switch between Ping Pong and Foosball. Everything below it (ELO, rank, history) updates to the selected sport.
- **ELO card:** your current rating and campus rank for the selected sport.
- **Play button:** starts the QR check-in flow to begin a ranked match ([section 3](#3-playing-a-ranked-match)).
- **Recent matches:** your last few results at a glance.
- **Arena Assistant card:** opens the chatbot ([section 8](#8-arena-assistant)).

### 2.2 Map and Facilities

The Map tab (map.png) shows every registered table and court on an OpenStreetMap view of campus. Each facility has a color-coded pin:

- **Green:** free, no one is playing through the app.
- **Red:** occupied, an app match is in progress.
- **Yellow:** free or occupied with people waiting in the queue.

You can toggle to a **list view** sorted by proximity (listview.png) if you prefer scanning a list over a map.

Tap a pin to open the **facility detail card** (facility.png). It shows:

- Current status, and if occupied, who is playing and for how long.
- The **King of the Table**, the player with the most wins at that specific facility.
- The current **queue** and a **Join Queue** button ([section 4](#4-the-digital-queue)).
- For **outdoor facilities only**, current weather conditions (temperature, precipitation, wind) so you can judge whether the table is playable before walking over. Indoor facilities show no weather.
- The availability disclaimer, shown under the status row.

### 2.3 Leaderboards

The Leaderboards tab (leaderboard.png) shows the top 100 ranked players. Use the filters to change scope:

- **Global:** everyone on campus.
- **Sport:** Ping Pong or Foosball rankings separately. Each sport has its own independent ELO, so your ping pong wins never affect your foosball rating.
- **Degree program:** the course rivalry view, ranking players within or across programs.
- **Friends:** a private ranking of just you and the friends you have added.

A **search bar** lets you find any registered player by their username handle. The app bar on this tab also has a button that opens the **Friends screen**, where you add friends and send challenges ([section 7](#7-direct-challenges)).

### 2.4 Profile and Stats

The Profile tab (profile.png) is your personal record:

- Avatar, name, handle, and current ELO per sport.
- An interactive **ELO trend chart** showing how your rating moved over time.
- **Statistics:** total games, wins, losses, win rate, and your longest winning streak (current and all time).
- **Fun stats:** your **Black Beast** (the opponent who beats you most often) and **Favorite Victim** (the opponent you beat most often). These labels only appear after you have played at least 3 matches against that specific person, so a single lucky game never earns anyone a title.
- **Achievements:** your earned badges ([section 9](#9-achievements)).
- **Match history:** every recorded match with opponent, score, date, and location.
- A **settings** button in the app bar ([section 11](#11-settings)).

## 3. Playing a Ranked Match

This is the core loop of the app. Every ranked match follows the Proof of Play principle: you must physically be at the table, and your opponent must confirm the result.

### 3.1 Starting a Match

1. Walk to a free table or court. Each registered facility has a printed QR sticker.
2. On the Home tab, tap **Play**. The QR scanner opens (qr.png).
3. Point the camera at the facility's QR code. The app validates it and checks you in.
4. **If the camera or sticker fails**, tap **Enter code manually** and type the short alphanumeric fallback code printed next to the QR sticker. This does exactly the same thing.

At check-in the app reads your GPS position once as a soft audit. If you appear far from the facility you see a warning banner, but check-in is never blocked by GPS. Indoor positioning is unreliable and the app knows it. Integrity comes from the physical QR code and opponent confirmation, not from GPS.

### 3.2 Match Setup

After a successful scan you reach the match setup screen:

- Choose **Singles** or **Doubles**.
- In doubles, players are assigned to Team 1 and Team 2. A doubles pair is rated as its own team entity with its own ELO, separate from each player's singles rating.

Once the match starts, the facility flips to **occupied** on the map for everyone, and an active game screen (activegame.png) shows a live timer with both players' names and ratings.

### 3.3 Recording the Result

1. When the game ends, one player taps **Record Result** and enters the final score (result.png).
2. The **opponent** then sees a confirmation screen (opponentconfirmation.png) with two options: **Confirm** or **Dispute**.
3. On confirmation, ELO updates immediately and atomically for both players, and a match summary screen (summary.png) shows the rating change animation and your updated rank.

### 3.4 Disputes and Timeouts

- **Dispute:** if your opponent entered a wrong score, dispute it. A disputed match is voided: no ELO changes for either player, both players are notified, and there is no in-app appeal. Settle it with a rematch. Note that repeatedly disputing matches (3 or more) triggers a 7-day cooldown during which further dispute attempts are ignored and the match is recorded as confirmed. This protects the rating system from players who dispute every loss.
- **Unconfirmed:** if the opponent never responds to the confirmation request, the match times out with no ELO change.
- **Abandoned:** if no result is ever submitted, the match is closed with no ELO change and the table is freed.

### 3.5 How ELO Works

- Every player starts at **1200** per sport.
- The winner gains what the loser loses, scaled by the rating gap. Beating a much stronger player earns you a lot; beating a much weaker player earns you little.
- Your first **10 matches** on a rating use a higher K factor (32 instead of 16), so your rating converges quickly while it is provisional.
- After **30 days** of inactivity on a sport, the rating slowly decays, but only the gains above the 1200 baseline erode.
- Winning a tournament awards a larger ELO bonus than a normal match.

Ranked matches require an internet connection. QR check-in and live opponent confirmation cannot work offline, and this is deliberate: it keeps the rating system tamper-resistant. Leaderboards, your profile, and recent data stay readable offline from the cache.

## 4. The Digital Queue

When a table is busy, do not stand around guessing.

1. Open the facility on the Map tab and tap **Join Queue**.
2. Your position appears in real time and updates live for everyone watching that facility.
3. When the table frees up, the player at the front of the queue gets an alert. Keep the app open in the foreground to receive it, since the alert is raised by the app itself watching the facility status.
4. Walk over and scan the QR code to claim the table.

The queue uses soft enforcement. The front player has priority to check in, and anyone else scanning sees a warning that someone is ahead of them, but nobody is hard blocked. If the person at the front never shows up within a few minutes of the table becoming free, the next check-in clears them from the queue automatically.

## 5. Tournaments

### 5.1 Browsing and Joining

The tournament browser (browser.png) lists upcoming and ongoing tournaments. Open one to see its detail page with sport, facility, schedule, registration deadline, and participant list. Tap register to join before the deadline.

### 5.2 Creating a Tournament

Any user can organize a tournament (create.png):

1. Open the tournament browser and tap create.
2. Fill in the form: tournament **name**, **sport**, **facility**, **maximum participants**, **registration deadline**, and **scheduled start time**. The deadline must be in the future and before the scheduled start.
3. Submit. Registration opens immediately.

If the tournament is at an **outdoor facility**, the detail page shows a weather forecast for the scheduled timeslot, including rain and wind advisories.

### 5.3 Reading the Bracket

All tournaments are **single elimination**. At the registration deadline the app generates the bracket (livebracket.png):

- If the participant count is not a power of 2, some players receive a **bye** in the first round. Byes are shown explicitly as empty slots, and the player advances automatically.
- If registration did not fill, the tournament proceeds anyway with a smaller re-seeded bracket.
- Each bracket match is played as a normal ranked match at the facility. The **organizer** advances winners through the bracket and can mark a no-show as a **forfeit**.
- A live standings view (standings.png) tracks who is still in and who is eliminated.

The tournament winner receives the larger ELO bonus and the Champion badge.

## 6. Friends

Friends in CampusArena exist for exactly two things: a private leaderboard filter and direct challenges. There are no profiles to browse, no feeds, and no messaging.

To add a friend:

1. Open the Leaderboards tab and tap the friends button in the app bar.
2. On the Friends screen, search for the person by their **username handle**.
3. Tap **Add**. They now appear in your friends list and in the Friends leaderboard filter.

You can remove a friend from the same screen at any time.

## 7. Direct Challenges

You can challenge any friend to a match:

1. On the Friends screen, tap the challenge button next to a friend's name and pick the sport.
2. Your friend gets an in-app alert the next time they have CampusArena open and can **accept** or **decline**. Alerts are raised by the app itself, not sent from a server, so keep the app open to receive them promptly.
3. If accepted, you coordinate a time yourselves (in person, however you like) and then start the match normally by scanning the QR code at a table. The challenge carries no scheduling fields and no weather information by design.

## 8. Arena Assistant

The Arena Assistant is an in-app chatbot for questions about the app and live campus activity. Open it from the card on the Home tab (aiopen.png).

### 8.1 What It Can Answer

The assistant answers from live app data and built-in app knowledge. Good questions include:

- "What tables are empty?"
- "What tournaments are on today?"
- "Where am I in the queue?"
- "What is my ELO in foosball?"
- "Who is top of the leaderboard?"
- "How does ELO work?"

Suggested question chips above the input bar cover the common ones. Answers about facilities and tournaments render as rich cards with the relevant details (airich.png).

The assistant is strictly read-only. It cannot join a queue, start a match, or change anything on your behalf. It can offer shortcuts that open the right screen, but you perform the action yourself.

### 8.2 The Availability Disclaimer

Every availability answer from the assistant carries a footer reminding you that "empty" reflects app activity only and that CampusArena cannot reserve a table. This footer is added by the app itself, not generated by the AI, so it is always present. The same notice appears as a banner the first time you open the chat.

### 8.3 Limited Mode and AI Configuration

The assistant has two modes:

- **AI mode:** answers are generated by a language model, grounded in live app data.
- **Limited mode:** a built-in rule-based matcher recognizes the common questions and answers from live data with fixed templates. The chat shows a "limited mode" pill when this is active (aierror.png shows the error and retry state).

The app falls back to limited mode automatically when the device is offline, when the AI provider errors, or when no API key is configured.

To enable AI mode, configure a provider key in the assistant settings:

1. In the chat screen, tap the settings icon in the app bar.
2. Choose a **provider**: regolo, openai, openrouter, anthropic, or gemini.
3. Paste your **API key** for that provider. The key is stored only on your device.
4. Optionally set a **model** name, or leave it empty to use the provider default (for regolo that is qwen3.5-122b).
5. Use the **test** button to verify the key works. Errors are reported specifically: invalid key, rate limited, network error, or timeout.

The chat itself is session only: closing the assistant discards the conversation.

## 9. Achievements

Badges are awarded automatically the moment you earn them, usually right after a match result is confirmed. They appear on your Profile tab. There are six:

| Badge | How to earn it |
|---|---|
| **First Victory** | Win your first ranked match. |
| **On Fire** | Win 5 ranked matches in a row. |
| **Giant Slayer** | Beat an opponent rated 200+ ELO above you. |
| **Explorer** | Play at least once at every facility on campus. |
| **Champion** | Win an official tournament. |
| **Workaholic** | Play 15 matches in a single month. |

## 10. Language and Appearance

- **Language:** CampusArena is fully available in **English and Italian** (italianexample.png). Change the language in Settings (Profile tab, settings icon, Preferences section). Your choice is saved to your account and survives reinstalls and new devices. By default the app follows your device language.
- **Dark mode:** the app follows your device theme (darkexample.png). Set your phone to dark mode and CampusArena switches automatically. There is no separate in-app toggle.

## 11. Settings

Open Settings from the gear icon on the Profile tab (settings.png). It contains:

- **Change password:** sends a password reset email to your registered address.
- **Privacy:** the privacy information screen.
- **Notifications:** toggle in-app alerts (challenge requests and tournament updates) on or off.
- **Language:** English or Italian, as described above.
- **Log out.**

## 12. Permissions: What the App Asks For and Why

| Permission | Used for | If you decline |
|---|---|---|
| **Camera** | Scanning the QR code on a table to start a ranked match. | You can still check in by typing the printed fallback code manually. |
| **Location** | Sorting the facility list by proximity, and a one-time soft presence check at check-in. | Check-in still works. Location never blocks anything; it is logged as an audit signal only. |
| **Notifications** (Android 13 and later) | In-app alerts for challenges and tournament updates. | The app works fully; you just will not receive alerts. |

The app never tracks your location in the background and never shares it with other players.

## 13. Quick Troubleshooting

- **The QR code will not scan:** tap Enter code manually and type the printed code.
- **The map says a table is free but someone is playing:** they are not playing through the app. This is expected; see the availability disclaimer.
- **The assistant shows a limited mode pill:** you are offline, or no AI key is configured. Add a key in assistant settings for full answers; limited mode still answers the common questions.
- **My opponent entered the wrong score:** tap Dispute on the confirmation screen. The match is voided with no rating change.
- **I got no queue alert:** keep the app open in the foreground while waiting; the table-ready alert is raised inside the app.
- **My rating dropped without playing:** ratings idle for more than 30 days decay slowly toward 1200. Play a match to stop the decay.

Enjoy the games, and may your ELO climb.

---

_CampusArena was built by Mirko Pica, Christian Prendin, and Abdullah Saeed for the Design and Implementation of Mobile Applications course at Politecnico di Milano._
