import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:sentry/sentry.dart';

import 'diagnostics.dart';

/// Uses Sentry's envelope encoder without initializing automatic SDK channels.
/// Only DiagnosticEvent can enter this transport; there is no native SDK,
/// global scope, session, attachment, replay, log or raw exception submission.
final class SentryDiagnosticSink implements DiagnosticSink {
  SentryDiagnosticSink(String dsn, {http.Client? client})
    : _client = client ?? http.Client(),
      _options = SentryOptions(dsn: dsn),
      _dsn = Dsn.parse(dsn) {
    final uri = Uri.parse(dsn);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isEmpty ||
        uri.userInfo.contains(':') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid public diagnostic endpoint');
    }
    _options.sendDefaultPii = false;
    _options.sendClientReports = false;
    _options.debug = false;
  }

  final http.Client _client;
  final SentryOptions _options;
  final Dsn _dsn;
  bool _closed = false;

  @override
  Future<void> submit(DiagnosticEvent event) async {
    if (_closed) throw StateError('Diagnostic transport closed');
    final envelope = SentryEnvelope.fromEvent(
      SentryEvent.fromJson(event.toJson()),
      SdkVersion(name: 'squadly.diagnostics', version: '1.0.0'),
    );
    final bytes = await envelope
        .envelopeStream(_options)
        .fold<List<int>>([], (buffer, part) => buffer..addAll(part));
    if (_closed) throw StateError('Diagnostic transport closed');
    final request = http.Request('POST', _dsn.postUri)
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/x-sentry-envelope'
      ..headers['X-Sentry-Auth'] =
          'Sentry sentry_version=7, sentry_client=squadly.diagnostics/1.0.0, sentry_key=${_dsn.publicKey}'
      ..bodyBytes = bytes;
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 10));
    await response.stream.drain<void>().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('Diagnostic submission failed');
    }
  }

  void close() {
    _closed = true;
    _client.close();
  }
}
