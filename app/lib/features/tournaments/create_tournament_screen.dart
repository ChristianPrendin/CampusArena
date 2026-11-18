import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/match_display.dart';
import '../../l10n/app_localizations.dart';
import '../../repositories/facility_repository.dart';
import '../../repositories/tournament_repository.dart';
import '../auth/cubit/auth_cubit.dart';
import 'cubit/create_tournament_cubit.dart';
import 'cubit/create_tournament_state.dart';

/// Form content is centred and width-constrained on larger canvases (no
/// bespoke tablet split-view for this screen).
const double _contentMaxWidth = 560;

/// Create-tournament form (design ref: `create.png`). Builds the
/// [CreateTournamentCubit] and drives the facility stream after construction.
class CreateTournamentScreen extends StatelessWidget {
  const CreateTournamentScreen({
    super.key,
    this.tournamentRepository,
    this.facilityRepository,
  });

  final TournamentRepository? tournamentRepository;
  final FacilityRepository? facilityRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CreateTournamentCubit(
        organizerId: context.read<AuthCubit>().state.uid!,
        tournamentRepository: tournamentRepository,
        facilityRepository: facilityRepository,
      )..loadFacilities(),
      child: const CreateTournamentView(),
    );
  }
}

/// Create-form content, provided a [CreateTournamentCubit] above it. Public so
/// widget tests can pump it with a driven cubit (see `LeaderboardView`).
class CreateTournamentView extends StatelessWidget {
  const CreateTournamentView({super.key});

  String _errorMessage(AppLocalizations l10n, CreateTournamentError error) {
    return switch (error) {
      CreateTournamentError.name => l10n.tournamentNameRequired,
      CreateTournamentError.facility => l10n.tournamentFacilityRequired,
      CreateTournamentError.schedule => l10n.tournamentScheduleRequired,
      CreateTournamentError.deadlineFuture => l10n.tournamentDeadlineFuture,
      CreateTournamentError.deadlineOrder =>
        l10n.tournamentDeadlineBeforeSchedule,
      CreateTournamentError.createFailed => l10n.tournamentCreateError,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<CreateTournamentCubit, CreateTournamentState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status || prev.error != curr.error,
      listener: (context, state) {
        if (state.status == CreateTournamentStatus.success) {
          context.pop();
        } else if (state.status == CreateTournamentStatus.failure &&
            state.error != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(_errorMessage(l10n, state.error!))),
            );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
          title: Text(l10n.tournamentCreateTitle),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      children: const [
                        _NameField(),
                        SizedBox(height: 14),
                        _SportSelector(),
                        SizedBox(height: 14),
                        _FacilityField(),
                        SizedBox(height: 14),
                        _MaxParticipantsField(),
                        SizedBox(height: 14),
                        _DeadlineField(),
                        SizedBox(height: 14),
                        _ScheduleField(),
                      ],
                    ),
                  ),
                  const _CreateButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The filled, rounded field surface shared by every row on the form.
class _Tile extends StatelessWidget {
  const _Tile({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final decoration = BoxDecoration(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.outlineVariant),
    );
    final padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    if (onTap == null) {
      return Container(
        width: double.infinity,
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: decoration,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.primary,
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<CreateTournamentCubit>();
    return TextField(
      onChanged: cubit.setName,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(labelText: l10n.tournamentNameLabel),
    );
  }
}

class _SportSelector extends StatelessWidget {
  const _SportSelector();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<CreateTournamentCubit, CreateTournamentState>(
      buildWhen: (p, c) => p.sportId != c.sportId,
      builder: (context, state) {
        final cubit = context.read<CreateTournamentCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 6),
              child: _FieldLabel(l10n.tournamentSportLabel),
            ),
            Row(
              children: [
                for (var i = 0; i < SportIds.supported.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _SportChip(
                      sportId: SportIds.supported[i],
                      selected: state.sportId == SportIds.supported[i],
                      onTap: () => cubit.setSport(SportIds.supported[i]),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SportChip extends StatelessWidget {
  const _SportChip({
    required this.sportId,
    required this.selected,
    required this.onTap,
  });

  final String sportId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final fg = selected ? colors.onPrimary : colors.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(sportIcon(sportId), size: 18, color: fg),
              const SizedBox(width: 6),
              Text(
                localizedSportName(l10n, sportId),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacilityField extends StatelessWidget {
  const _FacilityField();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<CreateTournamentCubit, CreateTournamentState>(
      buildWhen: (p, c) =>
          p.facilityId != c.facilityId || p.facilities != c.facilities,
      builder: (context, state) {
        final cubit = context.read<CreateTournamentCubit>();
        return _Tile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel(l10n.tournamentFacilityLabel),
              DropdownButton<String>(
                isExpanded: true,
                value: state.facilityId,
                underline: const SizedBox.shrink(),
                hint: Text(l10n.tournamentFacilityRequired),
                items: [
                  for (final facility in state.facilities)
                    DropdownMenuItem(
                      value: facility.facilityId,
                      child: Text(
                        facility.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) cubit.setFacility(id);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MaxParticipantsField extends StatelessWidget {
  const _MaxParticipantsField();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return BlocBuilder<CreateTournamentCubit, CreateTournamentState>(
      buildWhen: (p, c) => p.maxParticipants != c.maxParticipants,
      builder: (context, state) {
        final cubit = context.read<CreateTournamentCubit>();
        final atMin =
            state.maxParticipants <= CreateTournamentCubit.participantsMin;
        final atMax =
            state.maxParticipants >= CreateTournamentCubit.participantsMax;
        return _Tile(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(l10n.tournamentMaxLabel),
                    Text(
                      '${state.maxParticipants}',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: atMin ? null : cubit.decrementMax,
                icon: const Icon(Icons.remove_circle_outline),
                color: colors.primary,
              ),
              IconButton(
                onPressed: atMax ? null : cubit.incrementMax,
                icon: const Icon(Icons.add_circle_outline),
                color: colors.primary,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeadlineField extends StatelessWidget {
  const _DeadlineField();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<CreateTournamentCubit, CreateTournamentState>(
      buildWhen: (p, c) => p.registrationDeadline != c.registrationDeadline,
      builder: (context, state) {
        final cubit = context.read<CreateTournamentCubit>();
        return _PickerTile(
          label: l10n.tournamentDeadlineLabel,
          value: state.registrationDeadline,
          icon: Icons.event,
          onPick: (dt) => cubit.setDeadline(dt),
        );
      },
    );
  }
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<CreateTournamentCubit, CreateTournamentState>(
      buildWhen: (p, c) => p.scheduledAt != c.scheduledAt,
      builder: (context, state) {
        final cubit = context.read<CreateTournamentCubit>();
        return _PickerTile(
          label: l10n.tournamentScheduleLabel,
          value: state.scheduledAt,
          icon: Icons.schedule,
          onPick: (dt) => cubit.setScheduledAt(dt),
        );
      },
    );
  }
}

/// A tappable field that opens a Material date then time picker and reports the
/// combined [DateTime].
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final IconData icon;
  final ValueChanged<DateTime> onPick;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value ?? now),
    );
    if (time == null) return;
    onPick(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final display = value == null
        ? l10n.tournamentPickPrompt
        : DateFormat.E(locale).add_Hm().format(value!);
    return _Tile(
      onTap: () => _pick(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FieldLabel(label),
                Text(display, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          Icon(icon, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<CreateTournamentCubit, CreateTournamentState>(
      buildWhen: (p, c) => p.status != c.status,
      builder: (context, state) {
        final submitting = state.status == CreateTournamentStatus.submitting;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: submitting
                  ? null
                  : () => context.read<CreateTournamentCubit>().submit(),
              child: submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.tournamentCreateButton),
            ),
          ),
        );
      },
    );
  }
}
