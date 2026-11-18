import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:campus_arena/l10n/app_localizations.dart';
import '../../core/degree_programs.dart';
import '../../routing/route_constants.dart';
import 'auth_error_localizer.dart';
import 'auth_validators.dart';
import 'cubit/auth_cubit.dart';
import 'cubit/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _degreeProgram;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit({required bool recovering}) {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final cubit = context.read<AuthCubit>();
    // Recovery mode: the account already exists in Auth, only its profile doc is
    // missing — recreate it for the current uid (no signUp, no email/password).
    if (recovering) {
      cubit.provisionProfile(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        degreeProgram: _degreeProgram!,
      );
      return;
    }
    cubit.register(
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      degreeProgram: _degreeProgram!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = context.watch<AuthCubit>().state;
    // Authenticated-but-profile-missing sessions land here to recreate their
    // profile; the email/password fields and the "log in" link are hidden.
    // Excludes the mid-registration window: watchUser transiently emits null
    // (profileMissing: true) for the ~1s gap between signUp succeeding and the
    // user-doc write landing, which would otherwise flash this recovery UI
    // over the normal signup form.
    final recovering =
        authState.profileMissing && !authState.registrationInProgress;
    return Scaffold(
      appBar: AppBar(
        title: Text(recovering ? l10n.completeProfileTitle : l10n.register),
      ),
      body: BlocListener<AuthCubit, AuthState>(
        listenWhen: (previous, current) => current.status == AuthStatus.error,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(localizeAuthError(l10n, state.errorCode))),
            );
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (recovering) ...[
                      Text(
                        l10n.completeProfileMessage,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: InputDecoration(labelText: l10n.nameLabel),
                      validator: (value) =>
                          AuthValidators.required(l10n, value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      // Usernames are lowercase-only: auto-lowercase typed input
                      // so mixed case never trips the validator.
                      inputFormatters: [
                        TextInputFormatter.withFunction(
                          (oldValue, newValue) => newValue.copyWith(
                            text: newValue.text.toLowerCase(),
                          ),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.usernameLabel,
                      ),
                      validator: (value) =>
                          AuthValidators.username(l10n, value),
                    ),
                    // Email/password only create the Auth account; in recovery
                    // mode it already exists, so these are hidden.
                    if (!recovering) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(labelText: l10n.emailLabel),
                        validator: (value) => AuthValidators.email(l10n, value),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: l10n.passwordLabel,
                        ),
                        validator: (value) =>
                            AuthValidators.password(l10n, value),
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _degreeProgram,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.degreeProgramLabel,
                        hintText: l10n.degreeProgramHint,
                      ),
                      items: [
                        for (final program in kDegreePrograms)
                          DropdownMenuItem<String>(
                            value: program,
                            child: Text(localizeDegreeProgram(l10n, program)),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _degreeProgram = value),
                      validator: (value) =>
                          AuthValidators.required(l10n, value),
                    ),
                    const SizedBox(height: 24),
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        // Firebase's authStateChanges stream fires as soon as the
                        // account is created — before rating-seeding and the user
                        // doc write finish — flipping `status` to `authenticated`
                        // mid-registration. Keep the spinner up for the whole
                        // `registrationInProgress` window too, or the button
                        // reverts to idle (and re-clickable) during that gap.
                        final loading =
                            state.status == AuthStatus.loading ||
                            state.registrationInProgress;
                        return FilledButton(
                          onPressed: loading
                              ? null
                              : () => _submit(recovering: recovering),
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  recovering
                                      ? l10n.completeProfileButton
                                      : l10n.createAccount,
                                ),
                        );
                      },
                    ),
                    // The "already have an account? log in" link is meaningless
                    // in recovery mode — the session is already signed in.
                    if (!recovering) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        // Declarative navigation, matching LandingScreen: the auth
                        // screens are switched by the router redirect, never pushed.
                        onPressed: () => context.go(RouteConstants.login),
                        child: Text.rich(
                          TextSpan(
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            children: [
                              TextSpan(
                                text: '${l10n.haveAccountPromptPrefix} ',
                              ),
                              TextSpan(
                                text: l10n.logIn,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
