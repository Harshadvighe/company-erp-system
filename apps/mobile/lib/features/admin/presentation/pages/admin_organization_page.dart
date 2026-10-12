import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/admin/data/admin_repository.dart';

class AdminOrganizationPage extends ConsumerStatefulWidget {
  const AdminOrganizationPage({super.key});

  @override
  ConsumerState<AdminOrganizationPage> createState() =>
      _AdminOrganizationPageState();
}

class _AdminOrganizationPageState extends ConsumerState<AdminOrganizationPage> {
  late Future<List<Map<String, dynamic>>> _organizationFuture;

  @override
  void initState() {
    super.initState();
    _organizationFuture =
        ref.read(adminRepositoryProvider).getOrganizationStructure();
  }

  void _reload() {
    setState(() {
      _organizationFuture =
          ref.read(adminRepositoryProvider).getOrganizationStructure();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _organizationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppTheme.error, size: 40),
                const SizedBox(height: 8),
                const Text('Unable to load the organization structure.'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final departments = snapshot.data ?? [];
        if (departments.isEmpty) {
          return const Center(child: Text('No departments have been set up.'));
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Organization structure',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Set department heads, create teams, and manage team membership.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              for (final department in departments)
                _departmentCard(department, departments),
            ],
          ),
        );
      },
    );
  }

  Widget _departmentCard(
    Map<String, dynamic> department,
    List<Map<String, dynamic>> departments,
  ) {
    final staff = (department['staff'] as List? ?? [])
        .whereType<Map>()
        .map((member) => Map<String, dynamic>.from(member))
        .where((member) => member['status'] == 'ACTIVE')
        .toList();
    final teams = (department['teams'] as List? ?? [])
        .whereType<Map>()
        .map((team) => Map<String, dynamic>.from(team))
        .toList();
    final teamStaffIds = teams
        .expand((team) => (team['members'] as List? ?? []).whereType<Map>())
        .map((membership) => membership['staffId']?.toString())
        .whereType<String>()
        .toSet();
    final unassignedStaff =
        staff.where((member) => !teamStaffIds.contains(member['id'])).toList();
    final head = department['headStaff'] is Map
        ? Map<String, dynamic>.from(department['headStaff'] as Map)
        : null;
    final headId = head?['id']?.toString();
    final headIsInActiveStaff = staff.any((member) => member['id'] == headId);

    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0x26F26522),
                  child: Icon(Icons.apartment, color: AppTheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        department['name']?.toString() ?? 'Department',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${department['code'] ?? ''} · ${staff.length} employees · ${teams.length} teams',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Add team',
                  onPressed: () => _showTeamDialog(
                    department,
                    departments: departments,
                  ),
                  icon: const Icon(Icons.add_circle_outline,
                      color: AppTheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: headId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Department Head',
                prefixIcon: Icon(Icons.person_outline),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No department head'),
                ),
                ...staff.map(
                  (member) => DropdownMenuItem<String?>(
                    value: member['id']?.toString(),
                    child: Text(
                      '${member['fullName']} (${member['employeeId']})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (head != null && !headIsInActiveStaff)
                  DropdownMenuItem<String?>(
                    value: headId,
                    child: Text('${head['fullName']} (inactive)'),
                  ),
              ],
              onChanged: (staffId) async {
                try {
                  await ref.read(adminRepositoryProvider).updateDepartmentHead(
                        department['id'].toString(),
                        staffId,
                      );
                  _reload();
                } catch (error) {
                  _showError('Unable to update department head: $error');
                }
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.groups_outlined,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Teams (${teams.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (teams.isEmpty)
              const Text(
                'No teams yet. Add a team to assign a leader and members.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              )
            else
              for (final team in teams)
                _teamCard(department, staff, team, departments),
            if (unassignedStaff.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Department employees without a team (${unassignedStaff.length})',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: unassignedStaff
                    .map(
                      (member) => Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          member['fullName']?.toString() ?? 'Employee',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _teamCard(
    Map<String, dynamic> department,
    List<Map<String, dynamic>> staff,
    Map<String, dynamic> team,
    List<Map<String, dynamic>> departments,
  ) {
    final leader = team['leader'] is Map
        ? Map<String, dynamic>.from(team['leader'] as Map)
        : null;
    final members = (team['members'] as List? ?? [])
        .whereType<Map>()
        .map((item) => item['staff'])
        .whereType<Map>()
        .map((member) => Map<String, dynamic>.from(member))
        .toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  team['name']?.toString() ?? 'Team',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                team['code']?.toString() ?? '',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') {
                    _showTeamDialog(
                      department,
                      departments: departments,
                      team: team,
                    );
                  } else if (action == 'delete') {
                    _confirmDeleteTeam(team);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit team')),
                  PopupMenuItem(value: 'delete', child: Text('Delete team')),
                ],
              ),
            ],
          ),
          Text(
            'Team Leader: ${leader?['fullName'] ?? 'Not assigned'}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          if ((team['departments'] as List? ?? []).length > 1)
            Text(
              'Departments: ${(team['departments'] as List).whereType<Map>().map((link) => (link['department'] as Map?)?['name']?.toString()).whereType<String>().join(', ')}',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: members
                .where((member) => member['id'] != leader?['id'])
                .map(
                  (member) => Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      member['fullName']?.toString() ?? 'Member',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _showTeamDialog(
    Map<String, dynamic> department, {
    required List<Map<String, dynamic>> departments,
    Map<String, dynamic>? team,
  }) async {
    final teamDepartmentIds = (team?['departments'] as List? ?? [])
        .whereType<Map>()
        .map((link) => (link['department'] as Map?)?['id']?.toString())
        .whereType<String>()
        .toSet();
    if (teamDepartmentIds.isEmpty) {
      teamDepartmentIds.add(
        (team?['departmentId'] ?? department['id']).toString(),
      );
    }
    final nameController =
        TextEditingController(text: team?['name']?.toString() ?? '');
    final codeController =
        TextEditingController(text: team?['code']?.toString() ?? '');
    final currentMembers = (team?['members'] as List? ?? [])
        .whereType<Map>()
        .map((item) => item['staffId']?.toString())
        .whereType<String>()
        .toSet();
    var selectedMembers = currentMembers;
    String? leaderId =
        (team?['leaderStaffId'] ?? team?['leader']?['id'])?.toString();
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final candidateById = <String, Map<String, dynamic>>{};
          for (final item in departments.where(
              (item) => teamDepartmentIds.contains(item['id']?.toString()))) {
            final headId = (item['headStaff'] as Map?)?['id']?.toString();
            for (final value in (item['staff'] as List? ?? [])
                .whereType<Map>()
                .where((member) => member['status'] == 'ACTIVE')) {
              final member = Map<String, dynamic>.from(value);
              final id = member['id']?.toString();
              if (id == null) continue;
              candidateById[id] = {
                ...member,
                'departmentName': item['name'],
                'isDepartmentHead': id == headId,
              };
            }
          }
          final candidates = candidateById.values.toList()
            ..sort((a, b) =>
                a['fullName'].toString().compareTo(b['fullName'].toString()));
          return AlertDialog(
            backgroundColor: AppTheme.darkSurface,
            title: Text(team == null ? 'Create team' : 'Edit team'),
            content: SizedBox(
              width: 480,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration:
                            const InputDecoration(labelText: 'Team name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: codeController,
                        decoration:
                            const InputDecoration(labelText: 'Team code'),
                      ),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Departments',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: departments.map((item) {
                          final id = item['id'].toString();
                          return FilterChip(
                            label: Text(item['name']?.toString() ?? ''),
                            selected: teamDepartmentIds.contains(id),
                            onSelected: (selected) => setDialogState(() {
                              if (selected) {
                                teamDepartmentIds.add(id);
                              } else {
                                teamDepartmentIds.remove(id);
                                final remainingIds = <String>{};
                                for (final remainingDepartment in departments
                                    .where((item) => teamDepartmentIds.contains(
                                          item['id']?.toString(),
                                        ))) {
                                  remainingIds.addAll(
                                    (remainingDepartment['staff'] as List? ??
                                            [])
                                        .whereType<Map>()
                                        .where((member) =>
                                            member['status'] == 'ACTIVE')
                                        .map((member) =>
                                            member['id'].toString()),
                                  );
                                }
                                selectedMembers.removeWhere(
                                  (staffId) => !remainingIds.contains(staffId),
                                );
                                if (leaderId != null &&
                                    !remainingIds.contains(leaderId)) {
                                  leaderId = null;
                                }
                              }
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue: leaderId,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Team Leader'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No leader'),
                          ),
                          ...candidates.map(
                            (member) => DropdownMenuItem<String?>(
                              value: member['id']?.toString(),
                              child: Text(
                                '${member['fullName']} (${member['employeeId']}) · ${member['departmentName']}${member['isDepartmentHead'] == true ? ' · Department Head' : ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) => setDialogState(() {
                          leaderId = value;
                          if (value != null) selectedMembers.add(value);
                        }),
                      ),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Team Members',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (teamDepartmentIds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Select at least one department.'),
                        )
                      else if (candidates.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'No active staff in the selected departments.',
                          ),
                        ),
                      for (final member in candidates)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selectedMembers.contains(member['id']) ||
                              member['id'] == leaderId,
                          title: Text(member['fullName']?.toString() ?? ''),
                          subtitle: Text(
                            [
                              member['departmentName']?.toString(),
                              member['isDepartmentHead'] == true
                                  ? 'Department Head'
                                  : member['designation'] is Map
                                      ? member['designation']['name']
                                          ?.toString()
                                      : member['employeeId']?.toString(),
                            ]
                                .whereType<String>()
                                .where((value) => value.isNotEmpty)
                                .join(' · '),
                          ),
                          onChanged: member['id'] == leaderId
                              ? null
                              : (selected) => setDialogState(() {
                                    if (selected == true) {
                                      selectedMembers
                                          .add(member['id'].toString());
                                    } else {
                                      selectedMembers
                                          .remove(member['id'].toString());
                                    }
                                  }),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final code = codeController.text.trim();
                        if (name.isEmpty || code.isEmpty) {
                          _showError('Enter both a team name and team code.');
                          return;
                        }
                        if (teamDepartmentIds.isEmpty) {
                          _showError('Select at least one department.');
                          return;
                        }
                        if (selectedMembers.isEmpty && leaderId == null) {
                          _showError(
                              'Select at least one team member or leader.');
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          await ref.read(adminRepositoryProvider).saveTeam(
                            {
                              'name': name,
                              'code': code,
                              'departmentIds': teamDepartmentIds.toList(),
                              'leaderStaffId': leaderId,
                              'memberStaffIds': selectedMembers.toList(),
                            },
                            teamId: team?['id']?.toString(),
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          _reload();
                        } catch (error) {
                          setDialogState(() => isSaving = false);
                          _showError('Unable to save team: $error');
                        }
                      },
                child: Text(isSaving ? 'Saving...' : 'Save team'),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();
    codeController.dispose();
  }

  Future<void> _confirmDeleteTeam(Map<String, dynamic> team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete team?'),
        content: Text(
          'Remove ${team['name']}? Tasks assigned to this team will remain but lose their team assignment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(adminRepositoryProvider).deleteTeam(team['id'].toString());
      _reload();
    } catch (error) {
      _showError('Unable to delete team: $error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }
}
