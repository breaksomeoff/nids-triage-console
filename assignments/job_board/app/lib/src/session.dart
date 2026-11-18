import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

/// Logged-in company, kept across app restarts.
class Session extends ChangeNotifier {
  Session._(this._api, this._prefs);

  static const _tokenKey = 'session.token';
  static const _companyKey = 'session.company';

  final ApiClient _api;
  final SharedPreferences _prefs;

  Company? _company;
  bool _expired = false;

  Company? get company => _company;
  bool get isLoggedIn => _company != null;

  /// Whether the last logout was forced by the server rejecting the token.
  bool get expired => _expired;

  static Future<Session> restore(ApiClient api) async {
    final prefs = await SharedPreferences.getInstance();
    final session = Session._(api, prefs);
    final token = prefs.getString(_tokenKey);
    final company = prefs.getString(_companyKey);
    if (token != null && company != null) {
      try {
        session._company = Company.fromJson(
          jsonDecode(company) as Map<String, dynamic>,
        );
        api.token = token;
      } catch (_) {
        await session._forget();
      }
    }
    api.onUnauthorized = () {
      if (session.isLoggedIn) session._clear(expired: true);
    };
    return session;
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _api.login(email: email, password: password);
    _api.token = result.token;
    _company = result.company;
    _expired = false;
    await _prefs.setString(_tokenKey, result.token);
    await _prefs.setString(_companyKey, jsonEncode(result.company.toJson()));
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } on ApiException {
      // The local session is cleared anyway.
    }
    await _clear(expired: false);
  }

  Future<void> _clear({required bool expired}) async {
    _api.token = null;
    _company = null;
    _expired = expired;
    await _forget();
    notifyListeners();
  }

  Future<void> _forget() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_companyKey);
  }
}
