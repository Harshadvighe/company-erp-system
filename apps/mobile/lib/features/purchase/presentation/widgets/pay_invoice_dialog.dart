import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/purchase/data/purchase_repository.dart';

class PayInvoiceDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onPaymentSuccess;

  const PayInvoiceDialog({
    super.key,
    required this.invoice,
    required this.onPaymentSuccess,
  });

  @override
  ConsumerState<PayInvoiceDialog> createState() => _PayInvoiceDialogState();
}

class _PayInvoiceDialogState extends ConsumerState<PayInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refNumberController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _remarksController = TextEditingController();

  // Cheque specific fields
  final _chequeNumberController = TextEditingController();
  final _chequeBankController = TextEditingController();
  final _chequeBranchController = TextEditingController();

  String _paymentMode = 'BANK_TRANSFER';
  bool _overrideLimit = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final balance = (widget.invoice['balanceAmount'] as num?)?.toDouble() ?? 0.0;
    _amountController.text = balance > 0 ? balance.toStringAsFixed(2) : '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refNumberController.dispose();
    _bankAccountController.dispose();
    _remarksController.dispose();
    _chequeNumberController.dispose();
    _chequeBankController.dispose();
    _chequeBranchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoiceNumber = widget.invoice['invoiceNumber'] ?? 'N/A';
    final vendorName = widget.invoice['vendor']?['companyName'] ?? 'Vendor';
    final totalAmount = (widget.invoice['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final paidAmount = (widget.invoice['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final balanceAmount = (widget.invoice['balanceAmount'] as num?)?.toDouble() ?? 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppTheme.darkSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.payment, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Record Invoice Payment',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                          ),
                          Text(
                            '$invoiceNumber • $vendorName',
                            style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.darkTextSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Financial Overview Cards
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoColumn('Invoice Total', '₹${totalAmount.toStringAsFixed(2)}', Colors.white),
                      Container(width: 1, height: 35, color: AppTheme.darkBorder),
                      _buildInfoColumn('Paid to Date', '₹${paidAmount.toStringAsFixed(2)}', AppTheme.success),
                      Container(width: 1, height: 35, color: AppTheme.darkBorder),
                      _buildInfoColumn('Pending Balance', '₹${balanceAmount.toStringAsFixed(2)}', AppTheme.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Payment Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Payment Amount (₹)*',
                    prefixIcon: const Icon(Icons.currency_rupee, color: AppTheme.primary),
                    filled: true,
                    fillColor: AppTheme.darkBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter payment amount';
                    }
                    final amt = double.tryParse(value);
                    if (amt == null || amt <= 0) {
                      return 'Please enter a valid positive amount';
                    }
                    if (!_overrideLimit && amt > balanceAmount) {
                      return 'Amount exceeds pending balance (₹${balanceAmount.toStringAsFixed(2)})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Payment Mode Selector
                DropdownButtonFormField<String>(
                  value: _paymentMode,
                  dropdownColor: AppTheme.darkSurface,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Payment Mode*',
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.primary),
                    filled: true,
                    fillColor: AppTheme.darkBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.darkBorder)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT/RTGS)')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque Payment')),
                    DropdownMenuItem(value: 'UPI', child: Text('UPI / QR Transfer')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _paymentMode = v);
                  },
                ),
                const SizedBox(height: 14),

                // Cheque Specific Fields
                if (_paymentMode == 'CHEQUE') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _chequeNumberController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Cheque Number*',
                            filled: true,
                            fillColor: AppTheme.darkBackground,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => _paymentMode == 'CHEQUE' && (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _chequeBankController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Bank Name*',
                            filled: true,
                            fillColor: AppTheme.darkBackground,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          validator: (v) => _paymentMode == 'CHEQUE' && (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _chequeBranchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Bank Branch',
                      filled: true,
                      fillColor: AppTheme.darkBackground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Bank Account / Ref Number
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bankAccountController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Debit Account',
                          hintText: 'e.g. HDFC 50200049182391',
                          filled: true,
                          fillColor: AppTheme.darkBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _refNumberController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Ref / Transaction #',
                          hintText: 'UTR / TXN Ref',
                          filled: true,
                          fillColor: AppTheme.darkBackground,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Remarks
                TextFormField(
                  controller: _remarksController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Remarks / Notes',
                    filled: true,
                    fillColor: AppTheme.darkBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                // Override Switch
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Authorized Override (Allow payment exceeding balance)', style: TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
                  value: _overrideLimit,
                  activeColor: AppTheme.primary,
                  onChanged: (val) => setState(() => _overrideLimit = val ?? false),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.darkTextSecondary)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSubmitting ? null : _submitPayment,
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(_isSubmitting ? 'Processing...' : 'Submit Payment'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(purchaseRepositoryProvider);
      final invoiceId = widget.invoice['id'];
      final amount = double.parse(_amountController.text.trim());

      final payload = {
        'amount': amount,
        'paymentMode': _paymentMode,
        'bankAccount': _bankAccountController.text.trim(),
        'referenceNumber': _refNumberController.text.trim(),
        'remarks': _remarksController.text.trim(),
        if (_paymentMode == 'CHEQUE') ...{
          'chequeNumber': _chequeNumberController.text.trim(),
          'bankName': _chequeBankController.text.trim(),
          'branch': _chequeBranchController.text.trim(),
          'payeeName': widget.invoice['vendor']?['companyName'] ?? 'Vendor',
        },
      };

      await repo.recordInvoicePayment(invoiceId, payload);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onPaymentSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ₹${amount.toStringAsFixed(2)} recorded successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${e.toString()}'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
