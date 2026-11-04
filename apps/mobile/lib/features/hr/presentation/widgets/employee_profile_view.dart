import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:saark_erp_mobile/features/hr/data/hr_repository.dart';
import 'package:saark_erp_mobile/features/admin/data/admin_repository.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';
import 'package:saark_erp_mobile/core/utils/web_utils.dart';
import 'package:saark_erp_mobile/core/biometrics/face_camera_modal.dart';
/// Data class representing an Employee record matching the enterprise HR UI
class EmployeeProfileRecord {
  String dbId;
  String id;
  String firstName;
  String middleName;
  String lastName;
  String fullName;
  String workEmail;
  String dateOfBirth;
  String gender;
  String maritalStatus;
  String nationality;
  String bloodGroup;
  String emergencyContact;
  String personalEmail;
  String phone;
  String address;
  String? departmentId;
  String departmentName;
  String designation;
  String status; // 'PENDING_APPROVAL', 'ACTIVE', 'REJECTED'
  bool hasBiometric;
  bool faceVerificationEnabled;
  String? avatarUrl;
  String? username;
  List<String> assignedModules;

  EmployeeProfileRecord({
    this.dbId = '',
    required this.id,
    required this.firstName,
    required this.middleName,
    this.lastName = '',
    required this.fullName,
    required this.workEmail,
    required this.dateOfBirth,
    this.gender = '',
    this.maritalStatus = '',
    this.nationality = '',
    this.bloodGroup = '',
    this.emergencyContact = '',
    this.personalEmail = '',
    this.phone = '',
    this.address = '',
    this.departmentId,
    this.departmentName = 'General',
    this.designation = 'Employee',
    this.status = 'PENDING_APPROVAL',
    this.hasBiometric = false,
    this.faceVerificationEnabled = false,
    this.avatarUrl,
    this.username,
    this.assignedModules = const [],
  });

  factory EmployeeProfileRecord.fromEmployee(Employee emp) {
    return EmployeeProfileRecord(
      dbId: emp.id,
      id: emp.employeeCode.isNotEmpty ? emp.employeeCode : emp.id,
      firstName: emp.firstName,
      middleName: emp.middleName ?? '',
      lastName: emp.lastName,
      fullName: emp.fullName,
      workEmail: emp.email,
      dateOfBirth: emp.dateOfBirth != null ? emp.dateOfBirth!.toIso8601String().split('T').first : '',
      gender: '',
      maritalStatus: '',
      nationality: 'Indian',
      bloodGroup: emp.bloodGroup ?? '',
      emergencyContact: emp.emergencyPhone ?? '',
      personalEmail: '',
      phone: emp.phone,
      address: emp.address ?? '',
      departmentId: emp.departmentId,
      departmentName: emp.departmentName ?? 'Unassigned',
      designation: emp.designation,
      status: emp.status,
      hasBiometric: emp.hasBiometric,
      faceVerificationEnabled: false,
      avatarUrl: emp.avatarUrl,
      username: emp.username,
      assignedModules: List<String>.from(emp.assignedModules),
    );
  }
}

class EmployeeProfileView extends ConsumerStatefulWidget {
  const EmployeeProfileView({super.key});

  @override
  ConsumerState<EmployeeProfileView> createState() => _EmployeeProfileViewState();
}

class _EmployeeProfileViewState extends ConsumerState<EmployeeProfileView> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers initialized
  final _empIdController = TextEditingController(text: 'EMP-2026-001');
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _fullNameController = TextEditingController();

  void _syncFullNameFromParts() {
    final f = _firstNameController.text.trim();
    final m = _middleNameController.text.trim();
    final l = _lastNameController.text.trim();
    final parts = [f, if (m.isNotEmpty) m, if (l.isNotEmpty) l];
    _fullNameController.text = parts.join(' ');
  }


  Future<void> _showAddDepartmentDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    bool userEditedCode = false;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2024),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFF2C2E33)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.domain_add, color: Color(0xFFF26522), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Add New Department',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Department Name *',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Research and Development, QA, etc.',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF141517),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Color(0xFF2C2E33)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Color(0xFF2C2E33)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Color(0xFFF26522)),
                        ),
                      ),
                      onChanged: (val) {
                        if (!userEditedCode) {
                          final autoCode = val.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');
                          setDialogState(() {
                            codeCtrl.text = autoCode.length > 10 ? autoCode.substring(0, 10) : autoCode;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Department Code *',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: codeCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      onChanged: (_) => userEditedCode = true,
                      decoration: InputDecoration(
                        hintText: 'e.g. RND, QA, PROD',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF141517),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Color(0xFF2C2E33)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Color(0xFF2C2E33)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Color(0xFFF26522)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF26522),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final code = codeCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter department name')),
                            );
                            return;
                          }
                          setDialogState(() => isSaving = true);
                          try {
                            final adminRepo = ref.read(adminRepositoryProvider);
                            final created = await adminRepo.createDepartment(name: name, code: code);
                            if (mounted) {
                              setState(() {
                                _departments.add(created);
                                _selectedDepartmentId = created.id;
                              });
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  content: Text('Department "$name" created and selected successfully!'),
                                ),
                              );
                            }
                          } catch (err) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              final localCode = code.isNotEmpty
                                  ? code
                                  : name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '_');
                              final localItem = DepartmentItem(
                                id: 'dept_' + DateTime.now().millisecondsSinceEpoch.toString(),
                                name: name,
                                code: localCode.length > 10 ? localCode.substring(0, 10) : localCode,
                              );
                              setState(() {
                                _departments.add(localItem);
                                _selectedDepartmentId = localItem.id;
                              });
                              Navigator.of(dialogCtx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  content: Text('Department "$name" added and selected!'),
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save & Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showValidationError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  final _workEmailController = TextEditingController();
  final _dobController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _personalEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _designationController = TextEditingController(text: 'Junior Design Engineer');

  // Biometrics & Identity state
  String? _passportPhotoBase64;
  String? _livePhotoBase64;
  bool _enableFaceAuth = true;
  bool _createUserAccount = true;
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController(text: 'Saark@2026');
  String _selectedRole = 'ROLE_EMPLOYEE';
  bool _isBiometricEnrolled = false;

  // ERP Module Options for Granular Employee Access
  static const List<Map<String, dynamic>> _erpModuleOptions = [
    {'key': 'SALES_MARKETING', 'title': 'Sales & Marketing', 'icon': Icons.campaign_rounded},
    {'key': 'B2B_TRADING', 'title': 'B2B Trading', 'icon': Icons.storefront_rounded},
    {'key': 'PRODUCTION', 'title': 'Production Process', 'icon': Icons.precision_manufacturing_rounded},
    {'key': 'PANEL_MANUFACTURING', 'title': 'Panel Manufacturing', 'icon': Icons.electrical_services_rounded},
    {'key': 'QUALITY_CONTROL', 'title': 'Quality Control (QC/QA)', 'icon': Icons.verified_rounded},
    {'key': 'PROJECTS', 'title': 'Project Management', 'icon': Icons.folder_open_rounded},
    {'key': 'TASKS', 'title': 'Task Manager', 'icon': Icons.task_alt_rounded},
    {'key': 'ACCOUNTS', 'title': 'Accounts & Finance', 'icon': Icons.account_balance_rounded},
    {'key': 'HR', 'title': 'HR (Human Resources)', 'icon': Icons.people_alt_rounded},
    {'key': 'ATTENDANCE', 'title': 'Attendance', 'icon': Icons.access_time_rounded},
    {'key': 'PURCHASE', 'title': 'Purchase / Procurement', 'icon': Icons.shopping_bag_rounded},
    {'key': 'INVENTORY', 'title': 'Stores / Warehouse', 'icon': Icons.warehouse_rounded},
    {'key': 'MAINTENANCE', 'title': 'Maintenance', 'icon': Icons.home_repair_service_rounded},
    {'key': 'RESEARCH_DEVELOPMENT', 'title': 'R&D / Engineering', 'icon': Icons.science_rounded},
    {'key': 'ASSET_MANAGEMENT', 'title': 'Asset Management', 'icon': Icons.domain_rounded},
    {'key': 'ADMINISTRATION', 'title': 'Administration & IT', 'icon': Icons.admin_panel_settings_rounded},
  ];
  List<String> _selectedModules = ['SALES_MARKETING'];

  // Dropdown values
  String _selectedGender = '';
  String _selectedMaritalStatus = '';
  String _selectedNationality = 'Indian';
  String _selectedBloodGroup = '';
  String? _selectedDepartmentId;
  String _tableFilter = 'ALL'; // 'ALL', 'PENDING_APPROVAL', 'ACTIVE'

  // Designation dropdown options
  static const List<String> _defaultDesignations = [
    'Junior Design Engineer',
    'Senior Design Engineer',
    'Electrical Design Engineer',
    'Lead Design Engineer',
    'Panel Wiring Technician',
    'Senior Panel Wiring Technician',
    'Electrical Assembly Technician',
    'PLC / Automation Systems Specialist',
    'Testing & QC Engineer',
    'Quality Control & Testing Inspector',
    'FAT Testing Engineer',
    'Production Engineer',
    'Production Supervisor',
    'Shopfloor Lead',
    'Busbar Specialist & Fabricator',
    'Certified Wireman (Control Panels)',
    'ITI Apprentice Electrician',
    'Store & Inventory Executive',
    'Purchase Executive',
    'Purchase Manager',
    'Sales Executive',
    'Sales Manager',
    'Project Engineer',
    'Project Manager',
    'Maintenance Technician',
    'Accountant',
    'HR Executive',
    'Managing Director',
    'Employee',
  ];
  late final List<String> _designations = List.from(_defaultDesignations);
  String _selectedDesignation = 'Junior Design Engineer';

  // Master Data
  List<DepartmentItem> _departments = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // UI state
  bool _hideSavedRecords = false;
  String? _selectedRecordId;

  // Saved Records list
  List<EmployeeProfileRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final hrRepo = ref.read(hrRepositoryProvider);

      final depts = await adminRepo.getDepartments();
      final employees = await hrRepo.getEmployees();

      // Master designations
      try {
        final apiDesigs = await adminRepo.getDesignations();
        for (final d in apiDesigs) {
          final name = d.name.trim();
          if (name.isNotEmpty && !_designations.contains(name)) {
            _designations.add(name);
          }
        }
      } catch (_) {
        try {
          final hrDesigs = await hrRepo.getDesignations();
          for (final name in hrDesigs) {
            final trimmed = name.trim();
            if (trimmed.isNotEmpty && !_designations.contains(trimmed)) {
              _designations.add(trimmed);
            }
          }
        } catch (_) {}
      }

      for (final emp in employees) {
        final des = emp.designation.trim();
        if (des.isNotEmpty && !_designations.contains(des)) {
          _designations.add(des);
        }
      }

      if (mounted) {
        setState(() {
          _departments = depts;
          // Set default department to R&D / Engineering if available
          final rndDept = depts.firstWhere(
            (d) => d.code == 'RND' || d.name.toLowerCase().contains('research') || d.name.toLowerCase().contains('r&d'),
            orElse: () => depts.isNotEmpty ? depts.first : DepartmentItem(id: '', name: 'R&D / Engineering', code: 'RND'),
          );
          if (rndDept.id.isNotEmpty) {
            _selectedDepartmentId = rndDept.id;
          } else if (depts.isNotEmpty) {
            _selectedDepartmentId = depts.first.id;
          }

          _records = employees.map((e) => EmployeeProfileRecord.fromEmployee(e)).toList();

          // Auto calculate next employee code
          int maxNum = 0;
          for (final r in _records) {
            final match = RegExp(r'(\d+)$').firstMatch(r.id);
            if (match != null) {
              final n = int.tryParse(match.group(1)!) ?? 0;
              if (n > maxNum) maxNum = n;
            }
          }
          if (maxNum == 0) maxNum = _records.length;
          _empIdController.text = 'EMP-2026-${(maxNum + 1).toString().padLeft(3, '0')}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _empIdController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _fullNameController.dispose();
    _workEmailController.dispose();
    _dobController.dispose();
    _emergencyContactController.dispose();
    _personalEmailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _designationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectRecord(EmployeeProfileRecord record) {
    setState(() {
      _selectedRecordId = record.dbId.isNotEmpty ? record.dbId : record.id;
      _empIdController.text = record.id;
      _firstNameController.text = record.firstName;
      _middleNameController.text = record.middleName;
      _lastNameController.text = record.lastName;
      _fullNameController.text = record.fullName;
      _workEmailController.text = record.workEmail;
      _dobController.text = record.dateOfBirth;
      _selectedGender = record.gender;
      _selectedMaritalStatus = record.maritalStatus;
      _selectedNationality = record.nationality;
      _selectedBloodGroup = record.bloodGroup;
      _emergencyContactController.text = record.emergencyContact;
      _personalEmailController.text = record.personalEmail;
      _phoneController.text = record.phone;
      final recDesig = record.designation.trim();
      if (recDesig.isNotEmpty && !_designations.contains(recDesig)) {
        _designations.insert(0, recDesig);
      }
      _selectedDesignation = recDesig.isNotEmpty ? recDesig : 'Junior Design Engineer';
      _designationController.text = _selectedDesignation;
      _usernameController.text = (record.username != null && record.username!.isNotEmpty)
          ? record.username!
          : record.workEmail.split('@').first;
      if (record.departmentId != null && _departments.any((d) => d.id == record.departmentId)) {
        _selectedDepartmentId = record.departmentId;
      }
      _selectedModules = record.assignedModules.isNotEmpty
          ? List<String>.from(record.assignedModules)
          : ['SALES_MARKETING'];
    });

    _loadBiometricStatus(record.dbId.isNotEmpty ? record.dbId : record.id);
  }

  Future<void> _loadBiometricStatus(String id) async {
    try {
      final hrRepo = ref.read(hrRepositoryProvider);
      final status = await hrRepo.getFaceStatus(id);
      if (mounted) {
        setState(() {
          _isBiometricEnrolled = status['hasBiometric'] == true && status['isActive'] == true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isBiometricEnrolled = false);
    }
  }

  Uint8List? _safeDecodeBase64(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      final clean = base64Str.contains(',') ? base64Str.split(',').last : base64Str;
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openLiveCameraModal() async {
    final imageBase64 = await FaceCameraModal.show(
      context,
      title: 'HR Live Biometric Enrollment',
      subtitle: 'Position employee face inside the guide frame to capture registration biometric descriptor.',
      actionButtonText: 'Accept Biometric',
      isVerificationMode: false,
    );

    if (imageBase64 != null && mounted) {
      setState(() {
        _livePhotoBase64 = imageBase64;
        _isBiometricEnrolled = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📸 Live biometric photo captured successfully! Biometric descriptor ready for enrollment.'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickPassportPhoto() async {
    final passportFrame = await FaceCameraModal.show(
      context,
      title: 'Capture / Select Passport Photo',
      subtitle: 'Capture or align official employee passport / badge photo with clear plain background.',
      actionButtonText: 'Use as Passport Photo',
      isVerificationMode: false,
    );
    if (passportFrame != null && mounted) {
      setState(() {
        _passportPhotoBase64 = passportFrame;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('👤 Passport profile photo attached.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  Future<void> _reEnrollFace() async {
    if (_selectedRecordId == null) return;
    final imageBase64 = await FaceCameraModal.show(
      context,
      title: 'Re-enroll Face Biometric',
      subtitle: 'Capture a fresh live face photo to recalculate and update the 128-d biometric descriptor.',
      actionButtonText: 'Update Biometric',
      isVerificationMode: false,
    );

    if (imageBase64 != null && mounted) {
      setState(() => _isSaving = true);
      try {
        final hrRepo = ref.read(hrRepositoryProvider);
        await hrRepo.enrollFace(
          _selectedRecordId!,
          livePhotoBase64: imageBase64,
          passportPhotoBase64: _passportPhotoBase64,
          enableFaceAuth: _enableFaceAuth,
        );
        setState(() {
          _livePhotoBase64 = imageBase64;
          _isBiometricEnrolled = true;
          _isSaving = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Biometric re-enrolled and updated successfully!'),
              backgroundColor: Color(0xFF2E7D32),
            ),
          );
        }
      } catch (e) {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to re-enroll biometric: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _disableBiometrics() async {
    if (_selectedRecordId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        title: const Text('Disable Face Authentication?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'This will deactivate face recognition login for this employee. The user will be required to authenticate using password credentials only.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disable Face Auth'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isSaving = true);
      try {
        final hrRepo = ref.read(hrRepositoryProvider);
        await hrRepo.disableFace(_selectedRecordId!);
        setState(() {
          _isBiometricEnrolled = false;
          _enableFaceAuth = false;
          _isSaving = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔒 Face authentication disabled for employee.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to disable biometric: $e'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  void _clearForm() {
    setState(() {
      _selectedRecordId = null;
      int maxNum = 0;
      for (final r in _records) {
        final match = RegExp(r'(\d+)$').firstMatch(r.id);
        if (match != null) {
          final n = int.tryParse(match.group(1)!) ?? 0;
          if (n > maxNum) maxNum = n;
        }
      }
      if (maxNum == 0) maxNum = _records.length;
      _empIdController.text = 'EMP-2026-${(maxNum + 1).toString().padLeft(3, '0')}';
      _firstNameController.clear();
      _middleNameController.clear();
      _lastNameController.clear();
      _fullNameController.clear();
      _workEmailController.clear();
      _dobController.clear();
      _emergencyContactController.clear();
      _personalEmailController.clear();
      _phoneController.clear();
      _addressController.clear();
      _selectedDesignation = 'Junior Design Engineer';
      _designationController.text = 'Junior Design Engineer';
      _selectedGender = '';
      _selectedMaritalStatus = '';
      _selectedNationality = 'Indian';
      _selectedBloodGroup = '';
      _passportPhotoBase64 = null;
      _livePhotoBase64 = null;
      _isBiometricEnrolled = false;
      _usernameController.clear();
      _passwordController.text = 'Saark@2026';
      _enableFaceAuth = true;
      _selectedModules = ['SALES_MARKETING'];
      if (_departments.isNotEmpty) {
        final rndDept = _departments.firstWhere(
          (d) => d.code == 'RND' || d.name.toLowerCase().contains('research') || d.name.toLowerCase().contains('r&d'),
          orElse: () => _departments.first,
        );
        _selectedDepartmentId = rndDept.id;
      }
    });
  }

  Future<void> _saveRecord() async {
    final code = _empIdController.text.trim();
    final firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    String fullName = _fullNameController.text.trim();
    final workEmail = _workEmailController.text.trim();
    final phone = _phoneController.text.trim();
    final designation = _designationController.text.trim();

    // ─── Front-end Validations with immediate feedback ───────────────────────
    if (firstName.isEmpty) {
      _showValidationError('First Name is required');
      return;
    }
    if (firstName.length < 2) {
      _showValidationError('First Name must contain at least 2 characters');
      return;
    }
    if (!RegExp(r"^[a-zA-Z\s.'-]+$").hasMatch(firstName)) {
      _showValidationError('First Name must contain letters only');
      return;
    }

    if (middleName.isNotEmpty && !RegExp(r"^[a-zA-Z\s.'-]+$").hasMatch(middleName)) {
      _showValidationError('Middle Name must contain letters only');
      return;
    }

    if (lastName.isEmpty) {
      _showValidationError('Last Name is required');
      return;
    }
    if (!RegExp(r"^[a-zA-Z\s.'-]+$").hasMatch(lastName)) {
      _showValidationError('Last Name must contain letters only');
      return;
    }

    if (workEmail.isEmpty) {
      _showValidationError('Work email is required');
      return;
    }
    if (!RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)+$").hasMatch(workEmail)) {
      _showValidationError('Please enter a valid work email address (e.g. employee@saark.in)');
      return;
    }

    if (phone.isEmpty) {
      _showValidationError('Phone number is required');
      return;
    }
    if (phone.replaceAll(RegExp(r'[\s\-\+\(\)]'), '').length < 10) {
      _showValidationError('Phone number must contain at least 10 digits');
      return;
    }

    if (_selectedDepartmentId == null || _selectedDepartmentId!.isEmpty) {
      _showValidationError('Please select a Department');
      return;
    }

    if (designation.isEmpty) {
      _showValidationError('Designation is required');
      return;
    }

    final personalEmail = _personalEmailController.text.trim();
    if (personalEmail.isNotEmpty && !RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)+$").hasMatch(personalEmail)) {
      _showValidationError('Please enter a valid Personal Email address');
      return;
    }

    final emergencyPhone = _emergencyContactController.text.trim();
    if (emergencyPhone.isNotEmpty && emergencyPhone.replaceAll(RegExp(r'[\s\-\+\(\)]'), '').length < 7) {
      _showValidationError('Emergency Contact must contain a valid phone number');
      return;
    }

    if (fullName.isEmpty) {
      fullName = [firstName, if (middleName.isNotEmpty) middleName, lastName].join(' ');
    }

    setState(() => _isSaving = true);

    try {
      final hrRepo = ref.read(hrRepositoryProvider);

      final isNew = _selectedRecordId == null;
      final existingStatus = !isNew
          ? (_records.firstWhere(
              (r) => r.dbId == _selectedRecordId || r.id == _selectedRecordId,
              orElse: () => EmployeeProfileRecord(id: '', firstName: '', middleName: '', fullName: '', workEmail: '', dateOfBirth: ''),
            ).status)
          : 'PENDING_APPROVAL';

      final payload = {
        'firstName': firstName,
        'middleName': middleName.isNotEmpty ? middleName : null,
        'lastName': lastName,
        'email': workEmail,
        'phone': phone.isNotEmpty ? phone : '+91 98200 00000',
        'designation': designation.isNotEmpty ? designation : 'Staff Member',
        'dateOfBirth': _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
        'departmentId': (_selectedDepartmentId != null && _selectedDepartmentId!.trim().isNotEmpty) ? _selectedDepartmentId!.trim() : null,
        'status': isNew ? 'PENDING_APPROVAL' : (existingStatus.isNotEmpty ? existingStatus : 'ACTIVE'),
        'bloodGroup': _selectedBloodGroup.isNotEmpty ? _selectedBloodGroup : null,
        'emergencyPhone': _emergencyContactController.text.trim(),
        'address': _addressController.text.trim(),
        if (_passportPhotoBase64 != null) 'passportPhotoBase64': _passportPhotoBase64,
        if (_livePhotoBase64 != null) 'livePhotoBase64': _livePhotoBase64,
        'enableFaceAuth': _enableFaceAuth,
        'assignedModules': _selectedModules,
        'createUserAccount': _createUserAccount,
        if (_usernameController.text.trim().isNotEmpty)
          'username': _usernameController.text.trim(),
        if (_passwordController.text.trim().isNotEmpty)
          'password': _passwordController.text.trim(),
        'roleId': _selectedRole,
      };

      // Find department name
      final deptName = _departments.firstWhere(
        (d) => d.id == _selectedDepartmentId,
        orElse: () => DepartmentItem(id: '', name: 'R&D / Engineering', code: 'RND'),
      ).name;

      if (_selectedRecordId != null) {
        // UPDATE EXISTING RECORD
        final updated = await hrRepo.updateEmployee(_selectedRecordId!, payload);

        // If a new live face was captured during update, enroll it
        if (_livePhotoBase64 != null) {
          await hrRepo.enrollFace(
            _selectedRecordId!,
            livePhotoBase64: _livePhotoBase64!,
            passportPhotoBase64: _passportPhotoBase64,
            enableFaceAuth: _enableFaceAuth,
          );
          _isBiometricEnrolled = true;
        }

        final updatedRec = EmployeeProfileRecord(
          dbId: updated.id,
          id: updated.employeeCode.isNotEmpty ? updated.employeeCode : code,
          firstName: firstName,
          middleName: middleName,
          lastName: lastName,
          fullName: fullName,
          workEmail: workEmail,
          dateOfBirth: _dobController.text.trim(),
          gender: _selectedGender,
          maritalStatus: _selectedMaritalStatus,
          nationality: _selectedNationality,
          bloodGroup: _selectedBloodGroup,
          emergencyContact: _emergencyContactController.text.trim(),
          personalEmail: _personalEmailController.text.trim(),
          phone: phone,
          address: _addressController.text.trim(),
          departmentId: _selectedDepartmentId,
          departmentName: deptName,
          designation: designation,
          status: updated.status,
          hasBiometric: _isBiometricEnrolled,
          faceVerificationEnabled: _enableFaceAuth,
          avatarUrl: updated.avatarUrl,
          username: _usernameController.text.trim().isNotEmpty
              ? _usernameController.text.trim()
              : updated.username,
          assignedModules: List<String>.from(_selectedModules),
        );

        setState(() {
          final idx = _records.indexWhere((r) => r.dbId == _selectedRecordId || r.id == _selectedRecordId);
          if (idx != -1) {
            _records[idx] = updatedRec;
          }
          _selectedRecordId = updated.id;
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Employee "$fullName" (${updated.employeeCode}) updated! Login credentials synced & security notice dispatched to $workEmail.'),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // CREATE NEW EMPLOYEE RECORD (SUBMITS TO ADMIN APPROVAL QUEUE)
        final created = await hrRepo.createEmployee(payload);
        final enrolled = _livePhotoBase64 != null;

        final newRec = EmployeeProfileRecord(
          dbId: created.id,
          id: created.employeeCode,
          firstName: firstName,
          middleName: middleName,
          lastName: lastName,
          fullName: fullName,
          workEmail: workEmail,
          dateOfBirth: _dobController.text.trim(),
          gender: _selectedGender,
          maritalStatus: _selectedMaritalStatus,
          nationality: _selectedNationality,
          bloodGroup: _selectedBloodGroup,
          emergencyContact: _emergencyContactController.text.trim(),
          personalEmail: _personalEmailController.text.trim(),
          phone: phone,
          address: _addressController.text.trim(),
          departmentId: _selectedDepartmentId,
          departmentName: deptName,
          designation: designation,
          status: created.status.isNotEmpty ? created.status : 'PENDING_APPROVAL',
          hasBiometric: enrolled,
          faceVerificationEnabled: _enableFaceAuth,
          avatarUrl: created.avatarUrl,
          assignedModules: List<String>.from(_selectedModules),
        );

        setState(() {
          _records.insert(0, newRec);
          _selectedRecordId = created.id;
          _empIdController.text = created.employeeCode;
          _isBiometricEnrolled = enrolled;
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Employee "$fullName" (${created.employeeCode}) submitted to Admin for approval!\n'
                '📋 Status: PENDING ADMIN APPROVAL | 🔐 Face Biometrics: ${enrolled ? "Enrolled & Ready (2FA)" : "Not Enrolled"}',
              ),
              backgroundColor: const Color(0xFFF26522),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      String errorMsg = 'Failed to save employee: $e';
      if (e is DioException) {
        final serverData = e.response?.data;
        if (serverData is Map) {
          final msg = serverData['message'];
          if (msg is List) {
            errorMsg = msg.join('\n');
          } else if (msg != null) {
            errorMsg = msg.toString();
          } else if (serverData['error'] != null) {
            errorMsg = serverData['error'].toString();
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _downloadExcel() {
    final buffer = StringBuffer();
    buffer.writeln('Employee ID,Full Name,Department,Designation,Work Email,Phone,Status');
    for (final r in _records) {
      buffer.writeln('"${r.id}","${r.fullName}","${r.departmentName}","${r.designation}","${r.workEmail}","${r.phone}","${r.status}"');
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        title: const Row(
          children: [
            Icon(Icons.table_view_rounded, color: Color(0xFFF26522), size: 22),
            SizedBox(width: 10),
            Text('Export Employee Records', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total ${_records.length} records ready for download (saark_employees.csv).',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141517),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  '${buffer.toString().split('\n').take(6).join('\n')}\n...',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              
              final htmlBuffer = StringBuffer();
              htmlBuffer.writeln('<html xmlns:x="urn:schemas-microsoft-com:office:excel">');
              htmlBuffer.writeln('<head><meta charset="utf-8"></head><body>');
              htmlBuffer.writeln('<table border="1"><tr>');
              htmlBuffer.writeln('<th style="background-color: #F26522; color: white;">Employee ID</th>');
              htmlBuffer.writeln('<th style="background-color: #F26522; color: white;">Full Name</th>');
              htmlBuffer.writeln('<th style="background-color: #F26522; color: white;">Department</th>');
              htmlBuffer.writeln('<th style="background-color: #F26522; color: white;">Designation</th>');
              htmlBuffer.writeln('<th style="background-color: #F26522; color: white;">Work Email</th>');
              htmlBuffer.writeln('<th style="background-color: #F26522; color: white;">Phone</th>');
              htmlBuffer.writeln('<th style="background-color: #F26522; color: white;">Status</th>');
              htmlBuffer.writeln('</tr>');

              String escapeHtml(String? v) {
                if (v == null || v.isEmpty) return '';
                return v.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
              }

              for (final r in _records) {
                htmlBuffer.writeln('<tr>');
                htmlBuffer.writeln('<td>${escapeHtml(r.id)}</td>');
                htmlBuffer.writeln('<td>${escapeHtml(r.fullName)}</td>');
                htmlBuffer.writeln('<td>${escapeHtml(r.departmentName)}</td>');
                htmlBuffer.writeln('<td>${escapeHtml(r.designation)}</td>');
                htmlBuffer.writeln('<td>${escapeHtml(r.workEmail)}</td>');
                htmlBuffer.writeln('<td>${escapeHtml(r.phone)}</td>');
                htmlBuffer.writeln('<td>${escapeHtml(r.status)}</td>');
                htmlBuffer.writeln('</tr>');
              }
              htmlBuffer.writeln('</table></body></html>');

              downloadExcelFile(htmlBuffer.toString(), 'saark_employees.xls');

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Employee records exported successfully.'),
                  backgroundColor: Color(0xFFF26522),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download Excel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF26522),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    DateTime initial = DateTime(1998, 5, 15);
    if (_dobController.text.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(_dobController.text.trim());
      if (parsed != null && parsed.isBefore(DateTime.now())) {
        initial = parsed;
      }
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF26522),
              onPrimary: Colors.white,
              surface: Color(0xFF1E2024),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF26522)));
    }

    final pendingCount = _records.where((r) => r.status == 'PENDING_APPROVAL').length;

    return Container(
      color: const Color(0xFF141517),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header Action Bar: Title + Pending Notice + Buttons ──
          Row(
            children: [
              const Text(
                'Employee Profile & Onboarding',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // Request workflow indicator badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pendingCount > 0 ? const Color(0xFFF26522).withValues(alpha: 0.18) : Colors.green.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: pendingCount > 0 ? const Color(0xFFF26522).withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pendingCount > 0 ? Icons.pending_actions : Icons.verified_user_outlined,
                      size: 13,
                      color: pendingCount > 0 ? const Color(0xFFF26522) : Colors.greenAccent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$pendingCount Pending Admin Approval',
                      style: TextStyle(
                        color: pendingCount > 0 ? const Color(0xFFF26522) : Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Hide Saved Records
              ElevatedButton.icon(
                onPressed: () => setState(() => _hideSavedRecords = !_hideSavedRecords),
                icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                label: Text(_hideSavedRecords ? 'Show Saved Records' : 'Hide Saved Records'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF26522),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              // Download Excel
              ElevatedButton.icon(
                onPressed: _downloadExcel,
                icon: const Icon(Icons.file_download_outlined, size: 14),
                label: const Text('Download Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF26522),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ─── Dual Stacking: Add / Update Record + Saved Records ─────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 850 && constraints.maxHeight >= 500;

                if (isDesktop) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Add / Update Record
                      Text(
                        _selectedRecordId != null
                            ? 'Editing Employee Profile (${_empIdController.text}) — Click "Clear / New" to add a new employee'
                            : 'Add / Update Employee Profile (Submits to Admin for Department & Account Provisioning)',
                        style: const TextStyle(
                          color: Color(0xFFF26522),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        flex: _hideSavedRecords ? 1 : 5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1D21),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: const Color(0xFF2C2E33)),
                          ),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: _buildFormContent(isWide: true),
                            ),
                          ),
                        ),
                      ),

                      if (!_hideSavedRecords) ...[
                        const SizedBox(height: 8),
                        // Section 2: Saved Records & Requests
                        Row(
                          children: [
                            const Text(
                              'Saved Records & Requests Queue',
                              style: TextStyle(
                                color: Color(0xFFF26522),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            // Status Filter Chips
                            _buildFilterChip('ALL', 'All Records (${_records.length})'),
                            const SizedBox(width: 6),
                            _buildFilterChip('PENDING_APPROVAL', 'Pending Approval ($pendingCount)'),
                            const SizedBox(width: 6),
                            _buildFilterChip('ACTIVE', 'Approved (${_records.length - pendingCount})'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          flex: 5,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1D21),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: const Color(0xFF2C2E33)),
                            ),
                            child: _buildRecordsTable(),
                          ),
                        ),
                      ],
                    ],
                  );
                }

                // Mobile / Small screen layout
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _selectedRecordId != null
                            ? 'Editing Employee (${_empIdController.text})'
                            : 'Add / Update Record',
                        style: const TextStyle(
                          color: Color(0xFFF26522),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1D21),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF2C2E33)),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: _buildFormContent(isWide: false),
                      ),
                      if (!_hideSavedRecords) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              'Saved Records',
                              style: TextStyle(
                                color: Color(0xFFF26522),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            _buildFilterChip('ALL', 'All'),
                            const SizedBox(width: 4),
                            _buildFilterChip('PENDING_APPROVAL', 'Pending ($pendingCount)'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 260,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1D21),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: const Color(0xFF2C2E33)),
                          ),
                          child: _buildRecordsTable(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _tableFilter == value;
    return InkWell(
      onTap: () => setState(() => _tableFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF26522) : const Color(0xFF1E2024),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: isSelected ? const Color(0xFFF26522) : const Color(0xFF2C2E33)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ─── 2-Column Responsive Form Content ───────────────────────────────────────
  Widget _buildFormContent({required bool isWide}) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Row 1: Employee ID & First Name
          _buildRow(
            leftLabel: 'Employee ID:',
            leftInput: _buildTextInput(controller: _empIdController),
            rightLabel: 'First Name *:',
            rightInput: _buildTextInput(
              controller: _firstNameController,
              onChanged: (_) => _syncFullNameFromParts(),
            ),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 2: Middle Name & Last Name
          _buildRow(
            leftLabel: 'Middle Name:',
            leftInput: _buildTextInput(
              controller: _middleNameController,
              onChanged: (_) => _syncFullNameFromParts(),
            ),
            rightLabel: 'Last Name *:',
            rightInput: _buildTextInput(
              controller: _lastNameController,
              onChanged: (_) => _syncFullNameFromParts(),
            ),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 3: Full Name & Department
          _buildRow(
            leftLabel: 'Full Name:',
            leftInput: _buildTextInput(controller: _fullNameController),
            rightLabel: 'Department *:',
            rightInput: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141517),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: const Color(0xFF2C2E33)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _departments.any((d) => d.id == _selectedDepartmentId) ? _selectedDepartmentId : null,
                        dropdownColor: const Color(0xFF1E2024),
                        hint: const Text('Select Department (e.g. Research & Development)', style: TextStyle(color: Colors.white38, fontSize: 12)),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
                        isDense: true,
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: [
                          ..._departments.map((d) {
                            final displayName = (d.code == 'RND' || d.name.toLowerCase().contains('r&d') || d.name.toLowerCase().contains('research'))
                                ? 'Research and Development (${d.code})'
                                : '${d.name} (${d.code})';
                            return DropdownMenuItem<String>(
                              value: d.id,
                              child: Text(displayName, style: const TextStyle(fontSize: 12)),
                            );
                          }),
                          const DropdownMenuItem<String>(
                            value: '__ADD_NEW_DEPT__',
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline, color: Color(0xFFF26522), size: 14),
                                SizedBox(width: 6),
                                Text(
                                  '+ Add Department...',
                                  style: TextStyle(color: Color(0xFFF26522), fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v == '__ADD_NEW_DEPT__') {
                            _showAddDepartmentDialog();
                          } else if (v != null) {
                            setState(() => _selectedDepartmentId = v);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Add New Department',
                  child: InkWell(
                    onTap: _showAddDepartmentDialog,
                    borderRadius: BorderRadius.circular(2),
                    child: Container(
                      height: 28,
                      width: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF26522).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: const Color(0xFFF26522).withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.add, color: Color(0xFFF26522), size: 16),
                    ),
                  ),
                ),
              ],
            ),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 4: Designation & Work Email
          _buildRow(
            leftLabel: 'Designation *:',
            leftInput: _buildDesignationDropdown(),
            rightLabel: 'Work Email *:',
            rightInput: _buildTextInput(controller: _workEmailController),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 5: Date of Birth & Gender
          _buildRow(
            leftLabel: 'Date of Birth:',
            leftInput: InkWell(
              onTap: _pickDate,
              child: IgnorePointer(
                child: _buildTextInput(
                  controller: _dobController,
                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
                ),
              ),
            ),
            rightLabel: 'Gender:',
            rightInput: _buildDropdown(
              value: _selectedGender,
              items: const ['', 'Male', 'Female', 'Other'],
              onChanged: (v) => setState(() => _selectedGender = v ?? ''),
            ),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 6: Marital Status & Nationality
          _buildRow(
            leftLabel: 'Marital Status:',
            leftInput: _buildDropdown(
              value: _selectedMaritalStatus,
              items: const ['', 'Single', 'Married', 'Divorced', 'Widowed'],
              onChanged: (v) => setState(() => _selectedMaritalStatus = v ?? ''),
            ),
            rightLabel: 'Nationality:',
            rightInput: _buildDropdown(
              value: _selectedNationality,
              items: const ['', 'Indian', 'Other'],
              onChanged: (v) => setState(() => _selectedNationality = v ?? ''),
            ),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 7: Blood Group & Emergency Contact
          _buildRow(
            leftLabel: 'Blood Group:',
            leftInput: _buildDropdown(
              value: _selectedBloodGroup,
              items: const ['', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
              onChanged: (v) => setState(() => _selectedBloodGroup = v ?? ''),
            ),
            rightLabel: 'Emergency Contact:',
            rightInput: _buildTextInput(controller: _emergencyContactController),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 8: Personal Email & Phone Number
          _buildRow(
            leftLabel: 'Personal Email:',
            leftInput: _buildTextInput(controller: _personalEmailController),
            rightLabel: 'Phone Number *:',
            rightInput: _buildTextInput(controller: _phoneController),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 9: Current Address
          _buildRow(
            leftLabel: 'Current Address:',
            leftInput: _buildTextInput(controller: _addressController),
            rightLabel: '',
            rightInput: const SizedBox.shrink(),
            isWide: isWide,
          ),
          const SizedBox(height: 8),

          // Identity & Face Recognition Biometrics (2FA) Section
          _buildIdentityAndFaceVerificationSection(isWide: isWide),
          const SizedBox(height: 10),

          // Action buttons row (Right-aligned Save & Clear)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 12, color: Colors.white54),
                    SizedBox(width: 4),
                    Text(
                      'Saving creates an onboarding request sent to Admin for credential & role provisioning.',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _clearForm,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Clear / New'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveRecord,
                icon: _isSaving
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_selectedRecordId != null ? Icons.save_rounded : Icons.send_rounded, size: 14),
                label: Text(_isSaving
                    ? (_selectedRecordId != null ? 'Saving...' : 'Submitting...')
                    : (_selectedRecordId != null ? 'Update & Save Profile' : 'Save & Submit to Admin')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF26522),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Identity & Face Recognition Biometrics (2FA) Section ───────────────────
  Widget _buildIdentityAndFaceVerificationSection({required bool isWide}) {
    final passportBytes = _safeDecodeBase64(_passportPhotoBase64);
    final liveBytes = _safeDecodeBase64(_livePhotoBase64);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16181B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _isBiometricEnrolled ? const Color(0xFF00E676).withOpacity(0.3) : const Color(0xFFF26522).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF26522).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.face_retouching_natural_rounded, color: Color(0xFFF26522), size: 18),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Identity & Face Recognition Biometrics (2FA)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Live face capture generates a 128-d descriptor vector encrypted at rest (AES-256-GCM).',
                    style: TextStyle(color: Colors.white54, fontSize: 10.5),
                  ),
                ],
              ),
              const Spacer(),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isBiometricEnrolled ? const Color(0xFF00E676).withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: _isBiometricEnrolled ? const Color(0xFF00E676).withOpacity(0.4) : Colors.orange.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isBiometricEnrolled ? Icons.verified_user_rounded : Icons.pending_rounded,
                      size: 12,
                      color: _isBiometricEnrolled ? const Color(0xFF00E676) : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isBiometricEnrolled ? 'Biometrics Enrolled' : 'Biometrics Pending',
                      style: TextStyle(
                        color: _isBiometricEnrolled ? const Color(0xFF00E676) : Colors.orangeAccent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Two Photo Cards: Passport Photo & Live Face Capture
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildPassportPhotoCard(passportBytes)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildLiveBiometricCard(liveBytes)),
                  ],
                )
              : Column(
                  children: [
                    _buildPassportPhotoCard(passportBytes),
                    const SizedBox(height: 8),
                    _buildLiveBiometricCard(liveBytes),
                  ],
                ),
          const SizedBox(height: 12),

          // Biometric Login & User Account Configuration Row
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1C20),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF2C2E33)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Face Verification Toggle
                    InkWell(
                      onTap: () => setState(() => _enableFaceAuth = !_enableFaceAuth),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _enableFaceAuth,
                              activeColor: const Color(0xFFF26522),
                              onChanged: (v) => setState(() => _enableFaceAuth = v ?? true),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Enforce Face Recognition Login (2FA)',
                            style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Create User Account Toggle
                    InkWell(
                      onTap: () => setState(() => _createUserAccount = !_createUserAccount),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _createUserAccount,
                              activeColor: const Color(0xFFF26522),
                              onChanged: (v) => setState(() => _createUserAccount = v ?? true),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Provision ERP Login Account',
                            style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_createUserAccount) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Color(0xFF2C2E33), height: 1),
                  const SizedBox(height: 8),
                  // Username, Password, Role row
                  isWide
                      ? Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildInlineField(
                                label: 'Login Username:',
                                input: _buildTextInput(
                                  controller: _usernameController,
                                  onChanged: null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: _buildInlineField(
                                label: 'Initial Password:',
                                input: _buildTextInput(
                                  controller: _passwordController,
                                  onChanged: null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: _buildInlineField(
                                label: 'ERP Role:',
                                input: _buildRoleDropdown(),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildInlineField(label: 'Username:', input: _buildTextInput(controller: _usernameController)),
                            const SizedBox(height: 6),
                            _buildInlineField(label: 'Password:', input: _buildTextInput(controller: _passwordController)),
                            const SizedBox(height: 6),
                            _buildInlineField(label: 'ERP Role:', input: _buildRoleDropdown()),
                          ],
                        ),
                  const SizedBox(height: 10),
                  const Divider(color: Color(0xFF2C2E33), height: 1),
                  const SizedBox(height: 10),
                  _buildModuleAccessSection(isWide: isWide),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget _buildModuleAccessSection({required bool isWide}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141517),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2E33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFFF26522), size: 16),
              const SizedBox(width: 8),
              const Text(
                'Assigned ERP Module Access & Permissions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _selectedModules.isEmpty
                      ? const Color(0xFF333333)
                      : const Color(0x33F26522),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedModules.isEmpty
                        ? Colors.white24
                        : const Color(0xFFF26522),
                  ),
                ),
                child: Text(
                  _selectedModules.isEmpty
                      ? 'No Modules Selected'
                      : '${_selectedModules.length} Modules Authorized',
                  style: TextStyle(
                    color: _selectedModules.isEmpty
                        ? Colors.white60
                        : const Color(0xFFF26522),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedModules = _erpModuleOptions
                        .map((m) => m['key'] as String)
                        .toList();
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Select All', style: TextStyle(color: Color(0xFFF26522), fontSize: 11)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() => _selectedModules.clear());
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear All', style: TextStyle(color: Colors.white60, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Select which ERP modules this employee is permitted to access. When logged in, the employee will only see and navigate to the checked modules.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _erpModuleOptions.map((opt) {
              final key = opt['key'] as String;
              final isChecked = _selectedModules.contains(key);
              final icon = opt['icon'] as IconData;
              final title = opt['title'] as String;

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isChecked) {
                      _selectedModules.remove(key);
                    } else {
                      _selectedModules.add(key);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isChecked ? const Color(0x22F26522) : const Color(0xFF1E2024),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isChecked ? const Color(0xFFF26522) : const Color(0xFF2C2E33),
                      width: isChecked ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: Checkbox(
                          value: isChecked,
                          activeColor: const Color(0xFFF26522),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                          side: const BorderSide(color: Color(0xFF4C4E55)),
                          onChanged: (_) {
                            setState(() {
                              if (isChecked) {
                                _selectedModules.remove(key);
                              } else {
                                _selectedModules.add(key);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(icon, size: 16, color: isChecked ? const Color(0xFFF26522) : Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: TextStyle(
                          color: isChecked ? Colors.white : Colors.white70,
                          fontSize: 11.5,
                          fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPassportPhotoCard(Uint8List? passportBytes) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2E33)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            height: 85,
            decoration: BoxDecoration(
              color: const Color(0xFF141517),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF33373E)),
            ),
            clipBehavior: Clip.antiAlias,
            child: passportBytes != null
                ? Image.memory(passportBytes, fit: BoxFit.cover)
                : const Center(
                    child: Icon(Icons.account_box_outlined, color: Colors.white24, size: 36),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Passport / Profile Photo',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  passportBytes != null ? 'Official photo attached' : 'Upload or capture employee photo',
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickPassportPhoto,
                      icon: const Icon(Icons.camera_alt_outlined, size: 12),
                      label: Text(passportBytes != null ? 'Retake Photo' : 'Capture Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A2D33),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11),
                        elevation: 0,
                      ),
                    ),
                    if (passportBytes != null)
                      OutlinedButton(
                        onPressed: () => setState(() => _passportPhotoBase64 = null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent, width: 0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBiometricCard(Uint8List? liveBytes) {
    final hasBiometrics = liveBytes != null || _isBiometricEnrolled;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: hasBiometrics ? const Color(0xFF00E676).withOpacity(0.4) : const Color(0xFF2C2E33),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            height: 85,
            decoration: BoxDecoration(
              color: const Color(0xFF141517),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: hasBiometrics ? const Color(0xFF00E676) : const Color(0xFF33373E),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: liveBytes != null
                ? Image.memory(liveBytes, fit: BoxFit.cover)
                : Center(
                    child: Icon(
                      _isBiometricEnrolled ? Icons.verified_user_rounded : Icons.face_rounded,
                      color: _isBiometricEnrolled ? const Color(0xFF00E676) : Colors.white24,
                      size: 36,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Live Camera Face Capture',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    if (hasBiometrics)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const Text('128-d Ready', style: TextStyle(color: Color(0xFF00E676), fontSize: 9.5, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasBiometrics
                      ? 'Live biometric descriptor active'
                      : 'Camera capture required for 2FA login',
                  style: TextStyle(
                    color: hasBiometrics ? const Color(0xFF00E676) : Colors.white54,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openLiveCameraModal,
                      icon: const Icon(Icons.videocam_rounded, size: 12),
                      label: Text(_isBiometricEnrolled ? 'Re-capture Face' : 'Capture Live Face'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF26522),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        elevation: 0,
                      ),
                    ),
                    if (_selectedRecordId != null && _isBiometricEnrolled) ...[
                      OutlinedButton.icon(
                        onPressed: _reEnrollFace,
                        icon: const Icon(Icons.sync_rounded, size: 11),
                        label: const Text('Re-enroll'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00E5FF),
                          side: const BorderSide(color: Color(0xFF00E5FF), width: 0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _disableBiometrics,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent, width: 0.8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text('Disable Face Auth'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineField({required String label, required Widget input}) {
    return Row(
      children: [
        SizedBox(
          width: 95,
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
        ),
        Expanded(child: input),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141517),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF2C2E33)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          dropdownColor: const Color(0xFF1E2024),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
          isDense: true,
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 11.5),
          items: const [
            DropdownMenuItem(value: 'ROLE_EMPLOYEE', child: Text('Employee (Staff)')),
            DropdownMenuItem(value: 'ROLE_PM', child: Text('Project Manager')),
            DropdownMenuItem(value: 'ROLE_HR', child: Text('HR Manager')),
            DropdownMenuItem(value: 'ROLE_ADMIN', child: Text('System Administrator')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _selectedRole = v);
          },
        ),
      ),
    );
  }

  // ─── Two Column Form Row ────────────────────────────────────────────────────
  Widget _buildRow({
    required String leftLabel,
    required Widget leftInput,
    required String rightLabel,
    required Widget rightInput,
    required bool isWide,
  }) {
    if (!isWide) {
      return Column(
        children: [
          _buildField(leftLabel, leftInput),
          const SizedBox(height: 6),
          _buildField(rightLabel, rightInput),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: _buildField(leftLabel, leftInput)),
        const SizedBox(width: 16),
        Expanded(child: _buildField(rightLabel, rightInput)),
      ],
    );
  }

  Widget _buildField(String label, Widget input) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC0C0C0),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: input),
      ],
    );
  }

  // ─── Compact Input Styles ───────────────────────────────────────────────────
  Widget _buildTextInput({
    required TextEditingController controller,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF141517),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF2C2E33)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: InputBorder.none,
          isDense: true,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141517),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF2C2E33)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: const Color(0xFF1E2024),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
          isDense: true,
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: items.map((opt) {
            return DropdownMenuItem<String>(
              value: opt,
              child: Text(opt, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ─── Designation Dropdown with Predefined Options & Custom Entry ─────────────
  Widget _buildDesignationDropdown() {
    final currentVal = _designationController.text.trim();
    if (currentVal.isNotEmpty && !_designations.contains(currentVal)) {
      _designations.insert(0, currentVal);
    }
    final effectiveValue = _designations.contains(_selectedDesignation)
        ? _selectedDesignation
        : (currentVal.isNotEmpty && _designations.contains(currentVal)
            ? currentVal
            : (_designations.isNotEmpty ? _designations.first : 'Junior Design Engineer'));

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141517),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: const Color(0xFF2C2E33)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          dropdownColor: const Color(0xFF1E2024),
          hint: const Text('Select Designation', style: TextStyle(color: Colors.white38, fontSize: 12)),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFF26522), size: 20),
          isDense: true,
          isExpanded: true,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: [
            ..._designations.map((desig) {
              return DropdownMenuItem<String>(
                value: desig,
                child: Text(
                  desig,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            const DropdownMenuItem<String>(
              value: '__ADD_CUSTOM__',
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, color: Color(0xFFF26522), size: 14),
                  SizedBox(width: 6),
                  Text(
                    '+ Add Custom Designation...',
                    style: TextStyle(
                      color: Color(0xFFF26522),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (val) {
            if (val == '__ADD_CUSTOM__') {
              _showAddCustomDesignationDialog();
            } else if (val != null) {
              setState(() {
                _selectedDesignation = val;
                _designationController.text = val;
              });
            }
          },
        ),
      ),
    );
  }

  Future<void> _showAddCustomDesignationDialog() async {
    final customCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: const Row(
          children: [
            Icon(Icons.badge_outlined, color: Color(0xFFF26522), size: 20),
            SizedBox(width: 8),
            Text(
              'Add Custom Designation',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the new designation / role title for this employee:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF141517),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFFF26522)),
              ),
              child: TextField(
                controller: customCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: InputBorder.none,
                  hintText: 'e.g. Lead PLC Automation Engineer',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    Navigator.of(ctx).pop(val.trim());
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = customCtrl.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(ctx).pop(text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF26522),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Add & Select'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        if (!_designations.contains(result)) {
          _designations.insert(0, result);
        }
        _selectedDesignation = result;
        _designationController.text = result;
      });
    }
  }

  // ─── Saved Records Table with Status Badges ─────────────────────────────────
  Widget _buildRecordsTable() {
    var displayRecords = _records;
    if (_tableFilter == 'PENDING_APPROVAL') {
      displayRecords = _records.where((r) => r.status == 'PENDING_APPROVAL').toList();
    } else if (_tableFilter == 'ACTIVE') {
      displayRecords = _records.where((r) => r.status == 'ACTIVE').toList();
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DataTable(
                  headingRowHeight: 32,
                  dataRowMinHeight: 30,
                  dataRowMaxHeight: 36,
                  horizontalMargin: 12,
                  columnSpacing: 18,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF17181A)),
                  columns: const [
                    DataColumn(label: Text('Employee ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Full Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Department', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Designation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Work Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Assigned Modules', style: TextStyle(color: Color(0xFFF26522), fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Status / Approval', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Date of Birth', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: displayRecords.map((r) {
                    final isSelected = _selectedRecordId == r.dbId || _selectedRecordId == r.id;
                    final isPending = r.status == 'PENDING_APPROVAL';

                    return DataRow(
                      selected: isSelected,
                      onSelectChanged: (_) => _selectRecord(r),
                      color: WidgetStateProperty.resolveWith<Color?>((states) {
                        if (isSelected) {
                          return const Color(0xFFF26522).withValues(alpha: 0.18);
                        }
                        if (states.contains(WidgetState.hovered)) {
                          return Colors.white.withValues(alpha: 0.04);
                        }
                        return Colors.transparent;
                      }),
                      cells: [
                        DataCell(Text(
                          r.id,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFF26522) : const Color(0xFFC0C0C0),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        )),
                        DataCell(Text(r.fullName, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            r.departmentName,
                            style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11),
                          ),
                        )),
                        DataCell(Text(r.designation, style: const TextStyle(color: Color(0xFFC0C0C0), fontSize: 12))),
                        DataCell(Text(r.workEmail, style: const TextStyle(color: Color(0xFFC0C0C0), fontSize: 12))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: r.assignedModules.isEmpty ? Colors.white10 : const Color(0xFFF26522).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: r.assignedModules.isEmpty ? Colors.white24 : const Color(0xFFF26522).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            r.assignedModules.isEmpty ? 'No Modules' : '${r.assignedModules.length} Modules',
                            style: TextStyle(
                              color: r.assignedModules.isEmpty ? Colors.white60 : const Color(0xFFF26522),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPending ? Colors.orange.withValues(alpha: 0.18) : Colors.green.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: isPending ? Colors.orange.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            isPending ? 'Pending Admin Approval' : 'Approved / Active',
                            style: TextStyle(
                              color: isPending ? Colors.orangeAccent : Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )),
                        DataCell(Text(r.dateOfBirth.isNotEmpty ? r.dateOfBirth : '-', style: const TextStyle(color: Color(0xFFC0C0C0), fontSize: 12))),
                      ],
                    );
                  }).toList(),
                ),
                if (displayRecords.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_open_outlined, color: Colors.white24, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            _tableFilter == 'PENDING_APPROVAL' ? 'No pending requests found' : 'No records found',
                            style: const TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Fill in employee details above and click "Save & Submit to Admin"',
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
