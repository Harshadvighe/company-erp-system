import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/production/data/panel_manufacturing_repository.dart';

class PanelSpecDetailPage extends ConsumerWidget {
  final String specId;

  const PanelSpecDetailPage({super.key, required this.specId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specAsync = ref.watch(panelDetailProvider(specId));
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Specification & BOM Breakdown'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Specification',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Specification details copied to clipboard')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print Estimation Sheet',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Preparing Panel BOM PDF Export...')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: specAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(err.toString(), style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(panelDetailProvider(specId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (spec) => _buildContent(context, spec, currency),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> spec, NumberFormat currency) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final bomItems = (spec['bomItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          _buildHeaderCard(context, spec),
          const SizedBox(height: 20),

          // Main 2-column or 1-column layout
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildTechnicalSpecsCard(spec),
                      const SizedBox(height: 20),
                      _buildBOMTableCard(bomItems, currency),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildCostingSummaryCard(spec, currency),
                      const SizedBox(height: 20),
                      _buildCustomerCard(spec['customer'] as Map<String, dynamic>?),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            _buildTechnicalSpecsCard(spec),
            const SizedBox(height: 20),
            _buildCostingSummaryCard(spec, currency),
            const SizedBox(height: 20),
            _buildBOMTableCard(bomItems, currency),
            const SizedBox(height: 20),
            _buildCustomerCard(spec['customer'] as Map<String, dynamic>?),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Map<String, dynamic> spec) {
    final code = spec['panelCode'] ?? '—';
    final type = (spec['panelType'] ?? '').toString().replaceAll('_', ' ');
    final status = spec['status'] ?? 'DRAFT';
    final customer = spec['customer']?['companyName'] ?? 'Unassigned';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.speed, color: AppTheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(code, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                      const SizedBox(width: 10),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('$type • Customer: $customer', style: const TextStyle(fontSize: 13, color: AppTheme.darkTextSecondary)),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generating official Sales Quotation for this panel...')),
              );
            },
            icon: const Icon(Icons.receipt_long, size: 16),
            label: const Text('Generate Quotation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalSpecsCard(Map<String, dynamic> spec) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('Technical Parameters & Specifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 20,
            runSpacing: 16,
            children: [
              _buildParamTile('Operating Voltage', spec['voltage'] ?? '415V 3-Phase', Icons.electric_bolt),
              _buildParamTile('Current Rating', spec['currentRating'] ?? '100A', Icons.power),
              _buildParamTile('Pump Configuration', '${spec['pumpQty'] ?? 2} Nos • ${spec['pumpHp'] ?? 7.5} HP Each', Icons.water_drop),
              _buildParamTile('Automation Control', spec['controlType'] ?? 'AUTOMATIC_PLC', Icons.settings_suggest),
              _buildParamTile('Starter Architecture', spec['starterType'] ?? 'VFD', Icons.memory),
              _buildParamTile('Ingress Protection', spec['ipRating'] ?? 'IP55', Icons.shield),
              _buildParamTile('Enclosure Body', (spec['enclosureType'] ?? 'POWDER_COATED_MS').toString().replaceAll('_', ' '), Icons.inventory_2_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParamTile(String label, String value, IconData icon) {
    return SizedBox(
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.darkTextSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkText)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBOMTableCard(List<Map<String, dynamic>> items, NumberFormat currency) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_chart_outlined, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('Bill of Materials (BOM)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${items.length} Components', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No Bill of Materials items configured for this specification', style: TextStyle(color: AppTheme.darkTextSecondary)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppTheme.darkBackground),
                columns: const [
                  DataColumn(label: Text('COMPONENT')),
                  DataColumn(label: Text('SPECIFICATION')),
                  DataColumn(label: Text('MAKE / MFR')),
                  DataColumn(label: Text('QTY', textAlign: TextAlign.right)),
                  DataColumn(label: Text('UNIT PRICE', textAlign: TextAlign.right)),
                  DataColumn(label: Text('TOTAL PRICE', textAlign: TextAlign.right)),
                ],
                rows: items.map((item) {
                  final qty = item['quantity'] ?? 1;
                  final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0;
                  final totalPrice = (item['totalPrice'] as num?)?.toDouble() ?? (qty * unitPrice);

                  return DataRow(
                    cells: [
                      DataCell(Text(item['componentName'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(item['specification'] ?? '—', style: const TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12))),
                      DataCell(Text(item['manufacturer'] ?? '—', style: const TextStyle(fontSize: 12))),
                      DataCell(Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(currency.format(unitPrice))),
                      DataCell(Text(currency.format(totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success))),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCostingSummaryCard(Map<String, dynamic> spec, NumberFormat currency) {
    final materialCost = (spec['materialCost'] as num?)?.toDouble() ?? 0;
    final labourCost = (spec['labourCost'] as num?)?.toDouble() ?? 0;
    final overheadCost = (spec['overheadCost'] as num?)?.toDouble() ?? 0;
    final marginPercent = (spec['marginPercent'] as num?)?.toDouble() ?? 15.0;
    final baseCost = materialCost + labourCost + overheadCost;
    final finalPrice = (spec['finalPrice'] as num?)?.toDouble() ?? (baseCost * (1 + marginPercent / 100));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_outlined, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('Costing & Margin Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
            ],
          ),
          const Divider(height: 24),
          _buildCostRow('BOM Raw Material Cost', currency.format(materialCost)),
          const SizedBox(height: 10),
          _buildCostRow('Labour & Wiring Assembly', currency.format(labourCost)),
          const SizedBox(height: 10),
          _buildCostRow('Testing & Factory Overheads', currency.format(overheadCost)),
          const Divider(height: 20),
          _buildCostRow('Net Manufacturing Base Cost', currency.format(baseCost), isBold: true),
          const SizedBox(height: 10),
          _buildCostRow('Target Gross Margin (%)', '${marginPercent.toStringAsFixed(1)}%', valueColor: AppTheme.info),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ESTIMATED SELLING PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success)),
                    Text('Inclusive of Overheads & Margin', style: TextStyle(fontSize: 10, color: AppTheme.darkTextSecondary)),
                  ],
                ),
                Text(currency.format(finalPrice),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.success)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostRow(String title, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 13, color: isBold ? AppTheme.darkText : AppTheme.darkTextSecondary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 13, color: valueColor ?? AppTheme.darkText, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic>? customer) {
    if (customer == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.business_outlined, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text('Client Master Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
            ],
          ),
          const Divider(height: 20),
          Text(customer['companyName'] ?? '—', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
          const SizedBox(height: 4),
          Text('Code: ${customer['customerCode'] ?? '—'}', style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
          if (customer['email'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 14, color: AppTheme.darkTextSecondary),
                const SizedBox(width: 6),
                Text(customer['email'], style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
              ],
            ),
          ],
          if (customer['phone'] != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: AppTheme.darkTextSecondary),
                const SizedBox(width: 6),
                Text(customer['phone'], style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = AppTheme.warning;
    if (status == 'APPROVED') color = AppTheme.info;
    if (status == 'IN_PRODUCTION') color = AppTheme.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
