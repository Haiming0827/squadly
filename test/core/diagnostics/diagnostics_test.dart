import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:squadly/core/diagnostics/diagnostics.dart';

const _source = 'package:squadly/app/router.dart';
const _sensitive =
    'alice@example.test health=72.4 finance=9534.27 route_cipher=secret eySecretToken';
final _stack = StackTrace.fromString('#0 run ($_source:12:3)');

DiagnosticSanitizer _sanitizer({
  Set<String>? sources,
  DateTime Function()? clock,
}) => DiagnosticSanitizer(
  version: '0.1.0+1',
  environment: DiagnosticEnvironment.staging,
  allowedSources: sources ?? {_source},
  clock: clock ?? () => DateTime.utc(2026, 10, 20),
);

void main() {
  test('rebuilds only approved categories and source locations without private text', () {
    final event = _sanitizer().sanitize(
      const FormatException(_sensitive, {'body': _sensitive}),
      StackTrace.fromString('''
#0 $_sensitive ($_source:12:3)
#1 run (file:///Users/alice/$_sensitive.dart:2:1)
#2 run (package:squadly/private/secret.dart:22:3)
#3 run (https://example.test/$_sensitive:1:1)
#4 run ($_source?token=eySecretToken:1:1)
<asynchronous suspension>
'''),
    );
    expect(event.kind, DiagnosticErrorKind.format);
    expect(event.frames, hasLength(1));
    expect(event.frames.single.source, _source);
    expect(event.frames.single.line, 12);
    expect(event.frames.single.column, 3);
    final json = event.toJson();
    expect(json.keys.toSet(), {
      'event_id',
      'timestamp',
      'platform',
      'level',
      'release',
      'environment',
      'exception',
    });
    final encoded = jsonEncode(json);
    for (final value in [
      'alice@example.test',
      'health=72.4',
      'finance=9534.27',
      'route_cipher',
      'eySecretToken',
      '/Users/alice',
      'https://',
      'private/secret.dart',
    ]) {
      expect(encoded, isNot(contains(value)));
    }
    expect(event.id, matches(RegExp(r'^[a-f0-9]{32}$')));
  });

  test('never reads exception text or a dynamic exception class name', () {
    final event = _sanitizer().sanitize(_UnsafeException(), _stack);
    expect(event.kind, DiagnosticErrorKind.unknown);
    expect(jsonEncode(event.toJson()), isNot(contains('_UnsafeException')));
  });

  test('malformed stack traces cannot break diagnostic handling', () {
    final event = _sanitizer().sanitize(StateError(_sensitive), _UnsafeStack());
    expect(event.kind, DiagnosticErrorKind.state);
    expect(event.frames, isEmpty);
  });

  test(
    'source catalog and queued events cannot be mutated through callers',
    () {
      final sources = {_source};
      final sanitizer = _sanitizer(sources: sources);
      sources.add('package:squadly/secret.dart');
      final event = sanitizer.sanitize(
        StateError(_sensitive),
        StackTrace.fromString(
          '#0 a (package:squadly/secret.dart:1:1)\n#1 b ($_source:2:1)',
        ),
      );
      expect(event.frames, hasLength(1));
      final firstJson = event.toJson();
      (firstJson['exception']! as Map)['values'] = <Map<String, Object>>[
        {'value': _sensitive},
      ];
      firstJson['user'] = _sensitive;
      expect(jsonEncode(event.toJson()), isNot(contains(_sensitive)));
      expect(() => event.frames.clear(), throwsUnsupportedError);
    },
  );

  test('limits source frames and rejects invalid positions', () {
    final stack = StackTrace.fromString(
      '#0 bad ($_source:0:1)\n#1 bad ($_source:1:0)\n#2 bad ($_source:1:10001)\n${List.generate(40, (i) => '#${i + 3} fn ($_source:${i + 1}:2)').join('\n')}',
    );
    final event = _sanitizer().sanitize(StateError(_sensitive), stack);
    expect(event.frames, hasLength(20));
    expect(event.frames.first.line, 1);
    expect(event.frames.last.line, 20);
  });

  test(
    'configuration refuses private release strings and external source paths',
    () {
      expect(
        () => DiagnosticSanitizer(
          version: 'alice@example.test',
          environment: DiagnosticEnvironment.production,
          allowedSources: {_source},
        ),
        throwsArgumentError,
      );
      for (final source in [
        'file:///Users/alice/app.dart',
        'package:squadly/../secret.dart',
        'package:squadly/app/router.dart?token=secret',
      ]) {
        expect(() => _sanitizer(sources: {source}), throwsArgumentError);
      }
    },
  );

  test(
    'master switch and consent remain independent and default closed',
    () async {
      final sink = _RecordingSink();
      final reporter = DiagnosticReporter(
        sanitizer: _sanitizer(),
        sink: sink,
        sampleRate: 1,
      );
      expect(
        await reporter.capture(_UnsafeException(), _UnsafeStack()),
        DiagnosticCaptureResult.disabled,
      );
      reporter.setConsent(true);
      expect(
        await reporter.capture(StateError(_sensitive), _stack),
        DiagnosticCaptureResult.disabled,
      );
      reporter.setEnabled(true);
      reporter.setConsent(false);
      expect(
        await reporter.capture(StateError(_sensitive), _stack),
        DiagnosticCaptureResult.disabled,
      );
      expect(sink.events, isEmpty);
    },
  );

  test(
    'sampling defaults to zero even when both switches are enabled',
    () async {
      final sink = _RecordingSink();
      final reporter = DiagnosticReporter(
        sanitizer: _sanitizer(),
        sink: sink,
        enabled: true,
      )..setConsent(true);
      expect(
        await reporter.capture(StateError(_sensitive), _stack),
        DiagnosticCaptureResult.disabled,
      );
      expect(sink.events, isEmpty);
    },
  );

  test(
    'sampling boundary deterministically excludes unselected events',
    () async {
      final sink = _RecordingSink();
      final draws = [0.2, 0.1, 0.099].iterator;
      final reporter = DiagnosticReporter(
        sanitizer: _sanitizer(),
        sink: sink,
        enabled: true,
        sampleRate: 0.1,
        random: () {
          draws.moveNext();
          return draws.current;
        },
      )..setConsent(true);
      expect(
        await reporter.capture(StateError(_sensitive), _stack),
        DiagnosticCaptureResult.sampledOut,
      );
      expect(
        await reporter.capture(StateError(_sensitive), _stack),
        DiagnosticCaptureResult.sampledOut,
      );
      expect(
        await reporter.capture(StateError(_sensitive), _stack),
        DiagnosticCaptureResult.submitted,
      );
      expect(sink.events, hasLength(1));
    },
  );

  for (final revoke in ['master', 'consent']) {
    test(
      '$revoke revocation cancels the old bounded queue after re-enable',
      () async {
        final sink = _RecordingSink();
        final entered = Completer<void>();
        final release = Completer<void>();
        sink.onSubmit = (_) async {
          if (sink.events.length == 1) {
            entered.complete();
            await release.future;
          }
        };
        final reporter = DiagnosticReporter(
          sanitizer: _sanitizer(),
          sink: sink,
          enabled: true,
          sampleRate: 1,
          maxPending: 2,
        )..setConsent(true);
        final first = reporter.capture(StateError(_sensitive), _stack);
        await entered.future;
        final queued = reporter.capture(StateError(_sensitive), _stack);
        expect(
          await reporter.capture(StateError(_sensitive), _stack),
          DiagnosticCaptureResult.queueFull,
        );
        if (revoke == 'master') {
          reporter.setEnabled(false);
          reporter.setEnabled(true);
        } else {
          reporter.setConsent(false);
          reporter.setConsent(true);
        }
        release.complete();
        expect(await first, DiagnosticCaptureResult.submitted);
        expect(await queued, DiagnosticCaptureResult.disabled);
        expect(
          await reporter.capture(StateError(_sensitive), _stack),
          DiagnosticCaptureResult.submitted,
        );
        expect(sink.events, hasLength(2));
      },
    );
  }

  test(
    'sink failure is contained and does not poison subsequent submissions',
    () async {
      final sink = _RecordingSink();
      sink.onSubmit = (_) async {
        if (sink.events.length == 1) throw StateError(_sensitive);
      };
      final reporter = DiagnosticReporter(
        sanitizer: _sanitizer(),
        sink: sink,
        enabled: true,
        sampleRate: 1,
      )..setConsent(true);
      expect(
        await reporter.capture(StateError(_sensitive), _stack),
        DiagnosticCaptureResult.failed,
      );
      expect(
        await reporter.capture(StateError(_sensitive), _stack),
        DiagnosticCaptureResult.submitted,
      );
    },
  );

  test('invalid sampling and queue configuration fail closed', () async {
    final sink = _RecordingSink();
    for (final rate in [double.nan, double.infinity, -0.1, 1.1]) {
      expect(
        () => DiagnosticReporter(
          sanitizer: _sanitizer(),
          sink: sink,
          sampleRate: rate,
        ),
        throwsArgumentError,
      );
    }
    for (final capacity in [0, 33]) {
      expect(
        () => DiagnosticReporter(
          sanitizer: _sanitizer(),
          sink: sink,
          maxPending: capacity,
        ),
        throwsArgumentError,
      );
    }
    final reporter = DiagnosticReporter(
      sanitizer: _sanitizer(),
      sink: sink,
      enabled: true,
      sampleRate: 1,
      random: () => double.nan,
    )..setConsent(true);
    expect(
      await reporter.capture(StateError(_sensitive), _stack),
      DiagnosticCaptureResult.failed,
    );
    expect(sink.events, isEmpty);
  });
}

class _UnsafeException implements Exception {
  @override
  String toString() => throw StateError('Exception text must not be inspected');
}

class _UnsafeStack implements StackTrace {
  @override
  String toString() => throw StateError(_sensitive);
}

class _RecordingSink implements DiagnosticSink {
  final events = <DiagnosticEvent>[];
  Future<void> Function(DiagnosticEvent)? onSubmit;

  @override
  Future<void> submit(DiagnosticEvent event) async {
    events.add(event);
    await onSubmit?.call(event);
  }
}
