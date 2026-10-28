import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:squadly/core/diagnostics/diagnostics.dart';
import 'package:squadly/core/diagnostics/sentry_diagnostic_sink.dart';

void main() {
  final event =
      DiagnosticSanitizer(
        version: '0.1.0+1',
        environment: DiagnosticEnvironment.staging,
        allowedSources: {'package:squadly/main.dart'},
      ).sanitize(
        StateError('private-message health=70 token=secret@example.com'),
        StackTrace.fromString(
          '#0 secret@example.com (package:squadly/main.dart:12:3)',
        ),
      );
  test('Sentry envelope contains only the approved diagnostic event', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://sentry.example/api/42/envelope/');
      expect(request.followRedirects, isFalse);
      final body = utf8.decode(request.bodyBytes);
      final lines = body.trim().split('\n');
      expect(lines, hasLength(3));
      expect(jsonDecode(lines[1])['type'], 'event');
      final payload = jsonDecode(lines[2]) as Map;
      expect(payload.keys.toSet(), event.toJson().keys.toSet());
      expect(payload['exception']['values'][0]['value'], '[content omitted]');
      for (final forbidden in [
        'private-message',
        'health=70',
        'secret@example.com',
        'breadcrumbs',
        'user',
        'contexts',
        'attachments',
        'request',
        'transaction',
        'replay',
      ]) {
        expect(body, isNot(contains('"$forbidden"')));
        expect(body, isNot(contains('private-message')));
        expect(body, isNot(contains('secret@example.com')));
      }
      return http.Response('{}', 200);
    });
    final sink = SentryDiagnosticSink(
      'https://publickey@sentry.example/42',
      client: client,
    );
    addTearDown(sink.close);
    await sink.submit(event);
  });
  test(
    'non-success responses and closed sinks fail without backend content',
    () async {
      final sink = SentryDiagnosticSink(
        'https://publickey@sentry.example/42',
        client: MockClient(
          (_) async => http.Response('private backend response', 403),
        ),
      );
      await expectLater(sink.submit(event), throwsStateError);
      sink.close();
      await expectLater(sink.submit(event), throwsStateError);
    },
  );
  test('only public HTTPS endpoints are accepted', () {
    for (final dsn in [
      'http://publickey@sentry.example/42',
      'https://key:secret@sentry.example/42',
      'https://publickey@sentry.example/42?secret=1',
    ]) {
      expect(() => SentryDiagnosticSink(dsn), throwsFormatException);
    }
  });
}
