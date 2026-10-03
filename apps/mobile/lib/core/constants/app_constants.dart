import 'package:flutter/foundation.dart';

class AppConstants {
  // Permanent Tailscale URL - Works globally on 4G/5G mobile data & Wi-Fi anywhere
  static const String defaultPublicUrl = 'http://100.66.50.111:3000';
  static const String localWifiUrl = 'http://192.168.1.104:3000';
  static String? customServerUrl;

  // API - Dynamically routes whether on Web or Mobile
  static String get baseUrl {
    if (customServerUrl != null && customServerUrl!.isNotEmpty) {
      final clean = customServerUrl!.trim().replaceAll(RegExp(r'/+$'), '');
      return clean.endsWith('/api/v1') ? clean : '$clean/api/v1';
    }
    if (kIsWeb) {
      if (Uri.base.scheme == 'https' || Uri.base.port == 3000) {
        return '${Uri.base.origin}/api/v1';
      }
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      return 'http://$host:3000/api/v1';
    }
    // Mobile Physical Device default to Local Wi-Fi (can be switched to Tailscale or Tunnel in Login UI)
    return '$localWifiUrl/api/v1';
  }

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userProfileKey = 'user_profile';
  static const String themeKey = 'selected_theme';

  // Pagination
  static const int defaultPageSize = 25;

  // Timeouts
  static const int connectionTimeout = 30000;
  static const int receiveTimeout = 30000;

  // Customer Types
  static const List<String> customerTypes = [
    'END_CUSTOMER',
    'DEALER',
    'DISTRIBUTOR',
    'OEM',
    'GOVERNMENT',
    'OTHER',
  ];

  // Lead Statuses
  static const List<String> leadStatuses = [
    'NEW',
    'CONTACTED',
    'QUALIFIED',
    'PROPOSAL',
    'NEGOTIATION',
    'WON',
    'LOST',
  ];

  // Enquiry Statuses
  static const List<String> enquiryStatuses = [
    'PENDING',
    'QUOTED',
    'CLOSED_WON',
    'CLOSED_LOST',
  ];

  // Priority Levels
  static const List<String> priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];

  // Interaction Types
  static const List<String> interactionTypes = [
    'CALL',
    'EMAIL',
    'WHATSAPP',
    'MEETING',
    'VISIT',
    'DEMO',
    'FOLLOWUP',
    'OTHER',
  ];

  // Product Types
  static const List<String> productTypes = [
    'FINISHED_PRODUCT',
    'RAW_MATERIAL',
    'COMPONENT',
    'SERVICE',
    'CONSUMABLE',
    'SPARE_PART',
  ];

  // Products of Interest (Saark Specific)
  static const List<String> productsOfInterest = [
    'Booster Pump',
    'Water Meter',
    'WTP',
    'STP',
    'RO',
    'BMS',
    'Fire Panel',
    'VFD Panel',
    'Dewatering Panel',
    'HVAC',
    'HVAC Chiller Panel',
    'Water Softener',
    'Water Analyzer',
    'Air Quality Sensor',
    'Particulate Matter Module',
    'Datalogger',
    'Sensor Panel',
    'Pump Skid',
    'Other',
  ];

  // Lead Sources
  static const List<String> leadSources = [
    'DIRECT',
    'REFERRAL',
    'EXHIBITION',
    'WEBSITE',
    'COLD_CALL',
    'SOCIAL_MEDIA',
    'TENDER',
    'OTHER',
  ];
}
