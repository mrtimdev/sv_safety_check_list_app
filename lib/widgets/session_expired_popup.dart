// lib/widgets/session_expired_popup.dart

import 'package:flutter/material.dart';
import 'package:safety_check_list/screens/auth/login_screen.dart';

class SessionExpiredPopup {
  static void show({
    required BuildContext context,
    String message = 'សម័យប្រើប្រាស់បានផុតកំណត់',
    String description = 'សូមចូលប្រព័ន្ធម្តងទៀត',
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: _SessionExpiredContent(
            message: message,
            description: description,
            onDismiss: onDismiss,
          ),
        );
      },
    );
  }

  static Future<void> handleUnauthorized(
    BuildContext context, {
    String message = 'សម័យប្រើប្រាស់បានផុតកំណត់',
  }) async {
    // Clear all stored data
    // await SecureStorage.deleteToken();
    // await SecureStorage.deleteUser();

    // Show popup and navigate to login
    if (context.mounted) {
      show(
        context: context,
        message: message,
        onDismiss: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        },
      );
    }
  }
}

class _SessionExpiredContent extends StatefulWidget {
  final String message;
  final String description;
  final VoidCallback? onDismiss;

  const _SessionExpiredContent({
    required this.message,
    required this.description,
    this.onDismiss,
  });

  @override
  State<_SessionExpiredContent> createState() => _SessionExpiredContentState();
}

class _SessionExpiredContentState extends State<_SessionExpiredContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing ring
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 1500),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    curve: Curves.easeInOut,
                    builder: (context, double value, child) {
                      return Container(
                        width: 80 + (value * 20),
                        height: 80 + (value * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.3 - (value * 0.2)),
                        ),
                      );
                    },
                    onEnd: () => setState(() {}),
                  ),
                  // Main icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.timer_off_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Title with gradient
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFEF5350)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                widget.message,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              widget.description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Animated timer/clock
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder(
                    duration: const Duration(seconds: 2),
                    tween: Tween<double>(begin: 0, end: 2 * 3.14159),
                    builder: (context, double value, child) {
                      return Transform.rotate(
                        angle: value,
                        child: Icon(
                          Icons.autorenew_rounded,
                          color: Colors.red.shade400,
                          size: 20,
                        ),
                      );
                    },
                    onEnd: () => setState(() {}),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'កំពុងដឹកនាំទៅកាន់ទំព័រចូលប្រព័ន្ធ...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Login Button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFEF5350)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (widget.onDismiss != null) {
                    widget.onDismiss!();
                  } else {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'ចូលប្រព័ន្ធម្តងទៀត',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Close button (optional)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
              child: Text(
                'បិទ',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// // Extension to easily handle 401 errors in ApiService
// extension ApiResponseHandler on http.Response {
//   bool isUnauthorized() => statusCode == 401;
  
//   bool isForbidden() => statusCode == 403;
  
//   bool isSuccess() => statusCode >= 200 && statusCode < 300;
// }