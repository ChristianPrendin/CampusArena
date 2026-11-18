import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:campus_arena/l10n/app_localizations.dart';
import '../../core/constants.dart';
import '../../core/match_display.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/identity_avatar.dart';
import '../../models/user_model.dart';
import '../../repositories/challenge_repository.dart';
import '../../repositories/user_repository.dart';
import '../../routing/route_constants.dart';
import '../auth/cubit/auth_cubit.dart';
import '../challenges/cubit/challenge_cubit.dart';
import '../challenges/cubit/challenge_state.dart';
import 'cubit/friends_cubit.dart';
import 'cubit/friends_state.dart';

/// Friends list + add-by-search. Full-screen, outside the nav shell; the
/// signed-in user's private leaderboard source and the send-a-challenge entry
/// point (a per-row action — no design counterpart, precedent: the map recenter
/// button — since friends-only comes free: the list IS the friend set). Typing a
/// username proposes a list of matching players, each with an inline Add button.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({
    super.key,
    this.userRepository,
    this.challengeRepository,
  });

  /// Injectable for tests; production defaults to the live repositories.
  final UserRepository? userRepository;
  final ChallengeRepository? challengeRepository;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthCubit>().state.uid ?? '';
    return MultiBlocProvider(
      providers: [
        BlocProvider<FriendsCubit>(
          create: (_) => FriendsCubit(uid: uid, userRepository: userRepository),
        ),
        BlocProvider<ChallengeCubit>(
          // Send-only: the friends list never reads the challenge inboxes, so
          // don't open the incoming/outgoing listeners here.
          create: (_) => ChallengeCubit.sender(
            uid: uid,
            challengeRepository: challengeRepository,
            userRepository: userRepository,
          ),
        ),
      ],
      child: const _FriendsView(),
    );
  }
}

class _FriendsView extends StatefulWidget {
  const _FriendsView();

  @override
  State<_FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<_FriendsView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAddResult(BuildContext context, FriendsState state) {
    final l10n = AppLocalizations.of(context);
    final String message;
    switch (state.addStatus) {
      case FriendAddStatus.added:
        message = l10n.friendsAddedSnack(state.addedUsername ?? '');
      case FriendAddStatus.failed:
        message = l10n.friendsAddFailedSnack;
      case FriendAddStatus.idle:
        return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSendResult(BuildContext context, ChallengeState state) {
    final l10n = AppLocalizations.of(context);
    final String message;
    switch (state.sendStatus) {
      case ChallengeSendStatus.sent:
        message = l10n.challengeSentSnack(state.lastSentToName ?? '');
      case ChallengeSendStatus.duplicate:
        message = l10n.challengeErrorDuplicate;
      case ChallengeSendStatus.notFriends:
        message = l10n.challengeErrorNotFriends;
      case ChallengeSendStatus.failed:
        message = l10n.challengeErrorGeneric;
      case ChallengeSendStatus.idle:
      case ChallengeSendStatus.sending:
        return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      // The add-friend search sits at the top; let the keyboard float over the
      // list rather than pushing the whole layout up.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: Text(l10n.friendsTitle)),
      body: BlocListener<ChallengeCubit, ChallengeState>(
        listenWhen: (previous, current) =>
            previous.sendStatus == ChallengeSendStatus.sending &&
            current.sendStatus != ChallengeSendStatus.sending,
        listener: _onSendResult,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.friendsAddSectionTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) =>
                          context.read<FriendsCubit>().search(value),
                      decoration: InputDecoration(
                        hintText: l10n.friendsSearchHint,
                        prefixIcon: const Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.friendsSearchHelper,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: BlocConsumer<FriendsCubit, FriendsState>(
                  // Key on addTick, not addStatus: a second consecutive add keeps
                  // addStatus == added, so listening on it would swallow the
                  // repeat snackbar. The tick bumps on every add outcome.
                  listenWhen: (previous, current) =>
                      previous.addTick != current.addTick,
                  listener: _onAddResult,
                  builder: (context, state) {
                    // An active query swaps the friends list for the search
                    // results; clearing the field restores the list.
                    if (state.searchQuery.trim().isNotEmpty) {
                      return _SearchResults(state: state);
                    }
                    switch (state.status) {
                      case FriendsStatus.loading:
                        return const Center(child: CircularProgressIndicator());
                      case FriendsStatus.error:
                        return _CenteredMessage(text: l10n.friendsLoadError);
                      case FriendsStatus.ready:
                        if (state.friends.isEmpty) {
                          return const _FriendsEmptyState();
                        }
                        return _FriendsList(friends: state.friends);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.state});

  final FriendsState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (state.searchStatus) {
      case FriendSearchStatus.idle:
      case FriendSearchStatus.searching:
        return const Center(child: CircularProgressIndicator());
      case FriendSearchStatus.failed:
        return _CenteredMessage(text: l10n.friendsSearchFailed);
      case FriendSearchStatus.done:
        if (state.searchResults.isEmpty) {
          return _CenteredMessage(
            text: l10n.friendsSearchEmpty(state.searchQuery.trim()),
          );
        }
        final selfUid = context.read<FriendsCubit>().uid;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: state.searchResults.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final candidate = state.searchResults[index];
            return _SearchResultTile(
              candidate: candidate,
              isSelf: candidate.uid == selfUid,
              isFriend: state.isFriend(candidate.uid),
            );
          },
        );
    }
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.candidate,
    required this.isSelf,
    required this.isFriend,
  });

  final UserModel candidate;
  final bool isSelf;
  final bool isFriend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListTile(
      // Self shows the "You" label and stays inert; anyone else drills into
      // their public profile (back returns to this pushed screen).
      onTap: isSelf
          ? null
          : () => context.push(RouteConstants.publicProfile(candidate.uid)),
      leading: IdentityAvatar(
        seed: candidate.uid,
        initials: initialsFromName(candidate.name),
      ),
      title: Text(candidate.name),
      subtitle: Text(l10n.friendsHandle(candidate.username)),
      trailing: _trailing(context, l10n, theme),
    );
  }

  Widget _trailing(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    if (isSelf) {
      return Text(
        l10n.friendsYouLabel,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    if (isFriend) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            l10n.friendsAddedLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      );
    }
    return FilledButton.tonalIcon(
      onPressed: () => context.read<FriendsCubit>().addFriend(candidate),
      // The app's FilledButton theme sets a full-width minimumSize; unbounded in
      // a ListTile.trailing slot it would starve the title and wrap the name
      // vertically. Shrink-wrap it to its content so the tile stays single-line.
      style: FilledButton.styleFrom(
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
      label: Text(l10n.friendsAddButton),
    );
  }
}

class _FriendsList extends StatelessWidget {
  const _FriendsList({required this.friends});

  final List<UserModel> friends;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: friends.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final friend = friends[index];
        return ListTile(
          onTap: () => context.push(RouteConstants.publicProfile(friend.uid)),
          leading: IdentityAvatar(
            seed: friend.uid,
            initials: initialsFromName(friend.name),
          ),
          title: Text(friend.name),
          subtitle: Text(l10n.friendsHandle(friend.username)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.sports),
                tooltip: l10n.challengeButtonTooltip,
                onPressed: () => _openChallengeSheet(context, friend),
              ),
              IconButton(
                icon: const Icon(Icons.person_remove_outlined),
                tooltip: l10n.friendsRemoveTooltip,
                onPressed: () => _confirmRemove(context, friend),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Opens the sport-picker sheet, then sends the challenge through the
  /// [ChallengeCubit]. The success/failure snackbar is raised by the screen's
  /// send-result listener.
  Future<void> _openChallengeSheet(
    BuildContext context,
    UserModel friend,
  ) async {
    final cubit = context.read<ChallengeCubit>();
    final sportId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ChallengeSheet(friend: friend),
    );
    if (sportId == null) return;
    await cubit.send(
      toUserId: friend.uid,
      sportId: sportId,
      toName: friend.name,
    );
  }

  Future<void> _confirmRemove(BuildContext context, UserModel friend) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<FriendsCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.friendsRemoveTitle,
      message: l10n.friendsRemoveMessage(friend.name),
      confirmLabel: l10n.friendsRemoveConfirm,
      cancelLabel: l10n.friendsRemoveCancel,
      isDestructive: true,
    );
    if (confirmed) {
      await cubit.removeFriend(friend.uid);
    }
  }
}

class _FriendsEmptyState extends StatelessWidget {
  const _FriendsEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Icon(
                Icons.groups_outlined,
                size: 44,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.friendsEmptyTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.friendsEmptyBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Modal sheet to pick a sport before challenging [friend]. Pops the chosen
/// sportId (or null if dismissed); the caller performs the send.
class _ChallengeSheet extends StatefulWidget {
  const _ChallengeSheet({required this.friend});

  final UserModel friend;

  @override
  State<_ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends State<_ChallengeSheet> {
  String _sportId = SportIds.supported.first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.challengeSheetTitle(widget.friend.name),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.challengeSheetPickSport,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final sportId in SportIds.supported)
                  ChoiceChip(
                    avatar: Icon(sportIcon(sportId), size: 18),
                    label: Text(localizedSportName(l10n, sportId)),
                    selected: _sportId == sportId,
                    onSelected: (_) => setState(() => _sportId = sportId),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_sportId),
              icon: const Icon(Icons.send, size: 20),
              label: Text(l10n.challengeSheetSend),
            ),
          ],
        ),
      ),
    );
  }
}
