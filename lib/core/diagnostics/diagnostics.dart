import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

enum DiagnosticEnvironment { staging, production }

enum DiagnosticErrorKind {
  state,
  format,
  range,
  argument,
  type,
  assertion,
  timeout,
  runtime,
  unknown,
}

enum DiagnosticCaptureResult {
  disabled,
  sampledOut,
  queueFull,
  submitted,
  failed,
}

/// A sink accepts only an already rebuilt, immutable diagnostic event. It must
/// not attach the original error, SDK scope, identifiers or arbitrary context.
abstract interface class DiagnosticSink {
  Future<void> submit(DiagnosticEvent event);
}

final class DiagnosticFrame {
  const DiagnosticFrame._(this.source, this.line, this.column);

  final String source;
  final int line;
  final int column;

  Map<String, Object> toJson() => {
    'filename': source,
    'lineno': line,
    'colno': column,
    'in_app': true,
  };
}

/// Whitelisted diagnostic content, independent of any vendor SDK. Every JSON
/// export is fresh so callers cannot mutate an event retained in the queue.
final class DiagnosticEvent {
  DiagnosticEvent._({
    required this.id,
    required this.timestamp,
    required this.kind,
    required this.version,
    required this.environment,
    required List<DiagnosticFrame> frames,
  }) : frames = List.unmodifiable(frames);

  final String id;
  final DateTime timestamp;
  final DiagnosticErrorKind kind;
  final String version;
  final DiagnosticEnvironment environment;
  final List<DiagnosticFrame> frames;

  Map<String, Object> toJson() => {
    'event_id': id,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'platform': 'dart',
    'level': 'error',
    'release': 'squadly@$version',
    'environment': environment.name,
    'exception': {
      'values': [
        {
          'type': kind.name,
          'value': '[content omitted]',
          'stacktrace': {
            'frames': frames.map((frame) => frame.toJson()).toList(),
          },
        },
      ],
    },
  };
}

/// Rebuilds events from fixed categories and a caller-supplied static source
/// catalog. Exception.toString(), function names and arbitrary metadata are
/// deliberately never read. This is not an SDK-wide/native privacy filter.
final class DiagnosticSanitizer {
  DiagnosticSanitizer({
    required this.version,
    required this.environment,
    required Set<String> allowedSources,
    DateTime Function()? clock,
  }) : _sources = Set.unmodifiable(allowedSources),
       _clock = clock ?? DateTime.now {
    if (!RegExp(r'^\d{1,4}\.\d{1,4}\.\d{1,4}(?:\+\d{1,10})?$')
        .hasMatch(version)) {
      throw ArgumentError('Diagnostic version must be a numeric app version');
    }
    if (_sources.any(
      (source) => !_sourcePattern.hasMatch(source) || source.contains('..'),
    )) {
      throw ArgumentError(
        'Diagnostic sources must be static Squadly package paths',
      );
    }
  }

  final String version;
  final DiagnosticEnvironment environment;
  final Set<String> _sources;
  final DateTime Function() _clock;
  static final _sourcePattern = RegExp(
    r'^package:squadly/(?:[a-z0-9_]+/)*[a-z0-9_]+(?:\.(?:g|freezed))?\.dart$',
  );
  static final _framePattern = RegExp(
    r'^\s*#\d+\s+.*\((package:squadly/[^\s():]+\.dart):(\d{1,6}):(\d{1,5})\)\s*$',
  );

  DiagnosticEvent sanitize(Object error, StackTrace stack) => DiagnosticEvent._(
    id: const Uuid().v4().replaceAll('-', ''),
    timestamp: _clock().toUtc(),
    kind: _kind(error),
    version: version,
    environment: environment,
    frames: _frames(stack),
  );

  List<DiagnosticFrame> _frames(StackTrace stack) {
    final frames = <DiagnosticFrame>[];
    try {
      final text = stack.toString();
      final bounded = text.length > 16384 ? text.substring(0, 16384) : text;
      for (final line in bounded.split('\n')) {
        final match = _framePattern.firstMatch(line);
        if (match == null || !_sources.contains(match[1])) continue;
        final row = int.parse(match[2]!);
        final column = int.parse(match[3]!);
        if (row < 1 || column < 1 || column > 10000) continue;
        frames.add(DiagnosticFrame._(match[1]!, row, column));
        if (frames.length == 20) break;
      }
    } catch (_) {
      // A malformed or custom StackTrace is never allowed to break error
      // handling or leak its text through a secondary logging path.
    }
    return frames;
  }

  static DiagnosticErrorKind _kind(Object error) => switch (error) {
    StateError() => DiagnosticErrorKind.state,
    FormatException() => DiagnosticErrorKind.format,
    RangeError() => DiagnosticErrorKind.range,
    ArgumentError() => DiagnosticErrorKind.argument,
    TypeError() => DiagnosticErrorKind.type,
    AssertionError() => DiagnosticErrorKind.assertion,
    TimeoutException() => DiagnosticErrorKind.timeout,
    Error() => DiagnosticErrorKind.runtime,
    _ => DiagnosticErrorKind.unknown,
  };
}

/// In-memory, bounded submission. Both switches and sampling default off.
/// Revocation invalidates queued work, including work queued before a later
/// re-enable. An already submitted request cannot be recalled by this class.
final class DiagnosticReporter {
  DiagnosticReporter({
    required this._sanitizer,
    required this._sink,
    this._enabled = false,
    double sampleRate = 0,
    int maxPending = 8,
    double Function()? random,
  }) : _sampleRate = sampleRate,
       _maxPending = maxPending,
       _random = random ?? Random().nextDouble {
    if (!sampleRate.isFinite ||
        sampleRate < 0 ||
        sampleRate > 1 ||
        maxPending < 1 ||
        maxPending > 32) {
      throw ArgumentError('Invalid diagnostic sampling or queue limits');
    }
  }

  final DiagnosticSanitizer _sanitizer;
  final DiagnosticSink _sink;
  final double _sampleRate;
  final int _maxPending;
  final double Function() _random;
  bool _enabled;
  bool _consented = false;
  int _generation = 0;
  int _pending = 0;
  Future<void> _tail = Future.value();

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _generation++;
  }

  void setConsent(bool value) {
    if (_consented == value) return;
    _consented = value;
    _generation++;
  }

  Future<DiagnosticCaptureResult> capture(Object error, StackTrace stack) {
    if (!_enabled || !_consented || _sampleRate == 0) {
      return Future.value(DiagnosticCaptureResult.disabled);
    }
    if (_pending >= _maxPending) {
      return Future.value(DiagnosticCaptureResult.queueFull);
    }
    final DiagnosticEvent event;
    try {
      final draw = _random();
      if (!draw.isFinite || draw < 0 || draw >= 1) {
        return Future.value(DiagnosticCaptureResult.failed);
      }
      if (draw >= _sampleRate) {
        return Future.value(DiagnosticCaptureResult.sampledOut);
      }
      event = _sanitizer.sanitize(error, stack);
    } catch (_) {
      return Future.value(DiagnosticCaptureResult.failed);
    }
    final generation = _generation;
    final result = Completer<DiagnosticCaptureResult>();
    _pending++;
    _tail = _tail.then((_) async {
      try {
        if (!_enabled || !_consented || generation != _generation) {
          result.complete(DiagnosticCaptureResult.disabled);
          return;
        }
        await _sink.submit(event);
        result.complete(DiagnosticCaptureResult.submitted);
      } catch (_) {
        result.complete(DiagnosticCaptureResult.failed);
      } finally {
        _pending--;
      }
    });
    return result.future;
  }
}
