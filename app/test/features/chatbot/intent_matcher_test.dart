import 'package:campus_arena/features/chatbot/data/intent_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const matcher = RuleBasedIntentMatcher();

  group('emptyTables', () {
    for (final phrase in [
      'What tables are empty?',
      'which tables are free right now',
      'Any available tables?',
      'Quali tavoli sono liberi?',
      'tavoli vuoti in questo momento',
    ]) {
      test('classifies "$phrase"', () {
        expect(matcher.classify(phrase), ChatIntent.emptyTables);
      });
    }
  });

  group('tournamentsToday', () {
    for (final phrase in [
      'Tournaments today',
      'Are there any tournaments?',
      'Tornei di oggi',
      'quando sono i prossimi tornei',
    ]) {
      test('classifies "$phrase"', () {
        expect(matcher.classify(phrase), ChatIntent.tournamentsToday);
      });
    }
  });

  group('eloExplainer', () {
    for (final phrase in [
      'How does ELO work?',
      'What is my rank?',
      "what's my rating",
      'Come funziona la classifica?',
    ]) {
      test('classifies "$phrase"', () {
        expect(matcher.classify(phrase), ChatIntent.eloExplainer);
      });
    }
  });

  group('queuePosition', () {
    for (final phrase in [
      'Where am I in the queue?',
      'What is my position in line?',
      'Dove sono in coda?',
    ]) {
      test('classifies "$phrase"', () {
        expect(matcher.classify(phrase), ChatIntent.queuePosition);
      });
    }
  });

  group('general fallback', () {
    for (final phrase in [
      'Hello!',
      'What is CampusArena?',
      'Can I book a table for tomorrow?',
    ]) {
      test('classifies "$phrase"', () {
        expect(matcher.classify(phrase), ChatIntent.general);
      });
    }
  });

  test('classification is case-insensitive', () {
    expect(matcher.classify('WHAT TABLES ARE EMPTY'), ChatIntent.emptyTables);
  });
}
