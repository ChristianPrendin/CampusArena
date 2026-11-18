import 'package:flutter/material.dart';

import '../../../core/bracket/bracket_engine.dart';
import '../../../core/widgets/identity_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../cubit/tournament_detail_state.dart';
import '../tournament_ui.dart';

/// Result of the advance-slot flow: the chosen slot and the winner the organizer
/// picked. The detail cubit flips the *other* side's `eliminated` flag.
class AdvanceChoice {
  const AdvanceChoice(this.slot, this.winnerUid);
  final BracketSlot slot;
  final String winnerUid;
}

/// Bottom sheet listing the alive participants → returns the uid to forfeit.
Future<String?> showForfeitSheet({
  required BuildContext context,
  required List<StandingEntry> alive,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                l10n.tournamentForfeitTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            if (alive.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text(l10n.tournamentNoAliveParticipants),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in alive)
                      ListTile(
                        leading: IdentityAvatar(
                          seed: p.uid,
                          initials: initialsFromName(p.name),
                          radius: 18,
                        ),
                        title: Text(p.name ?? p.uid),
                        onTap: () => Navigator.of(sheetContext).pop(p.uid),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Bottom sheet listing playable slots; picking a slot expands to its two
/// players so the organizer taps the winner. Returns the chosen slot + winner.
Future<AdvanceChoice?> showAdvanceSheet({
  required BuildContext context,
  required List<BracketSlot> playableSlots,
  required Map<String, String?> names,
}) {
  final l10n = AppLocalizations.of(context);
  String label(BracketSide side) =>
      side.uid == null ? '' : (names[side.uid] ?? side.uid!);

  return showModalBottomSheet<AdvanceChoice>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      BracketSlot? selected;
      return StatefulBuilder(
        builder: (statefulContext, setState) {
          final theme = Theme.of(statefulContext);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    selected == null
                        ? l10n.tournamentAdvanceTitle
                        : l10n.tournamentAdvancePickWinner(
                            l10n.tournamentSlotVs(
                              label(selected!.a),
                              label(selected!.b),
                            ),
                          ),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (playableSlots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Text(l10n.tournamentNoPlayableSlots),
                  )
                else if (selected == null)
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final slot in playableSlots)
                          ListTile(
                            leading: Icon(
                              Icons.skip_next,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(
                              l10n.tournamentSlotVs(
                                label(slot.a),
                                label(slot.b),
                              ),
                            ),
                            subtitle: Text(
                              tournamentRoundLabel(l10n, slot.round),
                            ),
                            onTap: () => setState(() => selected = slot),
                          ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final side in [selected!.a, selected!.b])
                        if (side.uid != null)
                          ListTile(
                            leading: IdentityAvatar(
                              seed: side.uid!,
                              initials: initialsFromName(names[side.uid]),
                              radius: 18,
                            ),
                            title: Text(label(side)),
                            trailing: Icon(
                              Icons.emoji_events,
                              color: theme.colorScheme.primary,
                            ),
                            onTap: () => Navigator.of(
                              sheetContext,
                            ).pop(AdvanceChoice(selected!, side.uid!)),
                          ),
                    ],
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    },
  );
}
