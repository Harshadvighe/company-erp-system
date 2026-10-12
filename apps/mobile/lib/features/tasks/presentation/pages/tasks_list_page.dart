import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/features/tasks/data/tasks_repository.dart';
import 'package:saark_erp_mobile/features/staff/data/staff_repository.dart';
import 'package:saark_erp_mobile/features/projects/data/projects_repository.dart';
import 'package:saark_erp_mobile/features/admin/data/admin_repository.dart';
import 'package:saark_erp_mobile/features/my_work/data/my_work_repository.dart';

class TasksListPage extends ConsumerStatefulWidget {
  const TasksListPage({super.key});

  @override
  ConsumerState<TasksListPage> createState() => _TasksListPageState();
}

class _TasksListPageState extends ConsumerState<TasksListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedStatus = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Task Manager'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.assignment_ind_outlined), text: 'My Tasks'),
            Tab(icon: Icon(Icons.list_alt_outlined), text: 'All Tasks'),
          ],
        ),
        actions: [
          if (user?.staffId != null)
            IconButton(
              icon: const Icon(Icons.add_task),
              tooltip: 'Assign Task',
              onPressed: () => _showCreateTaskDialog(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                'ALL',
                'CREATED',
                'ASSIGNED',
                'PENDING',
                'IN_PROGRESS',
                'REVIEW',
                'COMPLETED'
              ].map((status) {
                final isSelected = _selectedStatus == status;
                final label = status == 'CREATED'
                    ? 'NOT STARTED'
                    : status.replaceAll('_', ' ');
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedStatus = status);
                    },
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppTheme.primary,
                  ),
                );
              }).toList(),
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTasksList(isMyTasks: true),
                _buildTasksList(isMyTasks: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksList({required bool isMyTasks}) {
    final user = ref.watch(currentUserProvider);
    final asyncTasks = isMyTasks
        ? ref.watch(myTasksProvider)
        : ref.watch(allTasksProvider(
            _selectedStatus == 'ALL' ? null : _selectedStatus));

    return asyncTasks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child:
              Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
      data: (tasks) {
        // Apply status filter locally if my tasks
        final filteredTasks = isMyTasks && _selectedStatus != 'ALL'
            ? tasks.where((t) => t.status == _selectedStatus).toList()
            : tasks;

        if (filteredTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.task_alt, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  isMyTasks
                      ? 'You have no tasks in this queue.'
                      : 'No tasks found.',
                  style: const TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredTasks.length,
          itemBuilder: (context, index) {
            final task = filteredTasks[index];
            return _buildTaskCard(task, user);
          },
        );
      },
    );
  }

  Widget _buildTaskCard(TaskItem task, AuthUser? user) {
    Color priorityColor = Colors.grey;
    if (task.priority == 'CRITICAL') priorityColor = Colors.red;
    if (task.priority == 'HIGH') priorityColor = Colors.orange;
    if (task.priority == 'MEDIUM') priorityColor = Colors.blue;

    final isAssignee =
        user?.staffId != null && task.assigneeStaffId == user!.staffId;
    final canWorkTask = isAssignee ||
        (task.assignmentScope == 'TEAM' && task.assigneeStaffId == null) ||
        task.assignmentScope == 'DEPARTMENT';
    final isTaskAssigner = task.isTaskAssigner ||
        task.assignedByStaffId == user?.staffId ||
        task.createdByStaffId == user?.staffId;
    final canManage = user?.isProjectManager == true ||
        user?.isAdmin == true ||
        isTaskAssigner ||
        task.teamRole == 'LEADER' ||
        task.assignmentScope == 'DEPARTMENT';

    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.go('/tasks/${task.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.taskNumber,
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.priority,
                      style: TextStyle(
                          color: priorityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  _buildStatusChip(task.status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                task.title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (task.projectName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.folder_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      task.projectName!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
              if (task.assignmentScope.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  switch (task.assignmentScope) {
                    'TEAM' =>
                      'Team: ${task.teamName ?? 'Team'} · Your role: ${task.teamRole == 'LEADER' ? 'Team Leader' : 'Member'}',
                    'ASSIGNED_BY' => 'Assigned by you',
                    'DEPARTMENT' =>
                      'Department: ${task.departmentName ?? 'Department'}',
                    _ => task.teamName == null
                        ? 'Directly assigned'
                        : 'Team: ${task.teamName} · Direct assignment',
                  },
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                    child: Text(
                      task.assigneeName?.isNotEmpty == true
                          ? task.assigneeName![0]
                          : '?',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    task.assigneeName ??
                        task.teamName ??
                        (task.assignmentScope == 'DEPARTMENT'
                            ? 'Department task'
                            : 'Unassigned'),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  if (task.dueDate != null) ...[
                    const Icon(Icons.schedule, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${_formatDueDate(task.dueDate!)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
              // Progress Bar
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Progress',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const Spacer(),
                  Text('${task.progress}%',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.progress.clamp(0, 100) / 100.0,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    task.progress == 100 ? AppTheme.success : AppTheme.primary,
                  ),
                  minHeight: 6,
                ),
              ),
              // Contextual Action Buttons (Zero Extra UI)
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canWorkTask && task.status == 'ASSIGNED')
                    ElevatedButton(
                      onPressed: () => _updateStatus(task.id, 'ACCEPTED'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary),
                      child: const Text('Accept Task'),
                    ),
                  if (canWorkTask && task.status == 'ACCEPTED')
                    ElevatedButton(
                      onPressed: () => _updateStatus(task.id, 'IN_PROGRESS'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary),
                      child: const Text('Start Work'),
                    ),
                  if (canWorkTask &&
                      (task.status == 'IN_PROGRESS' ||
                          task.status == 'PENDING' ||
                          task.status == 'RETURNED'))
                    OutlinedButton(
                      onPressed: () => _updateStatus(
                        task.id,
                        task.status == 'IN_PROGRESS' ? 'PENDING' : 'IN_PROGRESS',
                      ),
                      child: Text(
                        task.status == 'IN_PROGRESS' ? 'Mark Pending' : 'Resume',
                      ),
                    ),
                  if (canWorkTask &&
                      (task.status == 'IN_PROGRESS' ||
                          task.status == 'PENDING' ||
                          task.status == 'RETURNED'))
                    ElevatedButton(
                      onPressed: () => _updateStatus(task.id, 'REVIEW',
                          notes: 'Work completed; submitted to the assigner for review'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.warning),
                      child: const Text('Send to Assigner'),
                    ),
                  if (canManage && task.status == 'REVIEW') ...[
                    OutlinedButton(
                      onPressed: () => _updateStatus(task.id, 'RETURNED',
                          notes: 'Please review specifications and re-test'),
                      child: const Text('Return for Changes'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _updateStatus(task.id, 'COMPLETED',
                          notes: 'Approved by Manager'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success),
                      child: const Text('Approve & Complete'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    if (status == 'IN_PROGRESS') color = AppTheme.primary;
    if (status == 'PENDING') color = AppTheme.warning;
    if (status == 'REVIEW') color = AppTheme.warning;
    if (status == 'COMPLETED') color = AppTheme.success;
    if (status == 'RETURNED') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final dueDay = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (dueDay == today) return 'Today';
    if (dueDay == today.add(const Duration(days: 1))) return 'Tomorrow';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _updateStatus(String taskId, String status,
      {String? notes}) async {
    try {
      await ref
          .read(tasksRepositoryProvider)
          .updateTaskStatus(taskId, status, notes: notes);
      ref.invalidate(allTasksProvider(null));
      ref.invalidate(myTasksProvider);
      ref.invalidate(myWorkSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task moved to $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showCreateTeamDialog(
    BuildContext context,
  ) async {
    final organization =
        await ref.read(adminRepositoryProvider).getOrganizationStructure();
    if (!context.mounted) return null;

    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final selectedDepartmentIds = <String>{};
    final selectedMemberIds = <String>{};
    String? leaderStaffId;
    var isSaving = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedDepartments = organization
              .where((department) =>
                  selectedDepartmentIds.contains(department['id']?.toString()))
              .toList();
          final candidatesById = <String, Map<String, dynamic>>{};
          for (final department in selectedDepartments) {
            final headId = (department['headStaff'] as Map?)?['id']?.toString();
            for (final value
                in (department['staff'] as List? ?? []).whereType<Map>()) {
              final person = Map<String, dynamic>.from(value);
              if (person['status'] != 'ACTIVE') continue;
              final id = person['id']?.toString();
              if (id == null) continue;
              candidatesById[id] = {
                ...person,
                'departmentName': department['name'],
                'isDepartmentHead': id == headId,
              };
            }
          }
          final candidates = candidatesById.values.toList()
            ..sort((a, b) =>
                a['fullName'].toString().compareTo(b['fullName'].toString()));
          return AlertDialog(
            backgroundColor: AppTheme.darkSurface,
            title: const Text('Create cross-department team'),
            content: SizedBox(
              width: 520,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.68,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Team name *',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: 'Team code *',
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Departments',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: organization.map((department) {
                          final id = department['id'].toString();
                          final selected = selectedDepartmentIds.contains(id);
                          return FilterChip(
                            label: Text(department['name'].toString()),
                            selected: selected,
                            onSelected: isSaving
                                ? null
                                : (value) => setDialogState(() {
                                      if (value) {
                                        selectedDepartmentIds.add(id);
                                      } else {
                                        selectedDepartmentIds.remove(id);
                                      }
                                      final eligibleStaffIds = organization
                                          .where((item) => selectedDepartmentIds
                                              .contains(item['id']?.toString()))
                                          .expand((item) =>
                                              (item['staff'] as List? ?? [])
                                                  .whereType<Map>())
                                          .where((item) =>
                                              item['status'] == 'ACTIVE')
                                          .map((item) => item['id'].toString())
                                          .toSet();
                                      selectedMemberIds.removeWhere(
                                        (staffId) =>
                                            !eligibleStaffIds.contains(staffId),
                                      );
                                      if (leaderStaffId != null &&
                                          !eligibleStaffIds
                                              .contains(leaderStaffId)) {
                                        leaderStaffId = null;
                                      }
                                    }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: leaderStaffId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Team leader (optional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No leader'),
                          ),
                          ...candidates.map((person) => DropdownMenuItem(
                                value: person['id'].toString(),
                                child: Text(
                                  '${person['fullName']} · ${person['departmentName']}${person['isDepartmentHead'] == true ? ' · Department Head' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                        ],
                        onChanged: isSaving
                            ? null
                            : (value) => setDialogState(() {
                                  leaderStaffId = value;
                                  if (value != null) {
                                    selectedMemberIds.add(value);
                                  }
                                }),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Team members',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (selectedDepartmentIds.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Select one or more departments to choose active staff and department heads.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else if (candidates.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No active staff found in the selected departments.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        ...candidates.map((person) {
                          final id = person['id'].toString();
                          final isLeader = id == leaderStaffId;
                          final isHead = person['isDepartmentHead'] == true;
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: isLeader || selectedMemberIds.contains(id),
                            title: Text(person['fullName']?.toString() ?? ''),
                            subtitle: Text(
                              '${person['departmentName']}${isHead ? ' · Department Head' : ''}',
                            ),
                            onChanged: isSaving || isLeader
                                ? null
                                : (selected) => setDialogState(() {
                                      if (selected == true) {
                                        selectedMemberIds.add(id);
                                      } else {
                                        selectedMemberIds.remove(id);
                                      }
                                    }),
                          );
                        }),
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
                        if (name.isEmpty ||
                            code.isEmpty ||
                            selectedDepartmentIds.isEmpty ||
                            (selectedMemberIds.isEmpty &&
                                leaderStaffId == null)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Enter a name and code, select departments, and add a leader or member.',
                              ),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        try {
                          final team =
                              await ref.read(adminRepositoryProvider).saveTeam({
                            'name': name,
                            'code': code,
                            'departmentIds': selectedDepartmentIds.toList(),
                            'leaderStaffId': leaderStaffId,
                            'memberStaffIds': selectedMemberIds.toList(),
                          });
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, team);
                          }
                        } catch (error) {
                          setDialogState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unable to create team: $error'),
                              ),
                            );
                          }
                        }
                      },
                child: Text(isSaving ? 'Creating...' : 'Create team'),
              ),
            ],
          );
        },
      ),
    );
    nameController.dispose();
    codeController.dispose();
    return result;
  }

  void _showCreateTaskDialog(BuildContext context) async {
    final user = ref.read(currentUserProvider);
    final canManageOrganization = user?.canCreate('TASKS') == true;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'MEDIUM';
    String? selectedStaffId;
    String? selectedProjectId;
    String? selectedDepartmentId;
    String? selectedTeamId;
    DateTime? dueDate;

    late final List<StaffMember> staffList;
    late final List<ProjectItem> projectsList;
    late List<Map<String, dynamic>> departments;
    try {
      if (canManageOrganization) {
        staffList = await ref.read(staffRepositoryProvider).getStaffList();
        projectsList = await ref.read(projectsRepositoryProvider).getProjects();
        departments =
            await ref.read(adminRepositoryProvider).getOrganizationStructure();
      } else {
        final assignableStaff =
            await ref.read(tasksRepositoryProvider).getAssignableStaff();
        staffList = assignableStaff
            .map((staff) => StaffMember.fromJson(staff))
            .toList();
        projectsList = [];
        final ledTeams =
            await ref.read(tasksRepositoryProvider).getMyLedTeams();
        final departmentsById = <String, Map<String, dynamic>>{};
        for (final team in ledTeams) {
          var linkedDepartments = (team['departments'] as List? ?? [])
              .whereType<Map>()
              .map((link) => link['department'])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          if (linkedDepartments.isEmpty && team['department'] is Map) {
            linkedDepartments = [
              Map<String, dynamic>.from(team['department'] as Map),
            ];
          }
          for (final department in linkedDepartments) {
            final id = department['id']?.toString();
            if (id == null) continue;
            final entry = departmentsById.putIfAbsent(id, () => {
                  ...department,
                  'staff': <Map<String, dynamic>>[],
                  'teams': <Map<String, dynamic>>[],
                });
            (entry['teams'] as List).add(team);
          }
        }
        departments = departmentsById.values.toList();
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not load task assignment options: $error')),
        );
      }
      return;
    }
    List<Map<String, dynamic>> collectTeams(
      List<Map<String, dynamic>> organization,
    ) {
      final teamsById = <String, Map<String, dynamic>>{};
      for (final department in organization) {
        for (final value
            in (department['teams'] as List? ?? []).whereType<Map>()) {
          final team = Map<String, dynamic>.from(value);
          final id = team['id']?.toString();
          if (id == null) continue;
          final teamDepartments = (team['departments'] as List? ?? [])
              .whereType<Map>()
              .map((item) => item['department'])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          if (teamDepartments.isEmpty) {
            teamDepartments.add({
              'id': department['id'],
              'name': department['name'],
            });
          }
          final current = teamsById.putIfAbsent(id, () => team);
          final linkedDepartments =
              (current['_departments'] as Map<String, dynamic>?) ??
                  <String, dynamic>{};
          for (final linkedDepartment in teamDepartments) {
            final departmentId = linkedDepartment['id']?.toString();
            if (departmentId != null) {
              linkedDepartments[departmentId] = linkedDepartment;
            }
          }
          current['_departments'] = linkedDepartments;
        }
      }
      return teamsById.values.map((team) {
        final linkedDepartments =
            (team['_departments'] as Map<String, dynamic>? ?? {}).values;
        return {
          ...team,
          'departmentIds':
              linkedDepartments.map((item) => item['id'].toString()).toList(),
          'departmentNames':
              linkedDepartments.map((item) => item['name'].toString()).toList(),
        };
      }).toList();
    }

    var teams = collectTeams(departments);
    final canAssignTeam =
        canManageOrganization || teams.isNotEmpty;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Map<String, dynamic>? selectedTeam;
          for (final team in teams) {
            if (team['id']?.toString() == selectedTeamId) {
              selectedTeam = team;
              break;
            }
          }
          final teamLeader = selectedTeam?['leader'] is Map
              ? Map<String, dynamic>.from(selectedTeam!['leader'] as Map)
              : null;
          final teamMembers = <Map<String, dynamic>>[];
          final seenMemberIds = <String>{};
          final rawMembers = selectedTeam?['members'];
          if (rawMembers is List) {
            for (final item in rawMembers.whereType<Map>()) {
              final member = item['staff'];
              if (member is Map) {
                final person = Map<String, dynamic>.from(member);
                if (person['status'] != null &&
                    person['status'] != 'ACTIVE') {
                  continue;
                }
                final id = person['id']?.toString();
                if (id != null && seenMemberIds.add(id)) {
                  teamMembers.add(person);
                }
              }
            }
          }
          if (teamLeader != null) {
            final leaderId = teamLeader['id']?.toString();
            if (leaderId != null && seenMemberIds.add(leaderId)) {
              teamMembers.insert(0, teamLeader);
            }
          }
          final teamLabelById = <String, String>{
            if (teamLeader?['id'] != null)
              teamLeader!['id'].toString(): 'Team Leader',
            for (final person in teamMembers)
              if (person['id'] != teamLeader?['id'])
                person['id'].toString(): 'Team Member',
          };

          return AlertDialog(
            backgroundColor: AppTheme.darkSurface,
            title: const Text('Create New Task'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration:
                        const InputDecoration(labelText: 'Task Title *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (val) => setDialogState(() => priority = val!),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: dueDate ?? now,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: DateTime(2100),
                        helpText: 'Choose an optional due date',
                      );
                      if (selected != null) {
                        setDialogState(() => dueDate = selected);
                      }
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      dueDate == null
                          ? 'Add due date (optional)'
                          : 'Due ${_formatDueDate(dueDate!)}',
                    ),
                  ),
                  if (dueDate != null)
                    TextButton(
                      onPressed: () => setDialogState(() => dueDate = null),
                      child: const Text('Remove due date'),
                    ),
                  const SizedBox(height: 8),
                  if (canManageOrganization) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedProjectId,
                      decoration: const InputDecoration(
                          labelText: 'Project (Optional)'),
                      items: projectsList
                          .map((prj) => DropdownMenuItem(
                              value: prj.id, child: Text(prj.name)))
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedProjectId = val),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (canManageOrganization) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedDepartmentId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Department (Optional)'),
                      items: departments
                          .map((department) => DropdownMenuItem(
                                value: department['id'].toString(),
                                child: Text(
                                    department['name']?.toString() ?? ''),
                              ))
                          .toList(),
                      onChanged: (val) => setDialogState(() {
                        selectedDepartmentId = val;
                        if (selectedTeamId != null &&
                            !teams
                                .firstWhere(
                                  (team) =>
                                      team['id'].toString() == selectedTeamId,
                                )['departmentIds']
                                .contains(val)) {
                          selectedTeamId = null;
                          selectedStaffId = null;
                        }
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (canAssignTeam) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedTeamId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: canManageOrganization
                            ? 'Team (Optional)'
                            : 'Team you lead (Optional)',
                        helperText: teams.isEmpty
                            ? 'Create a team here to assign work across departments.'
                            : null,
                      ),
                      items: teams
                          .where((team) =>
                              selectedDepartmentId == null ||
                              (team['departmentIds'] as List)
                                  .contains(selectedDepartmentId))
                          .map((team) => DropdownMenuItem(
                                value: team['id'].toString(),
                                child: Text(
                                  '${team['name']} · ${(team['departmentNames'] as List).join(', ')}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (val) => setDialogState(() {
                        selectedTeamId = val;
                        selectedStaffId = null;
                      }),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (canManageOrganization)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                        final created = await _showCreateTeamDialog(context);
                        if (created == null || !context.mounted) return;
                        try {
                          departments = await ref
                              .read(adminRepositoryProvider)
                              .getOrganizationStructure();
                          teams = collectTeams(departments);
                          setDialogState(() {
                            selectedTeamId = created['id']?.toString();
                            selectedDepartmentId = null;
                            selectedStaffId = null;
                          });
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Team was created, but the team list could not refresh: $error',
                                ),
                              ),
                            );
                          }
                        }
                        },
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('Create team'),
                      ),
                    ),
                  if (selectedTeam != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.groups_outlined,
                                  color: AppTheme.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${selectedTeam['name']} team',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Leader: ${teamLeader?['fullName'] ?? 'Not assigned'}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Members (${teamMembers.length})',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          if (teamMembers.isEmpty)
                            const Text(
                              'No active members are listed for this team.',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            )
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: teamMembers
                                  .map(
                                    (person) => Chip(
                                      visualDensity: VisualDensity.compact,
                                      avatar: Icon(
                                        person['id'] == teamLeader?['id']
                                            ? Icons.star
                                            : Icons.person_outline,
                                        size: 14,
                                        color: AppTheme.primary,
                                      ),
                                      label: Text(
                                        person['fullName']?.toString() ??
                                            'Employee',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedStaffId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Assign to',
                        prefixIcon: Icon(Icons.person_add_alt_1),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Entire team'),
                        ),
                        ...teamMembers.map(
                          (person) => DropdownMenuItem<String?>(
                            value: person['id']?.toString(),
                            child: Text(
                              '${person['fullName']} · ${teamLabelById[person['id']?.toString()] ?? 'Team Member'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedStaffId = val),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedStaffId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Assignee Staff (Optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('No individual assignee')),
                        ...staffList.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text(
                              '${s.fullName} (${s.employeeId})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setDialogState(() => selectedStaffId = val),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a task title.')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await ref.read(tasksRepositoryProvider).createTask({
                      'title': titleController.text.trim(),
                      'description': descController.text.trim(),
                      'priority': priority,
                      'projectId': selectedProjectId,
                      'departmentId': selectedDepartmentId,
                      'teamId': selectedTeamId,
                      'assigneeStaffId': selectedStaffId,
                      if (dueDate != null)
                        'dueDate': DateTime.utc(
                          dueDate!.year,
                          dueDate!.month,
                          dueDate!.day,
                        ).toIso8601String(),
                    });
                    ref.invalidate(allTasksProvider(null));
                    ref.invalidate(myTasksProvider);
                    ref.invalidate(myWorkSummaryProvider);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Failed: $e')));
                    }
                  }
                },
                child: const Text('Create Task'),
              ),
            ],
          );
        },
      ),
    );
  }
}
