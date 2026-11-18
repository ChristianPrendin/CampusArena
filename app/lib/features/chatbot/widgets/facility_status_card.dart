import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../map/facility_ui.dart';
import '../data/tool_results.dart';

/// Rich card rendered inside an assistant message when a facility-availability
/// tool fired: colored status dot, name, sport icon, queue count, and an "Open
/// Map" action.
///
/// This card carries no disclaimer of its own: the short availability
/// disclaimer is appended — unconditionally, in code — to the assistant
/// message text that always renders directly above this card (see
/// [ChatbotRepository.answer]'s hard rule). Repeating it here produced two
/// copies in the same bubble.
class FacilityStatusCard extends StatelessWidget {
  const FacilityStatusCard({
    super.key,
    required this.facilities,
    this.onOpenMap,
  });

  final List<FacilityToolResult> facilities;
  final VoidCallback? onOpenMap;

  IconData _sportIcon(String sportId) {
    switch (sportId) {
      case SportIds.pingPong:
        return Icons.sports_tennis;
      case SportIds.foosball:
        return Icons.sports_soccer;
      default:
        return Icons.sports;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final facility in facilities)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: facilityStatusColor(
                        theme.colorScheme,
                        facility.status,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _sportIcon(facility.sportId),
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      facility.name,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.people_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${facility.queueLength}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          if (onOpenMap != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onOpenMap,
                child: Text(l10n.chatbotOpenMap),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
