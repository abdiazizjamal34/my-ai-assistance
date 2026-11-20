import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'auth_token_v1';
  static const _userIdKey = 'auth_user_id_v1';
  static const _lastConversationPrefix = 'last_conversation_v1';

  final FlutterSecureStorage _storage;

  Future<String?> readToken() => _storage.read(key: _tokenKey);
  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  // --- Last conversation (scoped per user) ---------------------------------

  String _lastConversationKey(String userId) =>
      '${_lastConversationPrefix}_$userId';

  Future<String?> readLastConversationId(String userId) =>
      _storage.read(key: _lastConversationKey(userId));

  Future<void> saveLastConversationId(String userId, String conversationId) =>
      _storage.write(
        key: _lastConversationKey(userId),
        value: conversationId,
      );

  Future<void> clearLastConversationId(String userId) =>
      _storage.delete(key: _lastConversationKey(userId));

  // --- Auth ----------------------------------------------------------------

  Future<void> save({required String token, required String userId}) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    // Keep per-user last-conversation keys so signing back in restores the chat.
  }
}