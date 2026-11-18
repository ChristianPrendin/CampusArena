# CampusArena Test Plan

---

## 1. Overview
This document outlines the testing strategy for CampusArena. In alignment with the project decision log and task board, the goal is to implement a comprehensive automated testing suite encompassing unit tests and widget tests. All parts added to the application should be covered by tests from the start.

## 2. Infrastructure
- **Frameworks**: `flutter_test` (built-in UI and unit testing).
- **State Management**: `bloc_test` for Cubit state transitions.
- **Mocking**: `mocktail` for mocking repositories and external services.
- **Integration Mocking (Stretch)**: `fake_cloud_firestore` for end-to-end integration tests.
- **Directory Structure**: `app/test/` directory mirrors the `app/lib/` directory closely.

## 3. Unit Testing Strategy
Unit tests target business logic, data models, utility functions, and state management without spinning up the Flutter framework.

### 3.1. ELO Engine (`core/elo/` or `core/utils/`)
- Test expected-score formulas.
- Test K-factor switching (K=32 to K=16 upon reaching 10 matches).
- Test laziness of inactivity decay (no separate Cloud Function).

### 3.2. Data Models & Business Logic
- Ensure deterministic `pairId` generation for doubles (sorting of UIDs).
- Verify queue ordering and soft enforcement logic.
- Verify `ScoringStrategy` implementations (PingPong, Foosball) properly compute match outcomes.

### 3.3. State Management
- Verify `Cubit` state transitions given mocked repository success/failure responses.

### 3.4. Arena Assistant (Chatbot)
- `ChatbotToolsService` (mocked repositories): empty-tables returns only `status == free`; tournaments-today filters by device-local calendar day; every tool call is bounded (`limit ≤ 25`).
- `RuleBasedIntentMatcher`: keyword → correct tool mapping; templated ARB answers.
- Disclaimer enforcement: any response where an availability tool fired carries the disclaimer (appended in code, independent of LLM output).
- `ChatCubit` transitions (`bloc_test`), including the error → retry path.

## 4. Widget Testing Strategy
Widget tests spin up a lightweight UI environment to verify component rendering and interactions, primarily focusing on critical flows identified in Phase 7.

### 4.1. Core Screens & Flows
- **Auth Forms**: Form validation, error states, and transitions in login/registration.
- **Leaderboard Filters**: Ensure sport/degree/friends chips accurately update the state and UI.
- **Match Confirmation Flow**: Ensure correct UI rendering and interaction across result entry, confirmation, and dispute.
- **Bracket Rendering**: Verify single-elimination tournament tree rendering, specifically the visual handling of byes.
- **Arena Assistant**: suggested chips send queries; disclaimer banner visible on first open; facility answer card shows the disclaimer footer (in chat and on the map detail card); error state offers retry; both locales render.

## 5. Integration Testing (Stretch Goal)
- Test the full "Proof of Play" flow: QR scan → Match Timer → Submit Result → Opponent Confirmation → ELO update and Facility status flip using `fake_cloud_firestore` to simulate real-time atomic changes across collections.
- Arena Assistant flagship queries ("empty tables", "tournaments today") end-to-end against seeded `fake_cloud_firestore` data in both EN and IT; airplane mode yields the deterministic fallback with the localized "limited mode" notice.

## 6. Continuous Integration (CI)
- A `flutter_ci.yml` pipeline will enforce linting (`flutter analyze`), code formatting (`dart format`), and pass all unit/widget tests (`flutter test`) automatically on PR. 
