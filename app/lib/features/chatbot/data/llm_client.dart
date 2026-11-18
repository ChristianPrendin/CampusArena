import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'assistant_provider.dart';
import 'assistant_settings_model.dart';

/// A single exchanged message in an LLM conversation.
class LlmMessage {
  final String role; // 'user' | 'assistant'
  final String content;

  const LlmMessage({required this.role, required this.content});
}

/// Outcome of [LlmClient.testConnection]: either a confirmed-working key, or
/// a human-readable reason it failed, so the settings screen can show
/// localized, actionable feedback instead of a raw exception.
class LlmConnectionTestResult {
  final bool success;
  final String? errorMessage;

  const LlmConnectionTestResult.success() : success = true, errorMessage = null;

  const LlmConnectionTestResult.failure(this.errorMessage) : success = false;
}

/// Thrown by [LlmClient.sendMessage] on any failure (network, HTTP error,
/// unexpected response shape). [ChatbotRepository] catches this and falls
/// back to the rule-based "limited mode" answer — it never lets an LLM
/// failure surface as an unhandled error to the UI.
class LlmException implements Exception {
  final String message;
  const LlmException(this.message);

  @override
  String toString() => 'LlmException: $message';
}

/// Thin HTTP client over the supported LLM providers' chat-completion APIs. Built on
/// `package:http` (already a dependency) rather than any provider SDK, so
/// swapping providers is just a different request/response shape, not a new
/// package. Every call uses a low temperature — the assistant should answer
/// from grounded tool data, not improvise.
class LlmClient {
  LlmClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  static const double _temperature = 0.2;

  /// 45s, not 20s: a large MoE model answering a tool-grounded prompt on a
  /// cold route can take well over 20 seconds. A too-tight timeout silently
  /// degrades every grounded answer to the rule-based fallback.
  static const Duration _timeout = Duration(seconds: 45);

  /// Must cover BOTH the answer and, on reasoning models, the hidden
  /// `reasoning_content` block that precedes it — `completion_tokens` counts
  /// them together. Qwen3.5-122b spends ~600-800 tokens reasoning about the
  /// Arena Assistant's ground rules before writing ~150 tokens of answer, so
  /// anything under ~1500 truncates the answer away entirely and returns
  /// empty content.
  static const int _maxTokens = 2048;

  /// Sends [systemPrompt] + [history] + the latest user turn to the
  /// configured provider/model and returns the assistant's reply text.
  /// Throws [LlmException] on any failure — callers must catch it.
  Future<String> sendMessage({
    required AssistantSettingsModel settings,
    required String systemPrompt,
    required List<LlmMessage> history,
  }) async {
    try {
      switch (settings.provider) {
        case AssistantProvider.openai:
          return await _sendOpenAiCompatible(
            baseUrl: 'https://api.openai.com/v1',
            settings: settings,
            systemPrompt: systemPrompt,
            history: history,
          );
        case AssistantProvider.openrouter:
          return await _sendOpenAiCompatible(
            baseUrl: 'https://openrouter.ai/api/v1',
            settings: settings,
            systemPrompt: systemPrompt,
            history: history,
          );
        case AssistantProvider.regolo:
          // Regolo (Seeweb, EU-hosted) serves /v1/chat/completions with the
          // exact OpenAI request/response schema and Bearer auth, so it needs
          // no transport of its own.
          //
          // Regolo's reasoning models (e.g. qwen3.5-122b) default to
          // `reasoning_effort: medium`, emitting a long hidden
          // `reasoning_content` block before the visible answer. Those tokens
          // count against `max_tokens`, so a tool-grounded prompt can spend
          // the whole budget reasoning and return empty content — which this
          // client reports as a failure and the UI shows as "couldn't reach
          // the assistant".
          //
          // `low` is the documented minimum (`none` does not exist; a
          // `thinking: false` field is silently ignored by the vLLM backend).
          // The Arena Assistant answers from grounded tool data — it has
          // little to reason about — so `low` costs nothing in quality and
          // buys headroom and latency.
          return await _sendOpenAiCompatible(
            baseUrl: 'https://api.regolo.ai/v1',
            settings: settings,
            systemPrompt: systemPrompt,
            history: history,
            extraBody: const {'reasoning_effort': 'low'},
          );
        case AssistantProvider.anthropic:
          return await _sendAnthropic(
            settings: settings,
            systemPrompt: systemPrompt,
            history: history,
          );
        case AssistantProvider.gemini:
          return await _sendGemini(
            settings: settings,
            systemPrompt: systemPrompt,
            history: history,
          );
      }
    } on LlmException {
      rethrow;
    } on TimeoutException {
      throw const LlmException('timeout');
    } on SocketException {
      throw const LlmException('network_error');
    } on HttpException {
      throw const LlmException('network_error');
    } catch (e) {
      throw LlmException('unexpected_error: $e');
    }
  }

  /// Fires a minimal ~1-token request against the configured provider/model
  /// and reports whether the key is valid, mapping common HTTP failures to
  /// short machine-readable reason codes the caller can localize.
  Future<LlmConnectionTestResult> testConnection(
    AssistantSettingsModel settings,
  ) async {
    if (!settings.hasApiKey) {
      return const LlmConnectionTestResult.failure('missing_api_key');
    }
    try {
      await sendMessage(
        settings: settings,
        systemPrompt: 'Reply with the single word: OK.',
        history: const [LlmMessage(role: 'user', content: 'Say OK.')],
      );
      return const LlmConnectionTestResult.success();
    } on LlmException catch (e) {
      return LlmConnectionTestResult.failure(e.message);
    } catch (e) {
      return LlmConnectionTestResult.failure('unexpected_error');
    }
  }

  String _mapHttpError(int statusCode) {
    switch (statusCode) {
      case 401:
      case 403:
        return 'invalid_api_key';
      case 429:
        return 'rate_limited';
      case 400:
        return 'bad_request';
      default:
        if (statusCode >= 500) return 'provider_unavailable';
        return 'http_error_$statusCode';
    }
  }

  /// OpenAI-compatible `/chat/completions` — used for OpenAI, OpenRouter and
  /// Regolo, which share the request/response schema.
  Future<String> _sendOpenAiCompatible({
    required String baseUrl,
    required AssistantSettingsModel settings,
    required String systemPrompt,
    required List<LlmMessage> history,
    Map<String, dynamic>? extraBody,
  }) async {
    final uri = Uri.parse('$baseUrl/chat/completions');
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...history.map((m) => {'role': m.role, 'content': m.content}),
    ];

    final response = await _httpClient
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${settings.apiKey}',
          },
          body: jsonEncode({
            'model': settings.model,
            'messages': messages,
            'temperature': _temperature,
            'max_tokens': _maxTokens,
            // Provider-specific extras (e.g. Regolo's `thinking`). Kept out of
            // the shared body so OpenAI/OpenRouter never see a param they'd
            // reject with a 400.
            ...?extraBody,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw LlmException(_mapHttpError(response.statusCode));
    }

    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>?;
    String? content;
    if (choices != null && choices.isNotEmpty) {
      final message =
          (choices.first as Map<String, dynamic>)['message']
              as Map<String, dynamic>?;
      content = message?['content'] as String?;
    }
    // An empty string is as useless as null: a reasoning model that spends its
    // whole token budget on `reasoning_content` returns `content: ""`. Treat
    // it as a failure so the caller falls back rather than showing a blank
    // bubble.
    if (content == null || content.trim().isEmpty) {
      throw const LlmException('unexpected_response');
    }
    return content.trim();
  }

  /// Anthropic Messages API — `x-api-key` + `anthropic-version` headers,
  /// system prompt is a top-level field rather than a message.
  Future<String> _sendAnthropic({
    required AssistantSettingsModel settings,
    required String systemPrompt,
    required List<LlmMessage> history,
  }) async {
    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    final messages = history
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    final response = await _httpClient
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': settings.apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': settings.model,
            'system': systemPrompt,
            'messages': messages,
            'temperature': _temperature,
            'max_tokens': _maxTokens,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw LlmException(_mapHttpError(response.statusCode));
    }

    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content = decoded['content'] as List<dynamic>?;
    final text = content != null && content.isNotEmpty
        ? (content.first as Map<String, dynamic>)['text'] as String?
        : null;
    if (text == null) {
      throw const LlmException('unexpected_response');
    }
    return text.trim();
  }

  /// Gemini `generateContent` — API key passed as a query param, no system
  /// role, so the system prompt is prepended as the first user turn's
  /// context via `systemInstruction`.
  Future<String> _sendGemini({
    required AssistantSettingsModel settings,
    required String systemPrompt,
    required List<LlmMessage> history,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '${settings.model}:generateContent?key=${settings.apiKey}',
    );

    final contents = history
        .map(
          (m) => {
            'role': m.role == 'assistant' ? 'model' : 'user',
            'parts': [
              {'text': m.content},
            ],
          },
        )
        .toList();

    final response = await _httpClient
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': systemPrompt},
              ],
            },
            'contents': contents,
            'generationConfig': {
              'temperature': _temperature,
              'maxOutputTokens': _maxTokens,
            },
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw LlmException(_mapHttpError(response.statusCode));
    }

    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    String? text;
    if (candidates != null && candidates.isNotEmpty) {
      final candidateContent =
          (candidates.first as Map<String, dynamic>)['content']
              as Map<String, dynamic>?;
      final parts = candidateContent?['parts'] as List<dynamic>?;
      if (parts != null && parts.isNotEmpty) {
        text = (parts.first as Map<String, dynamic>)['text'] as String?;
      }
    }
    if (text == null) {
      throw const LlmException('unexpected_response');
    }
    return text.trim();
  }
}
