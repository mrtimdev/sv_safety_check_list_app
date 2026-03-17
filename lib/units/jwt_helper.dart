// lib/utils/jwt_helper.dart

import 'dart:convert';
import 'dart:math';

class JwtHelper {
  static Map<String, dynamic>? decodeJwt(String token) {
    try {
      // Split the token into parts
      List<String> parts = token.split('.');
      if (parts.length != 3) {
        print('❌ Invalid JWT format: expected 3 parts, got ${parts.length}');
        return null;
      }

      // Decode the payload (second part)
      String payload = parts[1];

      // Add padding if needed
      while (payload.length % 4 != 0) {
        payload += '=';
      }

      String normalized = base64Url.normalize(payload);
      String decoded = utf8.decode(base64Url.decode(normalized));

      return json.decode(decoded);
    } catch (e) {
      print('❌ Error decoding JWT: $e');
      return null;
    }
  }

  static DateTime? getExpiryDate(String token) {
    final payload = decodeJwt(token);
    if (payload == null) return null;

    // JWT exp is in seconds since epoch
    final exp = payload['exp'];
    if (exp == null) {
      print('⚠️ No exp claim in token');
      return null;
    }

    // Convert seconds to milliseconds
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  }

  static int getExpiresInSeconds(String token) {
    final expiryDate = getExpiryDate(token);
    if (expiryDate == null) {
      print('⚠️ Could not get expiry from token, using default 1 hour');
      return 3600; // Default 1 hour
    }

    final now = DateTime.now();
    final difference = expiryDate.difference(now);

    // Ensure we don't return negative values
    final seconds = max(0, difference.inSeconds);
    print('📅 Token expires in: $seconds seconds (${seconds / 60} minutes)');

    return seconds;
  }

  static Map<String, dynamic>? getTokenClaims(String token) {
    return decodeJwt(token);
  }

  static String? getUsername(String token) {
    final claims = decodeJwt(token);
    return claims?['sub']; // 'sub' is the subject (username)
  }

  static String? getRole(String token) {
    final claims = decodeJwt(token);
    return claims?['ROLE'];
  }

  static int? getUserId(String token) {
    final claims = decodeJwt(token);
    return claims?['userId'];
  }

  static String? getTokenType(String token) {
    final claims = decodeJwt(token);
    return claims?['tokenType'];
  }

  static bool isAccessToken(String token) {
    return getTokenType(token) == 'access';
  }

  static bool isRefreshToken(String token) {
    return getTokenType(token) == 'refresh';
  }

  static bool isTokenExpired(String token) {
    final expiryDate = getExpiryDate(token);
    if (expiryDate == null) return true;

    return DateTime.now().isAfter(expiryDate);
  }

  static String getTimeRemaining(String token) {
    final expiryDate = getExpiryDate(token);
    if (expiryDate == null) return 'Unknown';

    final now = DateTime.now();
    if (now.isAfter(expiryDate)) return 'Expired';

    final difference = expiryDate.difference(now);
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

  static void printTokenInfo(String token) {
    final claims = decodeJwt(token);
    if (claims == null) {
      print('❌ Invalid token');
      return;
    }

    print('📋 Token Info:');
    print('  - Username: ${claims['sub']}');
    print('  - User ID: ${claims['userId']}');
    print('  - Role: ${claims['ROLE']}');
    print('  - Token Type: ${claims['tokenType']}');
    print('  - Expires: ${getExpiryDate(token)}');
    print('  - Time Remaining: ${getTimeRemaining(token)}');
  }
}
