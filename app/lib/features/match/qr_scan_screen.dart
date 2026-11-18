import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../routing/route_constants.dart';
import 'cubit/match_cubit.dart';
import 'cubit/match_state.dart';

/// The QR check-in surface, per `docs/design/screenshots/qr.png`: a live
/// camera viewfinder with corner brackets and a scan line, the soft GPS
/// warning banner, and the manual fallback-code entry. On deep-link entry the
/// facility is already resolved, so an explicit "Check in" button replaces the
/// blind scan.
class QrScanView extends StatefulWidget {
  const QrScanView({
    super.key,
    this.isDeepLink = false,
    this.enableCamera = true,
  });

  /// True when reached via `/play/facility/:id`: the facility is known, so show a
  /// confirm button instead of expecting another scan.
  final bool isDeepLink;

  /// Camera preview is unavailable under the widget-test binding; disable it to
  /// render the viewfinder chrome without instantiating [MobileScanner].
  final bool enableCamera;

  @override
  State<QrScanView> createState() => _QrScanViewState();
}

class _QrScanViewState extends State<QrScanView> {
  /// The last code we handed to the cubit. A detection matching it is ignored
  /// so a still-in-frame invalid QR can't spam-retry the join after the flow
  /// resets to idle; any *different* code (or a scan after a manual entry)
  /// fires immediately. The status guard below blocks re-entry while a submit
  /// is in flight, so this only ever suppresses an exact repeat.
  String? _lastCode;

  void _onDetect(BarcodeCapture capture) {
    final cubit = context.read<MatchCubit>();
    final status = cubit.state.status;
    // Block only while a submit is actually in flight. idle, a prepared-but-
    // unconfirmed check-in (the far-table "Check in" button rests here, and
    // indoor GPS drift makes that common) and a prior error are all live
    // scanning surfaces — a new code must never be stuck behind an old one.
    if (status == MatchStatus.resolving || status == MatchStatus.checkingIn) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;
      // Ignore the exact code just submitted so a still-in-frame QR can't
      // spam-retry; a different code (or a manual entry, which clears this)
      // fires immediately.
      if (raw == _lastCode) continue;
      _lastCode = raw;
      // Tactile confirmation the scanner locked on: the user is holding the
      // phone over a table, not watching the screen for the spinner to appear.
      HapticFeedback.selectionClick();
      cubit.submitCode(raw);
      return;
    }
  }

  Future<void> _enterManually() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ManualEntrySheet(),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    // A manual submit clears the scan dedup so the next scan — even of the same
    // code — is accepted, and doesn't itself get suppressed as a repeat.
    _lastCode = null;
    // ignore: use_build_context_synchronously
    context.read<MatchCubit>().submitCode(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    // Chrome that overlays the live camera feed stays dark regardless of the
    // app theme (see below), so it sources roles from the dark scheme rather
    // than raw color literals. The brackets keep using the themed [colors].
    final dark = AppTheme.darkColorScheme;
    final state = context.watch<MatchCubit>().state;

    final busy =
        state.status == MatchStatus.resolving ||
        state.status == MatchStatus.checkingIn;

    return Scaffold(
      // The viewfinder sits over a live camera feed, so this surface is dark
      // independent of the app theme (as in the design). Chrome over the camera
      // uses the dark scheme; themed roles still drive the brackets and banner.
      backgroundColor: dark.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.enableCamera)
            // Let MobileScanner own its controller. When the caller supplies one,
            // the widget skips its WidgetsBindingObserver and the app must drive
            // the camera lifecycle itself; without that, a background/resume or
            // hot-restart desyncs the native session and start() throws
            // MOBILE_SCANNER_ALREADY_STARTED_ERROR ("already started"). We never
            // touch the controller (no torch/lens switch), so ownership buys
            // nothing and costs the lifecycle handling.
            MobileScanner(onDetect: _onDetect),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: dark.onSurface),
                    onPressed: () => _close(context),
                  ),
                ),
                Expanded(
                  child: Center(child: _Viewfinder(color: colors.primary)),
                ),
                Text(
                  l10n.qrScanTitle,
                  style: TextStyle(
                    color: dark.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    l10n.qrScanHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dark.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                  child: _ManualEntryButton(onPressed: _enterManually),
                ),
              ],
            ),
          ),
          if (busy)
            ColoredBox(
              color: dark.scrim.withValues(alpha: 0.54),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteConstants.home);
    }
  }
}

/// The manual fallback-code button, outlined over the dark camera surface
/// (light border + label). The singles/doubles + side selection has moved to the
/// dedicated [MatchSetupView], so the viewfinder now carries only this affordance.
class _ManualEntryButton extends StatelessWidget {
  const _ManualEntryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dark = AppTheme.darkColorScheme;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: dark.onSurface,
        side: BorderSide(color: dark.outline, width: 1.5),
      ),
      icon: const Icon(Icons.keyboard),
      label: Text(l10n.qrEnterManually),
      onPressed: onPressed,
    );
  }
}

/// The square viewfinder frame: four rounded corner brackets and a scan line.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        children: [
          _corner(top: 0, left: 0, top4: true, left4: true),
          _corner(top: 0, right: 0, top4: true, right4: true),
          _corner(bottom: 0, left: 0, bottom4: true, left4: true),
          _corner(bottom: 0, right: 0, bottom4: true, right4: true),
          Center(
            child: Icon(
              Icons.qr_code_2,
              size: 60,
              color: AppTheme.darkColorScheme.onSurface.withValues(alpha: 0.24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _corner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool top4 = false,
    bool bottom4 = false,
    bool left4 = false,
    bool right4 = false,
  }) {
    const w = 4.0;
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          border: Border(
            top: top4 ? BorderSide(color: color, width: w) : BorderSide.none,
            bottom: bottom4
                ? BorderSide(color: color, width: w)
                : BorderSide.none,
            left: left4 ? BorderSide(color: color, width: w) : BorderSide.none,
            right: right4
                ? BorderSide(color: color, width: w)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for the printed alphanumeric fallback code. Pops the trimmed
/// code (or null on cancel).
class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet();

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.qrManualEntryTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l10n.qrManualEntryLabel),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: Text(l10n.qrManualEntrySubmit),
          ),
        ],
      ),
    );
  }
}
