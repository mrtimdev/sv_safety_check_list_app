// lib/services/secure_storage.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _rememberMeKey = 'remember_me';

  // New keys for token expiry
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _tokenExpiryDurationKey = 'token_expiry_duration';

  // Save token with optional expiry
  static Future<void> saveToken(String token,
      {int expiresInSeconds = 3600}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    // Calculate and save expiry time
    final expiryTime = DateTime.now().add(Duration(seconds: expiresInSeconds));
    await saveTokenExpiry(expiryTime);
    await prefs.setInt(_tokenExpiryDurationKey, expiresInSeconds);

    print('💾 Token saved, expires at: $expiryTime');
  }

  // Get token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Save token expiry
  static Future<void> saveTokenExpiry(DateTime expiryTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenExpiryKey, expiryTime.toIso8601String());
  }

  // Get token expiry
  static Future<DateTime?> getTokenExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryString = prefs.getString(_tokenExpiryKey);
    if (expiryString == null) return null;

    try {
      return DateTime.parse(expiryString);
    } catch (e) {
      return null;
    }
  }

  // Get token expiry duration (in seconds)
  static Future<int?> getTokenExpiryDuration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_tokenExpiryDurationKey);
  }

  // Check if token is expired
  static Future<bool> isTokenExpired() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;

    return DateTime.now().isAfter(expiry);
  }

  // Get remaining time as formatted string
  static Future<String> getRemainingTimeString() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return 'No token';

    final now = DateTime.now();
    if (now.isAfter(expiry)) return 'Expired';

    final difference = expiry.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    final seconds = difference.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // Get remaining time as Duration
  static Future<Duration?> getRemainingTime() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return null;

    final now = DateTime.now();
    if (now.isAfter(expiry)) return Duration.zero;

    return expiry.difference(now);
  }

  // Check if token needs refresh (less than 5 minutes remaining)
  static Future<bool> shouldRefreshToken() async {
    final remaining = await getRemainingTime();
    if (remaining == null) return false;

    // Return true if less than 5 minutes remaining
    return remaining.inMinutes < 5;
  }

  // Save refresh token
  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, token);
  }

  // Get refresh token
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // Save user data
  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = json.encode(user);
    await prefs.setString(_userKey, userJson);
  }

  // Get user data
  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return json.decode(userJson);
    }
    return null;
  }

  // Save remember me preference
  static Future<void> saveRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  // Get remember me preference
  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  // Check if user is logged in and token is valid
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    // Check if token is expired
    final expired = await isTokenExpired();
    return !expired;
  }

  // Check if user was previously logged in (ignore expiry)
  static Future<bool> hasStoredCredentials() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Clear all data (logout) - keeps remember me preference
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_tokenExpiryKey);
    await prefs.remove(_tokenExpiryDurationKey);
    // Note: remember_me preference is not cleared on logout
  }

  // Clear everything including remember me (for reset)
  static Future<void> clearEverything() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Refresh token using refresh token
  static Future<String?> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return null;

      // Call your refresh token API endpoint here
      // This is just a placeholder - implement based on your API
      /*
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newToken = data['token'];
        final newExpiry = data['expiresIn'] ?? 3600;
        
        await saveToken(newToken, expiresInSeconds: newExpiry);
        if (data['refreshToken'] != null) {
          await saveRefreshToken(data['refreshToken']);
        }
        
        return newToken;
      }
      */

      return null;
    } catch (e) {
      print('Error refreshing token: $e');
      return null;
    }
  }

  // Get token info for debugging
  static Future<Map<String, dynamic>> getTokenInfo() async {
    final token = await getToken();
    final expiry = await getTokenExpiry();
    final remaining = await getRemainingTime();
    final expired = await isTokenExpired();

    return {
      'hasToken': token != null,
      'expiry': expiry?.toIso8601String(),
      'remainingMinutes': remaining?.inMinutes,
      'isExpired': expired,
      'needsRefresh': await shouldRefreshToken(),
    };
  }
}
