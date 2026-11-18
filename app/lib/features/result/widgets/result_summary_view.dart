import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/achievements/achievement_display.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/achievement_def_model.dart';
import '../../../routing/route_constants.dart';
import '../cubit/result_state.dart';

/// The match summary (`docs/design/screenshots/summary.png`): a Victory/Defeat
/// header, an animated ELO delta counting up, the old → new rating, and — for
/// singles only — the new campus-rank pill. When this confirmation unlocked
/// achievements, a client-local reveal (badge PNG + name + haptic) is shown
/// inline — Phase 7-A, mirroring the queue-ready / challenge alert pattern
/// (no FCM push on Spark).
class ResultSummaryView extends StatelessWidget {
  const ResultSummaryView({super.key, required this.state});

  final ResultState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summary = state.summary;

    // Background/foreground stay theme-derived (no hardcoded hex): a win uses
    // the primary emerald; a loss a muted surface tone. The gradient is a
    // lightness-shifted pair of the base.
    final isWin = summary?.isWin ?? true;
    final base = isWin
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final onColor = isWin ? colorScheme.onPrimary : colorScheme.onSurface;
    final darker = _shift(base, 0.82);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [base, darker],
          ),
        ),
        child: SafeArea(
          child: summary == null
              ? Center(child: CircularProgressIndicator(color: onColor))
              : Stack(
                  children: [
                    if (isWin)
                      Positioned(
                        top: 12,
                        right: -12,
                        child: Icon(
                          Icons.emoji_events,
                          size: 180,
                          color: onColor.withValues(alpha: 0.12),
                        ),
                      ),
                    Column(
                      children: [
                        const SizedBox(height: 20),
                        Text(
                          isWin
                              ? l10n.resultVictoryTitle
                              : l10n.resultDefeatTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: onColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        _EloBlock(summary: summary, onColor: onColor),
                        if (summary.isSingles && summary.rank != null) ...[
                          const SizedBox(height: 28),
                          _RankPill(rank: summary.rank!, onColor: onColor),
                        ],
                        if (state.newBadges.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _AchievementReveal(
                            badges: state.newBadges,
                            onColor: onColor,
                          ),
                        ],
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(56),
                              backgroundColor: onColor,
                              foregroundColor: base,
                            ),
                            onPressed: () => context.go(RouteConstants.home),
                            child: Text(l10n.resultDone),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  static Color _shift(Color color, double factor) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * factor).clamp(0.0, 1.0))
        .toColor();
  }
}

class _EloBlock extends StatelessWidget {
  const _EloBlock({required this.summary, required this.onColor});

  final EloSummary summary;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final animatedDelta = (summary.delta * t).round();
        final animatedNew = summary.oldElo + animatedDelta;
        final sign = summary.delta >= 0 ? '+' : '';
        return Column(
          children: [
            Text(
              l10n.eloLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onColor.withValues(alpha: 0.85),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  summary.delta >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: onColor,
                  size: 44,
                ),
                const SizedBox(width: 8),
                Text(
                  '$sign$animatedDelta',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${summary.oldElo}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: onColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward, color: onColor, size: 20),
                ),
                Text(
                  '$animatedNew',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Client-local badge reveal: fires a haptic once when it first appears and
/// scales the badge PNG(s) + name in. Earned art is full-color (the locked,
/// desaturated variant lives on the profile grid).
class _AchievementReveal extends StatefulWidget {
  const _AchievementReveal({required this.badges, required this.onColor});

  final List<AchievementDefModel> badges;
  final Color onColor;

  @override
  State<_AchievementReveal> createState() => _AchievementRevealState();
}

class _AchievementRevealState extends State<_AchievementReveal> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(
        scale: t,
        child: Opacity(opacity: t.clamp(0, 1), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: widget.onColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.achievementUnlockHeadline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: widget.onColor.withValues(alpha: 0.85),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 20,
              runSpacing: 12,
              children: [
                for (final badge in widget.badges)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        badge.iconAsset,
                        width: 56,
                        height: 56,
                        errorBuilder: (context, _, _) => Icon(
                          Icons.emoji_events,
                          size: 56,
                          color: widget.onColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 84,
                        child: Text(
                          localizedAchievementName(l10n, badge.achievementId),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: widget.onColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RankPill extends StatelessWidget {
  const _RankPill({required this.rank, required this.onColor});

  final int rank;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: onColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            l10n.resultNewRank,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onColor.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.resultRankValue(rank),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: onColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_upward, color: onColor, size: 22),
            ],
          ),
        ],
      ),
    );
  }
}
