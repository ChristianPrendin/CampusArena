import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/identity_avatar.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/facility_model.dart';
import '../../../models/match_model.dart';
import '../../../models/user_model.dart';
import '../../../repositories/match_repository.dart';
import '../../../repositories/user_repository.dart';
import '../../weather/cubit/weather_cubit.dart';
import '../../weather/widgets/weather_snippet.dart';
import '../facility_ui.dart';

/// Facility detail slide-up content per `facility.png`: header with sport
/// tile and status row, the mandatory short availability disclaimer directly
/// under the status row (project_description.md §3.10), current match stats,
/// King of the Table, and the weather snippet for outdoor facilities.
///
/// [queueSection] is the seam with vertical B's queue feature: a nullable
/// slot rendered last (null → renders nothing). The map screen plugs in
/// `QueueSection(facilityId: facility.facilityId)`; it stays injectable so
/// this card is testable without auth or Firestore.
class FacilityDetailCard extends StatelessWidget {
  const FacilityDetailCard({
    super.key,
    required this.facility,
    required this.matchRepository,
    required this.userRepository,
    this.weatherCubit,
    this.queueSection,
  });

  final FacilityModel facility;

  /// Read-only lookups for the current match (players / duration) and the
  /// king's display name; injected so tests can mock them.
  final MatchRepository matchRepository;
  final UserRepository userRepository;

  /// Shared cubit so reopening cards reuses the in-memory weather cache.
  final WeatherCubit? weatherCubit;
  final Widget? queueSection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(facility: facility),
          const SizedBox(height: 14),
          const _DisclaimerRow(),
          const SizedBox(height: 14),
          _MatchStatsRow(facility: facility, matchRepository: matchRepository),
          const SizedBox(height: 14),
          _KingRow(facility: facility, userRepository: userRepository),
          if (facility.isOutdoor) const SizedBox(height: 14),
          WeatherSnippet(
            coordinates: facility.coordinates,
            isOutdoor: facility.isOutdoor,
            cubit: weatherCubit,
          ),
          if (queueSection != null) ...[
            const SizedBox(height: 14),
            queueSection!,
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.facility});

  final FacilityModel facility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            facilitySportIcon(facility.sportId),
            size: 24,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                facility.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  FacilityStatusChip(status: facility.status),
                  if (facility.isOutdoor) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.wb_sunny_outlined,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      l10n.facilityOutdoorLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mandatory availability disclaimer, short copy — placed directly under the
/// status row per project_description.md §3.10.
class _DisclaimerRow extends StatelessWidget {
  const _DisclaimerRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            AppLocalizations.of(context).availabilityDisclaimerShort,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Players / match-duration tiles. When the facility carries an active match
/// its document is watched read-only; without one the tiles show placeholders.
class _MatchStatsRow extends StatefulWidget {
  const _MatchStatsRow({required this.facility, required this.matchRepository});

  final FacilityModel facility;
  final MatchRepository matchRepository;

  @override
  State<_MatchStatsRow> createState() => _MatchStatsRowState();
}

class _MatchStatsRowState extends State<_MatchStatsRow> {
  // Memoised so parent rebuilds (any facility emission) don't resubscribe.
  Stream<MatchModel?>? _matchStream;

  // Ticks the displayed match duration forward while a match is live — without
  // it, the minute count only refreshes when the match document changes.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _matchStream = _streamFor(widget.facility.currentMatchId);
    _syncTicker();
  }

  @override
  void didUpdateWidget(_MatchStatsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facility.currentMatchId != widget.facility.currentMatchId) {
      _matchStream = _streamFor(widget.facility.currentMatchId);
      _syncTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    _ticker?.cancel();
    if (widget.facility.currentMatchId == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Stream<MatchModel?>? _streamFor(String? matchId) =>
      matchId == null ? null : widget.matchRepository.watchMatch(matchId);

  @override
  Widget build(BuildContext context) {
    final stream = _matchStream;
    if (stream == null) return _tiles(context, null);
    return StreamBuilder<MatchModel?>(
      stream: stream,
      builder: (context, snapshot) => _tiles(context, snapshot.data),
    );
  }

  Widget _tiles(BuildContext context, MatchModel? match) {
    final l10n = AppLocalizations.of(context);
    final placeholder = l10n.facilityValuePlaceholder;
    final minutes = match == null
        ? null
        : DateTime.now().difference(match.startedAt).inMinutes;

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: l10n.facilityPlayersLabel,
            icon: Icons.groups,
            value: match?.playerUids.length.toString() ?? placeholder,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            label: l10n.facilityMatchDurationLabel,
            icon: Icons.timer_outlined,
            value: minutes == null
                ? placeholder
                : l10n.facilityDurationMinutes(minutes < 0 ? 0 : minutes),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.icon,
    required this.value,
  });

  final String label;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(icon, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "King of the Table" row: `kingOfTableUid` resolved to a username via a
/// one-shot read, `kingOfTableWins` shown as the reign length.
class _KingRow extends StatefulWidget {
  const _KingRow({required this.facility, required this.userRepository});

  final FacilityModel facility;
  final UserRepository userRepository;

  @override
  State<_KingRow> createState() => _KingRowState();
}

class _KingRowState extends State<_KingRow> {
  // Memoised so parent rebuilds don't refetch the same user.
  Future<UserModel?>? _kingFuture;

  @override
  void initState() {
    super.initState();
    _kingFuture = _futureFor(widget.facility.kingOfTableUid);
  }

  @override
  void didUpdateWidget(_KingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.facility.kingOfTableUid != widget.facility.kingOfTableUid) {
      _kingFuture = _futureFor(widget.facility.kingOfTableUid);
    }
  }

  Future<UserModel?>? _futureFor(String? uid) =>
      uid == null ? null : widget.userRepository.getUser(uid);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final uid = widget.facility.kingOfTableUid;

    if (uid == null) {
      return _container(
        color: colors.surfaceContainerHighest,
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              size: 22,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.facilityNoKing,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<UserModel?>(
      future: _kingFuture,
      builder: (context, snapshot) {
        final name = snapshot.data?.username;
        return _container(
          color: colors.secondaryContainer,
          child: Row(
            children: [
              Icon(Icons.workspace_premium, size: 22, color: colors.tertiary),
              const SizedBox(width: 10),
              IdentityAvatar(
                seed: uid,
                initials: initialsFromName(name),
                radius: 17,
                fontSize: 12,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.facilityKingOfTable,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      name ?? l10n.facilityValuePlaceholder,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.facilityKingWins(widget.facility.kingOfTableWins),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSecondaryContainer,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _container({required Color color, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
