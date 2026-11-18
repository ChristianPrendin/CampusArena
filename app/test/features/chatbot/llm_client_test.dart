import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:campus_arena/features/chatbot/data/assistant_provider.dart';
import 'package:campus_arena/features/chatbot/data/assistant_settings_model.dart';
import 'package:campus_arena/features/chatbot/data/llm_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

AssistantSettingsModel settingsFor(
  AssistantProvider provider, {
  String apiKey = 'sk-key',
}) => AssistantSettingsModel(
  provider: provider,
  apiKey: apiKey,
  model: provider.defaultModel,
);

/// An [LlmClient] whose transport is a [MockClient] running [handler].
LlmClient clientWith(
  Future<http.Response> Function(http.Request request) handler,
) => LlmClient(httpClient: MockClient(handler));

const _systemPrompt = 'system';
const _history = [LlmMessage(role: 'user', content: 'hi')];

Future<String> send(LlmClient client, AssistantSettingsModel settings) =>
    client.sendMessage(
      settings: settings,
      systemPrompt: _systemPrompt,
      history: _history,
    );

void main() {
  group('sendMessage — OpenAI-compatible providers', () {
    http.Response okBody(String content) => http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': content},
          },
        ],
      }),
      200,
    );

    test('OpenAI returns the message content and uses Bearer auth', () async {
      late http.Request captured;
      final client = clientWith((req) async {
        captured = req;
        return okBody('  Hello there  ');
      });

      final reply = await send(client, settingsFor(AssistantProvider.openai));

      expect(reply, 'Hello there'); // trimmed
      expect(captured.url.host, 'api.openai.com');
      expect(captured.headers['Authorization'], 'Bearer sk-key');
    });

    test('OpenRouter hits its own base URL', () async {
      late Uri url;
      final client = clientWith((req) async {
        url = req.url;
        return okBody('ok');
      });
      await send(client, settingsFor(AssistantProvider.openrouter));
      expect(url.host, 'openrouter.ai');
    });

    test('Regolo injects reasoning_effort: low into the body', () async {
      late Map<String, dynamic> body;
      final client = clientWith((req) async {
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return okBody('ok');
      });
      await send(client, settingsFor(AssistantProvider.regolo));
      expect(body['reasoning_effort'], 'low');
      expect(body['temperature'], isNotNull);
    });

    test('empty content is treated as a failure', () async {
      final client = clientWith((_) async => okBody('   '));
      await expectLater(
        send(client, settingsFor(AssistantProvider.openai)),
        throwsA(
          isA<LlmException>().having(
            (e) => e.message,
            'message',
            'unexpected_response',
          ),
        ),
      );
    });
  });

  group('sendMessage — Anthropic', () {
    test('returns content[0].text and sends x-api-key', () async {
      late http.Request captured;
      final client = clientWith((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'content': [
              {'text': 'Claude says hi'},
            ],
          }),
          200,
        );
      });

      final reply = await send(
        client,
        settingsFor(AssistantProvider.anthropic),
      );

      expect(reply, 'Claude says hi');
      expect(captured.url.host, 'api.anthropic.com');
      expect(captured.headers['x-api-key'], 'sk-key');
      expect(captured.headers['anthropic-version'], '2023-06-01');
      // System prompt is a top-level field, not a message.
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['system'], _systemPrompt);
    });
  });

  group('sendMessage — Gemini', () {
    test('returns the first candidate part and passes key as query', () async {
      late Uri url;
      final client = clientWith((req) async {
        url = req.url;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Gemini hi'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final reply = await send(client, settingsFor(AssistantProvider.gemini));

      expect(reply, 'Gemini hi');
      expect(url.host, 'generativelanguage.googleapis.com');
      expect(url.queryParameters['key'], 'sk-key');
    });
  });

  group('HTTP error mapping', () {
    Future<void> expectMapped(int status, String reason) async {
      final client = clientWith((_) async => http.Response('nope', status));
      await expectLater(
        send(client, settingsFor(AssistantProvider.openai)),
        throwsA(
          isA<LlmException>().having((e) => e.message, 'message', reason),
        ),
      );
    }

    test('401 -> invalid_api_key', () => expectMapped(401, 'invalid_api_key'));
    test('403 -> invalid_api_key', () => expectMapped(403, 'invalid_api_key'));
    test('429 -> rate_limited', () => expectMapped(429, 'rate_limited'));
    test('400 -> bad_request', () => expectMapped(400, 'bad_request'));
    test(
      '500 -> provider_unavailable',
      () => expectMapped(500, 'provider_unavailable'),
    );
    test('418 -> http_error_418', () => expectMapped(418, 'http_error_418'));
  });

  group('transport failures map to reason codes', () {
    Future<void> expectReason(Object thrown, String reason) async {
      final client = clientWith((_) async => throw thrown);
      await expectLater(
        send(client, settingsFor(AssistantProvider.openai)),
        throwsA(
          isA<LlmException>().having((e) => e.message, 'message', reason),
        ),
      );
    }

    test(
      'TimeoutException -> timeout',
      () => expectReason(TimeoutException('slow'), 'timeout'),
    );
    test(
      'SocketException -> network_error',
      () => expectReason(const SocketException('down'), 'network_error'),
    );
    test('generic error -> unexpected_error', () async {
      final client = clientWith((_) async => throw StateError('boom'));
      await expectLater(
        send(client, settingsFor(AssistantProvider.openai)),
        throwsA(
          isA<LlmException>().having(
            (e) => e.message,
            'message',
            startsWith('unexpected_error'),
          ),
        ),
      );
    });
  });

  group('testConnection', () {
    test('reports missing_api_key without any request', () async {
      var called = false;
      final client = clientWith((_) async {
        called = true;
        return http.Response('', 200);
      });
      final result = await client.testConnection(
        settingsFor(AssistantProvider.openai, apiKey: ''),
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, 'missing_api_key');
      expect(called, isFalse);
    });

    test('reports success on a valid key', () async {
      final client = clientWith(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'OK'},
              },
            ],
          }),
          200,
        ),
      );
      final result = await client.testConnection(
        settingsFor(AssistantProvider.openai),
      );
      expect(result.success, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('maps an auth failure to its reason code', () async {
      final client = clientWith((_) async => http.Response('no', 401));
      final result = await client.testConnection(
        settingsFor(AssistantProvider.openai),
      );
      expect(result.success, isFalse);
      expect(result.errorMessage, 'invalid_api_key');
    });
  });
}
