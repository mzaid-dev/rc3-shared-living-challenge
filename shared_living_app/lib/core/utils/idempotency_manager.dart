import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Manages client-side Idempotency-Key lifecycle.
/// Rule: Reuse the key ONLY for network errors, timeouts, and 5xx with an UNCHANGED payload.
/// After any 4xx validation failure, or if the payload hash changes, generate a new key.
class IdempotencyContext {
  static const Uuid _uuid = Uuid();

  String _key;
  String? _lastPayloadHash;

  IdempotencyContext() : _key = _uuid.v4();

  String get key => _key;
  String? get lastPayloadHash => _lastPayloadHash;

  /// Computes SHA256 hash of the JSON payload
  static String hashPayload(String payload) {
    final bytes = utf8.encode(payload);
    return sha256.convert(bytes).toString();
  }

  /// Called before submitting. If payload changed, regenerates key automatically.
  String prepareKeyForPayload(String payload) {
    final currentHash = hashPayload(payload);
    if (_lastPayloadHash != null && _lastPayloadHash != currentHash) {
      // Payload changed; must generate a new idempotency key
      _key = _uuid.v4();
    }
    _lastPayloadHash = currentHash;
    return _key;
  }

  /// Handles failure outcome:
  /// - Network errors, timeouts, or 5xx: keep key if payload unchanged
  /// - 4xx validation error or other: generate new key immediately
  void handleFailure({
    required bool isNetworkOrTimeoutOr5xx,
    required String payload,
  }) {
    final currentHash = hashPayload(payload);
    if (isNetworkOrTimeoutOr5xx && _lastPayloadHash == currentHash) {
      // Retain the key for safe retry
      return;
    }
    // Any 4xx client validation error or payload mutation resets the key
    _key = _uuid.v4();
    _lastPayloadHash = currentHash;
  }

  /// Resets the context with a fresh key
  void reset() {
    _key = _uuid.v4();
    _lastPayloadHash = null;
  }
}
