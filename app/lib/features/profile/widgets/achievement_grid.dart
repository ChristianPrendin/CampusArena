import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/achievements/achievement_display.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/achievement_def_model.dart';

/// The profile achievement badge grid. One art file per badge: earned renders
/// full-color, locked renders the *same* PNG desaturated (a greyscale
/// [ColorFilter]) — no second art variant. Each tile is tappable: it surfaces
/// its detail (unlock date, or how to unlock it) as a system-message SnackBar,
/// mirroring the reset-password idiom (`settings_screen.dart`) rather than a
/// permanent on-grid caption. Works unchanged for a foreign profile (it just
/// reads that user's badges).
///
/// No dedicated design mockup exists for the grid; it extends the card idiom of
/// the stats grid (precedent noted in the PR, per the map recenter button).
class AchievementGrid extends StatelessWidget {
  const AchievementGrid({super.key, required this.defs, required this.badges});

  final List<AchievementDefModel> defs;

  /// achievementId → unlock timestamp for the profiled user.
  final Map<String, DateTime> badges;

  /// Standard luminance-weighted greyscale matrix for locked badges.
  static const List<double> _greyscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.profileAchievementsTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            // Fixed crossAxisCount so the 3 columns stretch to fill the card's
            // full width (like a real grid); a fixed mainAxisExtent — not
            // childAspectRatio — sizes the row to the tile's actual content
            // height instead of a computed aspect ratio, which is what left a
            // gap under every badge once the on-grid caption (removed — detail
            // now lives in the tap reveal) stopped needing that extra height.
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
                mainAxisExtent: 100,
              ),
              itemCount: defs.length,
              itemBuilder: (context, index) {
                final def = defs[index];
                return _BadgeTile(
                  def: def,
                  unlockedAt: badges[def.achievementId],
                  greyscale: _greyscale,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.def,
    required this.unlockedAt,
    required this.greyscale,
  });

  final AchievementDefModel def;
  final DateTime? unlockedAt;
  final List<double> greyscale;

  /// Surfaces the tile's detail as a system-message SnackBar (the
  /// reset-password idiom) instead of a permanent on-grid caption: unlock date
  /// for an earned badge, or how to earn it for a locked one.
  void _showDetail(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = unlockedAt != null
        ? l10n.achievementUnlockedOn(
            DateFormat.yMMMd(
              Localizations.localeOf(context).toString(),
            ).format(unlockedAt!),
          )
        : l10n.achievementUnlockHint(
            localizedAchievementDescription(l10n, def.achievementId),
          );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final earned = unlockedAt != null;

    final image = Image.asset(
      def.iconAsset,
      width: 56,
      height: 56,
      errorBuilder: (context, _, _) => Icon(
        Icons.emoji_events_outlined,
        size: 56,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    return InkWell(
      onTap: () => _showDetail(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: earned ? 1 : 0.55,
              child: earned
                  ? image
                  : ColorFiltered(
                      colorFilter: ColorFilter.matrix(greyscale),
                      child: image,
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              localizedAchievementName(l10n, def.achievementId),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: earned
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
