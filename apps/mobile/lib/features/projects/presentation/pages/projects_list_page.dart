import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/features/projects/data/projects_repository.dart';
import 'package:saark_erp_mobile/features/staff/data/staff_repository.dart';

class ProjectsListPage extends ConsumerStatefulWidget {
  const ProjectsListPage({super.key});

  @override
  ConsumerState<ProjectsListPage> createState() => _ProjectsListPageState();
}

class _ProjectsListPageState extends ConsumerState<ProjectsListPage> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final projectsAsync = ref.watch(projectsListProvider(_search));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Projects Portfolio'),
        actions: [
          if (user?.canCreate('PROJECTS') == true)
            IconButton(
              icon: const Icon(Icons.add_box_outlined),
              tooltip: 'New Project',
              onPressed: () => _showCreateProjectDialog(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Project Name or Code...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.darkSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) => setState(() => _search = val.trim()),
            ),
          ),
          Expanded(
            child: projectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error: $err', style: const TextStyle(color: AppTheme.error)),
              ),
              data: (projects) {
                if (projects.isEmpty) {
                  return const Center(
                    child: Text('No projects found.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return _buildProjectCard(project);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(ProjectItem project) {
    Color healthColor = AppTheme.success;
    if (project.health == 'AT_RISK') healthColor = AppTheme.warning;
    if (project.health == 'CRITICAL') healthColor = Colors.red;

    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/projects/${project.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      project.projectNumber,
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      project.projectType,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  // Health Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: healthColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: healthColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 8, color: healthColor),
                        const SizedBox(width: 4),
                        Text(
                          project.health.replaceAll('_', ' '),
                          style: TextStyle(color: healthColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                project.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (project.customerName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Customer: ${project.customerName}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
              const SizedBox(height: 12),
              // Meta stats row
              Row(
                children: [
                  const Icon(Icons.person_pin, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'PM: ${project.projectManagerName ?? "Unassigned"}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    'Budget: ₹${project.budget.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statChip(Icons.people_outline, '${project.memberCount} Members'),
                  const SizedBox(width: 8),
                  _statChip(Icons.flag_outlined, '${project.milestoneCount} Milestones'),
                  const SizedBox(width: 8),
                  _statChip(Icons.task_alt, '${project.taskCount} Tasks'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final budgetController = TextEditingController();
    String? selectedPmId;
    String projectType = 'Customer Project';

    final staffList = await ref.read(staffRepositoryProvider).getStaffList();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: const Text('Create New Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Project Name *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: projectType,
                  decoration: const InputDecoration(labelText: 'Project Type'),
                  items: [
                    'Customer Project',
                    'Panel Manufacturing',
                    'Engineering / R&D',
                    'Installation',
                    'Service',
                    'IT / Software',
                    'Internal',
                  ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setDialogState(() => projectType = val!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedPmId,
                  decoration: const InputDecoration(labelText: 'Project Manager *'),
                  items: staffList
                      .map((s) => DropdownMenuItem(value: s.id, child: Text('${s.fullName} (${s.designationName ?? "Staff"})')))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedPmId = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: budgetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Budget (₹)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || selectedPmId == null) return;
                Navigator.pop(ctx);
                try {
                  await ref.read(projectsRepositoryProvider).createProject({
                    'name': nameController.text.trim(),
                    'projectType': projectType,
                    'projectManagerStaffId': selectedPmId,
                    'budget': double.tryParse(budgetController.text.trim()) ?? 0,
                    'description': descController.text.trim(),
                  });
                  ref.invalidate(projectsListProvider(null));
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
              child: const Text('Create Project'),
            ),
          ],
        ),
      ),
    );
  }
}
