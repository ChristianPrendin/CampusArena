import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/features/match/cubit/match_cubit.dart';
import 'package:campus_arena/features/match/cubit/match_state.dart';
import 'package:campus_arena/features/match/qr_scan_screen.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMatchCubit extends MockCubit<MatchState> implements MatchCubit {}

void main() {
  late MockMatchCubit cubit;

  setUp(() {
    cubit = MockMatchCubit();
    when(() => cubit.uid).thenReturn('me');
  });

  Widget wrap({bool isDeepLink = false, Locale locale = const Locale('en')}) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<MatchCubit>.value(
          value: cubit,
          child: QrScanView(isDeepLink: isDeepLink, enableCamera: false),
        ),
      );

  testWidgets('renders the scan prompt and manual-entry fallback when idle', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(const MatchState());

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.text('Scan table QR'), findsOneWidget);
    expect(find.text('Enter code manually'), findsOneWidget);
  });

  testWidgets('renders the scan prompt in Italian', (tester) async {
    when(() => cubit.state).thenReturn(const MatchState());

    await tester.pumpWidget(wrap(locale: const Locale('it')));
    await tester.pump();

    expect(find.text('Inquadra il QR del tavolo'), findsOneWidget);
    expect(find.text('Inserisci il codice manualmente'), findsOneWidget);
  });

  testWidgets('the manual-entry sheet submits the typed code to the cubit', (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(const MatchState());
    when(() => cubit.submitCode(any())).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.text('Enter code manually'));
    await tester.pumpAndSettle();

    // The sheet is open with its own title + field.
    expect(find.text('Enter table code'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'bl27a');
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();

    verify(() => cubit.submitCode('bl27a')).called(1);
  });

  testWidgets('an empty manual code is ignored', (tester) async {
    when(() => cubit.state).thenReturn(const MatchState());
    when(() => cubit.submitCode(any())).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.text('Enter code manually'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
    await tester.pumpAndSettle();

    verifyNever(() => cubit.submitCode(any()));
  });

  testWidgets('a resolving state overlays a progress spinner', (tester) async {
    when(
      () => cubit.state,
    ).thenReturn(const MatchState(status: MatchStatus.resolving));

    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
