/// LLM providers the Arena Assistant can call.
///
/// The app ships with one shared provider/key baked in at build time via
/// `--dart-define-from-file` (see [AssistantDefaults]) so that end users never
/// have to know what an API key is. The multi-provider machinery below is
/// retained because Assistant Settings still exists as a debug-only override —
/// a user who opens it can point the assistant at their own key.
///
/// Security note: a `--dart-define` value is compiled into the binary and is
/// therefore extractable from a shipped APK. The only way to truly protect the
/// key is a server-side proxy. Accepted trade-off for a course project;
/// rotate the shared key after grading.
enum AssistantProvider { anthropic, openai, openrouter, gemini, regolo }

extension AssistantProviderX on AssistantProvider {
  /// Stable string persisted in [AssistantSettingsRepository] and used as the
  /// dropdown value key.
  String get id {
    switch (this) {
      case AssistantProvider.anthropic:
        return 'anthropic';
      case AssistantProvider.openai:
        return 'openai';
      case AssistantProvider.openrouter:
        return 'openrouter';
      case AssistantProvider.gemini:
        return 'gemini';
      case AssistantProvider.regolo:
        return 'regolo';
    }
  }

  /// Display label for the settings dropdown.
  String get label {
    switch (this) {
      case AssistantProvider.anthropic:
        return 'Anthropic (Claude)';
      case AssistantProvider.openai:
        return 'OpenAI';
      case AssistantProvider.openrouter:
        return 'OpenRouter';
      case AssistantProvider.gemini:
        return 'Google Gemini';
      case AssistantProvider.regolo:
        return 'Regolo AI (EU)';
    }
  }

  /// Default model id offered when a provider is selected. The user may
  /// freely edit this in Assistant Settings — it is never locked.
  String get defaultModel {
    switch (this) {
      case AssistantProvider.anthropic:
        return 'claude-3-5-haiku-latest';
      case AssistantProvider.openai:
        return 'gpt-4o-mini';
      case AssistantProvider.openrouter:
        return 'meta-llama/llama-3.3-70b-instruct:free';
      case AssistantProvider.gemini:
        return 'gemini-1.5-flash';
      case AssistantProvider.regolo:
        return 'qwen3.5-122b';
    }
  }

  static AssistantProvider fromId(String id) {
    return AssistantProvider.values.firstWhere(
      (p) => p.id == id,
      orElse: () => AssistantProvider.gemini,
    );
  }
}
