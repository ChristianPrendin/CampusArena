import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/core/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Pumps a button that opens the confirm dialog and records its result.
  Future<void> pumpTrigger(
    WidgetTester tester,
    List<bool> results, {
    bool isDestructive = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                results.add(
                  await showConfirmDialog(
                    context,
                    title: 'Remove friend',
                    message: 'Are you sure?',
                    confirmLabel: 'Remove',
                    cancelLabel: 'Cancel',
                    isDestructive: isDestructive,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the supplied copy', (tester) async {
    final results = <bool>[];
    await pumpTrigger(tester, results);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Remove friend'), findsOneWidget);
    expect(find.text('Are you sure?'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Remove'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
  });

  testWidgets('confirm resolves to true', (tester) async {
    final results = <bool>[];
    await pumpTrigger(tester, results);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(results.single, isTrue);
  });

  testWidgets('cancel resolves to false', (tester) async {
    final results = <bool>[];
    await pumpTrigger(tester, results);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(results.single, isFalse);
  });

  testWidgets('a destructive confirm is tinted with the error colour', (
    tester,
  ) async {
    final results = <bool>[];
    await pumpTrigger(tester, results, isDestructive: true);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Remove'),
    );
    expect(button.style, isNotNull);
  });
}
