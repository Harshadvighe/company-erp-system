import 'package:flutter/material.dart';

/// Data class representing an Employee record matching the enterprise HR UI
class EmployeeProfileRecord {
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

  EmployeeProfileRecord({
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
  });
}

class EmployeeProfileView extends StatefulWidget {
  const EmployeeProfileView({super.key});

  @override
  State<EmployeeProfileView> createState() => _EmployeeProfileViewState();
}

class _EmployeeProfileViewState extends State<EmployeeProfileView> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers initialized
  final _empIdController = TextEditingController(text: 'SE-0101');
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _workEmailController = TextEditingController();
  final _dobController = TextEditingController(text: '2026-10-02');
  final _emergencyContactController = TextEditingController();
  final _personalEmailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // Dropdown values (empty default to match screenshot blank inputs with down arrow)
  String _selectedGender = '';
  String _selectedMaritalStatus = '';
  String _selectedNationality = '';
  String _selectedBloodGroup = '';

  // UI state
  bool _hideSavedRecords = false;
  String? _selectedRecordId;

  // Saved Records list
  late List<EmployeeProfileRecord> _records;

  @override
  void initState() {
    super.initState();
    _records = [];
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
    super.dispose();
  }

  void _selectRecord(EmployeeProfileRecord record) {
    setState(() {
      _selectedRecordId = record.id;
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
    });
  }

  void _clearForm() {
    setState(() {
      _selectedRecordId = null;
      int maxId = 100;
      for (final r in _records) {
        final numPart = int.tryParse(r.id.replaceAll(RegExp(r'[^0-9]'), ''));
        if (numPart != null && numPart > maxId) {
          maxId = numPart;
        }
      }
      _empIdController.text = 'SE-0${maxId + 1}';
      _firstNameController.clear();
      _middleNameController.clear();
      _fullNameController.clear();
      _workEmailController.clear();
      _dobController.text = '2026-10-02';
      _emergencyContactController.clear();
      _personalEmailController.clear();
      _phoneController.clear();
      _addressController.clear();
      _selectedGender = '';
      _selectedMaritalStatus = '';
      _selectedNationality = '';
      _selectedBloodGroup = '';
    });
  }

  void _saveRecord() {
    final id = _empIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee ID is required')),
      );
      return;
    }

    final newRec = EmployeeProfileRecord(
      id: id,
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      fullName: _fullNameController.text.trim(),
      workEmail: _workEmailController.text.trim(),
      dateOfBirth: _dobController.text.trim(),
      gender: _selectedGender,
      maritalStatus: _selectedMaritalStatus,
      nationality: _selectedNationality,
      bloodGroup: _selectedBloodGroup,
      emergencyContact: _emergencyContactController.text.trim(),
      personalEmail: _personalEmailController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
    );

    setState(() {
      final existingIndex = _records.indexWhere((r) => r.id == id);
      if (existingIndex >= 0) {
        _records[existingIndex] = newRec;
      } else {
        _records.add(newRec);
      }
      _selectedRecordId = id;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Record $id saved successfully'),
        backgroundColor: const Color(0xFFF26522),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _downloadExcel() {
    final buffer = StringBuffer();
    buffer.writeln('Employee ID,First Name,Middle Name,Full Name,Work Email,Date of Birth');
    for (final r in _records) {
      buffer.writeln('"${r.id}","${r.firstName}","${r.middleName}","${r.fullName}","${r.workEmail}","${r.dateOfBirth}"');
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
      initialDate: DateTime(2026, 10, 2),
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
    return Container(
      color: const Color(0xFF141517),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Header Action Bar: Title + Hide Saved Records + Download Excel ──
          Row(
            children: [
              const Text(
                'Employee Profile',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
                      // Section 1: Add / Update Record (Header outside container)
                      const Text(
                        'Add / Update Record',
                        style: TextStyle(
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
                        // Section 2: Saved Records (Header outside container)
                        const Text(
                          'Saved Records',
                          style: TextStyle(
                            color: Color(0xFFF26522),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
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
                      const Text(
                        'Add / Update Record',
                        style: TextStyle(
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
                        const Text(
                          'Saved Records',
                          style: TextStyle(
                            color: Color(0xFFF26522),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
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
            rightInput: _buildTextInput(controller: _firstNameController),
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

          // Row 3: Work Email & Date of Birth
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

          // Row 4: Gender & Marital Status
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

          // Row 5: Nationality & Blood Group
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

          // Row 6: Emergency Contact & Personal Email
          _buildRow(
            leftLabel: 'Emergency Contact:',
            leftInput: _buildTextInput(controller: _emergencyContactController),
            rightLabel: 'Personal Email:',
            rightInput: _buildTextInput(controller: _personalEmailController),
            isWide: isWide,
          ),
          const SizedBox(height: 6),

          // Row 7: Phone Number & Current Address
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
              ElevatedButton(
                onPressed: _saveRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF26522),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                child: const Text('Save Record'),
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

  // ─── Saved Records Table ────────────────────────────────────────────────────
  Widget _buildRecordsTable() {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 950,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DataTable(
                  headingRowHeight: 32,
                  dataRowMinHeight: 28,
                  dataRowMaxHeight: 32,
                  horizontalMargin: 12,
                  columnSpacing: 20,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF17181A)),
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Employee ID',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'First Name',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Middle Name',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Full Name',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Work Email',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Date of Birth',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                  rows: _records.map((r) {
                    final isSelected = _selectedRecordId == r.id;
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
                        DataCell(Text(r.firstName, style: const TextStyle(color: Color(0xFFC0C0C0), fontSize: 12))),
                        DataCell(Text(r.middleName, style: const TextStyle(color: Color(0xFFC0C0C0), fontSize: 12))),
                        DataCell(Text(r.fullName, style: const TextStyle(color: Color(0xFFC0C0C0), fontSize: 12))),
                        DataCell(Text(r.workEmail, style: const TextStyle(color: Color(0xFFC0C0C0), fontSize: 12))),
                        DataCell(Text(r.dateOfBirth, style: const TextStyle(color: Color(0xFFC0C0C0), fontSize: 12))),
                      ],
                    );
                  }).toList(),
                ),
                if (_records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_outlined, color: Colors.white24, size: 36),
                          SizedBox(height: 8),
                          Text(
                            'No saved records found',
                            style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Fill in employee details above and click "Save Record" to add',
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
