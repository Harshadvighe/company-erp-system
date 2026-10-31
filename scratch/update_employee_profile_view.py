import re

path = 'apps/mobile/lib/features/hr/presentation/widgets/employee_profile_view.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Normalize newlines
has_crlf = '\r\n' in content
content = content.replace('\r\n', '\n')

# 1. EmployeeProfileRecord class definition
old_record_def = """class EmployeeProfileRecord {
  String dbId;
  String id;
  String firstName;
  String middleName;
  String fullName;"""

new_record_def = """class EmployeeProfileRecord {
  String dbId;
  String id;
  String firstName;
  String middleName;
  String lastName;
  String fullName;"""

assert old_record_def in content, "old_record_def not found"
content = content.replace(old_record_def, new_record_def, 1)

# 2. EmployeeProfileRecord constructor
old_record_ctor = """  EmployeeProfileRecord({
    this.dbId = '',
    required this.id,
    required this.firstName,
    required this.middleName,
    required this.fullName,"""

new_record_ctor = """  EmployeeProfileRecord({
    this.dbId = '',
    required this.id,
    required this.firstName,
    required this.middleName,
    this.lastName = '',
    required this.fullName,"""

assert old_record_ctor in content, "old_record_ctor not found"
content = content.replace(old_record_ctor, new_record_ctor, 1)

# 3. EmployeeProfileRecord.fromEmployee
old_from_emp = """    return EmployeeProfileRecord(
      dbId: emp.id,
      id: emp.employeeCode.isNotEmpty ? emp.employeeCode : emp.id,
      firstName: emp.firstName,
      middleName: '',
      fullName: emp.fullName,"""

new_from_emp = """    return EmployeeProfileRecord(
      dbId: emp.id,
      id: emp.employeeCode.isNotEmpty ? emp.employeeCode : emp.id,
      firstName: emp.firstName,
      middleName: emp.middleName ?? '',
      lastName: emp.lastName,
      fullName: emp.fullName,"""

assert old_from_emp in content, "old_from_emp not found"
content = content.replace(old_from_emp, new_from_emp, 1)

# 4. _EmployeeProfileViewState controllers and helper methods
old_controllers = """  // Text Controllers initialized
  final _empIdController = TextEditingController(text: 'EMP-2026-001');
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _fullNameController = TextEditingController();"""

new_controllers = """  // Text Controllers initialized
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
  }"""

assert old_controllers in content, "old_controllers not found"
content = content.replace(old_controllers, new_controllers, 1)

# 5. dispose
old_dispose = """    _firstNameController.dispose();
    _middleNameController.dispose();
    _fullNameController.dispose();"""

new_dispose = """    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _fullNameController.dispose();"""

assert old_dispose in content, "old_dispose not found"
content = content.replace(old_dispose, new_dispose, 1)

# 6. _selectRecord
old_select = """      _empIdController.text = record.id;
      _firstNameController.text = record.firstName;
      _middleNameController.text = record.middleName;
      _fullNameController.text = record.fullName;"""

new_select = """      _empIdController.text = record.id;
      _firstNameController.text = record.firstName;
      _middleNameController.text = record.middleName;
      _lastNameController.text = record.lastName;
      _fullNameController.text = record.fullName;"""

assert old_select in content, "old_select not found"
content = content.replace(old_select, new_select, 1)

# 7. _clearForm
old_clear = """      _firstNameController.clear();
      _middleNameController.clear();
      _fullNameController.clear();"""

new_clear = """      _firstNameController.clear();
      _middleNameController.clear();
      _lastNameController.clear();
      _fullNameController.clear();"""

assert old_clear in content, "old_clear not found"
content = content.replace(old_clear, new_clear, 1)

# 8. _saveRecord with comprehensive validation
old_save_start = """  Future<void> _saveRecord() async {
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
    }"""

new_save_start = """  Future<void> _saveRecord() async {
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
    if (!RegExp(r"^[a-zA-Z\\s.'-]+$").hasMatch(firstName)) {
      _showValidationError('First Name must contain letters only');
      return;
    }

    if (middleName.isNotEmpty && !RegExp(r"^[a-zA-Z\\s.'-]+$").hasMatch(middleName)) {
      _showValidationError('Middle Name must contain letters only');
      return;
    }

    if (lastName.isEmpty) {
      _showValidationError('Last Name is required');
      return;
    }
    if (lastName.length < 1) {
      _showValidationError('Last Name is required');
      return;
    }
    if (!RegExp(r"^[a-zA-Z\\s.'-]+$").hasMatch(lastName)) {
      _showValidationError('Last Name must contain letters only');
      return;
    }

    if (workEmail.isEmpty) {
      _showValidationError('Work email is required');
      return;
    }
    if (!RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)+$").hasMatch(workEmail)) {
      _showValidationError('Please enter a valid work email address (e.g. employee@saark.in)');
      return;
    }

    if (phone.isEmpty) {
      _showValidationError('Phone number is required');
      return;
    }
    if (phone.replaceAll(RegExp(r'[\\s\\-\\+\\(\\)]'), '').length < 10) {
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
    if (personalEmail.isNotEmpty && !RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)+$").hasMatch(personalEmail)) {
      _showValidationError('Please enter a valid Personal Email address');
      return;
    }

    final emergencyPhone = _emergencyContactController.text.trim();
    if (emergencyPhone.isNotEmpty && emergencyPhone.replaceAll(RegExp(r'[\\s\\-\\+\\(\\)]'), '').length < 7) {
      _showValidationError('Emergency Contact must contain a valid phone number');
      return;
    }

    if (fullName.isEmpty) {
      fullName = [firstName, if (middleName.isNotEmpty) middleName, lastName].join(' ');
    }"""

assert old_save_start in content, "old_save_start not found"
content = content.replace(old_save_start, new_save_start, 1)

# 9. Payload in _saveRecord
old_payload = """      final payload = {
        'firstName': firstName,
        'lastName': lastName,"""

new_payload = """      final payload = {
        'firstName': firstName,
        'middleName': middleName.isNotEmpty ? middleName : null,
        'lastName': lastName,"""

assert old_payload in content, "old_payload not found"
content = content.replace(old_payload, new_payload, 1)

# 10. updatedRec in _saveRecord
old_updated_rec = """        final updatedRec = EmployeeProfileRecord(
          dbId: updated.id,
          id: updated.employeeCode.isNotEmpty ? updated.employeeCode : code,
          firstName: firstName,
          middleName: middleName,
          fullName: fullName,"""

new_updated_rec = """        final updatedRec = EmployeeProfileRecord(
          dbId: updated.id,
          id: updated.employeeCode.isNotEmpty ? updated.employeeCode : code,
          firstName: firstName,
          middleName: middleName,
          lastName: lastName,
          fullName: fullName,"""

assert old_updated_rec in content, "old_updated_rec not found"
content = content.replace(old_updated_rec, new_updated_rec, 1)

# 11. newRec in _saveRecord
old_new_rec = """        final newRec = EmployeeProfileRecord(
          dbId: created.id,
          id: created.employeeCode,
          firstName: firstName,
          middleName: middleName,
          fullName: fullName,"""

new_new_rec = """        final newRec = EmployeeProfileRecord(
          dbId: created.id,
          id: created.employeeCode,
          firstName: firstName,
          middleName: middleName,
          lastName: lastName,
          fullName: fullName,"""

assert old_new_rec in content, "old_new_rec not found"
content = content.replace(old_new_rec, new_new_rec, 1)

# 12. Form content rows in _buildFormContent
old_form_rows = """        children: [
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
            rightInput: _buildDesignationDropdown(),
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
          ),"""

new_form_rows = """        children: [
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
            rightInput: Container(
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
          ),"""

assert old_form_rows in content, "old_form_rows not found"
content = content.replace(old_form_rows, new_form_rows, 1)

if has_crlf:
    content = content.replace('\n', '\r\n')

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("SUCCESS: employee_profile_view.dart updated successfully!")
