import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';

class QuotationDetailPage extends ConsumerStatefulWidget {
  final String quotationId;

  const QuotationDetailPage({super.key, required this.quotationId});

  @override
  ConsumerState<QuotationDetailPage> createState() => _QuotationDetailPageState();
}

class _QuotationDetailPageState extends ConsumerState<QuotationDetailPage> {
  bool _isActionInProgress = false;

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACCEPTED':
        return Colors.green;
      case 'CONVERTED':
        return Colors.purple;
      case 'SENT':
        return Colors.orange;
      case 'PENDING_APPROVAL':
        return Colors.amber.shade800;
      case 'REJECTED':
      case 'EXPIRED':
        return Colors.red;
      case 'DRAFT':
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isActionInProgress = true);
    try {
      final repo = ref.read(salesRepositoryProvider);
      await repo.updateQuotationStatus(widget.quotationId, newStatus);
      ref.invalidate(quotationDetailProvider(widget.quotationId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quotation status changed to $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _createRevision() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Revision?'),
        content: const Text(
          'This will increment the revision number (e.g. REV-1), clone the line items, and create an updated proposal for customer negotiations.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create Revision')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionInProgress = true);
    try {
      final repo = ref.read(salesRepositoryProvider);
      final res = await repo.createRevision(widget.quotationId, {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created ${res['code']} successfully!')),
        );
        context.pushReplacement('/crm/quotations/${res['id']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create revision: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _convertToSalesOrder(Map<String, dynamic> quote) async {
    final poController = TextEditingController();
    DateTime deliveryDate = DateTime.now().add(const Duration(days: 21));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Convert to Confirmed Sales Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Convert Quotation ${quote['code']} into a live Sales Order for engineering & panel manufacturing.', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: poController,
                decoration: const InputDecoration(
                  labelText: 'Customer PO Number (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt_long),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: deliveryDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setModalState(() => deliveryDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Target Delivery Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(deliveryDate)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: const Text('Confirm & Generate Order', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionInProgress = true);
    try {
      final repo = ref.read(salesRepositoryProvider);
      final res = await repo.convertToSalesOrder(widget.quotationId, {
        'poNumber': poController.text.trim().isEmpty ? null : poController.text.trim(),
        'deliveryDate': deliveryDate.toIso8601String(),
      });
      ref.invalidate(quotationDetailProvider(widget.quotationId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sales Order ${res['orderNumber']} generated!')),
        );
        context.push('/crm/sales-orders/${res['id']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to convert to order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final quoteAsync = ref.watch(quotationDetailProvider(widget.quotationId));

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Quotation Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(quotationDetailProvider(widget.quotationId)),
          ),
        ],
      ),
      body: quoteAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (quote) {
          final customer = quote['customer'] as Map<String, dynamic>?;
          final status = quote['status'] as String? ?? 'DRAFT';
          final code = quote['code'] as String? ?? quote['quotationNumber'] ?? 'QUO';
          final revisionNumber = quote['revisionNumber'] ?? 0;
          final items = quote['items'] as List<dynamic>? ?? [];
          final revisions = quote['revisions'] as List<dynamic>? ?? [];
          final grandTotal = (quote['grandTotal'] as num?)?.toDouble() ?? 0;
          final createdAt = quote['createdAt'] != null
              ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(quote['createdAt']))
              : '-';
          final validUntil = quote['validUntil'] != null
              ? DateFormat('dd MMM yyyy').format(DateTime.parse(quote['validUntil']))
              : '30 Days';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Header Card ─────────────────────────────────────────────
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    code,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.indigo.shade200),
                                    ),
                                    child: Text(
                                      'REV-$revisionNumber',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo.shade800),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Created: $createdAt', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              status.replaceAll('_', ' '),
                              style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Text(quote['subject'] ?? 'Commercial Proposal', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Valid Until: $validUntil', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ─── Quick Actions Bar ────────────────────────────────────────
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isActionInProgress ? null : _createRevision,
                        icon: const Icon(Icons.history, size: 16),
                        label: const Text('New Revision'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade600, foregroundColor: Colors.white),
                      ),
                      if (status != 'SENT' && status != 'ACCEPTED' && status != 'CONVERTED')
                        ElevatedButton.icon(
                          onPressed: _isActionInProgress ? null : () => _updateStatus('SENT'),
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Mark Sent'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                        ),
                      if (status != 'ACCEPTED' && status != 'CONVERTED')
                        ElevatedButton.icon(
                          onPressed: _isActionInProgress ? null : () => _updateStatus('ACCEPTED'),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Accept Quote'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                        ),
                      if (status != 'CONVERTED')
                        ElevatedButton.icon(
                          onPressed: _isActionInProgress ? null : () => _convertToSalesOrder(quote),
                          icon: const Icon(Icons.shopping_cart_checkout, size: 16),
                          label: const Text('Convert to Order'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade700, foregroundColor: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Customer 360 Linked Card ─────────────────────────────────
              if (customer != null)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: const Icon(Icons.business, color: AppTheme.primaryColor),
                    ),
                    title: Text(customer['companyName'] ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('GSTIN: ${customer['gstin'] ?? 'Unregistered'} • ${customer['city'] ?? ''}, ${customer['state'] ?? 'India'}'),
                        Text('Phone: ${customer['phone'] ?? '-'} • Email: ${customer['email'] ?? '-'}'),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => context.push('/crm/companies/${customer['id']}'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1), foregroundColor: AppTheme.primaryColor, elevation: 0),
                      child: const Text('Customer 360'),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // ─── Revisions Switcher ───────────────────────────────────────
              if (revisions.length > 1) ...[
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.layers_outlined, color: AppTheme.primaryColor),
                            SizedBox(width: 8),
                            Text('Revision History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const Divider(height: 16),
                        Wrap(
                          spacing: 8,
                          children: revisions.map((rev) {
                            final isCurrent = rev['id'] == quote['id'];
                            return ActionChip(
                              avatar: CircleAvatar(
                                backgroundColor: isCurrent ? AppTheme.primaryColor : Colors.grey.shade300,
                                radius: 10,
                                child: Text(
                                  '${rev['revisionNumber']}',
                                  style: TextStyle(fontSize: 10, color: isCurrent ? Colors.white : Colors.black),
                                ),
                              ),
                              label: Text('${rev['code']} (${currencyFormatter.format(rev['grandTotal'] ?? 0)})'),
                              backgroundColor: isCurrent ? AppTheme.primaryColor.withValues(alpha: 0.15) : Colors.grey.shade100,
                              onPressed: isCurrent
                                  ? null
                                  : () => context.pushReplacement('/crm/quotations/${rev['id']}'),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ─── Itemized Quotation Lines Table ───────────────────────────
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: AppTheme.primaryColor),
                          SizedBox(width: 8),
                          Text('Itemized Bill of Materials & Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 20),

                      ...items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final itm = entry.value;
                        final unitPrice = (itm['unitPrice'] as num?)?.toDouble() ?? 0;
                        final qty = itm['quantity'] ?? 1;
                        final total = (itm['totalAmount'] as num?)?.toDouble() ?? (qty * unitPrice);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '#${idx + 1}  ${itm['itemCode'] ?? 'ITEM'} (HSN ${itm['hsnSac'] ?? '8537'})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                                  ),
                                  Text(
                                    currencyFormatter.format(total),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(itm['description'] ?? '', style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Qty: $qty ${itm['unit'] ?? 'Nos'} × ${currencyFormatter.format(unitPrice)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                  Text('GST: ${itm['gstPercent'] ?? 18}% (${currencyFormatter.format(itm['gstAmount'] ?? 0)})', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Financial Breakdown Card ─────────────────────────────────
              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal:'),
                          Text(currencyFormatter.format(quote['subtotal'] ?? 0)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if ((quote['discountAmount'] ?? 0) > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Discount:'),
                            Text('- ${currencyFormatter.format(quote['discountAmount'])}', style: const TextStyle(color: Colors.red)),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Net Taxable Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(currencyFormatter.format(quote['taxableAmount'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if ((quote['cgstAmount'] ?? 0) > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('CGST (${quote['cgstPercent'] ?? 9}%):'),
                            Text(currencyFormatter.format(quote['cgstAmount'])),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('SGST (${quote['sgstPercent'] ?? 9}%):'),
                            Text(currencyFormatter.format(quote['sgstAmount'])),
                          ],
                        ),
                      ],
                      if ((quote['igstAmount'] ?? 0) > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('IGST (${quote['igstPercent'] ?? 18}%):'),
                            Text(currencyFormatter.format(quote['igstAmount'])),
                          ],
                        ),
                      ],
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('GRAND TOTAL (INC. TAX):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                          Text(
                            currencyFormatter.format(grandTotal),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ─── Commercial Terms Card ───────────────────────────────────
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.gavel, color: AppTheme.primaryColor),
                          SizedBox(width: 8),
                          Text('Agreed Terms & Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const Divider(height: 20),
                      _buildTermRow('Payment Terms', quote['paymentTerms'] ?? '50% Advance, 50% Before Dispatch'),
                      _buildTermRow('Delivery Terms', quote['deliveryTerms'] ?? '2 to 3 weeks'),
                      _buildTermRow('Freight & Transport', quote['freightTerms'] ?? 'Ex-Works Pune'),
                      _buildTermRow('Warranty', quote['warrantyTerms'] ?? '18 months from supply'),
                      if (quote['notes'] != null && quote['notes'].toString().isNotEmpty)
                        _buildTermRow('Notes', quote['notes']),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTermRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
