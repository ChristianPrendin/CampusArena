import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/match_display.dart';
import '../../../l10n/app_localizations.dart';

/// The pill toggle row that focuses the dashboard on one sport. One chip per
/// [SportIds.supported]; the selected chip fills with the primary colour.
class SportSelector extends StatelessWidget {
  const SportSelector({
    super.key,
    required this.selectedSportId,
    required this.onSelected,
  });

  final String selectedSportId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        for (final sportId in SportIds.supported) ...[
          if (sportId != SportIds.supported.first) const SizedBox(width: 8),
          Expanded(
            child: _SportChip(
              icon: sportIcon(sportId),
              label: localizedSportName(l10n, sportId),
              selected: sportId == selectedSportId,
              onTap: () => onSelected(sportId),
            ),
          ),
        ],
      ],
    );
  }
}

class _SportChip extends StatelessWidget {
  const _SportChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final background = selected ? colors.primary : colors.surfaceContainerHigh;
    final foreground = selected ? colors.onPrimary : colors.onSurfaceVariant;

    return Material(
      color: background,
      shape: StadiumBorder(
        side: selected
            ? BorderSide.none
            : BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
