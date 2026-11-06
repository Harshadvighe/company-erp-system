import 'package:flutter/material.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/hr/models/hr_models.dart';
import 'package:saark_erp_mobile/features/attendance/data/attendance_device_model.dart';

class AttendanceKpiCards extends StatelessWidget {
  final List<AttendanceItem> attendance;
  final List<BiometricDevice> devices;
  final int totalEmployees;

  const AttendanceKpiCards({
    super.key,
    required this.attendance,
    required this.devices,
    this.totalEmployees = 0,
  });

  @override
  Widget build(BuildContext context) {
    final presentCount = attendance.where((a) => a.status.toUpperCase() == 'PRESENT').length;
    final lateCount = attendance.where((a) => a.status.toUpperCase() == 'LATE').length;
    final absentCount = attendance.where((a) => a.status.toUpperCase() == 'ABSENT').length;
    final leaveCount = attendance.where((a) => a.status.toUpperCase() == 'ON_LEAVE').length;
    final totalOt = attendance.fold<double>(0.0, (sum, a) => sum + a.overtimeHours);
    final activeDevices = devices.where((d) => d.isActive).length;

    final effectiveRoster = totalEmployees > 0 ? totalEmployees : attendance.length;
    final presentRate = effectiveRoster > 0 ? ((presentCount + lateCount) / effectiveRoster * 100).toStringAsFixed(1) : '0.0';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 950;
        final isTablet = constraints.maxWidth > 650 && constraints.maxWidth <= 950;

        if (isDesktop) {
          return Row(
            children: [
              Expanded(
                child: _buildCard(
                  title: 'TOTAL ON ROSTER',
                  value: '$effectiveRoster',
                  badge: 'Industrial Staff',
                  icon: Icons.badge_outlined,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCard(
                  title: 'PRESENT TODAY',
                  value: '${presentCount + lateCount}',
                  badge: '$presentRate% Attendance',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCard(
                  title: 'LATE ARRIVALS',
                  value: '$lateCount',
                  badge: 'Grace Expired',
                  icon: Icons.access_time_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCard(
                  title: 'ABSENT / ON LEAVE',
                  value: '${absentCount + leaveCount}',
                  badge: '$leaveCount Approved Leaves',
                  icon: Icons.event_busy_rounded,
                  color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCard(
                  title: 'OVERTIME LOGGED',
                  value: '${totalOt.toStringAsFixed(1)} h',
                  badge: 'Shopfloor Shifts',
                  icon: Icons.hourglass_top_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCard(
                  title: 'BIOMETRIC FLEET',
                  value: '$activeDevices / ${devices.length}',
                  badge: 'Terminals Online',
                  icon: Icons.fingerprint_rounded,
                  color: const Color(0xFFA855F7),
                ),
              ),
            ],
          );
        } else if (isTablet) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildCard(
                      title: 'TOTAL ROSTER',
                      value: '$effectiveRoster',
                      badge: 'Industrial Staff',
                      icon: Icons.badge_outlined,
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCard(
                      title: 'PRESENT',
                      value: '${presentCount + lateCount}',
                      badge: '$presentRate% Present',
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCard(
                      title: 'LATE MARKS',
                      value: '$lateCount',
                      badge: 'Grace Expired',
                      icon: Icons.access_time_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildCard(
                      title: 'ABSENT / LEAVE',
                      value: '${absentCount + leaveCount}',
                      badge: '$leaveCount On Leave',
                      icon: Icons.event_busy_rounded,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCard(
                      title: 'OVERTIME HOURS',
                      value: '${totalOt.toStringAsFixed(1)} h',
                      badge: 'Shopfloor Shifts',
                      icon: Icons.hourglass_top_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCard(
                      title: 'DEVICES ONLINE',
                      value: '$activeDevices / ${devices.length}',
                      badge: 'Hardware Active',
                      icon: Icons.fingerprint_rounded,
                      color: const Color(0xFFA855F7),
                    ),
                  ),
                ],
              ),
            ],
          );
        } else {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 180,
                  child: _buildCard(
                    title: 'TOTAL ROSTER',
                    value: '$effectiveRoster',
                    badge: 'Industrial Staff',
                    icon: Icons.badge_outlined,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 180,
                  child: _buildCard(
                    title: 'PRESENT TODAY',
                    value: '${presentCount + lateCount}',
                    badge: '$presentRate% Present',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF22C55E),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 180,
                  child: _buildCard(
                    title: 'LATE ARRIVALS',
                    value: '$lateCount',
                    badge: 'Grace Expired',
                    icon: Icons.access_time_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 180,
                  child: _buildCard(
                    title: 'ABSENT / LEAVE',
                    value: '${absentCount + leaveCount}',
                    badge: '$leaveCount On Leave',
                    icon: Icons.event_busy_rounded,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 180,
                  child: _buildCard(
                    title: 'OVERTIME',
                    value: '${totalOt.toStringAsFixed(1)} h',
                    badge: 'Shopfloor Shifts',
                    icon: Icons.hourglass_top_rounded,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 180,
                  child: _buildCard(
                    title: 'HARDWARE FLEET',
                    value: '$activeDevices / ${devices.length}',
                    badge: 'Online Terminals',
                    icon: Icons.fingerprint_rounded,
                    color: const Color(0xFFA855F7),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildCard({
    required String title,
    required String value,
    required String badge,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            badge,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.white60,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

