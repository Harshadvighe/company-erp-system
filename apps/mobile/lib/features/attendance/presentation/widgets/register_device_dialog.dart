import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/attendance/data/attendance_device_model.dart';
import 'package:saark_erp_mobile/features/attendance/data/attendance_repository.dart';

class RegisterDeviceDialog extends ConsumerStatefulWidget {
  final BiometricDevice? existingDevice;
  final VoidCallback onSaved;

  const RegisterDeviceDialog({
    super.key,
    this.existingDevice,
    required this.onSaved,
  });

  @override
  ConsumerState<RegisterDeviceDialog> createState() => _RegisterDeviceDialogState();
}

class _RegisterDeviceDialogState extends ConsumerState<RegisterDeviceDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _manufacturerController;
  late TextEditingController _modelController;
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;

  String _deviceType = 'FINGERPRINT_FACE';
  String _connectionType = 'TCP_IP';
  bool _autoSyncEnabled = true;
  int _syncIntervalMinutes = 15;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.existingDevice;
    _codeController = TextEditingController(text: d?.deviceCode ?? 'TM-2026-000${DateTime.now().millisecond % 900 + 100}');
    _nameController = TextEditingController(text: d?.deviceName ?? '');
    _manufacturerController = TextEditingController(text: d?.manufacturer ?? 'TeamOffice');
    _modelController = TextEditingController(text: d?.model ?? 'TM-700 Facial + Fingerprint');
    _ipController = TextEditingController(text: d?.ipAddress ?? '192.168.1.114');
    _portController = TextEditingController(text: '${d?.port ?? 5005}');
    _locationController = TextEditingController(text: d?.location ?? 'Saark Office / Plant');
    _notesController = TextEditingController(text: d?.notes ?? '');

    if (d != null) {
      _deviceType = d.deviceType;
      _connectionType = d.connectionType;
      _autoSyncEnabled = d.autoSyncEnabled;
      _syncIntervalMinutes = d.syncIntervalMinutes;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _manufacturerController.dispose();
    _modelController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final repo = ref.read(attendanceRepositoryProvider);
    final payload = {
      'deviceCode': _codeController.text.trim(),
      'deviceName': _nameController.text.trim(),
      'manufacturer': _manufacturerController.text.trim(),
      'model': _modelController.text.trim(),
      'deviceType': _deviceType,
      'connectionType': _connectionType,
      'ipAddress': _ipController.text.trim(),
      'port': int.tryParse(_portController.text.trim()) ?? 4370,
      'location': _locationController.text.trim(),
      'autoSyncEnabled': _autoSyncEnabled,
      'syncIntervalMinutes': _syncIntervalMinutes,
      'notes': _notesController.text.trim(),
    };

    try {
      if (widget.existingDevice != null) {
        await repo.updateDevice(widget.existingDevice!.id, payload);
      } else {
        await repo.registerDevice(payload);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingDevice != null
                  ? 'Biometric terminal updated successfully'
                  : 'New biometric terminal registered successfully',
            ),
            backgroundColor: const Color(0xFF166534),
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving terminal: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingDevice != null;

    return Dialog(
      backgroundColor: const Color(0xFF16191F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2E3440), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.fingerprint_rounded, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Configure Biometric Machine' : 'Register New Biometric Machine',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'TeamOffice, ZKTeco, Suprema, eSSL & Realtime hardware integration',
                              style: TextStyle(fontSize: 11.5, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF262C38), height: 1),
                  const SizedBox(height: 18),

                  // Device Code & Name
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: _codeController,
                          label: 'DEVICE CODE',
                          hint: 'TM-2026-0001',
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          controller: _nameController,
                          label: 'DEVICE NAME',
                          hint: 'Main Gate Turnstile Face/Finger',
                          required: true,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Manufacturer & Model
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _manufacturerController,
                          label: 'MANUFACTURER',
                          hint: 'TeamOffice / ZKTeco',
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _modelController,
                          label: 'HARDWARE MODEL',
                          hint: 'TM-700 / uFace 800 Plus',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Biometric Type & Protocol
                  Row(
                    children: [
                      // Biometric Type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CAPTURE TYPE',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white60),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E222B),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF2E3440)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _deviceType,
                                  dropdownColor: const Color(0xFF1E222B),
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                  items: const [
                                    DropdownMenuItem(value: 'FINGERPRINT_FACE', child: Text('Face & Fingerprint')),
                                    DropdownMenuItem(value: 'FACE', child: Text('Facial Recognition')),
                                    DropdownMenuItem(value: 'FINGERPRINT', child: Text('Optical Fingerprint')),
                                    DropdownMenuItem(value: 'RFID', child: Text('RFID Card Reader')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _deviceType = v);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Connection Type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CONNECTION PROTOCOL',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white60),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E222B),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF2E3440)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _connectionType,
                                  dropdownColor: const Color(0xFF1E222B),
                                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                  items: const [
                                    DropdownMenuItem(value: 'TCP_IP', child: Text('TCP/IP Socket (Port 4370)')),
                                    DropdownMenuItem(value: 'HTTP', child: Text('HTTP Web API')),
                                    DropdownMenuItem(value: 'CLOUD', child: Text('Cloud Agent Sync')),
                                    DropdownMenuItem(value: 'USB', child: Text('USB Terminal')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _connectionType = v);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // IP & Port
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          controller: _ipController,
                          label: 'DEVICE IP ADDRESS (LAN / WAN)',
                          hint: '192.168.1.105',
                          required: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildTextField(
                          controller: _portController,
                          label: 'PORT',
                          hint: '4370',
                          required: true,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Location
                  _buildTextField(
                    controller: _locationController,
                    label: 'PLANT LOCATION',
                    hint: 'MIDC Plant Security Gate A / Assembly Bay 2',
                  ),

                  const SizedBox(height: 14),

                  // Auto Sync Cadence
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E222B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2E3440)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Background Auto-Sync',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                            Text(
                              'Polls terminal every $_syncIntervalMinutes minutes',
                              style: const TextStyle(fontSize: 11, color: Colors.white54),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _syncIntervalMinutes,
                                dropdownColor: const Color(0xFF1E222B),
                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12),
                                items: const [
                                  DropdownMenuItem(value: 5, child: Text('5 mins')),
                                  DropdownMenuItem(value: 10, child: Text('10 mins')),
                                  DropdownMenuItem(value: 15, child: Text('15 mins')),
                                  DropdownMenuItem(value: 30, child: Text('30 mins')),
                                  DropdownMenuItem(value: 60, child: Text('1 hour')),
                                ],
                                onChanged: (v) {
                                  if (v != null) setState(() => _syncIntervalMinutes = v);
                                },
                              ),
                            ),
                            Switch(
                              value: _autoSyncEnabled,
                              activeTrackColor: AppTheme.primary,
                              onChanged: (v) => setState(() => _autoSyncEnabled = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onPressed: _isSaving ? null : _handleSubmit,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_rounded, size: 16),
                        label: Text(
                          _isSaving ? 'Saving...' : (isEdit ? 'Update Terminal' : 'Save Terminal'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white60,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF1E222B),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF2E3440)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFF2E3440)),
            ),
          ),
          validator: required
              ? (val) => (val == null || val.trim().isEmpty) ? 'Required' : null
              : null,
        ),
      ],
    );
  }
}
