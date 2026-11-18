import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/chatbot/widgets/typing_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders three animating dots and drives its animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: TypingIndicator())),
      ),
    );

    // Three dots.
    expect(find.byType(Container), findsNWidgets(3));
    // The repeating controller keeps rebuilding; advance it without settling
    // (pumpAndSettle would never terminate on an infinite animation).
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TypingIndicator), findsOneWidget);
  });

  testWidgets('disposes its controller without leaks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: TypingIndicator()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Replacing the tree disposes the State; a leaked controller would throw.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    expect(find.byType(TypingIndicator), findsNothing);
  });
}
