import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'token_store.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthController extends ChangeNotifier {
  AuthController({
    required this.apiClient,
    TokenStore? store,
  }) : _store = store ?? TokenStore();

  final ApiClient apiClient;
  final TokenStore _store;

  AuthStatus _status = AuthStatus.unknown;
  String? _userId;

  AuthStatus get status => _status;
  String? get userId => _userId;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Called once at app startup. Loads the token from secure storage.
  Future<void> bootstrap() async {
    final token = await _store.readToken();
    final userId = await _store.readUserId();
    if (token != null && userId != null) {
      apiClient.setAuthToken(token);
      _userId = userId;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login({
    required String token,
    required String userId,
  }) async {
    await _store.save(token: token, userId: userId);
    apiClient.setAuthToken(token);
    _userId = userId;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    await _store.clear();
    apiClient.setAuthToken(null);
    _userId = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}