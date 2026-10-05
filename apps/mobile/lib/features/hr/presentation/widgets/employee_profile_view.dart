import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:saark_erp_mobile/features/hr/data/hr_repository.dart';
import 'package:saark_erp_mobile/features/admin/data/admin_repository.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';

/// Data class representing an Employee record matching the enterprise HR UI
class EmployeeProfileRecord {
  String dbId;
  String id;
  String firstName;
  String middleName;
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

  EmployeeProfileRecord({
    this.dbId = '',
    required this.id,
    required this.firstName,
    required this.middleName,
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
  });

  factory EmployeeProfileRecord.fromEmployee(Employee emp) {
    return EmployeeProfileRecord(
      dbId: emp.id,
      id: emp.employeeCode.isNotEmpty ? emp.employeeCode : emp.id,
      firstName: emp.firstName,
      middleName: '',
      fullName: emp.fullName,
      workEmail: emp.email,
      dateOfBirth: emp.joiningDate.toIso8601String().split('T').first,
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
  final _fullNameController = TextEditingController();
  final _workEmailController = TextEditingController();
  final _dobController = TextEditingController(text: '2026-10-05');
  final _emergencyContactController = TextEditingController();
  final _personalEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _designationController = TextEditingController(text: 'Junior Design Engineer');

  // Dropdown values
  String _selectedGender = '';
  String _selectedMaritalStatus = '';
  String _selectedNationality = 'Indian';
  String _selectedBloodGroup = '';
  String? _selectedDepartmentId;
  String _tableFilter = 'ALL'; // 'ALL', 'PENDING_APPROVAL', 'ACTIVE'

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
    _fullNameController.dispose();
    _workEmailController.dispose();
    _dobController.dispose();
    _emergencyContactController.dispose();
    _personalEmailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  void _selectRecord(EmployeeProfileRecord record) {
    setState(() {
      _selectedRecordId = record.dbId.isNotEmpty ? record.dbId : record.id;
      _empIdController.text = record.id;
      _firstNameController.text = record.firstName;
      _middleNameController.text = record.middleName;
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
      _addressController.text = record.address;
      _designationController.text = record.designation;
      if (record.departmentId != null && _departments.any((d) => d.id == record.departmentId)) {
        _selectedDepartmentId = record.departmentId;
      }
    });
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
      _fullNameController.clear();
      _workEmailController.clear();
      _dobController.text = '2026-10-05';
      _emergencyContactController.clear();
      _personalEmailController.clear();
      _phoneController.clear();
      _addressController.clear();
      _designationController.text = 'Junior Design Engineer';
      _selectedGender = '';
      _selectedMaritalStatus = '';
      _selectedNationality = 'Indian';
      _selectedBloodGroup = '';
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
    String firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    String fullName = _fullNameController.text.trim();
    final workEmail = _workEmailController.text.trim();
    final phone = _phoneController.text.trim();
    final designation = _designationController.text.trim();

    if (fullName.isEmpty && firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter employee name'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (workEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work email is required'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Derive names
    if (firstName.isEmpty && fullName.isNotEmpty) {
      final parts = fullName.split(' ');
      firstName = parts.first;
    }
    String lastName = '';
    if (fullName.isNotEmpty) {
      final parts = fullName.split(' ');
      if (parts.length > 1) {
        lastName = parts.sublist(1).join(' ');
      }
    }
    if (lastName.isEmpty) {
      lastName = middleName.isNotEmpty ? middleName : 'Staff';
    }
    if (fullName.isEmpty) {
      fullName = '$firstName $middleName $lastName'.replaceAll('  ', ' ').trim();
    }

    setState(() => _isSaving = true);

    try {
      final hrRepo = ref.read(hrRepositoryProvider);

      final payload = {
        'firstName': firstName,
        'lastName': lastName,
        'email': workEmail,
        'phone': phone.isNotEmpty ? phone : '+91 98200 00000',
        'designation': designation.isNotEmpty ? designation : 'Staff Member',
        'departmentId': _selectedDepartmentId,
        'status': 'PENDING_APPROVAL',
        'bloodGroup': _selectedBloodGroup.isNotEmpty ? _selectedBloodGroup : null,
        'emergencyPhone': _emergencyContactController.text.trim(),
        'address': _addressController.text.trim(),
      };

      // Find department name
      final deptName = _departments.firstWhere(
        (d) => d.id == _selectedDepartmentId,
        orElse: () => DepartmentItem(id: '', name: 'R&D / Engineering', code: 'RND'),
      ).name;

      if (_selectedRecordId != null) {
        // UPDATE EXISTING RECORD
        final updated = await hrRepo.updateEmployee(_selectedRecordId!, payload);

        final updatedRec = EmployeeProfileRecord(
          dbId: updated.id,
          id: updated.employeeCode.isNotEmpty ? updated.employeeCode : code,
          firstName: firstName,
          middleName: middleName,
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
              content: Text('✅ Employee "$fullName" (${updated.employeeCode}) updated successfully!'),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        // CREATE NEW EMPLOYEE RECORD
        final created = await hrRepo.createEmployee(payload);

        final newRec = EmployeeProfileRecord(
          dbId: created.id,
          id: created.employeeCode,
          firstName: firstName,
          middleName: middleName,
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
          status: created.status,
        );

        setState(() {
          _records.insert(0, newRec);
          _selectedRecordId = created.id;
          _empIdController.text = created.employeeCode;
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Employee record for "$fullName" (${created.employeeCode}) saved in $deptName!\n'
                '📨 Onboarding request submitted to Admin for username, password & role assignment.',
              ),
              backgroundColor: const Color(0xFFF26522),
              duration: const Duration(seconds: 4),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2026, 10, 5),
      firstDate: DateTime(1950),
      lastDate: DateTime(2035),
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
                  color: pendingCount > 0 ? const Color(0xFFF26522).withOpacity(0.18) : Colors.green.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: pendingCount > 0 ? const Color(0xFFF26522).withOpacity(0.4) : Colors.green.withOpacity(0.4),
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
            rightLabel: 'First Name:',
            rightInput: _buildTextInput(
              controller: _firstNameController,
              onChanged: (val) {
                if (_fullNameController.text.isEmpty || _fullNameController.text.startsWith(val)) {
                  _fullNameController.text = '$val ${_middleNameController.text}'.trim();
                }
              },
            ),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 2: Middle Name & Full Name
          _buildRow(
            leftLabel: 'Middle Name:',
            leftInput: _buildTextInput(controller: _middleNameController),
            rightLabel: 'Full Name:',
            rightInput: _buildTextInput(controller: _fullNameController),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 3: Department (Key requirement!) & Designation
          _buildRow(
            leftLabel: 'Department:',
            leftInput: Container(
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
                  hint: const Text('Select Department (e.g. R&D)', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
                  isDense: true,
                  isExpanded: true,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  items: _departments.map((d) {
                    return DropdownMenuItem<String>(
                      value: d.id,
                      child: Text('${d.name} (${d.code})', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedDepartmentId = v);
                    }
                  },
                ),
              ),
            ),
            rightLabel: 'Designation:',
            rightInput: _buildTextInput(controller: _designationController),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 4: Work Email & Date of Birth / Joining
          _buildRow(
            leftLabel: 'Work Email:',
            leftInput: _buildTextInput(controller: _workEmailController),
            rightLabel: 'Date of Birth:',
            rightInput: InkWell(
              onTap: _pickDate,
              child: IgnorePointer(
                child: _buildTextInput(
                  controller: _dobController,
                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
                ),
              ),
            ),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 5: Gender & Marital Status
          _buildRow(
            leftLabel: 'Gender:',
            leftInput: _buildDropdown(
              value: _selectedGender,
              items: const ['', 'Male', 'Female', 'Other'],
              onChanged: (v) => setState(() => _selectedGender = v ?? ''),
            ),
            rightLabel: 'Marital Status:',
            rightInput: _buildDropdown(
              value: _selectedMaritalStatus,
              items: const ['', 'Single', 'Married', 'Divorced', 'Widowed'],
              onChanged: (v) => setState(() => _selectedMaritalStatus = v ?? ''),
            ),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 6: Nationality & Blood Group
          _buildRow(
            leftLabel: 'Nationality:',
            leftInput: _buildDropdown(
              value: _selectedNationality,
              items: const ['', 'Indian', 'Other'],
              onChanged: (v) => setState(() => _selectedNationality = v ?? ''),
            ),
            rightLabel: 'Blood Group:',
            rightInput: _buildDropdown(
              value: _selectedBloodGroup,
              items: const ['', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
              onChanged: (v) => setState(() => _selectedBloodGroup = v ?? ''),
            ),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 7: Emergency Contact & Personal Email
          _buildRow(
            leftLabel: 'Emergency Contact:',
            leftInput: _buildTextInput(controller: _emergencyContactController),
            rightLabel: 'Personal Email:',
            rightInput: _buildTextInput(controller: _personalEmailController),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 8: Phone Number & Current Address
          _buildRow(
            leftLabel: 'Phone Number:',
            leftInput: _buildTextInput(controller: _phoneController),
            rightLabel: 'Current Address:',
            rightInput: _buildTextInput(controller: _addressController),
            isWide: isWide,
          ),
          const SizedBox(height: 10),

          // Action buttons row (Right-aligned Save & Clear)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
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
            width: 1050,
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
                          return const Color(0xFFF26522).withOpacity(0.18);
                        }
                        if (states.contains(WidgetState.hovered)) {
                          return Colors.white.withOpacity(0.04);
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
                            color: Colors.blue.withOpacity(0.15),
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
                            color: isPending ? Colors.orange.withOpacity(0.18) : Colors.green.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: isPending ? Colors.orange.withOpacity(0.4) : Colors.green.withOpacity(0.4)),
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
                        DataCell(Text(r.dateOfBirth, style: const TextStyle(color: Color(0xFFC0C0C0), fontSize: 12))),
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
