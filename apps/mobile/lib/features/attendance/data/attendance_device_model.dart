import 'package:flutter/material.dart';

enum DeviceConnectionType {
  tcpIp('TCP_IP', 'TCP/IP (Direct Socket)', Icons.settings_ethernet),
  http('HTTP', 'HTTP / REST API', Icons.http_rounded),
  cloud('CLOUD', 'Cloud Gateway', Icons.cloud_outlined),
  usb('USB', 'USB Interface', Icons.usb_rounded),
  serial('SERIAL', 'RS485 / Serial', Icons.cable_rounded);

  final String value;
  final String label;
  final IconData icon;
  const DeviceConnectionType(this.value, this.label, this.icon);

  static DeviceConnectionType fromString(String? val) {
    return DeviceConnectionType.values.firstWhere(
      (e) => e.value.toUpperCase() == (val ?? '').toUpperCase(),
      orElse: () => DeviceConnectionType.tcpIp,
    );
  }
}

enum DeviceBiometricType {
  fingerprintFace('FINGERPRINT_FACE', 'Face & Fingerprint', Icons.face_retouching_natural),
  face('FACE', 'AI Facial Recognition', Icons.face_rounded),
  fingerprint('FINGERPRINT', 'Optical Fingerprint', Icons.fingerprint_rounded),
  rfid('RFID', 'RFID / Proximity Card', Icons.nfc_rounded),
  card('CARD', 'Smart Card', Icons.credit_card_rounded);

  final String value;
  final String label;
  final IconData icon;
  const DeviceBiometricType(this.value, this.label, this.icon);

  static DeviceBiometricType fromString(String? val) {
    return DeviceBiometricType.values.firstWhere(
      (e) => e.value.toUpperCase() == (val ?? '').toUpperCase(),
      orElse: () => DeviceBiometricType.fingerprintFace,
    );
  }
}

class BiometricDevice {
  final String id;
  final String deviceCode;
  final String deviceName;
  final String deviceType;
  final String manufacturer;
  final String? model;
  final String? serialNumber;
  final String? ipAddress;
  final int port;
  final String connectionType;
  final String? apiEndpoint;
  final String? communicationKey;
  final bool isActive;
  final DateTime? lastSyncAt;
  final String? lastSyncStatus;
  final int lastSyncRecordCount;
  final String? lastSyncError;
  final int syncIntervalMinutes;
  final bool autoSyncEnabled;
  final String? location;
  final String? notes;

  const BiometricDevice({
    required this.id,
    required this.deviceCode,
    required this.deviceName,
    this.deviceType = 'FINGERPRINT_FACE',
    this.manufacturer = 'TeamOffice',
    this.model,
    this.serialNumber,
    this.ipAddress,
    this.port = 4370,
    this.connectionType = 'TCP_IP',
    this.apiEndpoint,
    this.communicationKey,
    this.isActive = true,
    this.lastSyncAt,
    this.lastSyncStatus,
    this.lastSyncRecordCount = 0,
    this.lastSyncError,
    this.syncIntervalMinutes = 15,
    this.autoSyncEnabled = true,
    this.location,
    this.notes,
  });

  DeviceConnectionType get connType => DeviceConnectionType.fromString(connectionType);
  DeviceBiometricType get bioType => DeviceBiometricType.fromString(deviceType);

  bool get isOnline {
    if (!isActive) return false;
    if (lastSyncStatus?.toUpperCase() == 'SUCCESS') return true;
    return false;
  }

  Color get statusColor {
    if (!isActive) return const Color(0xFF6B7280);
    switch (lastSyncStatus?.toUpperCase()) {
      case 'SUCCESS':
        return const Color(0xFF22C55E); // Green
      case 'FAILED':
        return const Color(0xFFEF4444); // Red
      case 'PARTIAL':
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFF38BDF8); // Blue/Pending
    }
  }

  String get statusLabel {
    if (!isActive) return 'DISABLED';
    switch (lastSyncStatus?.toUpperCase()) {
      case 'SUCCESS':
        return 'ONLINE & SYNCED';
      case 'FAILED':
        return 'SYNC FAILED';
      case 'PARTIAL':
        return 'PARTIAL SYNC';
      default:
        return 'READY / STANDBY';
    }
  }

  factory BiometricDevice.fromJson(Map<String, dynamic> json) {
    return BiometricDevice(
      id: json['id']?.toString() ?? '',
      deviceCode: json['deviceCode']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? 'Biometric Device',
      deviceType: json['deviceType']?.toString() ?? 'FINGERPRINT_FACE',
      manufacturer: json['manufacturer']?.toString() ?? 'TeamOffice',
      model: json['model']?.toString(),
      serialNumber: json['serialNumber']?.toString(),
      ipAddress: json['ipAddress']?.toString(),
      port: (json['port'] is num) ? (json['port'] as num).toInt() : 4370,
      connectionType: json['connectionType']?.toString() ?? 'TCP_IP',
      apiEndpoint: json['apiEndpoint']?.toString(),
      communicationKey: json['communicationKey']?.toString(),
      isActive: json['isActive'] == true || json['isActive'] == 1,
      lastSyncAt: json['lastSyncAt'] != null ? DateTime.tryParse(json['lastSyncAt'].toString()) : null,
      lastSyncStatus: json['lastSyncStatus']?.toString(),
      lastSyncRecordCount: (json['lastSyncRecordCount'] is num) ? (json['lastSyncRecordCount'] as num).toInt() : 0,
      lastSyncError: json['lastSyncError']?.toString(),
      syncIntervalMinutes: (json['syncIntervalMinutes'] is num) ? (json['syncIntervalMinutes'] as num).toInt() : 15,
      autoSyncEnabled: json['autoSyncEnabled'] == true || json['autoSyncEnabled'] == 1,
      location: json['location']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceCode': deviceCode,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'manufacturer': manufacturer,
      'model': model,
      'serialNumber': serialNumber,
      'ipAddress': ipAddress,
      'port': port,
      'connectionType': connectionType,
      'apiEndpoint': apiEndpoint,
      'communicationKey': communicationKey,
      'isActive': isActive,
      'syncIntervalMinutes': syncIntervalMinutes,
      'autoSyncEnabled': autoSyncEnabled,
      'location': location,
      'notes': notes,
    };
  }
}

class DeviceSyncLog {
  final String id;
  final String deviceId;
  final String deviceCode;
  final String syncType;
  final String syncStatus;
  final int recordsFetched;
  final int recordsInserted;
  final int recordsSkipped;
  final int recordsUpdated;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? durationMs;

  const DeviceSyncLog({
    required this.id,
    required this.deviceId,
    required this.deviceCode,
    required this.syncType,
    required this.syncStatus,
    this.recordsFetched = 0,
    this.recordsInserted = 0,
    this.recordsSkipped = 0,
    this.recordsUpdated = 0,
    this.errorMessage,
    required this.startedAt,
    this.completedAt,
    this.durationMs,
  });

  bool get isSuccess => syncStatus.toUpperCase() == 'SUCCESS';

  Color get statusColor {
    switch (syncStatus.toUpperCase()) {
      case 'SUCCESS':
        return const Color(0xFF22C55E);
      case 'FAILED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  factory DeviceSyncLog.fromJson(Map<String, dynamic> json) {
    return DeviceSyncLog(
      id: json['id']?.toString() ?? '',
      deviceId: json['deviceId']?.toString() ?? '',
      deviceCode: json['deviceCode']?.toString() ?? '',
      syncType: json['syncType']?.toString() ?? 'AUTO',
      syncStatus: json['syncStatus']?.toString() ?? 'PENDING',
      recordsFetched: (json['recordsFetched'] is num) ? (json['recordsFetched'] as num).toInt() : 0,
      recordsInserted: (json['recordsInserted'] is num) ? (json['recordsInserted'] as num).toInt() : 0,
      recordsSkipped: (json['recordsSkipped'] is num) ? (json['recordsSkipped'] as num).toInt() : 0,
      recordsUpdated: (json['recordsUpdated'] is num) ? (json['recordsUpdated'] as num).toInt() : 0,
      errorMessage: json['errorMessage']?.toString(),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ?? DateTime.now(),
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt'].toString()) : null,
      durationMs: (json['durationMs'] is num) ? (json['durationMs'] as num).toInt() : null,
    );
  }
}

