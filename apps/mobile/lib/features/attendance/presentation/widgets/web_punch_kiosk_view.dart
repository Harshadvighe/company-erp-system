import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';
import 'package:saark_erp_mobile/features/attendance/data/attendance_repository.dart';

class WebPunchKioskView extends ConsumerStatefulWidget {
  final List<Employee> employees;
  final VoidCallback onPunchCompleted;

  const WebPunchKioskView({
    super.key,
    required this.employees,
    required this.onPunchCompleted,
  });

  @override
  ConsumerState<WebPunchKioskView> createState() => _WebPunchKioskViewState();
}

class _WebPunchKioskViewState extends ConsumerState<WebPunchKioskView> {
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  Employee? _selectedEmployee;
  String _selectedShift = 'SHIFT_G';
  String _selectedBay = 'BAY_1_FABRICATION';
  bool _ppeCompliant = true;
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _recentKioskPunches = [];

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });

    if (widget.employees.isNotEmpty) {
      _selectedEmployee = widget.employees.first;
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handlePunch({required bool isClockIn}) async {
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an employee before punching.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final repo = ref.read(attendanceRepositoryProvider);
    try {
      if (isClockIn) {
        await repo.clockIn(
          employeeId: _selectedEmployee!.id,
          location: 'MIDC Plant Web Terminal',
          note: _noteController.text.trim().isNotEmpty
              ? _noteController.text.trim()
              : 'Web Kiosk Punch In',
          shiftCode: _selectedShift,
          assignedBay: _selectedBay,
          ppeCompliant: _ppeCompliant,
        );
      } else {
        await repo.clockOut(
          employeeId: _selectedEmployee!.id,
          note: _noteController.text.trim().isNotEmpty
              ? _noteController.text.trim()
              : 'Web Kiosk Shift Out',
        );
      }

      final punchRecord = {
        'employee': _selectedEmployee!,
        'type': isClockIn ? 'CLOCK_IN' : 'CLOCK_OUT',
        'time': DateTime.now(),
        'bay': _selectedBay,
        'shift': _selectedShift,
      };

      setState(() {
        _recentKioskPunches.insert(0, punchRecord);
        _noteController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isClockIn ? Icons.login_rounded : Icons.logout_rounded,
                  color: isClockIn ? Colors.greenAccent : Colors.orangeAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${isClockIn ? "CLOCK-IN" : "CLOCK-OUT"} Recorded for ${_selectedEmployee!.firstName} ${_selectedEmployee!.lastName} (${_selectedEmployee!.employeeCode})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E222B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      widget.onPunchCompleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Punch Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);
    final dateStr = DateFormat('EEEE, MMMM dd, yyyy').format(_currentTime);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Punch Console
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16191F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF262C38), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Digital Industrial Clock
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E222B), Color(0xFF16191F)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF38BDF8),
                                letterSpacing: 2.0,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fiber_manual_record, size: 10, color: Colors.greenAccent),
                                  SizedBox(width: 6),
                                  Text(
                                    'STATION READY • MIDC UNIT 1',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.greenAccent,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Select Employee
                      const Text(
                        'SELECT WORKER / TECHNICIAN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E222B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2E3440)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Employee>(
                            isExpanded: true,
                            value: _selectedEmployee,
                            dropdownColor: const Color(0xFF1E222B),
                            hint: const Text('Select Employee', style: TextStyle(color: Colors.white38)),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            items: widget.employees.map((emp) {
                              return DropdownMenuItem<Employee>(
                                value: emp,
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF252A34),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        emp.employeeCode,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF38BDF8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${emp.firstName} ${emp.lastName}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${emp.designation})',
                                      style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (emp) {
                              if (emp != null) {
                                setState(() {
                                  _selectedEmployee = emp;
                                  _selectedShift = emp.shiftCode;
                                  if (emp.assignedBay != null) {
                                    _selectedBay = emp.assignedBay!;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Shift & Bay Grid
                      Row(
                        children: [
                          // Shift Selector
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ASSIGNED SHIFT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E222B),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF2E3440)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _selectedShift,
                                      dropdownColor: const Color(0xFF1E222B),
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'SHIFT_G',
                                          child: Text('General (09:00 - 18:00)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'SHIFT_A',
                                          child: Text('Shift A (06:00 - 14:30)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'SHIFT_B',
                                          child: Text('Shift B (14:30 - 23:00)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'SHIFT_C',
                                          child: Text('Shift C (23:00 - 07:00)'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedShift = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Bay Selector
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'WORKSTATION / SHOPFLOOR BAY',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E222B),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF2E3440)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      value: _selectedBay,
                                      dropdownColor: const Color(0xFF1E222B),
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      items: const [
                                        DropdownMenuItem(value: 'BAY_1_FABRICATION', child: Text('Bay 1 - Enclosure Fabrication')),
                                        DropdownMenuItem(value: 'BAY_2_BUSBAR', child: Text('Bay 2 - Copper Busbar')),
                                        DropdownMenuItem(value: 'BAY_3_MOUNTING', child: Text('Bay 3 - Component Mounting')),
                                        DropdownMenuItem(value: 'BAY_4_WIRING', child: Text('Bay 4 - Control Wiring')),
                                        DropdownMenuItem(value: 'BAY_5_FAT_TESTING', child: Text('Bay 5 - FAT Testing & QA')),
                                        DropdownMenuItem(value: 'BAY_6_DISPATCH', child: Text('Bay 6 - Final Dispatch')),
                                        DropdownMenuItem(value: 'EXECUTIVE_OFFICE', child: Text('Executive / Engineering Office')),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedBay = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // PPE Safety Switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E222B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2E3440)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.security_rounded, color: Colors.greenAccent, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PPE Safety Compliance Confirmed',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Technician wearing helmet, safety shoes & antistatic wristband',
                                    style: TextStyle(fontSize: 11, color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _ppeCompliant,
                              activeTrackColor: Colors.greenAccent,
                              onChanged: (val) => setState(() => _ppeCompliant = val),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Punch Note
                      TextField(
                        controller: _noteController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Optional shift / job note (e.g. Panel Job #2041 FAT Stage)...',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1E222B),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2E3440)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2E3440)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Big Tactile Punch Buttons
                      Row(
                        children: [
                          // Clock-In Button
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF166534), // Dark Green
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: _isSubmitting ? null : () => _handlePunch(isClockIn: true),
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.login_rounded, size: 22),
                                label: const Text(
                                  'CLOCK IN (START SHIFT)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Clock-Out Button
                          Expanded(
                            child: SizedBox(
                              height: 54,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF991B1B), // Dark Red
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: _isSubmitting ? null : () => _handlePunch(isClockIn: false),
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.logout_rounded, size: 22),
                                label: const Text(
                                  'CLOCK OUT (END SHIFT)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (isWide) ...[
              const SizedBox(width: 20),
              // Right: Recent Punch Activity Feed
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16191F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF262C38), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.history_rounded, size: 18, color: Color(0xFF38BDF8)),
                              SizedBox(width: 8),
                              Text(
                                'RECENT TERMINAL ACTIVITY',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white70,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252A34),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${_recentKioskPunches.length} Today',
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Color(0xFF262C38), height: 1),
                      const SizedBox(height: 12),

                      if (_recentKioskPunches.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.touch_app_outlined, size: 36, color: Colors.white24),
                                SizedBox(height: 8),
                                Text(
                                  'No punches logged this session',
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentKioskPunches.length,
                          separatorBuilder: (_, __) => const Divider(color: Color(0xFF262C38), height: 14),
                          itemBuilder: (ctx, idx) {
                            final p = _recentKioskPunches[idx];
                            final emp = p['employee'] as Employee;
                            final isClockIn = p['type'] == 'CLOCK_IN';
                            final time = DateFormat('hh:mm:ss a').format(p['time'] as DateTime);

                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isClockIn
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.red.withValues(alpha: 0.2),
                                  child: Icon(
                                    isClockIn ? Icons.login_rounded : Icons.logout_rounded,
                                    size: 14,
                                    color: isClockIn ? Colors.greenAccent : Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${emp.firstName} ${emp.lastName}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '${emp.employeeCode} • ${p['bay']}',
                                        style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  time,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
