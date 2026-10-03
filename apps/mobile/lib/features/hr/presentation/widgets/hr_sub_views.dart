import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/features/hr/data/hr_repository.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';

// -------------------------------------------------------------
// REUSABLE SUB-WORKSPACE HEADER & TOOLBAR
// -------------------------------------------------------------
Widget buildHrSubHeader({
  required String title,
  required String subtitle,
  required IconData icon,
  List<Widget>? actions,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: const BoxDecoration(
      color: Color(0xFF1E2024),
      border: Border(bottom: BorderSide(color: Color(0xFF2E3238))),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFFF26522), size: 22),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        const Spacer(),
        if (actions != null) ...actions,
      ],
    ),
  );
}

// -------------------------------------------------------------
// 1. SHIFT SETUP VIEW
// -------------------------------------------------------------
class ShiftSetupView extends ConsumerWidget {
  const ShiftSetupView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shiftsAsync = ref.watch(shiftsProvider);

    return Column(
      children: [
        buildHrSubHeader(
          title: 'Shift Setup & Rosters',
          subtitle: 'Indian Factories Act 1948 compliant shift timings, grace minutes, and allowances',
          icon: Icons.alarm,
          actions: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 14),
              label: const Text('New Shift Roster'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF26522),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        Expanded(
          child: shiftsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF26522))),
            error: (err, _) => Center(child: Text('Error loading shifts: $err', style: const TextStyle(color: Colors.redAccent))),
            data: (shifts) {
              final list = shifts.isNotEmpty
                  ? shifts
                  : [
                      const ShiftMasterItem(
                        id: 's1',
                        code: 'SHIFT_G',
                        name: 'General Day Shift (Engineering & Plant)',
                        startTime: '08:30',
                        endTime: '17:00',
                        graceMinutes: 15,
                        shiftAllowance: 0,
                        departmentName: 'Engineering & Assembly',
                      ),
                      const ShiftMasterItem(
                        id: 's2',
                        code: 'SHIFT_A',
                        name: 'Morning Assembly Shift',
                        startTime: '06:00',
                        endTime: '14:30',
                        graceMinutes: 15,
                        shiftAllowance: 100,
                        departmentName: 'Fabrication & Busbar',
                      ),
                      const ShiftMasterItem(
                        id: 's3',
                        code: 'SHIFT_B',
                        name: 'Afternoon Wiring Shift',
                        startTime: '14:00',
                        endTime: '22:30',
                        graceMinutes: 15,
                        shiftAllowance: 150,
                        departmentName: 'Wiring & Mounting',
                      ),
                      const ShiftMasterItem(
                        id: 's4',
                        code: 'SHIFT_N',
                        name: 'Night Testing & Commissioning Shift',
                        startTime: '22:00',
                        endTime: '06:30',
                        graceMinutes: 10,
                        shiftAllowance: 250,
                        departmentName: 'FAT Testing & Dispatch',
                      ),
                    ];

              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final s = list[i];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2024),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2E3238)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF26522).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFF26522).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            s.code,
                            style: const TextStyle(color: Color(0xFFF26522), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                'Hours: ${s.startTime} - ${s.endTime} | Grace Window: ${s.graceMinutes} mins | Dept: ${s.departmentName ?? "Plant Floor"}',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              s.shiftAllowance > 0 ? '₹${s.shiftAllowance.toStringAsFixed(0)} / shift' : 'No Allowance',
                              style: TextStyle(
                                color: s.shiftAllowance > 0 ? Colors.greenAccent : Colors.white38,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text('Active Roster', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// 2. ATTENDANCE & LEAVE VIEW (FORM 25 MUSTER ROLL)
// -------------------------------------------------------------
class AttendanceLeaveView extends ConsumerWidget {
  const AttendanceLeaveView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(attendanceTodayProvider);

    return Column(
      children: [
        buildHrSubHeader(
          title: 'Attendance & Leave Ledger',
          subtitle: 'Daily biometric punches, Factories Act Form 25 muster register, and overtime tracking',
          icon: Icons.calendar_month_outlined,
          actions: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, size: 14),
              label: const Text('Export Form 25 Muster Roll'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        Expanded(
          child: attendanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF26522))),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
            data: (records) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // KPI Cards
                  Row(
                    children: [
                      _kpiCard('PRESENT TODAY', '${records.where((r) => r.status == "PRESENT").length}', Colors.greenAccent),
                      const SizedBox(width: 12),
                      _kpiCard('ON LEAVE', '${records.where((r) => r.status == "ON_LEAVE").length}', Colors.orangeAccent),
                      const SizedBox(width: 12),
                      _kpiCard('OVERTIME LOGGED', '${records.fold(0.0, (sum, r) => sum + r.overtimeHours).toStringAsFixed(1)} Hrs', const Color(0xFFF26522)),
                      const SizedBox(width: 12),
                      _kpiCard('PPE COMPLIANT', '98%', Colors.lightBlueAccent),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Table
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2024),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2E3238)),
                    ),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFF25282E)),
                      dataRowColor: WidgetStateProperty.all(const Color(0xFF1E2024)),
                      columns: const [
                        DataColumn(label: Text('Employee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Shift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Punch In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Punch Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Hours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Overtime', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                      rows: records.map((r) {
                        return DataRow(cells: [
                          DataCell(Text(r.employee?.fullName ?? r.employeeId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
                          DataCell(Text(r.shiftCode, style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(r.punchIn != null ? DateFormat('HH:mm').format(r.punchIn!) : '--:--', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(r.punchOut != null ? DateFormat('HH:mm').format(r.punchOut!) : '--:--', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text('${r.workHours}h', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(
                            r.overtimeHours > 0 ? '+${r.overtimeHours}h (Sec 59)' : '-',
                            style: TextStyle(color: r.overtimeHours > 0 ? const Color(0xFFF26522) : Colors.white38),
                          )),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: r.status == 'PRESENT' ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r.status,
                              style: TextStyle(
                                color: r.status == 'PRESENT' ? Colors.greenAccent : Colors.orangeAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2024),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2E3238)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 3. LEAVE REQUESTS VIEW
// -------------------------------------------------------------
class LeaveRequestsView extends ConsumerWidget {
  const LeaveRequestsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(leaveRequestsProvider(null));

    return Column(
      children: [
        buildHrSubHeader(
          title: 'Leave Requests & Approvals',
          subtitle: 'Casual, Sick, Earned/Privilege leaves approval workflow for plant and office workforce',
          icon: Icons.move_to_inbox_outlined,
          actions: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Apply Leave'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF26522),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        Expanded(
          child: leavesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF26522))),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
            data: (leaves) {
              if (leaves.isEmpty) {
                return const Center(
                  child: Text('No leave requests found.', style: TextStyle(color: Colors.white54)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: leaves.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final lv = leaves[i];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2024),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2E3238)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFF26522).withValues(alpha: 0.2),
                          foregroundColor: const Color(0xFFF26522),
                          child: const Icon(Icons.event_note, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    lv.employee?.fullName ?? 'Employee',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white12,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(lv.leaveType, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Duration: ${DateFormat('dd MMM').format(lv.startDate)} to ${DateFormat('dd MMM yyyy').format(lv.endDate)} (${lv.daysCount} days)',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text('Reason: ${lv.reason}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (lv.status == 'PENDING') ...[
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                            ),
                            child: const Text('Reject', style: TextStyle(fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Approve', style: TextStyle(fontSize: 11)),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: lv.status == 'APPROVED' ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              lv.status,
                              style: TextStyle(
                                color: lv.status == 'APPROVED' ? Colors.greenAccent : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// 4. PAYROLL & COMPENSATION VIEW
// -------------------------------------------------------------
class PayrollCompensationView extends ConsumerWidget {
  const PayrollCompensationView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payrollAsync = ref.watch(payrollListProvider);

    return Column(
      children: [
        buildHrSubHeader(
          title: 'Payroll & Statutory Compensation',
          subtitle: 'Salary breakdown, Basic, HRA, Overtime Wages (Sec 59), EPF 12%, ESI, and Professional Tax',
          icon: Icons.payments_outlined,
          actions: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.play_arrow, size: 14),
              label: const Text('Run Monthly Payroll Batch'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF26522),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        Expanded(
          child: payrollAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFF26522))),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
            data: (records) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      _paySummaryCard('TOTAL GROSS PAY', '₹${records.fold(0.0, (s, r) => s + r.grossPay).toStringAsFixed(0)}', Colors.white),
                      const SizedBox(width: 12),
                      _paySummaryCard('EPF DEDUCTIONS (12%)', '₹${records.fold(0.0, (s, r) => s + r.pfDeduction).toStringAsFixed(0)}', Colors.orangeAccent),
                      const SizedBox(width: 12),
                      _paySummaryCard('OVERTIME WAGES', '₹${records.fold(0.0, (s, r) => s + r.overtimePay).toStringAsFixed(0)}', const Color(0xFFF26522)),
                      const SizedBox(width: 12),
                      _paySummaryCard('TOTAL NET PAYOUT', '₹${records.fold(0.0, (s, r) => s + r.netPay).toStringAsFixed(0)}', Colors.greenAccent),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2024),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2E3238)),
                    ),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFF25282E)),
                      columns: const [
                        DataColumn(label: Text('Slip Number', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Employee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Basic', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Gross Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('PF / ESI / PT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Net Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                      rows: records.map((r) {
                        return DataRow(cells: [
                          DataCell(Text(r.slipNumber, style: const TextStyle(color: Color(0xFFF26522), fontWeight: FontWeight.bold, fontSize: 12))),
                          DataCell(Text(r.employee?.fullName ?? r.employeeId, style: const TextStyle(color: Colors.white))),
                          DataCell(Text('₹${r.basicSalary.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text('₹${r.grossPay.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70))),
                          DataCell(Text('₹${r.totalDeductions.toStringAsFixed(0)}', style: const TextStyle(color: Colors.orangeAccent))),
                          DataCell(Text('₹${r.netPay.toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(r.paymentStatus, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _paySummaryCard(String title, String val, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2024),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2E3238)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(val, style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 5. GENERIC STRUCTURED WORKSPACE VIEW FOR OTHER SUB-MODULES
// -------------------------------------------------------------
class GenericHrWorkspaceView extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String primaryActionLabel;
  final List<String> tableHeaders;
  final List<List<String>> sampleRows;

  const GenericHrWorkspaceView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryActionLabel,
    required this.tableHeaders,
    required this.sampleRows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildHrSubHeader(
          title: title,
          subtitle: subtitle,
          icon: icon,
          actions: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.filter_list, size: 14),
              label: const Text('Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 14),
              label: Text(primaryActionLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF26522),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2024),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF2E3238)),
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF25282E)),
                  columns: tableHeaders
                      .map((h) => DataColumn(label: Text(h, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))))
                      .toList(),
                  rows: sampleRows.map((row) {
                    return DataRow(
                      cells: row
                          .map((cell) => DataCell(Text(cell, style: const TextStyle(color: Colors.white70, fontSize: 12))))
                          .toList(),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
