# CampusArena

**DIMA Project — Design and Implementation of Mobile Applications**  
*Politecnico di Milano · Academic Year 2025/2026 · Team of 3 · Cross-Platform (Flutter)*

CampusArena is a cross-platform mobile application that digitizes, tracks, and gamifies amateur sports activity across the Politecnico di Milano campus. It provides a dynamic ELO-based ranking system for players, centered around physical facilities (e.g., Ping Pong tables, Foosball tables). Padel is a planned stretch goal; 3v3 Basketball is documented as a future extension but not implemented.

To comply with course guidelines, the system is designed to be **facility-centric** rather than user/social-centric, avoiding social network features by tying all user interactions directly to physical campus locations and competitive match/tournament events.

## 🚀 Key Features

* **ELO Scoring & Leaderboards**: Sport-specific ELO rating system with a provisional phase (higher K-factor for the first 10 matches) and leaderboard views filtered by sport, friends, or degree program.
* **Real-Time Facility Map**: Interactive map displaying color-coded status pins for registered facilities, showing live occupancy details and — for outdoor facilities only — current weather conditions (Open-Meteo API).
* **Proof of Play (QR Check-In)**: QR-code check-in with a soft, non-blocking GPS audit and mandatory opponent confirmation, tying every recorded score to a real table.
* **Digital Queue System**: Digital queuing for busy tables/courts with push alerts when they become available.
* **Tournaments**: Automated single-elimination bracket generation and management (round-robin deferred to future work).
* **Player Profiles & Stats**: Advanced statistics (win rates, ELO trend graphs, win/loss history) and gamification badges/achievements.
* **Direct Challenges**: Send challenge requests to friends only; accept/decline via push notification. No in-app scheduling and no weather info — players coordinate offline and start via normal QR check-in.
* **Arena Assistant**: a read-only AI chatbot answering app questions ("What tables are empty?", "Tournaments today?") over live app data, with a deterministic fallback when offline. Availability answers always carry a disclaimer — statuses reflect app activity only; CampusArena is not a booking service.

## 🏗️ Project Structure

* `/app`: The main Flutter project codebase.
* `/docs`: Project deliverables —
  - `design_document.pdf`: the Design & Test Document (LaTeX source in `docs/design_document/`).
  - `presentation.pdf`: the final project presentation.
  - `user_manual.md`: end-user guide covering every task in the app.
  - `docs/design/`: the UI design system (HTML spec + screen designs).
* `/brain`: Canonical project docs — project description & decision log, Firestore schema, task board, git workflow, and test plan.

## 🛠️ Tech Stack

* **Frontend Framework**: Flutter & Dart (Adaptive Layouts via `LayoutBuilder` & `MediaQuery`)
* **State Management**: Cubit (via `flutter_bloc`)
* **Navigation**: Declarative routing (`go_router`) & structural tab navigation
* **Backend Services**: Firebase (Auth, Firestore real-time DB, Cloud Messaging)
* **Offline Persistence**: Firestore's built-in offline persistence for cached reads (leaderboards, profile, recent data); ranked matches require connectivity by design
* **Hardware & External APIs**:
  - `mobile_scanner` (QR scanning)
  - `geolocator` (GPS-based validation)
  - Open-Meteo REST API (Asynchronous weather retrieval)
  - OpenStreetMap (`flutter_map`)
  - Free-tier LLM API, provider TBD (Arena Assistant; key via `--dart-define=ASSISTANT_API_KEY`, never committed)

## 🤝 Contact

If you have contributions, need support, have suggestions, or just want to get in touch with the authors, feel free to send an email!
* Mirko Pica - [mirko.pica@mail.polimi.it](mailto:mirko.pica@mail.polimi.it)
* Christian Prendin - [christian.prendin@mail.polimi.it](mailto:christian.prendin@mail.polimi.it)
* Abdullah Saeed - [abdullah.saeed@mail.polimi.it](mailto:abdullah.saeed@mail.polimi.it)

## License

This software is licensed under the terms of the MIT license.
See [LICENSE](LICENSE) for more details.

---
*Developed for the "Design and Implementation of Mobile Applications" course @ Politecnico di Milano.*