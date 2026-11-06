import 'package:flutter/material.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';

class ShiftRosterView extends StatelessWidget {
  final List<Map<String, dynamic>> shifts;
  final List<Employee> employees;

  const ShiftRosterView({
    super.key,
    required this.shifts,
    required this.employees,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shifts Grid
          const Text(
            'MANUFACTURING PLANT SHIFT TIMETABLE & ALLOWANCES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 850;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: shifts.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 4 : 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: isDesktop ? 1.3 : 1.1,
                ),
                itemBuilder: (ctx, idx) => _buildShiftCard(shifts[idx]),
              );
            },
          ),

          const SizedBox(height: 28),

          // Factories Act Form 25 Muster Roll
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FACTORIES ACT 1948 • FORM 25 MUSTER ROLL REGISTER',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Statutory daily attendance ledger for manufacturing bay technicians & staff',
                    style: TextStyle(fontSize: 11.5, color: Colors.white54),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Form 25 Muster Roll generated for download (PDF/Excel)'),
                      backgroundColor: Color(0xFF166534),
                    ),
                  );
                },
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: const Text('Export Form 25 (PDF)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Form 25 Matrix Table
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16191F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF262C38), width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF1E222B)),
                  headingRowHeight: 40,
                  dataRowMaxHeight: 48,
                  dataRowMinHeight: 44,
                  horizontalMargin: 12,
                  columnSpacing: 10,
                  columns: [
                    const DataColumn(label: Text('EMP CODE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('EMPLOYEE NAME', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('DEPT', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                    ...List.generate(
                      15,
                      (i) => DataColumn(
                        label: Text(
                          '${i + 1}',
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const DataColumn(label: Text('PRESENT', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('ABSENT', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))),
                    const DataColumn(label: Text('TOTAL OT', style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                  rows: employees.map((emp) {
                    final isOffice = emp.workerCategory == 'STAFF_OFFICE';
                    return DataRow(
                      cells: [
                        DataCell(Text(emp.employeeCode, style: const TextStyle(fontSize: 11.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold))),
                        DataCell(Text('${emp.firstName} ${emp.lastName}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600))),
                        DataCell(Text(emp.departmentName ?? 'Factory', style: const TextStyle(fontSize: 11, color: Colors.white54))),
                        ...List.generate(15, (dayIndex) {
                          // Day 7 & 14 Sunday weekly off
                          final isSunday = (dayIndex + 1) == 7 || (dayIndex + 1) == 14;
                          final status = isSunday ? 'WO' : ((dayIndex % 4 == 0 && !isOffice) ? 'A' : 'P');
                          return DataCell(
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _matrixColor(status).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _matrixColor(status),
                                ),
                              ),
                            ),
                          );
                        }),
                        const DataCell(Text('12', style: TextStyle(fontSize: 11.5, color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                        const DataCell(Text('1', style: TextStyle(fontSize: 11.5, color: Colors.redAccent, fontWeight: FontWeight.bold))),
                        const DataCell(Text('4.5 h', style: TextStyle(fontSize: 11.5, color: AppTheme.primary, fontWeight: FontWeight.bold))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final code = shift['code']?.toString() ?? 'SHIFT_G';
    final name = shift['name']?.toString() ?? 'Shift';
    final startTime = shift['startTime']?.toString() ?? '09:00';
    final endTime = shift['endTime']?.toString() ?? '18:00';
    final grace = shift['graceMinutes']?.toString() ?? '15';
    final lunch = shift['lunchBreakMinutes']?.toString() ?? '45';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16191F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF262C38), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const Icon(Icons.access_time_filled, size: 16, color: Color(0xFF38BDF8)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '$startTime - $endTime',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF38BDF8),
            ),
          ),
          const Spacer(),
          Text(
            'Grace: $grace mins • Lunch: $lunch mins',
            style: const TextStyle(fontSize: 10.5, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Color _matrixColor(String code) {
    switch (code) {
      case 'P':
        return Colors.greenAccent;
      case 'A':
        return Colors.redAccent;
      case 'HD':
        return Colors.orangeAccent;
      case 'WO':
        return Colors.white38;
      case 'L':
        return const Color(0xFF38BDF8);
      default:
        return Colors.white54;
    }
  }
}
