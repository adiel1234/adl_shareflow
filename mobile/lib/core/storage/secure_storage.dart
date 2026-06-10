import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serialized secure storage — prevents Android Keystore deadlocks when
/// auth init and API interceptors read concurrently at startup.
class AppSecureStorage {
  AppSecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static Future<void> _queue = Future.value();

  static Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  static Future<String?> read(
    String key, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _serialized(
      () => _storage.read(key: key).timeout(timeout),
    ).catchError((_) => null);
  }

  static Future<void> write(String key, String value) {
    return _serialized(() => _storage.write(key: key, value: value));
  }

  static Future<void> delete(String key) {
    return _serialized(() => _storage.delete(key: key));
  }

  static Future<void> deleteAll() {
    return _serialized(() => _storage.deleteAll());
  }
}
