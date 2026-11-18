import 'package:campus_arena/features/auth/auth_validators.dart';
import 'package:campus_arena/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('AuthValidators.username', () {
    test('accepts 3–20 lowercase letters, digits and underscores', () {
      expect(AuthValidators.username(l10n, 'abc_1'), isNull);
      expect(AuthValidators.username(l10n, 'a1'.padRight(20, 'x')), isNull);
      expect(AuthValidators.username(l10n, '  ada  '), isNull); // trimmed
    });

    test('rejects empty as a required field', () {
      expect(AuthValidators.username(l10n, ''), l10n.fieldRequired);
      expect(AuthValidators.username(l10n, '   '), l10n.fieldRequired);
      expect(AuthValidators.username(l10n, null), l10n.fieldRequired);
    });

    test('rejects bad length and illegal characters', () {
      expect(AuthValidators.username(l10n, 'ab'), l10n.invalidUsername);
      expect(
        AuthValidators.username(l10n, 'a'.padRight(21, 'a')),
        l10n.invalidUsername,
      );
      expect(AuthValidators.username(l10n, 'me me'), l10n.invalidUsername);
      expect(AuthValidators.username(l10n, 'olé!'), l10n.invalidUsername);
      expect(AuthValidators.username(l10n, 'a.b'), l10n.invalidUsername);
      // Uppercase is rejected: usernames are lowercase-only.
      expect(AuthValidators.username(l10n, 'Bob'), l10n.invalidUsername);
    });
  });
}
