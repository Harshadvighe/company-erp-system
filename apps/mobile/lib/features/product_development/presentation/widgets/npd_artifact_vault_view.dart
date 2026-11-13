import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/npd_models.dart';
import '../../data/npd_repository.dart';

class NpdArtifactVaultView extends ConsumerStatefulWidget {
  final NpdBoardData boardData;
  final VoidCallback onRefresh;

  const NpdArtifactVaultView({
    super.key,
    required this.boardData,
    required this.onRefresh,
  });

  @override
  ConsumerState<NpdArtifactVaultView> createState() => _NpdArtifactVaultViewState();
}

class _NpdArtifactVaultViewState extends ConsumerState<NpdArtifactVaultView> {
  String _selectedCategory = 'ALL';

  @override
  Widget build(BuildContext context) {
    final artifacts = widget.boardData.artifacts.where((a) {
      if (_selectedCategory == 'ALL') return true;
      return a.artifactCategory == _selectedCategory;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header & Action Strip ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2128),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Wrap(
                spacing: 8,
                children: [
                  _buildCategoryPill('All Artifacts', 'ALL'),
                  _buildCategoryPill('Schematics', 'SCHEMATIC'),
                  _buildCategoryPill('Gerbers', 'GERBER'),
                  _buildCategoryPill('Firmware Binaries', 'FIRMWARE_BIN'),
                  _buildCategoryPill('Pick & Place', 'PICK_AND_PLACE'),
                  _buildCategoryPill('Register Maps', 'REGISTER_MAP'),
                ],
              ),
              const Spacer(),
              if (widget.boardData.artifacts.isEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF4CC9F0)),
                  label: const Text('Seed Sample Files', style: TextStyle(color: Color(0xFF4CC9F0))),
                  onPressed: () => _seedSampleArtifacts(),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A86FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Register Artifact'),
                onPressed: () => _showAddArtifactDialog(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── Artifacts Grid / List ────────────────────────────────────────────
        if (artifacts.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2128),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(Icons.folder_open_rounded, size: 48, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 10),
                const Text(
                  'No artifacts registered in this category.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload schematics, Gerber archives, or firmware release binaries.',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: artifacts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final art = artifacts[index];
              return _buildArtifactCard(art);
            },
          ),
      ],
    );
  }

  Widget _buildCategoryPill(String title, String cat) {
    final isSelected = _selectedCategory == cat;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = cat),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3A86FF).withOpacity(0.25) : const Color(0xFF2A2E39),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF3A86FF) : Colors.white12,
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

  Widget _buildArtifactCard(NpdArtifact art) {
    IconData icon = Icons.insert_drive_file_outlined;
    Color iconColor = const Color(0xFF4CC9F0);

    if (art.artifactCategory == 'GERBER') {
      icon = Icons.layers_outlined;
      iconColor = const Color(0xFFFF9F1C);
    } else if (art.artifactCategory == 'FIRMWARE_BIN') {
      icon = Icons.memory_rounded;
      iconColor = const Color(0xFFE0AAFF);
    } else if (art.artifactCategory == 'PICK_AND_PLACE') {
      icon = Icons.grid_on_rounded;
      iconColor = const Color(0xFF2EC4B6);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2128),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      art.fileName,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        art.versionTag ?? 'v1.0.0',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (art.isFrozen)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B4D8).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, size: 10, color: Color(0xFF00B4D8)),
                            SizedBox(width: 4),
                            Text('Frozen', style: TextStyle(color: Color(0xFF00B4D8), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  art.filePath,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (art.sha256Hash != null) ...[
                  Row(
                    children: [
                      const Text('SHA-256: ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      Flexible(
                        child: SelectableText(
                          art.sha256Hash!,
                          style: const TextStyle(
                            color: Color(0xFF4CC9F0),
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: art.sha256Hash!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('SHA-256 hash copied!'), backgroundColor: Color(0xFF4CC9F0)),
                          );
                        },
                        child: const Icon(Icons.copy, size: 14, color: Colors.white38),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                art.createdAt.toLocal().toString().substring(0, 10),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                'By ${art.uploadedByName ?? 'Engineer'}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddArtifactDialog() {
    final fileController = TextEditingController();
    final pathController = TextEditingController(text: 'vault/hardware/');
    final hashController = TextEditingController();
    final verController = TextEditingController(text: 'v1.0.0');
    String category = 'GERBER';
    int stepNumber = 9;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2128),
          title: const Text('Register Engineering Artifact', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: category,
                    dropdownColor: const Color(0xFF252932),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Artifact Category'),
                    items: [
                      'SCHEMATIC',
                      'GERBER',
                      'PICK_AND_PLACE',
                      'FIRMWARE_BIN',
                      'REGISTER_MAP',
                      'TEST_SPEC',
                    ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDialogState(() => category = v ?? 'GERBER'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: fileController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'File Name (e.g. PRJ_IOT_GATEWAY_GERBER_REV1.zip)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: pathController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Repository / Cloud Storage Path'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: hashController,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                    decoration: const InputDecoration(labelText: 'SHA-256 Checksum Hash (64 Hex chars)'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: verController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Version Tag (e.g. v1.0.0-RC1)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: stepNumber,
                          dropdownColor: const Color(0xFF252932),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Linked Step (1-24)'),
                          items: List.generate(24, (i) => i + 1)
                              .map((s) => DropdownMenuItem(value: s, child: Text('Step $s')))
                              .toList(),
                          onChanged: (v) => setDialogState(() => stepNumber = v ?? 9),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A86FF)),
              onPressed: () async {
                try {
                  final repo = ref.read(npdRepositoryProvider);
                  await repo.createArtifact(widget.boardData.project.id, {
                    'stepNumber': stepNumber,
                    'artifactCategory': category,
                    'fileName': fileController.text.trim(),
                    'filePath': pathController.text.trim(),
                    'sha256Hash': hashController.text.trim().isNotEmpty ? hashController.text.trim() : null,
                    'versionTag': verController.text.trim(),
                  });
                  Navigator.pop(ctx);
                  widget.onRefresh();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              },
              child: const Text('Register Artifact'),
            ),
          ],
        ),
      ),
    );
  }

  void _seedSampleArtifacts() async {
    final sampleFiles = [
      {
        'stepNumber': 6,
        'artifactCategory': 'SCHEMATIC',
        'fileName': 'ESP32S3_Gateway_Mainboard_RevA.kicad_sch',
        'filePath': 'git://hardware/schematics/ESP32S3_Gateway_Mainboard_RevA.kicad_sch',
        'sha256Hash': 'a94a8fe5ccb19ba61c4c0873d391e987982fbbd342080a969f64980a3773ee41',
        'versionTag': 'RevA.1',
      },
      {
        'stepNumber': 9,
        'artifactCategory': 'GERBER',
        'fileName': 'GERBER_RS485_ESP32_FAB_REV1.0.zip',
        'filePath': 's3://saark-erp-documents/npd/gerber/GERBER_RS485_ESP32_FAB_REV1.0.zip',
        'sha256Hash': '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b',
        'versionTag': 'v1.0.0-PROD',
      },
      {
        'stepNumber': 9,
        'artifactCategory': 'PICK_AND_PLACE',
        'fileName': 'CPL_SMT_PICK_PLACE_CENTROID_REV1.0.csv',
        'filePath': 's3://saark-erp-documents/npd/cpl/CPL_SMT_PICK_PLACE_CENTROID_REV1.0.csv',
        'sha256Hash': 'd4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35',
        'versionTag': 'v1.0.0-PROD',
      },
      {
        'stepNumber': 22,
        'artifactCategory': 'FIRMWARE_BIN',
        'fileName': 'firmware_release_v1.0.0_signed.bin',
        'filePath': 'binaries/firmware/release/firmware_release_v1.0.0_signed.bin',
        'sha256Hash': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'versionTag': 'v1.0.0-GOLDEN',
      },
    ];

    try {
      final repo = ref.read(npdRepositoryProvider);
      for (final f in sampleFiles) {
        await repo.createArtifact(widget.boardData.project.id, f);
      }
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sample artifacts seeded!'), backgroundColor: Color(0xFF2EC4B6)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}

