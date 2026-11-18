import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:campus_arena/l10n/app_localizations.dart';
import 'onboarding_cubit.dart';

/// A single walkthrough slide.
class TutorialSlide {
  final IconData icon;
  final String title;
  final String body;

  /// Optional muted caption shown below [body] — used by the map/queue slide
  /// to carry the availability disclaimer business rule.
  final String? disclaimer;

  const TutorialSlide({
    required this.icon,
    required this.title,
    required this.body,
    this.disclaimer,
  });
}

/// Reusable, self-contained walkthrough. Hosted by the onboarding route now and
/// re-hostable from Settings later (Phase 5) — it owns no onboarding logic, it
/// just calls [onFinish] when the user skips or reaches the end.
class MiniTutorialView extends StatefulWidget {
  const MiniTutorialView({super.key, required this.onFinish});

  final VoidCallback onFinish;

  @override
  State<MiniTutorialView> createState() => _MiniTutorialViewState();
}

class _MiniTutorialViewState extends State<MiniTutorialView> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<TutorialSlide> _slides(AppLocalizations l10n) => [
    TutorialSlide(
      icon: Icons.qr_code_scanner,
      title: l10n.tutorialSlide1Title,
      body: l10n.tutorialSlide1Body,
    ),
    TutorialSlide(
      icon: Icons.leaderboard,
      title: l10n.tutorialSlide2Title,
      body: l10n.tutorialSlide2Body,
    ),
    TutorialSlide(
      icon: Icons.groups,
      title: l10n.tutorialSlide3Title,
      body: l10n.tutorialSlide3Body,
      disclaimer: l10n.tutorialSlide3Disclaimer,
    ),
  ];

  void _next(int lastIndex) {
    if (_page >= lastIndex) {
      widget.onFinish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final slides = _slides(l10n);
    final lastIndex = slides.length - 1;
    final isLast = _page == lastIndex;

    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: widget.onFinish,
              child: Text(l10n.tutorialSkip),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: slides.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) {
                final slide = slides[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Icon(
                          slide.icon,
                          size: 72,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        slide.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        slide.body,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (slide.disclaimer != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          slide.disclaimer!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _page ? 20 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i == _page
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _next(lastIndex),
                child: Text(isLast ? l10n.tutorialDone : l10n.tutorialNext),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onboarding route wrapper: finishing the walkthrough completes onboarding.
class MiniTutorialScreen extends StatelessWidget {
  const MiniTutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MiniTutorialView(
        onFinish: () => context.read<OnboardingCubit>().completeOnboarding(),
      ),
    );
  }
}
