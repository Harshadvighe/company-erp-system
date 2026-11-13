import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/npd_models.dart';
import '../../data/npd_repository.dart';

class Npd24StepBoardView extends ConsumerStatefulWidget {
  final NpdBoardData boardData;
  final VoidCallback onRefresh;

  const Npd24StepBoardView({
    super.key,
    required this.boardData,
    required this.onRefresh,
  });

  @override
  ConsumerState<Npd24StepBoardView> createState() => _Npd24StepBoardViewState();
}

class _Npd24StepBoardViewState extends ConsumerState<Npd24StepBoardView> {
  int _selectedPhaseFilter = 0; // 0 = All, 1, 2, 3, 4
  bool _onlyGatesFilter = false;

  @override
  Widget build(BuildContext context) {
    final steps = widget.boardData.steps.where((s) {
      if (_onlyGatesFilter && s.gateType == 'STANDARD') return false;
      if (_selectedPhaseFilter > 0 && s.phaseNumber != _selectedPhaseFilter) return false;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Filter Bar ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2128),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'NPI Phases:',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              _buildPhasePill('All 24 Steps', 0),
              _buildPhasePill('Phase 1: Concept (1-5)', 1, const Color(0xFF00B4D8)),
              _buildPhasePill('Phase 2: Design (6-9)', 2, const Color(0xFF7209B7)),
              _buildPhasePill('Phase 3: Sourcing (10-20)', 3, const Color(0xFFF77F00)),
              _buildPhasePill('Phase 4: Bring-Up (21-24)', 4, const Color(0xFF2EC4B6)),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('🛑 Hard-Stop Gates Only', style: TextStyle(fontSize: 12)),
                selected: _onlyGatesFilter,
                selectedColor: Colors.redAccent.withOpacity(0.3),
                checkmarkColor: Colors.redAccent,
                labelStyle: TextStyle(
                  color: _onlyGatesFilter ? Colors.redAccent : Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: const Color(0xFF2A2E39),
                onSelected: (val) => setState(() => _onlyGatesFilter = val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── Steps List ──────────────────────────────────────────────────────
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: steps.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final step = steps[index];
            return _buildStepCard(step);
          },
        ),
      ],
    );
  }

  Widget _buildPhasePill(String title, int phaseNumber, [Color? color]) {
    final isSelected = _selectedPhaseFilter == phaseNumber;
    final pillColor = color ?? const Color(0xFF3A86FF);

    return InkWell(
      onTap: () => setState(() => _selectedPhaseFilter = phaseNumber),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? pillColor.withOpacity(0.25) : const Color(0xFF2A2E39),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? pillColor : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(NpdWorkflowStep step) {
    final isSignedOff = step.status == 'SIGNED_OFF';
    final isInProgress = step.status == 'IN_PROGRESS';
    final isPending = step.status == 'PENDING';

    Color statusColor = const Color(0xFF6C757D);
    if (isSignedOff) statusColor = const Color(0xFF2EC4B6);
    else if (isInProgress) statusColor = const Color(0xFF3A86FF);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2128),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInProgress ? const Color(0xFF3A86FF).withOpacity(0.6) : Colors.white.withOpacity(0.08),
          width: isInProgress ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isInProgress
                  ? const Color(0xFF3A86FF).withOpacity(0.12)
                  : isSignedOff
                      ? const Color(0xFF2EC4B6).withOpacity(0.08)
                      : const Color(0xFF252932),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                // Step Number Circle
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(0.2),
                    border: Border.all(color: statusColor, width: 2),
                  ),
                  child: isSignedOff
                      ? const Icon(Icons.check, size: 18, color: Color(0xFF2EC4B6))
                      : Text(
                          '${step.stepNumber}',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Step ${step.stepNumber}: ${step.stepTitle}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildGateBadge(step.gateType),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Phase ${step.phaseNumber}: ${step.phaseName}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    step.status,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Body: Dual Track Deliverables
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    final hwWidget = _buildDeliverableBox(
                      title: 'Hardware Deliverable (HW)',
                      icon: Icons.precision_manufacturing_outlined,
                      accentColor: const Color(0xFFFF9F1C),
                      content: step.hwDeliverable,
                    );
                    final swWidget = _buildDeliverableBox(
                      title: 'Firmware & Software Task (FW/SW)',
                      icon: Icons.code_rounded,
                      accentColor: const Color(0xFF4CC9F0),
                      content: step.swDeliverable,
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          hwWidget,
                          const SizedBox(height: 10),
                          swWidget,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: hwWidget),
                        const SizedBox(width: 12),
                        Expanded(child: swWidget),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Audit or Sign-off Action Bar
                if (isSignedOff) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2EC4B6).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2EC4B6).withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: Color(0xFF2EC4B6), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Signed Off by ${step.signoffStaffName ?? 'Lead Engineer'} (${step.signoffRole ?? 'Auditor'}) on ${step.signedOffAt?.toLocal().toString().substring(0, 16) ?? 'Audit Lock'}'
                            '${step.signoffComments != null && step.signoffComments!.isNotEmpty ? ' — "${step.signoffComments}"' : ''}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isInProgress) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A86FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.rate_review_rounded, size: 18),
                        label: Text(
                          step.gateType != 'STANDARD'
                              ? 'Enforce Gate & Sign Off Step ${step.stepNumber}'
                              : 'Sign Off Step ${step.stepNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _showSignoffDialog(step),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Icon(Icons.lock_clock_outlined, size: 16, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(width: 6),
                      Text(
                        'Awaiting completion of Step ${step.stepNumber - 1}',
                        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverableBox({
    required String title,
    required IconData icon,
    required Color accentColor,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16181D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGateBadge(String gateType) {
    if (gateType == 'STANDARD') return const SizedBox.shrink();

    String label = '🛑 Gate';
    Color color = Colors.redAccent;

    switch (gateType) {
      case 'HARD_STOP_REVIEW':
        label = '🛑 Hard-Stop Peer Review';
        color = const Color(0xFFFF4D6D);
        break;
      case 'DESIGN_FREEZE':
        label = '🔒 Design & Register Freeze';
        color = const Color(0xFF00B4D8);
        break;
      case 'COMPLIANCE_STOP':
        label = '⚠️ 100% RoHS PO Stop';
        color = const Color(0xFFFFB703);
        break;
      case 'GOLDEN_SAMPLE_LOCK':
        label = '🔑 Golden Sample & FW Lock';
        color = const Color(0xFFE0AAFF);
        break;
      case 'FACTORY_PASS_GATE':
        label = '⚡ Automated Test Rig Gate';
        color = const Color(0xFF2EC4B6);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showSignoffDialog(NpdWorkflowStep step) {
    final commentsController = TextEditingController();
    final roleController = TextEditingController(text: 'Lead Hardware/Firmware Auditor');
    final fwHashController = TextEditingController();
    bool bypassGate = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2128),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Color(0xFF3A86FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sign Off Step ${step.stepNumber}: ${step.stepTitle}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGateNoticeBox(step.gateType),
                  const SizedBox(height: 14),

                  const Text(
                    'Auditor Role / Title:',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: roleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF16181D),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: 'e.g. Lead Systems Engineer',
                      hintStyle: const TextStyle(color: Colors.white30),
                    ),
                  ),

                  const SizedBox(height: 14),

                  if (step.stepNumber == 22) ...[
                    const Text(
                      'Firmware Release v1.0.0 SHA-256 Hash:',
                      style: TextStyle(color: Color(0xFFE0AAFF), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: fwHashController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF16181D),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: 'e.g. e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
                        hintStyle: const TextStyle(color: Colors.white30),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  const Text(
                    'Review Sign-off Comments / Audit Checklist:',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: commentsController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF16181D),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: 'Record audit notes, peer reviewers, or test bench verification logs...',
                      hintStyle: const TextStyle(color: Colors.white30),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Bypass Switch for emergencies / admins
                  Row(
                    children: [
                      Switch(
                        value: bypassGate,
                        activeColor: Colors.amber,
                        onChanged: (val) => setDialogState(() => bypassGate = val),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Engineering Lead Override (Bypass non-blocking prerequisite gates)',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2EC4B6),
                foregroundColor: Colors.black87,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        final repo = ref.read(npdRepositoryProvider);
                        await repo.signoffStep(
                          step.projectId,
                          step.stepNumber,
                          comments: commentsController.text.trim(),
                          role: roleController.text.trim(),
                          bypassGate: bypassGate,
                          firmwareHash: fwHashController.text.trim().isNotEmpty
                              ? fwHashController.text.trim()
                              : null,
                        );
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          widget.onRefresh();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Step ${step.stepNumber} successfully signed off!'),
                              backgroundColor: const Color(0xFF2EC4B6),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sign-off error: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                    )
                  : const Text('Confirm Sign-Off', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGateNoticeBox(String gateType) {
    if (gateType == 'STANDARD') return const SizedBox.shrink();

    String title = 'Hard Gate Enforcement Notice';
    String desc = 'Ensure all hardware and firmware deliverables have been verified.';
    Color color = Colors.orangeAccent;

    if (gateType == 'HARD_STOP_REVIEW') {
      title = '🛑 Mandatory Peer Review Hard Gate';
      desc = 'Requires written sign-off from both Lead HW and Lead FW engineers before schematic freeze.';
      color = Colors.redAccent;
    } else if (gateType == 'DESIGN_FREEZE') {
      title = '🔒 Step 9 Design & Register Map Freeze';
      desc = 'Signing off this step PERMANENTLY freezes the SSOT Register Map (PC_REG/MB_REG) and Gerber files.';
      color = const Color(0xFF00B4D8);
    } else if (gateType == 'COMPLIANCE_STOP') {
      title = '⚠️ Step 14 100% RoHS Verification Gate';
      desc = 'PO release is blocked if any component lacks RoHS 3 / REACH compliance documentation.';
      color = Colors.amber;
    } else if (gateType == 'GOLDEN_SAMPLE_LOCK') {
      title = '🔑 Step 22 Golden Sample & Firmware Hash Lock';
      desc = 'Locks 3x Golden Samples in vault and registers immutable SHA-256 binary hash.';
      color = const Color(0xFFE0AAFF);
    } else if (gateType == 'FACTORY_PASS_GATE') {
      title = '⚡ Step 23 Automated Factory Test Pass Gate';
      desc = 'Requires at least one PASS result from the automated test fixture API before sign-off.';
      color = const Color(0xFF2EC4B6);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
