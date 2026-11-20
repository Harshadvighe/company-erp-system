import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:saark_erp_mobile/core/storage/app_storage.dart';

/// Representation of an assignable ERP Module or Industrial Model
class ErpModuleDefinition {
  final String key;
  final String title;
  final IconData icon;
  final String category;
  final String? route;

  const ErpModuleDefinition({
    required this.key,
    required this.title,
    required this.icon,
    this.category = 'Core Operations',
    this.route,
  });

  static IconData resolveIcon(dynamic iconValue) {
    if (iconValue is int) {
      if (iconValue == Icons.precision_manufacturing_rounded.codePoint) return Icons.precision_manufacturing_rounded;
      if (iconValue == Icons.engineering_rounded.codePoint) return Icons.engineering_rounded;
      if (iconValue == Icons.settings_suggest_rounded.codePoint) return Icons.settings_suggest_rounded;
      if (iconValue == Icons.memory_rounded.codePoint) return Icons.memory_rounded;
      if (iconValue == Icons.architecture_rounded.codePoint) return Icons.architecture_rounded;
      if (iconValue == Icons.devices_other_rounded.codePoint) return Icons.devices_other_rounded;
      if (iconValue == Icons.water_drop_rounded.codePoint) return Icons.water_drop_rounded;
      if (iconValue == Icons.bolt_rounded.codePoint) return Icons.bolt_rounded;
    }
    return Icons.extension_rounded;
  }

  Map<String, dynamic> toMap() => {
        'key': key,
        'title': title,
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
        'category': category,
        'route': route,
      };

  factory ErpModuleDefinition.fromMap(Map<String, dynamic> map) {
    return ErpModuleDefinition(
      key: map['key'] ?? '',
      title: map['title'] ?? map['key'] ?? '',
      icon: resolveIcon(map['iconCodePoint']),
      category: map['category'] ?? 'Custom Models & Modules',
      route: map['route'],
    );
  }
}

/// Central registry managing standard and dynamically created ERP modules/models
class ErpModulesRegistry {
  static const String _storageKey = 'custom_erp_modules_registry_v1';

  // ── Standard Built-in Operations & Industrial Models ────────────────────────
  static const List<ErpModuleDefinition> defaultModules = [
    // ── 1. Core Enterprise Operations ──
    ErpModuleDefinition(
      key: 'SALES_MARKETING',
      title: 'Sales & Marketing',
      icon: Icons.campaign_rounded,
      category: 'Core Operations',
      route: '/sales-marketing',
    ),
    ErpModuleDefinition(
      key: 'B2B_TRADING',
      title: 'B2B Trading & Marketplace',
      icon: Icons.storefront_rounded,
      category: 'Core Operations',
      route: '/crm/enquiries',
    ),
    ErpModuleDefinition(
      key: 'CUSTOMER_CRM',
      title: 'CRM & Lead Management',
      icon: Icons.inbox_rounded,
      category: 'Core Operations',
      route: '/crm/dashboard',
    ),
    ErpModuleDefinition(
      key: 'PRODUCTION',
      title: 'Production Process',
      icon: Icons.precision_manufacturing_rounded,
      category: 'Core Operations',
      route: '/production',
    ),
    ErpModuleDefinition(
      key: 'QUALITY_CONTROL',
      title: 'Quality Control (QC/QA)',
      icon: Icons.verified_rounded,
      category: 'Core Operations',
      route: '/production/management',
    ),
    ErpModuleDefinition(
      key: 'PROJECTS',
      title: 'Project Management',
      icon: Icons.folder_open_rounded,
      category: 'Core Operations',
      route: '/projects',
    ),
    ErpModuleDefinition(
      key: 'TASKS',
      title: 'Task Manager',
      icon: Icons.task_alt_rounded,
      category: 'Core Operations',
      route: '/tasks',
    ),
    ErpModuleDefinition(
      key: 'ACCOUNTS',
      title: 'Accounts & Finance',
      icon: Icons.account_balance_rounded,
      category: 'Core Operations',
      route: '/accounts',
    ),
    ErpModuleDefinition(
      key: 'HR',
      title: 'HR (Human Resources)',
      icon: Icons.people_alt_rounded,
      category: 'Core Operations',
      route: '/hr',
    ),
    ErpModuleDefinition(
      key: 'ATTENDANCE',
      title: 'Attendance & Biometrics',
      icon: Icons.access_time_rounded,
      category: 'Core Operations',
      route: '/attendance',
    ),
    ErpModuleDefinition(
      key: 'PURCHASE',
      title: 'Purchase & Procurement',
      icon: Icons.shopping_bag_rounded,
      category: 'Core Operations',
      route: '/purchase/orders',
    ),
    ErpModuleDefinition(
      key: 'INVENTORY',
      title: 'Stores & Warehouse',
      icon: Icons.warehouse_rounded,
      category: 'Core Operations',
      route: '/inventory',
    ),
    ErpModuleDefinition(
      key: 'MAINTENANCE',
      title: 'Maintenance & Service',
      icon: Icons.home_repair_service_rounded,
      category: 'Core Operations',
      route: '/my-work',
    ),
    ErpModuleDefinition(
      key: 'RESEARCH_DEVELOPMENT',
      title: 'R&D / Engineering',
      icon: Icons.science_rounded,
      category: 'Core Operations',
      route: '/production/specs',
    ),
    ErpModuleDefinition(
      key: 'ASSET_MANAGEMENT',
      title: 'Asset Management',
      icon: Icons.domain_rounded,
      category: 'Core Operations',
      route: '/inventory?view=assets',
    ),
    ErpModuleDefinition(
      key: 'ADMINISTRATION',
      title: 'Administration & IT',
      icon: Icons.admin_panel_settings_rounded,
      category: 'Core Operations',
      route: '/admin',
    ),

    // ── 2. Industrial Panel Models & Engineering Calculators ──
    ErpModuleDefinition(
      key: 'PANEL_MANUFACTURING',
      title: 'Panel Manufacturing & BOM',
      icon: Icons.electrical_services_rounded,
      category: 'Panel Models & Design',
      route: '/production/new',
    ),
    ErpModuleDefinition(
      key: 'BOOSTER_PUMP',
      title: 'Booster Pump Panel Calculator',
      icon: Icons.speed_rounded,
      category: 'Panel Models & Design',
      route: '/production/booster-pump-calculator',
    ),
    ErpModuleDefinition(
      key: 'STP_PANEL',
      title: 'STP Automation Panel Model',
      icon: Icons.water_drop_rounded,
      category: 'Panel Models & Design',
      route: '/production/specs',
    ),
    ErpModuleDefinition(
      key: 'HYPN_PANEL',
      title: 'HYPN Booster Panel Model',
      icon: Icons.compress_rounded,
      category: 'Panel Models & Design',
      route: '/production/booster-pump-calculator',
    ),
    ErpModuleDefinition(
      key: 'WTP_PANEL',
      title: 'WTP Water Treatment Panel Model',
      icon: Icons.waves_rounded,
      category: 'Panel Models & Design',
      route: '/production/specs',
    ),
    ErpModuleDefinition(
      key: 'DEWATERING_PANEL',
      title: 'Dewatering Pump Panel Model',
      icon: Icons.plumbing_rounded,
      category: 'Panel Models & Design',
      route: '/production/specs',
    ),
    ErpModuleDefinition(
      key: 'FIRE_FIGHTING_PANEL',
      title: 'Fire Fighting Panel Model',
      icon: Icons.local_fire_department_rounded,
      category: 'Panel Models & Design',
      route: '/production/specs',
    ),
    ErpModuleDefinition(
      key: 'VFD_PANEL',
      title: 'VFD Automation Panel Model',
      icon: Icons.electric_meter_rounded,
      category: 'Panel Models & Design',
      route: '/production/specs',
    ),
    ErpModuleDefinition(
      key: 'MCC_PCC_PANEL',
      title: 'MCC / PCC Control Panels',
      icon: Icons.developer_board_rounded,
      category: 'Panel Models & Design',
      route: '/production/specs',
    ),
    ErpModuleDefinition(
      key: 'PRODUCT_DEVELOPMENT',
      title: 'Saark Product Sector & NPD',
      icon: Icons.inventory_2_rounded,
      category: 'Panel Models & Design',
      route: '/products',
    ),
    ErpModuleDefinition(
      key: 'WATER_METER',
      title: 'Water Meter & Flow Instrumentation',
      icon: Icons.tune_rounded,
      category: 'Panel Models & Design',
      route: '/products',
    ),
    ErpModuleDefinition(
      key: 'BMS',
      title: 'Building Management Systems (BMS)',
      icon: Icons.apartment_rounded,
      category: 'Panel Models & Design',
      route: '/products',
    ),
  ];

  /// Loads all modules merging default modules, persistent custom modules, and currently assigned modules
  static Future<List<ErpModuleDefinition>> loadAllModules({List<String>? includeAssigned}) async {
    final Map<String, ErpModuleDefinition> map = {
      for (final m in defaultModules) m.key: m,
    };

    // 1. Read registered custom modules from persistent storage
    try {
      final savedStr = await AppStorage.read(_storageKey);
      if (savedStr != null && savedStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(savedStr);
        for (final item in list) {
          if (item is Map<String, dynamic> && item['key'] != null) {
            final def = ErpModuleDefinition.fromMap(item);
            map[def.key] = def;
          }
        }
      }
    } catch (_) {}

    // 2. Automatically include any module already assigned to employees in the database
    if (includeAssigned != null) {
      for (final assigned in includeAssigned) {
        if (!map.containsKey(assigned) && assigned.isNotEmpty) {
          final cleanTitle = assigned
              .replaceAll('_', ' ')
              .split(' ')
              .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}' : '')
              .join(' ');
          map[assigned] = ErpModuleDefinition(
            key: assigned,
            title: cleanTitle,
            icon: Icons.extension_rounded,
            category: 'Assigned / Custom Models',
          );
        }
      }
    }

    return map.values.toList();
  }

  /// Registers and saves a new custom module or model permanently
  static Future<ErpModuleDefinition> registerCustomModule({
    required String title,
    String? customKey,
    IconData? icon,
    String? category,
    String? route,
  }) async {
    final key = (customKey != null && customKey.trim().isNotEmpty)
        ? customKey.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_]'), '_')
        : title.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_]'), '_');

    final newDef = ErpModuleDefinition(
      key: key,
      title: title.trim(),
      icon: icon ?? Icons.extension_rounded,
      category: category ?? 'Custom Models & Modules',
      route: route ?? '/dashboard',
    );

    try {
      final current = await loadAllModules();
      final customList = current
          .where((m) => !defaultModules.any((d) => d.key == m.key))
          .map((m) => m.toMap())
          .toList();

      if (!customList.any((m) => m['key'] == key)) {
        customList.add(newDef.toMap());
        await AppStorage.write(_storageKey, jsonEncode(customList));
      }
    } catch (_) {}

    return newDef;
  }
}

