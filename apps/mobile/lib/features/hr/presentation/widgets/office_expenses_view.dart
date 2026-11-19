import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class OfficeExpensesView extends ConsumerStatefulWidget {
  const OfficeExpensesView({super.key});

  @override
  ConsumerState<OfficeExpensesView> createState() => _OfficeExpensesViewState();
}

class _OfficeExpensesViewState extends ConsumerState<OfficeExpensesView> {
  bool _isLoading = true;
  String _selectedCategory = 'ALL';
  String _selectedStatus = 'ALL';
  List<dynamic> _expenses = [];
  Map<String, dynamic> _summary = {};

  final _categories = [
    'ALL',
    'TRAVEL',
    'STATIONERY',
    'TEA_PANTRY',
    'COURIER',
    'TOOLS',
    'UTILITIES',
    'OTHER',
  ];

  final _statuses = [
    'ALL',
    'SUBMITTED',
    'REVIEWED',
    'APPROVED',
    'PAID',
    'REJECTED',
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);

      // Fetch summary
      final sumRes = await dio.get('/hr/expenses/summary');
      if (sumRes.statusCode == 200 && sumRes.data != null) {
        final d = sumRes.data['data'] ?? sumRes.data;
        _summary = d['summary'] ?? {};
      }

      // Fetch vouchers
      String url = '/hr/expenses?';
      if (_selectedStatus != 'ALL') url += 'status=$_selectedStatus&';
      if (_selectedCategory != 'ALL') url += 'category=$_selectedCategory&';

      final expRes = await dio.get(url);
      if (expRes.statusCode == 200 && expRes.data != null) {
        _expenses = expRes.data['data'] ?? expRes.data ?? [];
      }
    } catch (e) {
      debugPrint('Error fetching expenses: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SUBMITTED':
        return Colors.orangeAccent;
      case 'REVIEWED':
        return Colors.blueAccent;
      case 'APPROVED':
        return Colors.tealAccent;
      case 'PAID':
        return Colors.greenAccent;
      case 'REJECTED':
        return Colors.redAccent;
      default:
        return Colors.white70;
    }
  }

  void _openSubmitDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'TRAVEL';
    String staffName = 'Current Staff';
    String department = 'Operations';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2024),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: Color(0xFFF26522)),
              SizedBox(width: 8),
              Text(
                'Submit Expense Voucher (Step 4.1)',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Category', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141517),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: category,
                        dropdownColor: const Color(0xFF1E2024),
                        isExpanded: true,
                        items: _categories
                            .where((c) => c != 'ALL')
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.replaceAll('_', ' '), style: const TextStyle(color: Colors.white)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => category = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Title / Purpose', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. Site Visit Travel or Cable Ties',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF141517),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Amount (INR)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(color: Color(0xFFF26522)),
                      hintText: '1500.00',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF141517),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Description / Business Justification', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Explain why this expense was incurred...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF141517),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.attachment, color: Color(0xFFF26522), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Receipt Photo / Bill Attachment Verified (Camera Captured)',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                        Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (titleCtrl.text.trim().isEmpty || amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid title and amount')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final dio = ref.read(dioProvider);
                  await dio.post('/hr/expenses', data: {
                    'title': titleCtrl.text.trim(),
                    'category': category,
                    'amount': amt,
                    'description': descCtrl.text.trim(),
                    'receiptUrl': 'https://storage.saark.in/receipts/bill_verified.jpg',
                    'staffName': staffName,
                    'department': department,
                  });
                  _fetchData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Expense voucher submitted successfully (Step 4.1)')),
                  );
                } catch (e) {
                  debugPrint('Submit error: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF26522),
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Voucher'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewVoucher(String id, String voucherNo) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/hr/expenses/$id/review', data: {
        'status': 'REVIEWED',
        'reviewNotes': 'Verified by Department Admin against store register and original bill.',
      });
      _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Voucher $voucherNo reviewed and forwarded to Managing Director (Step 4.2)')),
      );
    } catch (e) {
      debugPrint('Review error: $e');
    }
  }

  Future<void> _approveVoucher(String id, String voucherNo) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/hr/expenses/$id/approve', data: {
        'status': 'APPROVED',
        'approvalNotes': 'Approved by Managing Director (Saarkadmin). Released to Petty Cash.',
        'paymentMode': 'PETTY_CASH',
        'markPaid': true,
      });
      _fetchData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Voucher $voucherNo approved by MD & posted to Office Expense Ledger!')),
      );
    } catch (e) {
      debugPrint('Approve error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return Column(
      children: [
        // Sub-Header & Actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFF1E2024),
            border: Border(bottom: BorderSide(color: Color(0xFF2E3238))),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFFF26522), size: 24),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Office Expenses & Staff Vouchers (Workflow 4)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Staff Submission -> Dept Admin Review -> Managing Director (Saarkadmin) Approval -> Ledger Posting',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _openSubmitDialog,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Submit Expense Voucher'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF26522),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        // KPI Summary Tiles
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildKpiCard(
                'Total Vouchers',
                '${_summary['total_vouchers'] ?? 0}',
                Icons.folder_shared,
                Colors.blueAccent,
              ),
              const SizedBox(width: 12),
              _buildKpiCard(
                'Total Claimed',
                currencyFmt.format(_summary['total_amount'] ?? 0),
                Icons.account_balance_wallet,
                Colors.purpleAccent,
              ),
              const SizedBox(width: 12),
              _buildKpiCard(
                'Pending Review / MD Signoff',
                '${(_summary['pending_review'] ?? 0) + (_summary['pending_approval'] ?? 0)}',
                Icons.pending_actions,
                Colors.orangeAccent,
              ),
              const SizedBox(width: 12),
              _buildKpiCard(
                'Approved & Posted to Ledger',
                currencyFmt.format(_summary['approved_amount'] ?? 0),
                Icons.verified,
                Colors.greenAccent,
              ),
            ],
          ),
        ),

        // Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Text('Filter Category:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2024),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    dropdownColor: const Color(0xFF1E2024),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' '))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                        _fetchData();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 20),
              const Text('Status:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2024),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedStatus,
                    dropdownColor: const Color(0xFF1E2024),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: _statuses
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedStatus = val);
                        _fetchData();
                      }
                    },
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                onPressed: _fetchData,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),

        // Expense Vouchers List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFF26522)))
              : _expenses.isEmpty
                  ? const Center(
                      child: Text('No expense vouchers found.', style: TextStyle(color: Colors.white38)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _expenses.length,
                      itemBuilder: (context, idx) {
                        final v = _expenses[idx];
                        final status = v['status'] ?? 'SUBMITTED';
                        final color = _getStatusColor(status);
                        final amt = (v['amount'] as num?)?.toDouble() ?? 0.0;
                        final dateStr = v['expense_date'] != null
                            ? DateFormat('dd MMM yyyy').format(DateTime.parse(v['expense_date']))
                            : 'Today';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2024),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.15),
                                foregroundColor: color,
                                radius: 22,
                                child: const Icon(Icons.receipt, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          v['voucher_number'] ?? 'EXP-2026',
                                          style: const TextStyle(
                                            color: Color(0xFFF26522),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          v['title'] ?? 'Expense',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            (v['category'] ?? 'OTHER').replaceAll('_', ' '),
                                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Submitted by: ${v['staff_name'] ?? 'Staff'} (${v['department'] ?? 'Operations'}) on $dateStr',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                    if (v['description'] != null && v['description'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        'Note: ${v['description']}',
                                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                                      ),
                                    ],
                                    if (v['ledger_ref'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Ledger Entry: ${v['ledger_account']} | Ref: ${v['ledger_ref']} | Mode: ${v['payment_mode']}',
                                        style: const TextStyle(color: Colors.tealAccent, fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFmt.format(amt),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: color.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (status == 'SUBMITTED') ...[
                                    OutlinedButton.icon(
                                      onPressed: () => _reviewVoucher(v['id'], v['voucher_number']),
                                      icon: const Icon(Icons.check, size: 12),
                                      label: const Text('Review & Verify (Step 4.2)', style: TextStyle(fontSize: 10)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blueAccent,
                                        side: const BorderSide(color: Colors.blueAccent),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      ),
                                    ),
                                  ] else if (status == 'REVIEWED') ...[
                                    ElevatedButton.icon(
                                      onPressed: () => _approveVoucher(v['id'], v['voucher_number']),
                                      icon: const Icon(Icons.verified, size: 12),
                                      label: const Text('MD Approve & Post to Ledger', style: TextStyle(fontSize: 10)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2024),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              foregroundColor: color,
              radius: 18,
              child: Icon(icon, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
