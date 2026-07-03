import 'package:freezed_annotation/freezed_annotation.dart';

part 'device.freezed.dart';
part 'device.g.dart';

/// Request body for POST /api/v1/users/{user_id}/devices.
@freezed
abstract class DeviceRegisterRequest with _$DeviceRegisterRequest {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
  const factory DeviceRegisterRequest({
    required String deviceToken,
    required String platform,
    String? appVersion,
  }) = _DeviceRegisterRequest;

  factory DeviceRegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$DeviceRegisterRequestFromJson(json);
}

/// Response body for POST /api/v1/users/{user_id}/devices (200 or 201).
@freezed
abstract class DeviceRegisterResponse with _$DeviceRegisterResponse {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory DeviceRegisterResponse({
    required int deviceId,
  }) = _DeviceRegisterResponse;

  factory DeviceRegisterResponse.fromJson(Map<String, dynamic> json) =>
      _$DeviceRegisterResponseFromJson(json);
}
