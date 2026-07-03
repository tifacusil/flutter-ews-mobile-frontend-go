/// A single recipient returned by
/// GET /api/v1/projects/{id}/alert-recipients?level=…
class AlertRecipient {
  const AlertRecipient({
    required this.userId,
    required this.username,
    this.email,
    this.phone,
  });

  final int userId;
  final String username;
  final String? email;
  final String? phone;

  factory AlertRecipient.fromJson(Map<String, dynamic> json) => AlertRecipient(
        userId: (json['user_id'] as int?) ?? 0,
        username: (json['username'] as String?) ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
      );
}
