import 'package:dio/dio.dart';

import '../constants.dart';
import '../models/api_alert.dart'; // AlertRecipient
import '../models/project.dart';
import '../models/recent_alert.dart';
import '../models/sensor.dart';
import 'auth_service.dart';
import 'user_management_service.dart'; // ApiException

/// HTTP client that covers all data-plane endpoints via the Nginx proxy (port 80):
///   - Project     GET /api/v1/projects/{id}   (includes sensors inline)
///   - Sensors     GET /api/v1/projects/{id}/sensors
///   - Alerts      GET /api/v1/warnings/alerts/recent
///   - Recipients  GET /api/v1/projects/{id}/alert-recipients
///
/// The project list is no longer fetched here — the flow is:
///   subscriptions → project_ids → parallel getProject() calls.
///
/// Obtain via [dataServiceProvider].
class DataService {
  DataService({required AuthService authService})
      : _dio = _buildDio(authService, kApiBaseUrl);

  final Dio _dio;

  static Dio _buildDio(AuthService auth, String baseUrl) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: kConnectTimeout,
        receiveTimeout: kReceiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

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

  Never _throw(Object error) {
    if (error is DioException && error.error is ApiException) {
      throw error.error as ApiException;
    }
    if (error is ApiException) throw error;
    throw error;
  }

  // ---------------------------------------------------------------------------
  // Projects
  // ---------------------------------------------------------------------------

  /// GET /api/v1/projects/{project_id}
  ///
  /// Returns the project with its sensors list already populated.
  Future<ApiProject> getProject(String projectId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/projects/$projectId',
      );
      return ApiProject.fromJson(res.data!);
    } catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Sensors
  // ---------------------------------------------------------------------------

  /// GET /api/v1/projects/{project_id}/sensors
  Future<List<ApiSensor>> getSensors(String projectId) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/v1/projects/$projectId/sensors',
      );
      return (res.data ?? [])
          .cast<Map<String, dynamic>>()
          .map(ApiSensor.fromJson)
          .toList();
    } catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Alerts
  // ---------------------------------------------------------------------------

  /// GET /api/v1/warnings/alerts/recent?limit={limit}
  ///
  /// Returns the most recent alerts across all projects the authenticated
  /// user has access to (filtered server-side by subscription). The gateway
  /// routes early-warning under `/api/v1/warnings/` and strips that prefix.
  Future<List<RecentAlert>> getRecentAlerts({int limit = 50}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/warnings/alerts/recent',
        queryParameters: {'limit': limit},
      );
      final data = res.data;
      final list = (data?['alerts'] as List<dynamic>?) ?? [];
      return list
          .cast<Map<String, dynamic>>()
          .map(RecentAlert.fromJson)
          .toList();
    } catch (e) {
      _throw(e);
    }
  }

  /// GET /api/v1/projects/{project_id}/alert-recipients?level={level}
  Future<List<AlertRecipient>> getAlertRecipients(
    String projectId, {
    String level = 'red',
  }) async {
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/v1/projects/$projectId/alert-recipients',
        queryParameters: {'level': level},
      );
      return (res.data ?? [])
          .cast<Map<String, dynamic>>()
          .map(AlertRecipient.fromJson)
          .toList();
    } catch (e) {
      _throw(e);
    }
  }
}
