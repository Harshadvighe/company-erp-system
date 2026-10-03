import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';

class CrmAnalyticsPage extends ConsumerWidget {
  const CrmAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(crmAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/crm/dashboard');
            }
          },
        ),
        title: const Text('CRM & Sales Intelligence'),
        backgroundColor: AppTheme.darkSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(crmAnalyticsProvider),
            tooltip: 'Refresh Analytics',
          ),
        ],
      ),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(err.toString(), style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(crmAnalyticsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final sources = (data['leadSources'] as List? ?? []);
          final oppStages = (data['opportunityStages'] as List? ?? []);
          final wonVsLost = data['wonVsLost'] as Map<String, dynamic>? ?? {};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Won vs Lost Header Card
              _buildWonVsLostCard(wonVsLost),
              const SizedBox(height: 16),

              // Product / Lead Sources Section
              _buildSectionHeader('Lead Sources Breakdown', Icons.source_outlined),
              const SizedBox(height: 8),
              _buildSourceGrid(sources),
              const SizedBox(height: 20),

              // Opportunities by Stage Section
              _buildSectionHeader('Sales Pipeline by Stage', Icons.show_chart),
              const SizedBox(height: 8),
              _buildStageBars(oppStages),
              const SizedBox(height: 20),

              // SAARK Core Systems Focus Card
              _buildCoreProductsCard(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildWonVsLostCard(Map<String, dynamic> data) {
    final wonCount = data['wonCount'] ?? 0;
    final lostCount = data['lostCount'] ?? 0;
    final wonVal = (data['wonValue'] ?? 0) as num;
    final lostVal = (data['lostValue'] ?? 0) as num;
    final total = wonCount + lostCount;
    final winRate = total > 0 ? ((wonCount / total) * 100).toStringAsFixed(1) : '0.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Win / Loss Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text('Win Rate: $winRate%', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statBox('Deals Won', '$wonCount', '₹${(wonVal / 100000).toStringAsFixed(1)}L', Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statBox('Deals Lost', '$lostCount', '₹${(lostVal / 100000).toStringAsFixed(1)}L', Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String count, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildSourceGrid(List<dynamic> sources) {
    if (sources.isEmpty) {
      return const Text('No lead source data available yet', style: TextStyle(color: Colors.grey, fontSize: 13));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 600
            ? (constraints.maxWidth - 10) / 2
            : 160.0;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: sources.map((s) {
            final src = s as Map<String, dynamic>;
            final name = (src['source'] ?? 'UNKNOWN').toString().replaceAll('_', ' ');
            final count = src['count'] ?? 0;

            return Container(
              width: cardWidth,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text('$count Leads', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStageBars(List<dynamic> stages) {
    if (stages.isEmpty) {
      return const Text('No active pipeline stages', style: TextStyle(color: Colors.grey, fontSize: 13));
    }

    return Column(
      children: stages.map((s) {
        final stage = s as Map<String, dynamic>;
        final name = stage['stage'] ?? '';
        final count = (stage['count'] ?? 0) as int;
        final totalVal = (stage['totalValue'] ?? 0) as num;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 6, height: 24, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 10),
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    Text('$count Deals', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 12),
                    Text('₹${(totalVal / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCoreProductsCard() {
    const products = [
      'Booster Pump Panel',
      'VFD Dual Pump Skid',
      'STP & WTP Automation',
      'Air Quality & Datalogger',
      'Water Softener Panel',
      'HVAC Chiller Panel',
      'Fire Fighting Panel',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SAARK Engineered Systems Portfolio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: products
                .map((p) => Chip(
                      label: Text(p, style: const TextStyle(fontSize: 11)),
                      backgroundColor: AppTheme.darkSurface,
                      side: const BorderSide(color: AppTheme.darkBorder),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
