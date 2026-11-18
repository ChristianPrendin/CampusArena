## Description
<!-- Briefly describe what this PR does and why it is needed. -->
<!-- Feature/fix PRs target `develop`. Only release PRs (phase gates) target `main`. -->


## Related Task
<!-- Link to the specific task or mention the Phase / Item from the task board -->
- Vertical: [A / B / C]
- Phase: 
- Reviewer: <!-- Assign per git_workflow.md reviewer rules (the dev on the other side of the boundary you're touching) -->

## Shared Contracts
<!-- Per git_workflow.md: state explicitly which cross-vertical Shared Contracts this PR touches. -->
- [ ] None
- [ ] Match document shape
- [ ] Facility status field (`facilities/{id}.status` / `.currentMatchId`)
- [ ] Queue position write (`facilities/{id}/queue/{uid}.position`)
<!-- If any contract is checked, describe the schema or state change below and tag both its current writer and reader. -->

## Shared Files
<!-- app_router.dart, main.dart, and the ARB files are the cross-vertical conflict points. -->
- [ ] This PR does not touch them, OR it was opened the same day the changes were made and the other two devs were pinged.

## Breaking Changes
<!-- Does this PR rename, remove, or change the signature of any public API (repository methods, Cubit state classes, model fields) that other verticals consume? -->
- [ ] No
- [ ] Yes (describe what changed and who is affected below)


## Checklist
- [ ] Branched off `develop` and rebased on `develop` before opening this PR (no merge commits).
- [ ] My code follows the Dart style guide (`dart format` applied).
- [ ] I have not introduced any hardcoded user-facing strings (used ARB files if applicable).
- [ ] CI pipeline is green (I have run `flutter analyze` and `flutter test` locally, OR the GitHub Actions check on this PR has passed).
- [ ] If this PR adds a new sport, the `ScoringStrategy` contract remains unmodified.
- [ ] If this PR introduces a new Cubit, it emits an initial state synchronously.
- [ ] Firestore writes affecting ELO or queue position use atomic transactions.
- [ ] If this PR shows facility availability ("free"/"empty" status), the disclaimer footer is present via the `availabilityDisclaimerShort` ARB key (see `brain/project_description.md` §3.10).

## UI Changes (If applicable)
<!-- Per git_workflow.md: pair a screenshot of the implemented screen (both themes where relevant)
     with the matching design screenshot from the design system (docs/design/screenshots/). -->
| Implemented | Design reference |
|---|---|
|  |  |
