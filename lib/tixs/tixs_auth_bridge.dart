import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;

/// Manages the Tixs session cookie extracted from the in-app WebView.
///
/// The Tixs backend uses an HttpOnly `__Host-tixs-session` cookie.
/// We extract it from the WebView's cookie store after sign-in and cache it
/// in FlutterSecureStorage for use in native HTTP requests (NFT challenge/claim).
///
/// Private keys and mnemonics are never sent to the Tixs backend.
class TixsAuthBridge {
  static const _sessionKey = 'tixs_session_cookie';
  static const _accountKey = 'tixs_account_json';
  static const _cookieName = '__Host-tixs-session';
  static const _baseUrl = 'https://tixs.ai';

  final FlutterSecureStorage _storage;

  TixsAuthBridge({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Called after a WebView navigation completes on tixs.ai.
  /// Attempts to extract the session cookie and fetch account identity.
  Future<bool> syncFromWebView() async {
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(_baseUrl),
      );
      final session = cookies.firstWhere(
        (c) => c.name == _cookieName,
        orElse: () => Cookie(name: '', value: ''),
      );
      if (session.value.isEmpty) {
        await _clearSession();
        return false;
      }
      await _storage.write(key: _sessionKey, value: session.value);
      await _fetchAndCacheAccount(session.value);
      return true;
    } catch (e) {
      debugPrint('[TixsAuth] syncFromWebView error: $e');
      return false;
    }
  }

  /// Returns the raw session cookie value, or null if not signed in.
  Future<String?> get sessionCookie => _storage.read(key: _sessionKey);

  /// Returns the cached account map (id, email, username), or null.
  Future<Map<String, dynamic>?> get account async {
    final raw = await _storage.read(key: _accountKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> get isSignedIn async => (await sessionCookie) != null;

  /// Signs out: clears cached session and optionally signs out of the WebView.
  Future<void> signOut() async {
    await _clearSession();
    await CookieManager.instance().deleteCookie(
      url: WebUri(_baseUrl),
      name: _cookieName,
    );
  }

  /// Builds standard headers for Tixs API requests.
  Future<Map<String, String>> apiHeaders() async {
    final cookie = await sessionCookie;
    return {
      'Content-Type': 'application/json',
      if (cookie != null) 'Cookie': '$_cookieName=$cookie',
      'Origin': _baseUrl,
    };
  }

  Future<void> _fetchAndCacheAccount(String sessionValue) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/me'),
        headers: {'Cookie': '$_cookieName=$sessionValue'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        await _storage.write(key: _accountKey, value: response.body);
      }
    } catch (e) {
      debugPrint('[TixsAuth] account fetch error: $e');
    }
  }

  Future<void> _clearSession() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _accountKey);
  }
}
