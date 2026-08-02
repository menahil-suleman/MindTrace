/// Mirrors the backend's `UserOut` schema.
class UserOut {
  final String id;
  final String email;
  final String username;
  final String? gender;
  final DateTime createdAt;

  const UserOut({
    required this.id,
    required this.email,
    required this.username,
    this.gender,
    required this.createdAt,
  });

  factory UserOut.fromJson(Map<String, dynamic> json) => UserOut(
        id: json['id'] as String,
        email: json['email'] as String,
        username: json['username'] as String? ?? '',
        gender: json['gender'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

/// Mirrors the backend's `Token` schema.
class AuthToken {
  final String accessToken;
  final String tokenType;

  const AuthToken({required this.accessToken, required this.tokenType});

  factory AuthToken.fromJson(Map<String, dynamic> json) => AuthToken(
        accessToken: json['access_token'] as String,
        tokenType: json['token_type'] as String? ?? 'bearer',
      );
}
