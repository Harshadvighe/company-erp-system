import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'company_sorting_workspace_view.dart';

/// 14-Color Swatch Palette defined in tabs/company_graph.py
const List<Color> kGraphPalette = [
  Color(0xFFF97316), // Orange
  Color(0xFF38BDF8), // Sky Blue
  Color(0xFF22C55E), // Emerald Green
  Color(0xFFFBBF24), // Amber
  Color(0xFFA78BFA), // Lavender / Violet
  Color(0xFFF472B6), // Pink
  Color(0xFF2DD4BF), // Teal
  Color(0xFFFB7185), // Rose
  Color(0xFF60A5FA), // Light Blue
  Color(0xFF4ADE80), // Lime Green
  Color(0xFFFCD34D), // Light Gold
  Color(0xFFC084FC), // Bright Purple
  Color(0xFFF87171), // Coral Red
  Color(0xFF34D399), // Mint Green
];

const List<String> kGraphPaletteHex = [
  '#F97316',
  '#38BDF8',
  '#22C55E',
  '#FBBF24',
  '#A78BFA',
  '#F472B6',
  '#2DD4BF',
  '#FB7185',
  '#60A5FA',
  '#4ADE80',
  '#FCD34D',
  '#C084FC',
  '#F87171',
  '#34D399',
];

/// Data item for each slice of the Donut Chart
class GraphSliceData {
  final String label;
  final int count;
  final double percentage;
  final Color color;
  final String hexColor;

  const GraphSliceData({
    required this.label,
    required this.count,
    required this.percentage,
    required this.color,
    required this.hexColor,
  });
}

/// Dynamic Circular Pie/Donut Graphical Analytics & Legend
class CompanyGraphWorkspaceView extends StatefulWidget {
  final List<CompanySortingItem>? records;

  const CompanyGraphWorkspaceView({super.key, this.records});

  @override
  State<CompanyGraphWorkspaceView> createState() => _CompanyGraphWorkspaceViewState();
}

class _CompanyGraphWorkspaceViewState extends State<CompanyGraphWorkspaceView> {
  late List<CompanySortingItem> _records;
  String _selectedReport = 'Product & System';

  final List<String> _reportOptions = [
    'Product & System',
    'Company Valuation',
    'Activity & Communication',
    'Next Meeting (Month-wise)',
    'Enquiry',
  ];

  @override
  void initState() {
    super.initState();
    _records = widget.records ?? getInitial40CompanySortingRecords();
  }

  @override
  void didUpdateWidget(covariant CompanyGraphWorkspaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records != null) {
      _records = widget.records!;
    }
  }

  void _refresh() {
    setState(() {
      // Trigger repaint and recalculation
    });
  }

  /// Calculates distribution slices for the active report
  List<GraphSliceData> _computeSlices() {
    final Map<String, int> rawCounts = {};
    int totalCountSum = 0;

    switch (_selectedReport) {
      case 'Product & System':
        // Check canonical products + Other / None
        final canonicalList = [
          'Booster Pump System',
          'STP',
          'Water Meter',
          'BMS',
          'RO',
          'De-watering Panel',
          'Water Softener',
          'Pump Skid',
          'HVAC',
          'HVAC Chiller Panel',
          'Water Analyzer (COD,BOD,TSS) Panel',
          'Air Quality Sensor / Analyzer',
          'Particulate Matter Reduction System Module',
          'Datalogger',
          'Pump Sensor Panel',
          'WTP',
          'FIRE PANEL',
        ];

        for (final prod in canonicalList) {
          int count = 0;
          for (final r in _records) {
            if (hasProduct(r.productsSelected, prod)) {
              count++;
            }
          }
          if (count > 0) {
            rawCounts[prod] = count;
            totalCountSum += count;
          }
        }

        // Count items with Other / None
        int otherNoneCount = 0;
        for (final r in _records) {
          final p = r.productsSelected.trim();
          if (p.isEmpty || p.toLowerCase() == 'none' || p.toLowerCase() == 'other') {
            otherNoneCount++;
          } else {
            // Check if none of the canonical products matched
            bool matchedAny = canonicalList.any((prod) => hasProduct(r.productsSelected, prod));
            if (!matchedAny) {
              otherNoneCount++;
            }
          }
        }
        if (otherNoneCount > 0) {
          rawCounts['Other / None'] = otherNoneCount;
          totalCountSum += otherNoneCount;
        }
        break;

      case 'Company Valuation':
        final valuations = [
          'Work in VFD Panel',
          'Work in Dewatering',
          'Distributor',
          'Dealer',
          'Serious Base',
        ];

        for (final val in valuations) {
          int count = 0;
          for (final r in _records) {
            if (r.valuation.toLowerCase().contains(val.toLowerCase())) {
              count++;
            }
          }
          if (count > 0) {
            rawCounts[val] = count;
            totalCountSum += count;
          }
        }

        int otherCount = 0;
        for (final r in _records) {
          final v = r.valuation.trim();
          if (v.isEmpty) {
            otherCount++;
          } else {
            bool matched = valuations.any((val) => r.valuation.toLowerCase().contains(val.toLowerCase()));
            if (!matched) otherCount++;
          }
        }
        if (otherCount > 0) {
          rawCounts['Other / None'] = otherCount;
          totalCountSum += otherCount;
        }
        break;

      case 'Activity & Communication':
        int withAct = 0;
        int noAct = 0;
        int withComm = 0;
        int withoutComm = 0;

        for (final r in _records) {
          if (r.activityCount > 0) {
            withAct++;
          } else {
            noAct++;
          }

          if (r.communicationDetails.trim().isNotEmpty || r.communicationDate.trim().isNotEmpty) {
            withComm++;
          } else {
            withoutComm++;
          }
        }

        if (withAct > 0) rawCounts['Active (count > 0)'] = withAct;
        if (noAct > 0) rawCounts['No Activity (count == 0)'] = noAct;
        if (withComm > 0) rawCounts['With Communication'] = withComm;
        if (withoutComm > 0) rawCounts['Without Communication'] = withoutComm;

        totalCountSum = withAct + noAct + withComm + withoutComm;
        break;

      case 'Next Meeting (Month-wise)':
        final Map<String, int> monthCounts = {};
        int noMeeting = 0;

        for (final r in _records) {
          final dtStr = r.nextMeeting.trim();
          if (dtStr.isEmpty) {
            noMeeting++;
          } else {
            DateTime? parsed;
            try {
              parsed = DateTime.parse(dtStr);
            } catch (_) {
              final parts = dtStr.split('-');
              if (parts.length == 3) {
                parsed = DateTime.tryParse('${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}');
              }
            }

            if (parsed != null) {
              const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
              final mStr = '${months[parsed.month - 1]} ${parsed.year}';
              monthCounts[mStr] = (monthCounts[mStr] ?? 0) + 1;
            } else {
              monthCounts[dtStr] = (monthCounts[dtStr] ?? 0) + 1;
            }
          }
        }

        // Add chronological months
        final sortedKeys = monthCounts.keys.toList();
        for (final k in sortedKeys) {
          rawCounts[k] = monthCounts[k]!;
          totalCountSum += monthCounts[k]!;
        }

        if (noMeeting > 0) {
          rawCounts['No Meeting'] = noMeeting;
          totalCountSum += noMeeting;
        }
        break;

      case 'Enquiry':
      default:
        int enquiryYes = 0;
        int enquiryNo = 0;
        final Map<String, int> typeCounts = {};

        for (final r in _records) {
          if (r.enquiry.trim().toLowerCase() == 'yes') {
            enquiryYes++;
            final t = r.enquiryType.trim();
            if (t.isNotEmpty) {
              final label = 'Type: $t';
              typeCounts[label] = (typeCounts[label] ?? 0) + 1;
            }
          } else {
            enquiryNo++;
          }
        }

        if (enquiryYes > 0) rawCounts['Enquiry Yes'] = enquiryYes;
        if (enquiryNo > 0) rawCounts['Enquiry No'] = enquiryNo;
        for (final entry in typeCounts.entries) {
          rawCounts[entry.key] = entry.value;
        }

        totalCountSum = rawCounts.values.fold(0, (a, b) => a + b);
        break;
    }

    if (totalCountSum == 0) return [];

    final List<GraphSliceData> slices = [];
    int colorIdx = 0;

    for (final entry in rawCounts.entries) {
      final double pct = (entry.value / totalCountSum) * 100.0;
      final color = kGraphPalette[colorIdx % kGraphPalette.length];
      final hex = kGraphPaletteHex[colorIdx % kGraphPaletteHex.length];

      slices.add(
        GraphSliceData(
          label: entry.key,
          count: entry.value,
          percentage: pct,
          color: color,
          hexColor: hex,
        ),
      );
      colorIdx++;
    }

    return slices;
  }

  @override
  Widget build(BuildContext context) {
    final slices = _computeSlices();
    final totalCompanies = _records.length;

    return Container(
      color: const Color(0xFF16181C),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── TOP UTILITY BAR ──────────────────────────────────────────────
          _buildTopUtilityBar(totalCompanies),

          const SizedBox(height: 12),

          // ─── DUAL-PANE ANALYTICAL VIEWPORT ────────────────────────────────
          SizedBox(
            height: 520,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Pane: "Circular Chart"
                Expanded(
                  flex: 5,
                  child: _buildCircularChartPane(slices, totalCompanies),
                ),

                const SizedBox(width: 14),

                // Right Pane: "Colour Legend"
                Expanded(
                  flex: 6,
                  child: _buildLegendPane(slices),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TOP UTILITY BAR ────────────────────────────────────────────────────────
  Widget _buildTopUtilityBar(int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2127),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2A2E39)),
      ),
      child: Row(
        children: [
          // Module Title
          const Text(
            'Company Sorting - Graphical Report',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 24),

          // Report Dropdown
          const Text('Report:', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 8),
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF131518),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF383D48)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedReport,
                isDense: true,
                dropdownColor: const Color(0xFF1E2127),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                items: _reportOptions
                    .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReport = val);
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Refresh Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF15A24),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
            ),
            onPressed: _refresh,
            child: const Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),

          const Spacer(),

          // Live Count Echo
          Text(
            '$_selectedReport | Total: $totalCount',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─── LEFT PANE: CIRCULAR CHART ──────────────────────────────────────────────
  Widget _buildCircularChartPane(List<GraphSliceData> slices, int totalCompanies) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2127),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2A2E39)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pane Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2A2E39))),
            ),
            child: const Text(
              'Circular Chart',
              style: TextStyle(
                color: Color(0xFFF15A24),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Vector Canvas Viewport
          Expanded(
            child: Center(
              child: Container(
                width: 380,
                height: 380,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A), // Deep Charcoal matching specification
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF3F3F46)),
                ),
                child: slices.isEmpty
                    ? const Center(
                        child: Text(
                          'No Data Available',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      )
                    : CustomPaint(
                        painter: _DonutChartPainter(
                          slices: slices,
                          totalCenterCount: totalCompanies,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── RIGHT PANE: COLOUR LEGEND ──────────────────────────────────────────────
  Widget _buildLegendPane(List<GraphSliceData> slices) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2127),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2A2E39)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2A2E39))),
            ),
            child: const Text(
              'Colour Legend',
              style: TextStyle(
                color: Color(0xFFF15A24),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Scrollable List of Swatches
          Expanded(
            child: slices.isEmpty
                ? const Center(
                    child: Text('No legend entries to display', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: slices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final item = slices[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16181C),
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFF272B35)),
                        ),
                        child: Row(
                          children: [
                            // 16 x 16 px Canvas color swatch square
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: item.color,
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(color: Colors.white30, width: 0.8),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Label + Count + Percentage: e.g. "Booster Pump System : 18 (16.7%)"
                            Expanded(
                              child: Text(
                                '${item.label} : ${item.count} (${item.percentage.toStringAsFixed(1)}%)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            // Hex Color Code tag for color-blind accessibility
                            Text(
                              item.hexColor,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Pure Vector CustomPainter implementing the circular donut graph
class _DonutChartPainter extends CustomPainter {
  final List<GraphSliceData> slices;
  final int totalCenterCount;

  _DonutChartPainter({
    required this.slices,
    required this.totalCenterCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;

    final center = Offset(size.width / 2.0, size.height / 2.0);
    const outerRadius = 130.0;
    const innerRadius = 32.0;

    double startAngle = -math.pi / 2.0; // Start at 12 o'clock

    final slicePaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final borderPaint = Paint()
      ..color = const Color(0xFF27272A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true;

    // 1. Draw Arcs for Each Slice
    for (final slice in slices) {
      final sweepAngle = (slice.percentage / 100.0) * 2 * math.pi;
      slicePaint.color = slice.color;

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: outerRadius),
          startAngle,
          sweepAngle,
          false,
        )
        ..close();

      canvas.drawPath(path, slicePaint);
      canvas.drawPath(path, borderPaint);

      // 2. Trigonometric Label Positioning inside slice if >= 4.0%
      if (slice.percentage >= 4.0) {
        final midAngle = startAngle + (sweepAngle / 2.0);
        const labelRadius = outerRadius * 0.65;
        final tx = center.dx + math.cos(midAngle) * labelRadius;
        final ty = center.dy + math.sin(midAngle) * labelRadius;

        _drawSliceLabel(canvas, Offset(tx, ty), slice.count, slice.percentage);
      }

      startAngle += sweepAngle;
    }

    // 3. Donut Center Cutout Hub
    final donutHolePaint = Paint()
      ..color = const Color(0xFF27272A)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final donutHoleBorder = Paint()
      ..color = const Color(0xFF3F3F46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

    canvas.drawCircle(center, innerRadius, donutHolePaint);
    canvas.drawCircle(center, innerRadius, donutHoleBorder);

    // 4. Center Text: Grand Total Count & "Companies"
    _drawCenterHubText(canvas, center, totalCenterCount);
  }

  void _drawSliceLabel(Canvas canvas, Offset pos, int count, double percentage) {
    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: '$count\n',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            height: 1.1,
            shadows: [
              Shadow(color: Colors.black87, blurRadius: 2),
            ],
          ),
        ),
        TextSpan(
          text: '${percentage.toStringAsFixed(1)}%',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(color: Colors.black87, blurRadius: 2),
            ],
          ),
        ),
      ],
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final drawOffset = Offset(
      pos.dx - (textPainter.width / 2.0),
      pos.dy - (textPainter.height / 2.0),
    );

    textPainter.paint(canvas, drawOffset);
  }

  void _drawCenterHubText(Canvas canvas, Offset center, int count) {
    // Grand Total Count
    final countSpan = TextSpan(
      text: '$count',
      style: const TextStyle(
        color: Color(0xFFF4F4F5),
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    final countPainter = TextPainter(
      text: countSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    countPainter.paint(
      canvas,
      Offset(center.dx - (countPainter.width / 2.0), center.dy - 14),
    );

    // Subtitle "Companies"
    const subSpan = TextSpan(
      text: 'Companies',
      style: TextStyle(
        color: Color(0xFFA1A1AA),
        fontSize: 8,
        fontWeight: FontWeight.w500,
      ),
    );
    final subPainter = TextPainter(
      text: subSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    subPainter.paint(
      canvas,
      Offset(center.dx - (subPainter.width / 2.0), center.dy + 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.totalCenterCount != totalCenterCount;
  }
}
