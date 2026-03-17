// lib/services/token_monitor_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:safety_check_list/services/secure_storage.dart';

class TokenMonitorService {
  static final TokenMonitorService _instance = TokenMonitorService._internal();
  factory TokenMonitorService() => _instance;
  TokenMonitorService._internal();

  Timer? _tokenCheckTimer;
  final _tokenExpiredController = StreamController<bool>.broadcast();
  Stream<bool> get onTokenExpired => _tokenExpiredController.stream;

  bool _isMonitoringStarted = false;

  // Default check interval: every 30 seconds
  static const Duration defaultCheckInterval = Duration(seconds: 30);

  // Warning threshold: 5 minutes before expiry
  static const Duration warningThreshold = Duration(minutes: 5);

  // Callbacks
  VoidCallback? _onTokenExpired;
  VoidCallback? _onTokenNearExpiry;

  // Start monitoring token
  void startMonitoring({
    Duration checkInterval = defaultCheckInterval,
    VoidCallback? onTokenExpired,
    VoidCallback? onTokenNearExpiry,
  }) {
    if (_isMonitoringStarted) return;

    _isMonitoringStarted = true;
    _onTokenExpired = onTokenExpired;
    _onTokenNearExpiry = onTokenNearExpiry;

    _tokenCheckTimer = Timer.periodic(checkInterval, (timer) async {
      await _checkTokenStatus();
    });

    // Also check immediately
    _checkTokenStatus();

    print('🕒 Token monitoring started with interval: $checkInterval');
  }

  // Stop monitoring
  void stopMonitoring() {
    _tokenCheckTimer?.cancel();
    _tokenCheckTimer = null;
    _isMonitoringStarted = false;
    _onTokenExpired = null;
    _onTokenNearExpiry = null;
    print('🛑 Token monitoring stopped');
  }

  // Check token status
  Future<void> _checkTokenStatus() async {
    try {
      final token = await SecureStorage.getToken();

      if (token == null) {
        print('🔴 No token found');
        _tokenExpiredController.add(true);
        _onTokenExpired?.call();
        return;
      }

      final isExpired = await SecureStorage.isTokenExpired();
      final remaining = await SecureStorage.getRemainingTime();

      if (remaining != null) {
        print(
            '⏰ Token expires in: ${remaining.inMinutes} minutes ${remaining.inSeconds % 60} seconds');

        if (isExpired) {
          print('🔴 Token expired');
          _tokenExpiredController.add(true);
          _onTokenExpired?.call();
          await SecureStorage.clearAll();
          stopMonitoring();
        } else if (remaining <= warningThreshold) {
          print('🟡 Token near expiry');
          _tokenExpiredController.add(false);
          _onTokenNearExpiry?.call();
        }
      }
    } catch (e) {
      print('❌ Error checking token status: $e');
    }
  }

  void dispose() {
    stopMonitoring();
    _tokenExpiredController.close();
  }
}
