# CampusArena Git Workflow

This project uses a **`develop`-based integration flow** across three rotating verticals. `develop` is the day-to-day trunk; `main` holds shippable snapshots.

## Branching Model

- `develop`: The long-lived integration branch and the base for **all** feature and fix work. It must be buildable and runnable at all times. This is where day-to-day development converges.
- `main`: Holds shippable, deliverable snapshots only. It receives merges **exclusively** via a release PR from `develop` (see *Releases*). Never branch off `main`, and never push directly to it.
- **Feature Branches**: Branch off `develop`.
  - Naming convention: `feature/[VerticalLetter]-[kebab-case-description]`
  - Example: `feature/A-elo-engine`
  - Example: `feature/B-qr-scan`
- **Fix Branches**: Branch off `develop`, same as features — used for bugs found on `develop`. Fix work is highest priority and halts feature work until the build is restored (see *Handling Breakages*).
  - Naming convention: `fix/[kebab-case-description]`
  - Example: `fix/dashboard-null-crash`

**Branch protection:** `main` and `develop` are protected on GitHub — PRs only, the `flutter_ci.yml` check must pass, one approval required, direct pushes blocked.

## Development Cycle

1. **Pull the latest `develop`** before starting any new work.
2. **Branch off `develop`** to your feature or fix branch.
3. **Commit frequently** locally.
4. **Rebase before opening a PR:** Run `git rebase develop` on your branch before opening the Pull Request. This surfaces conflicts early and keeps the branch diff clean. Do not merge `develop` into your branch.
5. **Merge cadence:** Open a Pull Request as soon as a unit of work is complete, and **keep branch lifetime short.** Long-lived branches will cause catastrophic merge conflicts in shared files (e.g., routing, injection, schema definitions).
6. **Delete the branch** after your PR is merged.

**Shared-file coordination:** the only expected conflict points between verticals are `app_router.dart`, `main.dart`, and the ARB files (`app_en.arb` / `app_it.arb`). If your branch touches any of them, open the PR the **same day** and ping the other two developers. Announce at the daily sync who is touching these files today.

## Pull Requests

All feature/fix code enters `develop` via Pull Request.

### Requirements for Merge

1. **CI Pipeline Pass:** The automated checks (`flutter analyze`, `dart format`, unit tests) must be green. If the pipeline fails, the PR cannot be merged.
2. **One Approval:** You must secure exactly one approval from a team member.
   - **Reviewer Selection:** Ownership of Vertical A / B / C **rotates by phase** — see `task_board.md`'s Assignment Summary table for who owns what *this specific phase*. There is no fixed "A = Models," "B = Repositories," "C = UI" mapping for the whole project, so pick your reviewer based on what your change actually touches right now, not a role from an earlier phase:
      - **Touching a Shared Contract** (Match document shape, Facility status field, Queue position write — see `task_board.md`'s Shared Contracts table): tag both the current writer and the current reader of that contract.
      - **Touching a model, schema field, or business-logic calculation** (e.g. ELO math): tag whoever is building the repository or Cubit that stores or consumes it this phase.
      - **Touching a repository signature or data stream:** tag whoever is building the UI/Cubit that calls it this phase.
      - **Touching UI/Cubit only, with no data-layer or contract change:** no mandatory cross-vertical reviewer — tag any teammate for a general pass.
      - *Rule of thumb:* if your change crosses a vertical boundary, the *current* owner of the other side — per this phase's Assignment Summary row — is your reviewer. If it crosses both, tag both.
3. **PR description requirements:**
   - State explicitly which **Shared Contract(s)** the PR touches (match doc shape / facility status / queue position), or "none".
   - Every UI PR includes a screenshot of the implemented screen **next to the matching design screenshot** from the design system (`docs/design/screenshots/`).
4. **Squash and Merge:** When merging into `develop`, always select **Squash and Merge**. This condenses your feature commits into a single, clean commit on `develop`, keeping the history linear and legible.

## Releases (Promotion to `main`)

`main` is updated at each **phase gate** so there is always a demo-ready, tagged snapshot.

1. Open a release Pull Request from `develop` into `main`.
2. CI must be green (the same checks apply — see `flutter_ci.yml`).
3. Merge with a **standard merge commit** — never squash a release PR. Squashing would make `main` diverge from `develop` permanently; a merge commit keeps `main` containing `develop`'s exact history, so each gate's diff is only the delta since the last one. (Squash remains the rule for feature PRs into `develop` only.)
4. **Tag** the merge commit: `phase-3`, `phase-4`, `phase-5`, `phase-6`, and `v1.0-delivery` for the final submission.
5. Smoke-test the APK from the tagged commit on a real device.

Whatever isn't merged into `develop` by a gate follows the task board's cut rules (cut 🟢 first, then 🟡, never 🔴).

There is **no hotfix-from-`main`** path: if a deliverable on `main` turns out to be broken, fix it on `develop` and cut a fresh release PR. The only exception is a frozen submission you genuinely cannot re-cut — in that rare case, branch off the `main` tag, patch, and merge the fix back into `develop`.

## Handling Breakages

If `develop` breaks, all feature development halts. Restoring the build on `develop` becomes the immediate, highest priority for the entire team. Because `main` only ever receives green release PRs from `develop`, keeping `develop` healthy keeps `main` deliverable.

## Shared Contracts

If your PR alters a Shared Contract defined in the Task Board (e.g., Match document shape, Facility status field, Queue position write), highlight this explicitly in the PR description. Both other developers should be aware of the change.

## Working Practices

- Always work on a feature branch — never on `develop` or `main`.
- **Review the diff yourself before opening the PR.** You own every line you submit; the graded oral exam tests your understanding of this code.

**Daily rhythm:** 15-minute sync at a fixed time — yesterday / today / blockers, plus who is touching `app_router.dart`/`main.dart`/ARB today.
