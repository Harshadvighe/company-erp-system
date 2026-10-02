import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/purchase/data/purchase_repository.dart';

class ChequeManagementModal extends ConsumerStatefulWidget {
  final VoidCallback onUpdated;

  const ChequeManagementModal({super.key, required this.onUpdated});

  @override
  ConsumerState<ChequeManagementModal> createState() => _ChequeManagementModalState();
}

class _ChequeManagementModalState extends ConsumerState<ChequeManagementModal> {
  List<Map<String, dynamic>> _cheques = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCheques();
  }

  Future<void> _loadCheques() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(purchaseRepositoryProvider);
      final list = await repo.getCheques();
      if (mounted) setState(() => _cheques = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CLEARED':
        return AppTheme.success;
      case 'DEPOSITED':
        return AppTheme.info;
      case 'BOUNCED':
        return AppTheme.error;
      case 'CANCELLED':
        return Colors.grey;
      case 'ISSUED':
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppTheme.darkSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 680),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cheque Details & Management',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Track issued cheques, banking clearance status & handle return/bounce reversals',
                            style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.darkTextSecondary),
                    onPressed: _loadCheques,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.darkTextSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Cheque List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _cheques.isEmpty
                      ? const Center(
                          child: Text('No cheques recorded yet.', style: TextStyle(color: AppTheme.darkTextSecondary)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _cheques.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final chq = _cheques[index];
                            final status = chq['status'] ?? 'ISSUED';
                            final amount = (chq['amount'] as num?)?.toDouble() ?? 0.0;
                            final vendor = chq['vendor'];
                            final vendorName = vendor is Map
                                ? (vendor['companyName']?.toString() ?? chq['payeeName']?.toString() ?? 'Vendor')
                                : (vendor?.toString() ?? chq['payeeName']?.toString() ?? 'Vendor');
                            final chequeNum = chq['chequeNumber']?.toString() ?? 'N/A';
                            final bank = chq['bankName'] ?? '';
                            final branch = chq['branch'] ?? '';

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.darkBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.darkBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.pin, color: _getStatusColor(status), size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Cheque #$chequeNum',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 2),
                                        Text('$vendorName • $bank $branch',
                                            style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('₹${amount.toStringAsFixed(2)}',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(status).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: _getStatusColor(status).withOpacity(0.5)),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                                color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: AppTheme.darkTextSecondary),
                                    color: AppTheme.darkSurface,
                                    onSelected: (newStatus) => _updateStatus(chq['id'], newStatus),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'ISSUED', child: Text('Mark as ISSUED')),
                                      const PopupMenuItem(value: 'DEPOSITED', child: Text('Mark as DEPOSITED')),
                                      const PopupMenuItem(value: 'CLEARED', child: Text('Mark as CLEARED')),
                                      const PopupMenuItem(value: 'BOUNCED', child: Text('Mark as BOUNCED (Reverse)')),
                                      const PopupMenuItem(value: 'CANCELLED', child: Text('Mark as CANCELLED')),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String chequeId, String newStatus) async {
    String? reason;
    if (newStatus == 'BOUNCED') {
      reason = await _promptBounceReason();
      if (reason == null) return;
    }

    try {
      final repo = ref.read(purchaseRepositoryProvider);
      await repo.updateChequeStatus(chequeId, newStatus, reason: reason);
      await _loadCheques();
      widget.onUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cheque status updated to $newStatus'),
            backgroundColor: newStatus == 'BOUNCED' ? AppTheme.error : AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update cheque: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<String?> _promptBounceReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Cheque Return / Bounce Reason', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. Insufficient Funds / Signature mismatch',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim().isEmpty ? 'Cheque Bounced' : ctrl.text.trim()),
            child: const Text('Confirm Bounce'),
          ),
        ],
      ),
    );
  }
}
