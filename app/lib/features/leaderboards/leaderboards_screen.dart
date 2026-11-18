import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:campus_arena/l10n/app_localizations.dart';
import '../../core/constants.dart';
import '../../core/widgets/error_retry_view.dart';
import '../../models/rating_model.dart';
import '../../repositories/rating_repository.dart';
import '../../repositories/user_repository.dart';
import '../../routing/route_constants.dart';
import '../auth/cubit/auth_cubit.dart';
import 'cubit/leaderboard_cubit.dart';
import 'cubit/leaderboard_state.dart';
import 'widgets/current_user_rank_bar.dart';
import 'widgets/leaderboard_filter_chips.dart';
import 'widgets/leaderboard_podium.dart';
import 'widgets/leaderboard_row.dart';

/// Board content is centred and width-constrained on larger canvases (no
/// bespoke split-view — only Map and Dashboard get those).
const double _contentMaxWidth = 640;

class LeaderboardsScreen extends StatelessWidget {
  const LeaderboardsScreen({
    super.key,
    this.ratingRepository,
    this.userRepository,
  });

  final RatingRepository? ratingRepository;
  final UserRepository? userRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaderboardCubit(
        uid: context.read<AuthCubit>().state.uid!,
        ratingRepository: ratingRepository,
        userRepository: userRepository,
      )..init(),
      child: const LeaderboardView(),
    );
  }
}

class LeaderboardView extends StatelessWidget {
  const LeaderboardView({super.key});

  /// Routes a tapped board/search row: a pair row opens the team profile, a
  /// singles row the player's public profile.
  void _openTarget(BuildContext context, RatingModel rating) {
    if (rating.ownerType == OwnerType.pair) {
      context.push(
        RouteConstants.teamProfile(rating.ownerId, sportId: rating.sportId),
      );
      return;
    }
    _openProfile(context, rating.ownerId);
  }

  void _openProfile(BuildContext context, String uid) {
    // The public drill-in reuses ProfileScreen with the settings gear hidden,
    // so opening it on yourself is a strictly worse view of your own Profile
    // tab. Acknowledge the tap with a snackbar instead of a dead end.
    if (uid == context.read<LeaderboardCubit>().uid) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).leaderboardThisIsYou),
          ),
        );
      return;
    }
    context.push(RouteConstants.publicProfile(uid));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      // The search field sits at the top; let the keyboard float over the board
      // instead of shoving the whole layout up.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(l10n.leaderboardsTab),
        actions: [
          // Friends management: the friends list feeds the friends-scope board.
          // An app-bar action (not the empty-state button — the board always
          // contains the signed-in user, so it is never empty) keeps this
          // reachable at all times. Until 5-B adds the profile gear, this is
          // also the app's only entry to the friends screen.
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: l10n.friendsTitle,
            onPressed: () => context.push(RouteConstants.friends),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
            child: BlocBuilder<LeaderboardCubit, LeaderboardState>(
              builder: (context, state) {
                final cubit = context.read<LeaderboardCubit>();
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    _SearchBar(
                      hint: l10n.leaderboardSearchHint,
                      onChanged: cubit.search,
                    ),
                    const SizedBox(height: 8),
                    LeaderboardFilterChips(
                      selectedSportId: state.selectedSportId,
                      scope: state.scope,
                      mode: state.mode,
                      onSport: cubit.selectSport,
                      onScope: cubit.selectScope,
                      onMode: cubit.selectMode,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: state.isSearching
                          ? _SearchResults(
                              state: state,
                              onTap: (r) => _openTarget(context, r),
                            )
                          : _Board(
                              state: state,
                              onRetry: cubit.retry,
                              onTap: (r) => _openTarget(context, r),
                            ),
                    ),
                    // The pinned rank is a singles, campus-wide (global) rank, so
                    // it is only truthful on the global singles board — hidden for
                    // the friends/course scopes and doubles to avoid a mismatch.
                    if (!state.isSearching &&
                        state.mode == LeaderboardMode.singles &&
                        state.scope == LeaderboardScope.global &&
                        state.status == LeaderboardStatus.ready &&
                        state.currentUserRating != null &&
                        state.currentUserRank != null)
                      CurrentUserRankBar(
                        rank: state.currentUserRank!,
                        rating: state.currentUserRating!,
                        name:
                            state.displayNames[cubit.uid] ??
                            l10n.leaderboardYou,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.state,
    required this.onRetry,
    required this.onTap,
  });

  final LeaderboardState state;
  final VoidCallback onRetry;
  final ValueChanged<RatingModel> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (state.status) {
      case LeaderboardStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LeaderboardStatus.error:
        return ErrorRetryView(
          message: l10n.leaderboardLoadError,
          retryLabel: l10n.retryButtonLabel,
          onRetry: onRetry,
        );
      case LeaderboardStatus.ready:
        if (state.entries.isEmpty) {
          return _EmptyView(message: l10n.leaderboardEmpty);
        }
        final entries = state.entries;
        final isDoubles = state.mode == LeaderboardMode.doubles;
        final podium = entries.take(3).toList();
        final rest = entries.length > 3
            ? entries.sublist(3)
            : const <RatingModel>[];
        // Both modes share the podium-plus-rows shape; only name resolution
        // differs — a pair shows both members joined and their combined initials.
        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            LeaderboardPodium(
              top: podium,
              displayNames: state.displayNames,
              labelFor: isDoubles ? _pairLabel : null,
              initialsFor: isDoubles ? _pairInitials : null,
              onTap: onTap,
            ),
            for (var i = 0; i < rest.length; i++)
              if (isDoubles)
                _pairRow(rest[i], i + 4)
              else
                LeaderboardRow(
                  rank: i + 4,
                  rating: rest[i],
                  name: state.displayNames[rest[i].ownerId] ?? rest[i].ownerId,
                  onTap: () => onTap(rest[i]),
                ),
          ],
        );
    }
  }

  Widget _pairRow(RatingModel rating, int rank) {
    final names = pairMemberNames(rating, state.displayNames);
    return LeaderboardRow(
      rank: rank,
      rating: rating,
      name: names.where((n) => n.isNotEmpty).join(' & '),
      memberNames: names,
      onTap: () => onTap(rating),
    );
  }

  /// The joined "A & B" label for a pair rating's podium spot.
  String _pairLabel(RatingModel rating) => pairMemberNames(
    rating,
    state.displayNames,
  ).where((n) => n.isNotEmpty).join(' & ');

  /// Combined initials for a pair — the first letter of each member's name (so
  /// "Anna & Bruno" reads "AB"), rather than the joined label's first two words.
  String _pairInitials(RatingModel rating) {
    final letters = [
      for (final n in pairMemberNames(rating, state.displayNames))
        if (n.trim().isNotEmpty) n.trim()[0].toUpperCase(),
    ].take(2).join();
    return letters.isEmpty ? '?' : letters;
  }
}

/// Member display names for a pair [rating], index-aligned with its memberUids,
/// falling back to the uid while a name is still unresolved.
List<String> pairMemberNames(
  RatingModel rating,
  Map<String, String> displayNames,
) => [for (final u in rating.memberUids ?? const []) displayNames[u] ?? u];

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.state, required this.onTap});

  final LeaderboardState state;
  final ValueChanged<RatingModel> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final results = state.searchResults;
    // Spinner only on the first resolve — a re-search (filter change) keeps the
    // prior rows visible until the fresh ranks land.
    if (results.isEmpty &&
        state.searchStatus == LeaderboardSearchStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty) {
      return _EmptyView(message: l10n.leaderboardNoPlayers);
    }
    // Each result has a position on the current board (position + ELO); a
    // singles row taps through to the player, a pair row to the team profile.
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, i) {
        final result = results[i];
        final rating = result.rating!;
        if (result.user == null) {
          final names = pairMemberNames(rating, state.displayNames);
          return LeaderboardRow(
            rank: result.rank!,
            rating: rating,
            name: names.where((n) => n.isNotEmpty).join(' & '),
            memberNames: names,
            onTap: () => onTap(rating),
          );
        }
        return LeaderboardRow(
          rank: result.rank!,
          rating: rating,
          name: result.user!.name,
          onTap: () => onTap(rating),
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.leaderboard_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
