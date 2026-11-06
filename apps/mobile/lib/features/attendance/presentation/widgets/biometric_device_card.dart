import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/attendance/data/attendance_device_model.dart';
import 'package:saark_erp_mobile/features/attendance/data/attendance_repository.dart';

class BiometricDeviceCard extends ConsumerStatefulWidget {
  final BiometricDevice device;
  final VoidCallback onRefresh;
  final Function(BiometricDevice) onEdit;

  const BiometricDeviceCard({
    super.key,
    required this.device,
    required this.onRefresh,
    required this.onEdit,
  });

  @override
  ConsumerState<BiometricDeviceCard> createState() => _BiometricDeviceCardState();
}

class _BiometricDeviceCardState extends ConsumerState<BiometricDeviceCard> {
  bool _isTesting = false;
  bool _isSyncing = false;
  String? _testResult;
  bool _testSuccess = false;

  Future<void> _handleTestConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final repo = ref.read(attendanceRepositoryProvider);
    final res = await repo.testDeviceConnection(widget.device.id);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = res['success'] == true;
        _testResult = res['message'] ?? (_testSuccess ? 'Connection active' : 'Device unreachable');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                _testSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: _testSuccess ? Colors.greenAccent : Colors.redAccent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '[${widget.device.deviceCode}] ${_testResult!}',
                  style: const TextStyle(fontSize: 13),
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
  }

  Future<void> _handleSyncNow() async {
    setState(() {
      _isSyncing = true;
    });

    final repo = ref.read(attendanceRepositoryProvider);
    final res = await repo.syncDevice(widget.device.id);

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });

      final success = res['success'] == true;
      final fetched = res['recordsFetched'] ?? 0;
      final inserted = res['recordsInserted'] ?? 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '✅ Synced ${widget.device.deviceName}: $fetched punches fetched, $inserted recorded!'
                : '❌ Sync failed: ${res['message'] ?? 'Device communication error'}',
            style: const TextStyle(fontSize: 13),
          ),
          backgroundColor: success ? const Color(0xFF166534) : const Color(0xFF991B1B),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );

      widget.onRefresh();
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text('Remove Biometric Terminal?', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to deregister "${widget.device.deviceName}" (${widget.device.deviceCode})? Biometric punches will no longer auto-sync from this IP.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Terminal', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final repo = ref.read(attendanceRepositoryProvider);
      await repo.deleteDevice(widget.device.id);
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dev = widget.device;
    final statusColor = dev.statusColor;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16191F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2E3440), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & Online Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Icon(
                  dev.bioType.icon,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dev.deviceName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252A34),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            dev.deviceCode,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF38BDF8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• ${dev.manufacturer} ${dev.model ?? ''}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.white54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      dev.statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFF252A34), height: 1),
          const SizedBox(height: 12),

          // Specs Grid
          Row(
            children: [
              Expanded(
                child: _specItem(
                  icon: Icons.lan_outlined,
                  label: 'IP ADDRESS / PORT',
                  val: dev.ipAddress != null ? '${dev.ipAddress}:${dev.port}' : 'Cloud Agent',
                  valColor: Colors.white,
                ),
              ),
              Expanded(
                child: _specItem(
                  icon: Icons.place_outlined,
                  label: 'PLANT LOCATION',
                  val: dev.location ?? 'Factory Main Floor',
                  valColor: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _specItem(
                  icon: Icons.update_rounded,
                  label: 'AUTO-SYNC CADENCE',
                  val: dev.autoSyncEnabled ? 'Every ${dev.syncIntervalMinutes} mins' : 'Manual Trigger',
                  valColor: dev.autoSyncEnabled ? const Color(0xFF38BDF8) : Colors.white54,
                ),
              ),
              Expanded(
                child: _specItem(
                  icon: Icons.history_rounded,
                  label: 'LAST RECORD COUNT',
                  val: '${dev.lastSyncRecordCount} punches synced',
                  valColor: Colors.greenAccent,
                ),
              ),
            ],
          ),

          if (_testResult != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _testSuccess ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _testSuccess ? Colors.green.withValues(alpha: 0.4) : Colors.red.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _testSuccess ? Icons.check_circle_outline : Icons.error_outline,
                    size: 14,
                    color: _testSuccess ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _testSuccess ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(color: Color(0xFF252A34), height: 1),
          const SizedBox(height: 12),

          // Actions Bar
          Row(
            children: [
              // Test Connection
              OutlinedButton.icon(
                onPressed: _isTesting ? null : _handleTestConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.bolt_rounded, size: 14),
                label: Text(_isTesting ? 'Pinging...' : 'Test Ping'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),

              // Sync Now
              ElevatedButton.icon(
                onPressed: _isSyncing ? null : _handleSyncNow,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 14),
                label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),

              // Edit
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
                tooltip: 'Edit Configuration',
                onPressed: () => widget.onEdit(dev),
                visualDensity: VisualDensity.compact,
              ),

              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                tooltip: 'Remove Terminal',
                onPressed: _handleDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _specItem({
    required IconData icon,
    required String label,
    required String val,
    required Color valColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white38,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                val,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: valColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
