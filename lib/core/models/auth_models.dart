import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_models.freezed.dart';
part 'auth_models.g.dart';

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

/// Request body for POST /api/v1/users/login.
@freezed
abstract class LoginRequest with _$LoginRequest {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LoginRequest({
    required String username,
    required String password,
  }) = _LoginRequest;

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
}

/// Response body for POST /api/v1/users/login (200).
@freezed
abstract class LoginResponse with _$LoginResponse {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LoginResponse({
    required String token,
    required int userId,
    required String username,
    required String role,
    required DateTime expiresAt,
  }) = _LoginResponse;

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);
}

// ---------------------------------------------------------------------------
// Register
// ---------------------------------------------------------------------------

/// Request body for POST /api/v1/users/register.
@freezed
abstract class RegisterRequest with _$RegisterRequest {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
  const factory RegisterRequest({
    required String username,
    required String email,
    String? phoneE164,
    required String password,
    /// Defaults to 'viewer' server-side if omitted.
    String? role,
  }) = _RegisterRequest;

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
}

/// Response body for POST /api/v1/users/register (201).
@freezed
abstract class RegisterResponse with _$RegisterResponse {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory RegisterResponse({
    required int userId,
    required String username,
    required String role,
  }) = _RegisterResponse;

  factory RegisterResponse.fromJson(Map<String, dynamic> json) =>
      _$RegisterResponseFromJson(json);
}
