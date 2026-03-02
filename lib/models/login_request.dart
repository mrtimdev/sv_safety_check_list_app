// Login Response Model
class LoginResponse {
  final bool success;
  final String? message;
  final String? token;
  final String? refreshToken; // Add this
  final Map<String, dynamic>? user;
  final String? identifyError;
  final String? passwordError;

  LoginResponse({
    required this.success,
    this.message,
    this.token,
    this.refreshToken, // Add this
    this.user,
    this.identifyError,
    this.passwordError,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] ?? false,
      message: json['message'],
      token: json['token'],
      refreshToken: json['refreshToken'], // Add this
      user: json['user'],
      identifyError: json['identifyError'],
      passwordError: json['passwordError'],
    );
  }
}

// Login Request Model
class LoginRequest {
  final String identifier;
  final String password;

  LoginRequest({
    required this.identifier,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'password': password,
      };
}
