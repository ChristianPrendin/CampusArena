import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/result/widgets/result_message_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: AppTheme.lightTheme, home: child);

  testWidgets('renders the icon, title, body and action', (tester) async {
    await tester.pumpWidget(
      wrap(
        ResultMessageView(
          icon: Icons.gavel,
          title: 'Result disputed',
          body: 'The other player disagreed with the score.',
          actionLabel: 'Back to dashboard',
          onAction: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.gavel), findsOneWidget);
    expect(find.text('Result disputed'), findsOneWidget);
    expect(
      find.text('The other player disagreed with the score.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Back to dashboard'),
      findsOneWidget,
    );
  });

  testWidgets('fires onAction when the button is tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        ResultMessageView(
          icon: Icons.error_outline,
          title: 'Something went wrong',
          body: 'Try again.',
          actionLabel: 'Retry',
          onAction: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('honours a custom icon colour', (tester) async {
    await tester.pumpWidget(
      wrap(
        ResultMessageView(
          icon: Icons.warning_amber,
          iconColor: Colors.red,
          title: 'Abandoned',
          body: 'No result was recorded.',
          actionLabel: 'OK',
          onAction: () {},
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byIcon(Icons.warning_amber));
    expect(icon.color, Colors.red);
  });
}
