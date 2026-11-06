import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';
import 'package:saark_erp_mobile/features/attendance/data/attendance_repository.dart';

class DailyAttendanceTable extends ConsumerStatefulWidget {
  final List<AttendanceItem> records;
  final VoidCallback onRefresh;

  const DailyAttendanceTable({
    super.key,
    required this.records,
    required this.onRefresh,
  });

  @override
  ConsumerState<DailyAttendanceTable> createState() => _DailyAttendanceTableState();
}

class _DailyAttendanceTableState extends ConsumerState<DailyAttendanceTable> {
  String _searchQuery = '';
  String _selectedShift = 'ALL';
  String _selectedStatus = 'ALL';
  String _selectedDepartment = 'ALL';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.records.where((item) {
      final emp = item.employee;
      final fullName = '${emp?.firstName ?? ''} ${emp?.lastName ?? ''}'.toLowerCase();
      final code = (emp?.employeeCode ?? item.employeeId).toLowerCase();
      final dept = (emp?.departmentName ?? '').toLowerCase();

      // Search match
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!fullName.contains(q) && !code.contains(q) && !dept.contains(q)) {
          return false;
        }
      }

      // Shift match
      if (_selectedShift != 'ALL' && item.shiftCode.toUpperCase() != _selectedShift) {
        return false;
      }

      // Status match
      if (_selectedStatus != 'ALL' && item.status.toUpperCase() != _selectedStatus) {
        return false;
      }

      // Department match
      if (_selectedDepartment != 'ALL') {
        if (emp?.departmentName?.toUpperCase() != _selectedDepartment.toUpperCase()) {
          return false;
        }
      }

      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter toolbar
        _buildFilterBar(),
        const SizedBox(height: 14),

        // Attendance Table Container
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16191F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF262C38), width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width - 80,
                          ),
                          child: DataTable(
                            headingRowHeight: 44,
                            dataRowMaxHeight: 62,
                            dataRowMinHeight: 52,
                            horizontalMargin: 16,
                            columnSpacing: 20,
                            headingRowColor: WidgetStateProperty.all(const Color(0xFF1E222B)),
                            dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                              (states) => states.contains(WidgetState.hovered)
                                  ? const Color(0xFF222733)
                                  : Colors.transparent,
                            ),
                            dividerThickness: 0.8,
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'EMPLOYEE / ID',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'SHIFT & ROSTER',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'PUNCH IN (TIME & SOURCE)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'PUNCH OUT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'DURATION',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'STATUS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'OVERTIME (HRS)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'ACTIONS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                            rows: filtered.map((item) => _buildRow(item)).toList(),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildRow(AttendanceItem item) {
    final emp = item.employee;
    final fullName = emp != null ? '${emp.firstName} ${emp.lastName}' : item.employeeId;
    final code = emp?.employeeCode ?? 'EMP';
    final dept = emp?.departmentName ?? 'Plant Operations';
    final desig = emp?.designation ?? 'Technician';

    final timeFormatter = DateFormat('hh:mm a');
    final inTimeStr = item.punchIn != null ? timeFormatter.format(item.punchIn!) : '—';
    final outTimeStr = item.punchOut != null ? timeFormatter.format(item.punchOut!) : '—';

    final statusColor = _getStatusColor(item.status);

    return DataRow(
      cells: [
        // Employee Info
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: Text(
                  fullName.isNotEmpty ? fullName.substring(0, 1).toUpperCase() : 'E',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$code • $desig • $dept',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Shift & Roster
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF252A34),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.shiftCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _getShiftTimeLabel(item.shiftCode),
                style: const TextStyle(fontSize: 10.5, color: Colors.white38),
              ),
            ],
          ),
        ),

        // In Punch
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    inTimeStr,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: item.punchIn != null ? Colors.white : Colors.white38,
                    ),
                  ),
                  if (item.punchIn != null) ...[
                    const SizedBox(width: 6),
                    Icon(
                      item.checkInNote?.contains('Face') == true
                          ? Icons.face_rounded
                          : (item.checkInNote?.contains('Finger') == true
                              ? Icons.fingerprint_rounded
                              : Icons.touch_app_outlined),
                      size: 13,
                      color: const Color(0xFF38BDF8),
                    ),
                  ],
                ],
              ),
              if (item.location != null)
                Text(
                  item.location!,
                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),

        // Out Punch
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                outTimeStr,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: item.punchOut != null ? Colors.white : Colors.white38,
                ),
              ),
              if (item.punchIn != null && item.punchOut == null)
                const Text(
                  'Shift In Progress',
                  style: TextStyle(fontSize: 10, color: Colors.greenAccent),
                ),
            ],
          ),
        ),

        // Duration / Work Hours
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${item.workHours.toStringAsFixed(1)} hrs',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                width: 70,
                child: LinearProgressIndicator(
                  value: (item.workHours / 8.0).clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFF2E3440),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    item.workHours >= 8.0 ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  minHeight: 3.5,
                ),
              ),
            ],
          ),
        ),

        // Status Badge
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              item.status.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ),

        // Overtime
        DataCell(
          item.overtimeHours > 0
              ? Row(
                  children: [
                    Text(
                      '+${item.overtimeHours.toStringAsFixed(1)} h',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      item.overtimeApproved ? Icons.verified_rounded : Icons.pending_outlined,
                      size: 14,
                      color: item.overtimeApproved ? Colors.greenAccent : Colors.amberAccent,
                    ),
                  ],
                )
              : const Text('0.0 h', style: TextStyle(fontSize: 12, color: Colors.white38)),
        ),

        // Actions
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.punchIn != null && item.punchOut == null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _handleQuickClockOut(item),
                  child: const Text('Clock Out'),
                ),
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, size: 20, color: Colors.white70),
                tooltip: 'Manual Punch Adjustment',
                onPressed: () => _showManualAdjustmentDialog(item),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16191F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF262C38), width: 1.2),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Box
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by employee or code...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E222B),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF2E3440)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF2E3440)),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Shift Dropdown
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E222B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2E3440)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedShift,
                dropdownColor: const Color(0xFF1E222B),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Shifts')),
                  DropdownMenuItem(value: 'SHIFT_G', child: Text('General (09:00 - 18:00)')),
                  DropdownMenuItem(value: 'SHIFT_A', child: Text('Shift A (06:00 - 14:30)')),
                  DropdownMenuItem(value: 'SHIFT_B', child: Text('Shift B (14:30 - 23:00)')),
                  DropdownMenuItem(value: 'SHIFT_C', child: Text('Shift C (23:00 - 07:00)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedShift = val);
                },
              ),
            ),
          ),

          // Status Filter Chips
          ...['ALL', 'PRESENT', 'LATE', 'ABSENT', 'ON_LEAVE'].map((status) {
            final isSelected = _selectedStatus == status;
            return ChoiceChip(
              label: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.primary,
              backgroundColor: const Color(0xFF1E222B),
              side: BorderSide(
                color: isSelected ? AppTheme.primary : const Color(0xFF2E3440),
              ),
              onSelected: (_) => setState(() => _selectedStatus = status),
            );
          }),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
            tooltip: 'Refresh Ledger',
            onPressed: widget.onRefresh,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            const Text(
              'No attendance records found matching filters',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try clearing search filters or changing the selected shift.',
              style: TextStyle(fontSize: 12, color: Colors.white38),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _selectedShift = 'ALL';
                  _selectedStatus = 'ALL';
                  _selectedDepartment = 'ALL';
                });
              },
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PRESENT':
        return const Color(0xFF22C55E); // Green
      case 'LATE':
        return const Color(0xFFF59E0B); // Amber
      case 'HALF_DAY':
        return Colors.orangeAccent;
      case 'ABSENT':
        return const Color(0xFFEF4444); // Red
      case 'ON_LEAVE':
        return const Color(0xFF38BDF8); // Cyan
      default:
        return Colors.white54;
    }
  }

  String _getShiftTimeLabel(String shift) {
    switch (shift.toUpperCase()) {
      case 'SHIFT_G':
        return '09:00 - 18:00';
      case 'SHIFT_A':
        return '06:00 - 14:30';
      case 'SHIFT_B':
        return '14:30 - 23:00';
      case 'SHIFT_C':
        return '23:00 - 07:00';
      default:
        return 'Standard Shift';
    }
  }

  Future<void> _handleQuickClockOut(AttendanceItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: const Text('Confirm Shift Clock-Out', style: TextStyle(color: Colors.white)),
        content: Text(
          'Record shift clock-out punch for ${item.employee?.firstName ?? item.employeeId} at ${DateFormat("hh:mm a").format(DateTime.now())}?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Record Clock-Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(attendanceRepositoryProvider);
      await repo.clockOut(employeeId: item.employeeId, note: 'Supervisor Clock-Out');
      widget.onRefresh();
    }
  }

  void _showManualAdjustmentDialog(AttendanceItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: Row(
          children: [
            const Icon(Icons.edit_calendar_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Punch Adjustment • ${item.employee?.firstName ?? item.employeeId}',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${DateFormat("yyyy-MM-dd").format(item.punchDate)} • Shift: ${item.shiftCode}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Manual adjustments are logged with supervisor ID in compliance with Factories Act Form 25 audit requirements.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Punch record updated successfully'),
                  backgroundColor: Color(0xFF166534),
                ),
              );
              widget.onRefresh();
            },
            child: const Text('Save Override', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
