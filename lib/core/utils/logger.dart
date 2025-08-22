// lib/core/utils/logger.dart
import 'dart:convert' as convert; // <-- alias to avoid clash with AppLogger.json()
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Log levels in increasing severity.
enum LogLevel { trace, debug, info, warn, error }

typedef CrashReporter = Future<void> Function(
  Object error,
  StackTrace? stack, {
  String? reason,
  Map<String, dynamic>? context,
});

/// App-wide logger (non-HTTP). Use alongside Dio's HTTP logger.
class AppLogger {
  // Built-in redactions (can't be const because RegExp isn't const).
  static final List<Pattern> _builtInRedactions = <Pattern>[
    RegExp(r'Bearer\s+[A-Za-z0-9\-_\.]+'),
    RegExp(r'api_key=[^&\s]+'),
    RegExp(r'"password"\s*:\s*".*?"'),
    RegExp(r'"token"\s*:\s*".*?"'),
    RegExp(r'"authorization"\s*:\s*".*?"'),
  ];

  AppLogger._({
    required bool enabled,
    List<Pattern> redactions = const [],
    CrashReporter? crashReporter,
    String defaultTag = 'APP',
  })  : _enabled = enabled,
        _redactions = redactions,
        _crashReporter = crashReporter,
        _defaultTag = defaultTag;

  static AppLogger? _instance;

  /// Initialize once during app bootstrap (e.g., in DI setup).
  static void init({
    required bool enabled,
    List<Pattern> redactions = const [], // const default only
    CrashReporter? crashReporter,
    String defaultTag = 'APP',
  }) {
    _instance = AppLogger._(
      enabled: enabled,
      redactions: [..._builtInRedactions, ...redactions],
      crashReporter: crashReporter,
      defaultTag: defaultTag,
    );
  }

  /// Global singleton. Defaults to enabled in debug mode if not explicitly init'd.
  static AppLogger get I => _instance ??= AppLogger._(
        enabled: kDebugMode,
        redactions: _builtInRedactions, // safe by default in debug
      );

  final bool _enabled;
  final List<Pattern> _redactions;
  final CrashReporter? _crashReporter;
  final String _defaultTag;

  // ----------------- Public API -----------------

  void t(String msg, {String? tag, Map<String, dynamic>? ctx}) => _log(LogLevel.trace, msg, tag: tag, ctx: ctx);

  void d(String msg, {String? tag, Map<String, dynamic>? ctx}) => _log(LogLevel.debug, msg, tag: tag, ctx: ctx);

  void i(String msg, {String? tag, Map<String, dynamic>? ctx}) => _log(LogLevel.info, msg, tag: tag, ctx: ctx);

  void w(String msg, {String? tag, Object? error, StackTrace? stack, Map<String, dynamic>? ctx}) =>
      _log(LogLevel.warn, msg, tag: tag, error: error, stack: stack, ctx: ctx);

  void e(String msg, {String? tag, Object? error, StackTrace? stack, Map<String, dynamic>? ctx}) {
    _log(LogLevel.error, msg, tag: tag, error: error, stack: stack, ctx: ctx);
    if (_crashReporter != null) {
      _crashReporter(error ?? msg, stack, reason: msg, context: ctx);
    }
  }

  /// Pretty-print JSON or map/list safely (with redaction).
  void json(Object? data, {String? tag, LogLevel level = LogLevel.debug}) {
    final pretty = prettyJson(data, redactKeys: const {'password', 'token', 'authorization'});
    _log(level, pretty, tag: tag);
  }

  /// Measure time for async operations.
  Future<T> measure<T>(String label, Future<T> Function() run, {String? tag}) async {
    final sw = Stopwatch()..start();
    try {
      final result = await run();
      sw.stop();
      d('$label finished in ${sw.elapsedMilliseconds}ms', tag: tag);
      return result;
    } catch (e, st) {
      sw.stop();
      eRuntime('$label failed after ${sw.elapsedMilliseconds}ms', error: e, stack: st, tag: tag);
      rethrow;
    }
  }

  /// Convenience to log runtime errors at error level.
  void eRuntime(String msg, {Object? error, StackTrace? stack, String? tag}) =>
      e(msg, error: error, stack: stack, tag: tag);

  // ----------------- Internals -----------------

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stack,
    Map<String, dynamic>? ctx,
  }) {
    if (!_enabled) return;

    final name = tag ?? _defaultTag;
    final prefix = _emoji(level);
    final sanitizedMsg = _applyRedactions(message);
    final ctxStr = (ctx == null || ctx.isEmpty) ? '' : ' ${_applyRedactions(prettyJson(ctx))}';

    developer.log(
      '$prefix $sanitizedMsg$ctxStr',
      name: name,
      error: error,
      stackTrace: stack,
      level: _numeric(level),
    );
  }

  String _applyRedactions(String input) {
    var out = input;
    for (final p in _redactions) {
      if (p is RegExp) {
        out = out.replaceAll(p, _mask);
      } else {
        out = out.replaceAll('$p', _mask);
      }
    }
    return out;
  }

  static const _mask = '***';

  static int _numeric(LogLevel l) => switch (l) {
        LogLevel.trace => 500,
        LogLevel.debug => 800,
        LogLevel.info => 1000,
        LogLevel.warn => 1200,
        LogLevel.error => 1500,
      };

  static String _emoji(LogLevel l) => switch (l) {
        LogLevel.trace => '🟣',
        LogLevel.debug => '🔵',
        LogLevel.info => '🟢',
        LogLevel.warn => '🟠',
        LogLevel.error => '🔴',
      };

  // ----------------- Utils -----------------

  /// Pretty-prints any Object to JSON when possible, with optional key redaction.
  static String prettyJson(
    Object? data, {
    Set<String> redactKeys = const {},
    int indent = 2,
  }) {
    Object? safe = data;
    try {
      if (data is String) {
        // Use alias to avoid clashing with AppLogger.json()
        safe = convert.jsonDecode(data);
      }
      safe = _redactDeep(safe, redactKeys);
      final encoder = convert.JsonEncoder.withIndent(' ' * indent);
      return encoder.convert(safe);
    } catch (_) {
      // Fallback to simple toString
      return data.toString();
    }
  }

  static Object? _redactDeep(Object? v, Set<String> keys) {
    if (v is Map) {
      return v.map((k, val) {
        if (k is String && keys.contains(k.toLowerCase())) {
          return MapEntry(k, _mask);
        }
        return MapEntry(k, _redactDeep(val, keys));
      });
    } else if (v is List) {
      return v.map((e) => _redactDeep(e, keys)).toList();
    }
    return v;
  }

  /// Optional: route Flutter framework errors to the logger.
  static void hookFlutterErrors() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (kDebugMode) {
        original?.call(details); // keep default console in debug
      }
      AppLogger.I.e(
        details.exceptionAsString(),
        error: details.exception,
        stack: details.stack,
        tag: 'FlutterError',
      );
    };
  }
}
