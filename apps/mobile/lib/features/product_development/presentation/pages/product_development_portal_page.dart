import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import '../../data/npd_models.dart';
import '../../data/npd_repository.dart';
import '../widgets/npd_24_step_board_view.dart';
import '../widgets/npd_register_map_view.dart';
import '../widgets/npd_bom_rohs_view.dart';
import '../widgets/npd_artifact_vault_view.dart';
import '../widgets/npd_factory_qc_view.dart';

class ProductDevelopmentPortalPage extends ConsumerStatefulWidget {
  const ProductDevelopmentPortalPage({super.key});

  @override
  ConsumerState<ProductDevelopmentPortalPage> createState() =>
      _ProductDevelopmentPortalPageState();
}

class _ProductDevelopmentPortalPageState
    extends ConsumerState<ProductDevelopmentPortalPage> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final projectsAsync = ref.watch(npdProjectsProvider);
    final selectedId = ref.watch(selectedNpdProjectIdProvider);
    final boardAsync = ref.watch(currentBoardDataProvider);

    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFF14161B),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ─── 1. Desktop Window Strip ─────────────────────────────────────
            _buildWindowBar(user),

            // ─── 2. Top Header Banner ────────────────────────────────────────
            _buildTopHeader(context, isCompact, projectsAsync, selectedId),

            // ─── 3. Main Workspace Area ──────────────────────────────────────
            Expanded(
              child: boardAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF3A86FF)),
                ),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 12),
                      Text('Error loading NPD Board: $err', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.refresh(currentBoardDataProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (boardData) {
                  if (boardData == null) {
                    return _buildEmptyState();
                  }

                  return Column(
                    children: [
                      // Sub-Tabs Bar
                      _buildSubTabBar(boardData),

                      // Tab View Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: _buildActiveTabContent(boardData),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Window Strip ─────────────────────────────────────────────────────────
  Widget _buildWindowBar(dynamic user) {
    return Container(
      height: 38,
      color: const Color(0xFF0F1115),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 18),
            onPressed: () => context.go('/dashboard'),
          ),
          const SizedBox(width: 12),
          const Text(
            'SAARK EXPLORATION — PRODUCT & DEVELOPMENT (NPI LIFECYCLE)',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2128),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle, color: Color(0xFF3A86FF), size: 14),
                const SizedBox(width: 6),
                Text(
                  user?.fullName ?? user?.username ?? 'Engineering Lead',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Top Header Banner ───────────────────────────────────────────────────
  Widget _buildTopHeader(
    BuildContext context,
    bool isCompact,
    AsyncValue<List<NpdProject>> projectsAsync,
    String? selectedId,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2128),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Project Selector Dropdown
          projectsAsync.when(
            loading: () => const SizedBox(
              width: 220,
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (_, __) => const Text('Error', style: TextStyle(color: Colors.redAccent)),
            data: (projects) {
              if (projects.isEmpty) {
                return const Text(
                  'No Projects',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                );
              }

              final currentId = selectedId ?? projects.first.id;
              final currentProject = projects.firstWhere(
                (p) => p.id == currentId,
                orElse: () => projects.first,
              );

              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A86FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.precision_manufacturing_rounded, color: Color(0xFF3A86FF), size: 24),
                  ),
                  const SizedBox(width: 12),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentProject.id,
                      dropdownColor: const Color(0xFF252932),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      items: projects.map((p) {
                        return DropdownMenuItem<String>(
                          value: p.id,
                          child: Text('${p.projectCode}: ${p.projectName}'),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null) {
                          ref.read(selectedNpdProjectIdProvider.notifier).state = newId;
                          ref.refresh(currentBoardDataProvider);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // MCU Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CC9F0).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF4CC9F0).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.memory, size: 12, color: Color(0xFF4CC9F0)),
                        const SizedBox(width: 4),
                        Text(
                          currentProject.targetMcu,
                          style: const TextStyle(color: Color(0xFF4CC9F0), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const Spacer(),

          // New Project Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A86FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Project', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _showCreateProjectDialog(),
          ),
        ],
      ),
    );
  }

  // ─── Sub-Tab Bar ──────────────────────────────────────────────────────────
  Widget _buildSubTabBar(NpdBoardData boardData) {
    final tabs = [
      {'title': '📋 24-Step Workflow Board', 'index': 0},
      {'title': '📑 SSOT Register Map', 'index': 1},
      {'title': '📦 Engineering BOM & RoHS (${boardData.totalBomCount})', 'index': 2},
      {'title': '🔒 Artifact Vault (${boardData.artifacts.length})', 'index': 3},
      {'title': '⚡ Factory QC Test Logs (${boardData.totalTests})', 'index': 4},
    ];

    return Container(
      color: const Color(0xFF181B22),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Navigation Tabs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tabs.map((t) {
                  final idx = t['index'] as int;
                  final title = t['title'] as String;
                  final isSelected = _activeTab == idx;

                  return InkWell(
                    onTap: () => setState(() => _activeTab = idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? const Color(0xFF3A86FF) : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Overall Progress Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2EC4B6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2EC4B6).withOpacity(0.3)),
            ),
            child: Text(
              'Progress: ${boardData.signedOffSteps}/24 Steps (${boardData.progressPct}%)',
              style: const TextStyle(
                color: Color(0xFF2EC4B6),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Active Tab Content ───────────────────────────────────────────────────
  Widget _buildActiveTabContent(NpdBoardData boardData) {
    switch (_activeTab) {
      case 0:
        return Npd24StepBoardView(
          boardData: boardData,
          onRefresh: () => ref.refresh(currentBoardDataProvider),
        );
      case 1:
        return NpdRegisterMapView(
          boardData: boardData,
          onRefresh: () => ref.refresh(currentBoardDataProvider),
        );
      case 2:
        return NpdBomRohsView(
          boardData: boardData,
          onRefresh: () => ref.refresh(currentBoardDataProvider),
        );
      case 3:
        return NpdArtifactVaultView(
          boardData: boardData,
          onRefresh: () => ref.refresh(currentBoardDataProvider),
        );
      case 4:
        return NpdFactoryQcView(
          boardData: boardData,
          onRefresh: () => ref.refresh(currentBoardDataProvider),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Empty State ──────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2128),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF3A86FF).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.precision_manufacturing_rounded, size: 48, color: Color(0xFF3A86FF)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Product Development Projects Found',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a project to initialize the 4-Phase, 24-Step Dual-Track (Hardware + Firmware) Workflow Engine with SSOT Register Mapping.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A86FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.rocket_launch_rounded, size: 18),
              label: const Text('Initialize Industrial IoT Gateway Project', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _seedDefaultProject(),
            ),
          ],
        ),
      ),
    );
  }

  void _seedDefaultProject() async {
    try {
      final repo = ref.read(npdRepositoryProvider);
      final newBoard = await repo.createProject({
        'projectName': 'Industrial IoT Modbus-to-MQTT Gateway',
        'productCategory': 'Industrial IoT & Edge Computing',
        'targetMcu': 'ESP32-S3-WROOM-1-N8R8',
        'operatingVoltage': '9V - 36V DC Wide Input',
        'formFactor': 'DIN Rail 4U Enclosure',
        'complianceTargets': 'CE, FCC Part 15, RoHS 3, WEEE, BIS CRS',
      });

      ref.read(selectedNpdProjectIdProvider.notifier).state = newBoard.project.id;
      ref.refresh(npdProjectsProvider);
      ref.refresh(currentBoardDataProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project initialized with 24 workflow steps & SSOT register map!'),
            backgroundColor: Color(0xFF2EC4B6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showCreateProjectDialog() {
    final nameCtrl = TextEditingController();
    final mcuCtrl = TextEditingController(text: 'ESP32-S3-WROOM-1');
    final catCtrl = TextEditingController(text: 'Industrial Automation');
    final voltCtrl = TextEditingController(text: '3.3V / 12V-24V DC');
    final formCtrl = TextEditingController(text: 'DIN Rail 4U');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2128),
        title: const Text('Create New NPD Project', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Project Name (e.g. Smart Energy Meter)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mcuCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Target MCU / Processor'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: catCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Product Category'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: voltCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Operating Voltage'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: formCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Form Factor / Enclosure'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A86FF)),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              try {
                final repo = ref.read(npdRepositoryProvider);
                final res = await repo.createProject({
                  'projectName': nameCtrl.text.trim(),
                  'targetMcu': mcuCtrl.text.trim(),
                  'productCategory': catCtrl.text.trim(),
                  'operatingVoltage': voltCtrl.text.trim(),
                  'formFactor': formCtrl.text.trim(),
                });
                Navigator.pop(ctx);
                ref.read(selectedNpdProjectIdProvider.notifier).state = res.project.id;
                ref.refresh(npdProjectsProvider);
                ref.refresh(currentBoardDataProvider);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text('Create Project'),
          ),
        ],
      ),
    );
  }
}

