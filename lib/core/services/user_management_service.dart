import 'package:dio/dio.dart';

import '../constants.dart';
import '../models/auth_models.dart';
import '../models/device.dart';
import '../models/subscription.dart';
import '../models/user.dart';
import 'auth_service.dart';

/// Exception thrown when the server returns a non-2xx status.
class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  /// Whether this error means the session has expired / is invalid.
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Wraps all HTTP calls to the User Management Service (port 8085).
///
/// Obtain via [userManagementServiceProvider].
class UserManagementService {
  UserManagementService({required AuthService authService})
      : _auth = authService,
        _dio = _buildDio(authService);

  final AuthService _auth;
  final Dio _dio;

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static Dio _buildDio(AuthService auth) {
    final dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: kConnectTimeout,
        receiveTimeout: kReceiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Inject JWT on every authenticated request.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = auth.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (err, handler) {
          // Surface DioExceptions as ApiExceptions so callers don't need
          // to import Dio.
          final response = err.response;
          if (response != null) {
            final body = response.data;
            final message = (body is Map && body['error'] != null)
                ? body['error'] as String
                : err.message ?? 'Unknown error';
            handler.reject(
              DioException(
                requestOptions: err.requestOptions,
                response: response,
                error: ApiException(
                  statusCode: response.statusCode ?? 0,
                  message: message,
                ),
              ),
            );
          } else {
            handler.next(err);
          }
        },
      ),
    );

    return dio;
  }

  /// Extracts a typed [ApiException] from a [DioException], or re-throws.
  Never _throw(Object error) {
    if (error is DioException && error.error is ApiException) {
      throw error.error as ApiException;
    }
    if (error is ApiException) throw error;
    throw error;
  }

  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  /// POST /api/v1/users/login
  ///
  /// On success, persists the session (token, userId, username, role) so
  /// subsequent requests are automatically authenticated.
  Future<LoginResponse> login(String username, String password) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/users/login',
        data: LoginRequest(username: username, password: password).toJson(),
      );
      final loginResp = LoginResponse.fromJson(res.data!);
      await _auth.saveSession(
        token: loginResp.token,
        userId: loginResp.userId,
        username: loginResp.username,
        role: loginResp.role,
      );
      return loginResp;
    } catch (e) {
      _throw(e);
    }
  }

  /// POST /api/v1/users/logout
  ///
  /// Revokes all active device tokens for the authenticated user server-side.
  /// The JWT itself remains valid until expiry — discard it client-side after
  /// this call completes.
  Future<void> logout() async {
    try {
      await _dio.post<void>('/api/v1/users/logout');
    } catch (e) {
      _throw(e);
    }
  }

  /// POST /api/v1/users/register
  ///
  /// Creating an `admin` account requires the caller to already be an
  /// authenticated admin (the JWT is injected automatically if present).
  Future<RegisterResponse> register(RegisterRequest request) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/users/register',
        data: request.toJson(),
      );
      return RegisterResponse.fromJson(res.data!);
    } catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  /// GET /api/v1/users/{user_id}
  Future<UserProfile> getUser(int userId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/$userId',
      );
      return UserProfile.fromJson(res.data!);
    } catch (e) {
      _throw(e);
    }
  }

  /// PUT /api/v1/users/{user_id}
  ///
  /// Only [email] and [phoneE164] can be updated via this endpoint.
  Future<UserProfile> updateUser(int userId, UpdateUserRequest request) async {
    try {
      final res = await _dio.put<Map<String, dynamic>>(
        '/api/v1/users/$userId',
        data: request.toJson(),
      );
      return UserProfile.fromJson(res.data!);
    } catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Subscriptions
  // ---------------------------------------------------------------------------

  /// POST /api/v1/users/{user_id}/subscriptions  (admin only)
  Future<Subscription> createSubscription(
    int userId,
    CreateSubscriptionRequest request,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/users/$userId/subscriptions',
        data: request.toJson(),
      );
      return Subscription.fromJson(res.data!);
    } catch (e) {
      _throw(e);
    }
  }

  /// GET /api/v1/users/{user_id}/subscriptions
  ///
  /// Server wraps the list: `{"subscriptions": [...]}`.
  Future<List<Subscription>> listSubscriptions(int userId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/users/$userId/subscriptions',
      );
      final list = (res.data?['subscriptions'] as List<dynamic>?) ?? [];
      return list
          .cast<Map<String, dynamic>>()
          .map(Subscription.fromJson)
          .toList();
    } catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Devices
  // ---------------------------------------------------------------------------

  /// POST /api/v1/users/{user_id}/devices
  ///
  /// Registers or refreshes the push notification token for the current user.
  /// Call this on every app launch after login. The user id is taken from the
  /// persisted session.
  Future<DeviceRegisterResponse> registerDevice(
    DeviceRegisterRequest request,
  ) async {
    final userId = _auth.userId;
    if (userId == null) {
      throw const ApiException(
        statusCode: 401,
        message: 'No active session — cannot register device.',
      );
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/users/$userId/devices',
        data: request.toJson(),
      );
      return DeviceRegisterResponse.fromJson(res.data!);
    } catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Session helpers
  // ---------------------------------------------------------------------------

  /// Clears the local session. Call after revoking the device token.
  Future<void> clearSession() => _auth.clearSession();
}
