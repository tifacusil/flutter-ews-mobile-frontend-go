/// A single sensor reading returned by the Readings Service.
///
/// [payload] is a raw JSON map whose shape depends on [sensorType].
/// Pass it directly to the typed payload fromJson, e.g.:
///   `GnssPayload.fromJson(reading.payload)`
class ReadingDto {
  const ReadingDto({
    required this.projectId,
    required this.sensorId,
    required this.sensorType,
    required this.timestamp,
    this.receivedAt,
    required this.payload,
  });

  final String projectId;
  final String sensorId;
  final String sensorType;
  final DateTime timestamp;
  final DateTime? receivedAt;

  /// Raw payload — shape varies by [sensorType].
  final Map<String, dynamic> payload;

  factory ReadingDto.fromJson(Map<String, dynamic> json) => ReadingDto(
        projectId: (json['project_id'] as String?) ?? '',
        sensorId: (json['sensor_id'] as String?) ?? '',
        sensorType: (json['sensor_type'] as String?) ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.fromMillisecondsSinceEpoch(0),
        receivedAt: json['received_at'] != null
            ? DateTime.tryParse(json['received_at'] as String)
            : null,
        payload: (json['payload'] as Map<String, dynamic>?) ?? {},
      );
}

/// Paginated wrapper returned by the Readings Service list endpoints.
class PagedResponse<T> {
  const PagedResponse({
    required this.total,
    required this.offset,
    required this.limit,
    required this.items,
  });

  final int total;
  final int offset;
  final int limit;
  final List<T> items;

  static PagedResponse<ReadingDto> fromJson(Map<String, dynamic> json) =>
      PagedResponse<ReadingDto>(
        total: (json['total'] as num?)?.toInt() ?? 0,
        offset: (json['offset'] as num?)?.toInt() ?? 0,
        limit: (json['limit'] as num?)?.toInt() ?? 0,
        items: ((json['items'] as List<dynamic>?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(ReadingDto.fromJson)
            .toList(),
      );
}
