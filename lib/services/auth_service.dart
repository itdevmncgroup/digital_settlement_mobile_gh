import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

/// Session state (JWT + current user), persisted in the platform's secure
/// storage (Keystore/Keychain). Notifies listeners on login/logout so the
/// app can switch between the login screen and the main shell.
class AuthService extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();

  String? accessToken;
  String? refreshToken;
  AppUser? user;
  bool loading = true;

  bool get isLoggedIn => accessToken != null && user != null;

  Future<void> loadFromStorage() async {
    accessToken = await _storage.read(key: 'accessToken');
    refreshToken = await _storage.read(key: 'refreshToken');
    final userJson = await _storage.read(key: 'user');
    if (userJson != null) {
      try {
        user = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {
        user = null;
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setSession({required String accessToken, required String refreshToken, required AppUser user}) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.user = user;
    await _storage.write(key: 'accessToken', value: accessToken);
    await _storage.write(key: 'refreshToken', value: refreshToken);
    await _storage.write(key: 'user', value: jsonEncode(user.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    accessToken = null;
    refreshToken = null;
    user = null;
    await _storage.deleteAll();
    notifyListeners();
  }
}
