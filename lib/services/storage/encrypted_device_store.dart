import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Abstraction over where the device master encryption key lives so tests can
/// inject an in-memory variant instead of the platform keychain.
abstract class SecretKeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Platform keychain/keystore backed key storage.
class SecureSecretKeyStore implements SecretKeyStore {
  final FlutterSecureStorage _storage;

  SecureSecretKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Process-only key storage for tests and unsupported platforms.
class InMemorySecretKeyStore implements SecretKeyStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// Encrypted on-device persistence for private child data.
///
/// Every box is opened with a Hive AES-256 cipher. The 256-bit master key is
/// generated once and held in the platform keychain ([SecureSecretKeyStore]).
/// Nothing stored through this store is ever synced to a server.
class EncryptedDeviceStore {
  static const String goalsBox = 'goals';
  static const String reflectionsBox = 'reflections';
  static const String coachingSessionsBox = 'coaching_sessions';
  static const String chatMessagesBox = 'chat_messages';
  static const String parentConversationsBox = 'parent_conversations';
  static const String aiSettingsBox = 'ai_settings';
  static const String promptsBox = 'prompts';
  static const String promptVersionsBox = 'prompt_versions';
  static const String reportSettingsBox = 'report_settings';
  static const String approvedReportsBox = 'approved_reports';
  static const String usageRecordsBox = 'usage_records';
  static const String usageAggregatesBox = 'usage_aggregates';

  static const String _masterKeyName = 'cleartime.device.master_key.v1';

  final SecretKeyStore _keyStore;
  final String? _storagePath;
  final Map<String, Box<dynamic>> _boxes = {};
  bool _initialized = false;
  List<int>? _masterKey;

  EncryptedDeviceStore({
    SecretKeyStore? keyStore,
    String? storagePath,
  })  : _keyStore = keyStore ?? SecureSecretKeyStore(),
        _storagePath = storagePath;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    if (_storagePath != null) {
      try {
        Hive.init(_storagePath!);
      } on HiveError {
        // Already initialized by an earlier store in the same process.
      }
    }

    var encoded = await _keyStore.read(_masterKeyName);
    if (encoded == null || encoded.isEmpty) {
      final random = Random.secure();
      final key = List<int>.generate(32, (_) => random.nextInt(256));
      encoded = base64Encode(key);
      await _keyStore.write(_masterKeyName, encoded);
    }
    _masterKey = base64Decode(encoded);
    _initialized = true;
  }

  Future<Box<dynamic>> _openBox(String name) async {
    await initialize();
    final existing = _boxes[name];
    if (existing != null && existing.isOpen) return existing;
    final box = await Hive.openBox<dynamic>(
      name,
      encryptionCipher: HiveAesCipher(_masterKey!),
    );
    _boxes[name] = box;
    return box;
  }

  Future<void> putJson(String boxName, String key, Map<String, dynamic> json) async {
    final box = await _openBox(boxName);
    await box.put(key, json);
  }

  Future<Map<String, dynamic>?> getJson(String boxName, String key) async {
    final box = await _openBox(boxName);
    final value = box.get(key);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Future<void> delete(String boxName, String key) async {
    final box = await _openBox(boxName);
    await box.delete(key);
  }

  Future<void> clearBox(String boxName) async {
    final box = await _openBox(boxName);
    await box.clear();
  }

  /// Reads every JSON entry in a box. Entries that cannot be decoded are
  /// skipped and surfaced through [onCorrupt] so callers can show a truthful
  /// recovery state instead of crashing or silently dropping data.
  Future<List<Map<String, dynamic>>> getAllJson(
    String boxName, {
    void Function(String key, Object error)? onCorrupt,
  }) async {
    final box = await _openBox(boxName);
    final results = <Map<String, dynamic>>[];
    for (final key in box.keys) {
      try {
        final value = box.get(key);
        if (value is Map<String, dynamic>) {
          results.add(value);
        } else if (value is Map) {
          results.add(Map<String, dynamic>.from(value));
        }
      } catch (e) {
        onCorrupt?.call(key.toString(), e);
      }
    }
    return results;
  }

  Future<void> close() async {
    for (final box in _boxes.values) {
      await box.close();
    }
    _boxes.clear();
    _initialized = false;
  }
}
