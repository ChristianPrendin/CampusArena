import 'package:bloc_test/bloc_test.dart';
import 'package:campus_arena/core/theme/app_theme.dart';
import 'package:campus_arena/features/result/cubit/result_cubit.dart';
import 'package:campus_arena/features/result/cubit/result_state.dart';
import 'package:campus_arena/features/result/result_flow_page.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:campus_arena/routing/route_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockResultCubit extends MockCubit<ResultState> implements ResultCubit {}

void main() {
  late MockResultCubit cubit;

  setUp(() {
    cubit = MockResultCubit();
    when(() => cubit.retry()).thenReturn(null);
  });

  void seed(ResultState state) {
    when(() => cubit.state).thenReturn(state);
    whenListen(cubit, const Stream<ResultState>.empty(), initialState: state);
  }

  Widget wrap() {
    final router = GoRouter(
      initialLocation: '/result',
      routes: [
        GoRoute(
          path: '/result',
          builder: (_, _) => BlocProvider<ResultCubit>.value(
            value: cubit,
            child: const ResultFlowView(),
          ),
        ),
        GoRoute(
          path: RouteConstants.home,
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }

  testWidgets('loading shows a spinner', (tester) async {
    seed(const ResultState());
    await tester.pumpWidget(wrap());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('closed(unconfirmed) shows the timeout message', (tester) async {
    seed(
      const ResultState(
        phase: ResultPhase.closed,
        closedKind: ResultClosedKind.unconfirmed,
      ),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('Not confirmed in time'), findsOneWidget);
  });

  testWidgets('closed(abandoned) shows the abandoned message', (tester) async {
    seed(
      const ResultState(
        phase: ResultPhase.closed,
        closedKind: ResultClosedKind.abandoned,
      ),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('Match abandoned'), findsOneWidget);
  });

  testWidgets('closed(disputed) shows the disputed message and Close routes '
      'home', (tester) async {
    seed(
      const ResultState(
        phase: ResultPhase.closed,
        closedKind: ResultClosedKind.disputed,
      ),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Result disputed'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('error shows the retry action and re-triggers the cubit', (
    tester,
  ) async {
    seed(const ResultState(phase: ResultPhase.error));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    verify(() => cubit.retry()).called(1);
  });
}
