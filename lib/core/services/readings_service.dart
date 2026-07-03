import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../models/reading.dart';
import 'auth_service.dart';
import 'user_management_service.dart'; // re-uses ApiException

/// HTTP client for the Readings Service (port 8083).
///
/// Provides time-series sensor data.
/// Obtain via [readingsServiceProvider].
class ReadingsService {
  ReadingsService({required AuthService authService})
      : _dio = _buildDio(authService);

  final Dio _dio;

  static Dio _buildDio(AuthService auth) {
    final dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
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
            debugPrint(
              'ReadingsService ${response.statusCode} '
              '${err.requestOptions.path}: $body',
            );
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

    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) => debugPrint(o.toString()),
    ));

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
  // GET /api/v1/data/api/v1/sensors/{sensor_id}/readings
  //
  // The gateway routes data-management under `/api/v1/data/` and strips that
  // prefix; the service itself serves `/api/v1/sensors/...`, hence the doubled
  // `/api/v1` in the public path.
  // ---------------------------------------------------------------------------

  /// Fetches paginated readings for a single sensor.
  ///
  /// [from] / [to] are optional UTC date-time bounds.
  /// [sensorType] narrows results when a sensor hosts multiple types.
  /// [fixQuality] filters GNSS readings by fix quality (e.g. `"rtk_fixed"`).
  /// [limit] defaults to 500 if not provided.
  Future<PagedResponse<ReadingDto>> getSensorReadings({
    required String sensorId,
    DateTime? from,
    DateTime? to,
    String? sensorType,
    String? fixQuality,
    int offset = 0,
    int limit = 500,
  }) async {
    try {
      final params = <String, dynamic>{
        'offset': offset,
        'limit': limit,
        if (from case final f?) 'from': f.toUtc().toIso8601String(),
        if (to case final t?) 'to': t.toUtc().toIso8601String(),
        // ignore: use_null_aware_elements
        if (sensorType != null) 'sensor_type': sensorType,
        // ignore: use_null_aware_elements
        if (fixQuality != null) 'fix_quality': fixQuality,
      };

      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/data/api/v1/sensors/$sensorId/readings',
        queryParameters: params,
      );

      return PagedResponse.fromJson(res.data!);
    } catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch-all helper (automatic pagination)
  // ---------------------------------------------------------------------------

  /// Fetches **all** readings for a sensor in the given window, automatically
  /// issuing additional parallel requests when the server has more pages.
  ///
  /// Use this instead of [getSensorReadings] whenever the result count may
  /// exceed one page (e.g. rainfall at 5-min intervals over a week = ~2 000
  /// rows; GNSS over 6 months = ~4 000 rows).
  ///
  /// [pageSize] controls how many rows are requested per HTTP call (max the
  /// server allows — currently 1 000).
  Future<List<ReadingDto>> getAllSensorReadings({
    required String sensorId,
    DateTime? from,
    DateTime? to,
    String? sensorType,
    String? fixQuality,
    int pageSize = 1000,
  }) async {
    // First page — also tells us the total row count.
    final first = await getSensorReadings(
      sensorId: sensorId,
      from: from,
      to: to,
      sensorType: sensorType,
      fixQuality: fixQuality,
      offset: 0,
      limit: pageSize,
    );

    if (first.total <= first.items.length) return first.items;

    // How many additional pages do we need?
    final remaining = first.total - first.items.length;
    final extraPages = (remaining / pageSize).ceil();

    // Fetch them all in parallel.
    final futures = List.generate(
      extraPages,
      (i) => getSensorReadings(
        sensorId: sensorId,
        from: from,
        to: to,
        sensorType: sensorType,
        fixQuality: fixQuality,
        offset: first.items.length + i * pageSize,
        limit: pageSize,
      ),
    );

    final pages = await Future.wait(futures);

    return [
      ...first.items,
      for (final page in pages) ...page.items,
    ];
  }
}
