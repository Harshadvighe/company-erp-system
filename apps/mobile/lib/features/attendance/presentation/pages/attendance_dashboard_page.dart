import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/widgets/back_to_dashboard_button.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';
import 'package:saark_erp_mobile/features/attendance/data/attendance_device_model.dart';
import 'package:saark_erp_mobile/features/attendance/data/attendance_repository.dart';
import 'package:saark_erp_mobile/features/attendance/presentation/widgets/attendance_kpi_cards.dart';
import 'package:saark_erp_mobile/features/attendance/presentation/widgets/daily_attendance_table.dart';
import 'package:saark_erp_mobile/features/attendance/presentation/widgets/biometric_device_card.dart';
import 'package:saark_erp_mobile/features/attendance/presentation/widgets/web_punch_kiosk_view.dart';
import 'package:saark_erp_mobile/features/attendance/presentation/widgets/shift_roster_view.dart';
import 'package:saark_erp_mobile/features/attendance/presentation/widgets/register_device_dialog.dart';

class AttendanceDashboardPage extends ConsumerStatefulWidget {
  const AttendanceDashboardPage({super.key});

  @override
  ConsumerState<AttendanceDashboardPage> createState() => _AttendanceDashboardPageState();
}

class _AttendanceDashboardPageState extends ConsumerState<AttendanceDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSyncingAll = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(dailyAttendanceRecordsProvider);
    ref.invalidate(attendanceDevicesProvider);
    ref.invalidate(attendanceSyncLogsProvider);
    ref.invalidate(attendanceEmployeesProvider);
    ref.invalidate(attendanceShiftsProvider);
  }

  Future<void> _handleSyncAllDevices() async {
    setState(() => _isSyncingAll = true);
    final repo = ref.read(attendanceRepositoryProvider);

    try {
      final devices = await repo.getDevices();
      int successCount = 0;
      int totalFetched = 0;

      for (final dev in devices) {
        if (dev.isActive) {
          final res = await repo.syncDevice(dev.id);
          if (res['success'] == true) {
            successCount++;
            totalFetched += (res['recordsFetched'] as num? ?? 0).toInt();
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Biometric Fleet Sync Complete: $successCount devices polled, $totalFetched new punches integrated!',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E222B),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      _refreshAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingAll = false);
      }
    }
  }

  void _showRegisterDeviceModal({BiometricDevice? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RegisterDeviceDialog(
        existingDevice: existing,
        onSaved: () => ref.invalidate(attendanceDevicesProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(attendanceSelectedDateProvider);
    final attendanceAsync = ref.watch(dailyAttendanceRecordsProvider);
    final devicesAsync = ref.watch(attendanceDevicesProvider);
    final employeesAsync = ref.watch(attendanceEmployeesProvider);
    final shiftsAsync = ref.watch(attendanceShiftsProvider);
    final syncLogsAsync = ref.watch(attendanceSyncLogsProvider);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1115),
        body: SafeArea(
          child: Column(
            children: [
              // ── Top Header Bar ───────────────────────────────────────────
              _buildTopBar(selectedDate),

              // ── Navigation Tabs ──────────────────────────────────────────
              _buildTabBar(),

              // ── Tab Views ────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 0: Daily Attendance Ledger
                    _buildLedgerTab(attendanceAsync, devicesAsync, employeesAsync),

                    // Tab 1: Biometric Hardware Fleet
                    _buildDeviceFleetTab(devicesAsync, syncLogsAsync),

                    // Tab 2: Web Punch & Face Kiosk
                    _buildWebPunchTab(employeesAsync),

                    // Tab 3: Shift Rosters & Form 25 Muster Roll
                    _buildRosterTab(shiftsAsync, employeesAsync),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(DateTime selectedDate) {
    final dateDisplay = DateFormat('EEE, dd MMM yyyy').format(selectedDate);
    final isToday = DateFormat('yyyy-MM-dd').format(selectedDate) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF16191F),
        border: Border(bottom: BorderSide(color: Color(0xFF262C38), width: 1.2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;

          return Row(
            children: [
              // Back to Dashboard Button
              const BackToDashboardButton(),
              const SizedBox(width: 16),

              // Module Title & Branding
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'Attendance & Biometrics',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.verified, size: 14, color: Color(0xFF38BDF8)),
                            ],
                          ),
                          if (!isCompact)
                            const Text(
                              'Factories Act Form 25 Muster Roll, Realtime Biometric Punching Fleet, & Shift Overtime Engine',
                              style: TextStyle(fontSize: 11, color: Colors.white54),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Date Navigator
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E222B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2E3440)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 18, color: Colors.white70),
                      tooltip: 'Previous Day',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        ref.read(attendanceSelectedDateProvider.notifier).state =
                            selectedDate.subtract(const Duration(days: 1));
                      },
                    ),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          ref.read(attendanceSelectedDateProvider.notifier).state = picked;
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 6),
                            Text(
                              isToday ? 'Today ($dateDisplay)' : dateDisplay,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 18, color: Colors.white70),
                      tooltip: 'Next Day',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        ref.read(attendanceSelectedDateProvider.notifier).state =
                            selectedDate.add(const Duration(days: 1));
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Sync All Devices Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isSyncingAll ? null : _handleSyncAllDevices,
                icon: _isSyncingAll
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 15),
                label: Text(_isSyncingAll ? 'Syncing...' : 'Sync Fleet'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13151A),
        border: Border(bottom: BorderSide(color: Color(0xFF262C38), width: 1.0)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: const [
          Tab(
            icon: Icon(Icons.table_chart_rounded, size: 16),
            text: 'Daily Attendance Ledger',
          ),
          Tab(
            icon: Icon(Icons.settings_input_composite_rounded, size: 16),
            text: 'Biometric Hardware Fleet',
          ),
          Tab(
            icon: Icon(Icons.touch_app_rounded, size: 16),
            text: 'Web Punch Kiosk',
          ),
          Tab(
            icon: Icon(Icons.assignment_rounded, size: 16),
            text: 'Shifts & Form 25 Muster Roll',
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTab(
    AsyncValue<List<AttendanceItem>> attendanceAsync,
    AsyncValue<List<BiometricDevice>> devicesAsync,
    AsyncValue<List<dynamic>> employeesAsync,
  ) {
    return attendanceAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (err, _) => Center(
        child: Text('Error loading attendance: $err', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (attendance) {
        final devices = devicesAsync.value ?? [];
        final totalEmps = employeesAsync.value?.length ?? attendance.length;

        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              // Top KPI Bar
              AttendanceKpiCards(
                attendance: attendance,
                devices: devices,
                totalEmployees: totalEmps,
              ),
              const SizedBox(height: 16),

              // Attendance Ledger Table
              Expanded(
                child: DailyAttendanceTable(
                  records: attendance,
                  onRefresh: _refreshAll,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceFleetTab(
    AsyncValue<List<BiometricDevice>> devicesAsync,
    AsyncValue<List<DeviceSyncLog>> syncLogsAsync,
  ) {
    return devicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (err, _) => Center(
        child: Text('Error loading devices: $err', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (devices) {
        final logs = syncLogsAsync.value ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Add Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BIOMETRIC HARDWARE FLEET INTEGRATION',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Direct TCP/IP socket connection to TeamOffice TM-700, ZKTeco & Suprema biometric readers',
                        style: TextStyle(fontSize: 11.5, color: Colors.white54),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E222B),
                      foregroundColor: const Color(0xFF38BDF8),
                      side: const BorderSide(color: Color(0xFF38BDF8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showRegisterDeviceModal(),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                    label: const Text('Add Biometric Terminal'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Device Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: devices.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isDesktop ? 3 : 1,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: isDesktop ? 1.35 : 1.7,
                    ),
                    itemBuilder: (ctx, idx) => BiometricDeviceCard(
                      device: devices[idx],
                      onRefresh: () => ref.invalidate(attendanceDevicesProvider),
                      onEdit: (dev) => _showRegisterDeviceModal(existing: dev),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              // Sync Logs Audit Trail
              const Text(
                'DEVICE SYNC AUDIT TRAIL & TRANSACTION LOGS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 12),

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
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 80),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFF1E222B)),
                        headingRowHeight: 40,
                        dataRowMaxHeight: 46,
                        dataRowMinHeight: 42,
                        horizontalMargin: 16,
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text('TIME', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('TERMINAL CODE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('SYNC TYPE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('RECORDS FETCHED', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('INSERTED', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('STATUS', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('DURATION', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
                        ],
                        rows: logs.map((log) {
                          final timeStr = DateFormat('yyyy-MM-dd hh:mm a').format(log.startedAt);
                          return DataRow(
                            cells: [
                              DataCell(Text(timeStr, style: const TextStyle(fontSize: 11.5, color: Colors.white70))),
                              DataCell(Text(log.deviceCode, style: const TextStyle(fontSize: 11.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold))),
                              DataCell(Text(log.syncType, style: const TextStyle(fontSize: 11, color: Colors.white60))),
                              DataCell(Text('${log.recordsFetched}', style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold))),
                              DataCell(Text('${log.recordsInserted}', style: const TextStyle(fontSize: 11.5, color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: log.statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    log.syncStatus,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: log.statusColor),
                                  ),
                                ),
                              ),
                              DataCell(Text(log.durationMs != null ? '${log.durationMs} ms' : '—', style: const TextStyle(fontSize: 11, color: Colors.white54))),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWebPunchTab(AsyncValue<List<dynamic>> employeesAsync) {
    return employeesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      error: (err, _) => Center(
        child: Text('Error loading employees: $err', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (employees) {
        final empList = employees.whereType<dynamic>().toList();
        return Padding(
          padding: const EdgeInsets.all(20),
          child: WebPunchKioskView(
            employees: empList.cast(),
            onPunchCompleted: _refreshAll,
          ),
        );
      },
    );
  }

  Widget _buildRosterTab(
    AsyncValue<List<Map<String, dynamic>>> shiftsAsync,
    AsyncValue<List<dynamic>> employeesAsync,
  ) {
    final shifts = shiftsAsync.value ?? [];
    final employees = employeesAsync.value ?? [];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ShiftRosterView(
        shifts: shifts,
        employees: employees.cast(),
      ),
    );
  }
}
