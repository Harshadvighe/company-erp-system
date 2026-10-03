import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/features/tasks/data/tasks_repository.dart';
import 'package:saark_erp_mobile/features/staff/data/staff_repository.dart';
import 'package:saark_erp_mobile/features/projects/data/projects_repository.dart';

class TasksListPage extends ConsumerStatefulWidget {
  const TasksListPage({super.key});

  @override
  ConsumerState<TasksListPage> createState() => _TasksListPageState();
}

class _TasksListPageState extends ConsumerState<TasksListPage> with SingleTickerProviderStateMixin {
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
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
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
          if (user?.canCreate('TASKS') == true)
            IconButton(
              icon: const Icon(Icons.add_task),
              tooltip: 'Create Task',
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
              children: ['ALL', 'ASSIGNED', 'IN_PROGRESS', 'REVIEW', 'COMPLETED'].map((status) {
                final isSelected = _selectedStatus == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(status.replaceAll('_', ' ')),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedStatus = status);
                    },
                    selectedColor: AppTheme.primary.withOpacity(0.2),
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
        : ref.watch(allTasksProvider(_selectedStatus == 'ALL' ? null : _selectedStatus));

    return asyncTasks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
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
                  isMyTasks ? 'You have no tasks in this queue.' : 'No tasks found.',
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

    final isAssignee = user?.staffId != null && task.assigneeStaffId == user!.staffId;
    final canManage = user?.isProjectManager == true || user?.isAdmin == true;

    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.taskNumber,
                    style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.priority,
                    style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                _buildStatusChip(task.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              task.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (task.projectName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    task.projectName!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppTheme.primary.withOpacity(0.2),
                  child: Text(
                    task.assigneeName?.isNotEmpty == true ? task.assigneeName![0] : '?',
                    style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  task.assigneeName ?? 'Unassigned',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                if (task.dueDate != null) ...[
                  const Icon(Icons.schedule, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ],
            ),
            // Progress Bar
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: task.progress / 100.0,
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
                if (isAssignee && task.status == 'ASSIGNED')
                  ElevatedButton(
                    onPressed: () => _updateStatus(task.id, 'ACCEPTED'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                    child: const Text('Accept Task'),
                  ),
                if (isAssignee && task.status == 'ACCEPTED')
                  ElevatedButton(
                    onPressed: () => _updateStatus(task.id, 'IN_PROGRESS'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                    child: const Text('Start Work'),
                  ),
                if (isAssignee && task.status == 'IN_PROGRESS')
                  ElevatedButton(
                    onPressed: () => _updateStatus(task.id, 'REVIEW', notes: 'Completed duties and submitted for signoff'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
                    child: const Text('Submit for Review'),
                  ),
                if (canManage && task.status == 'REVIEW') ...[
                  OutlinedButton(
                    onPressed: () => _updateStatus(task.id, 'RETURNED', notes: 'Please review specifications and re-test'),
                    child: const Text('Return for Changes'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _updateStatus(task.id, 'COMPLETED', notes: 'Approved by Manager'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                    child: const Text('Approve & Complete'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    if (status == 'IN_PROGRESS') color = AppTheme.primary;
    if (status == 'REVIEW') color = AppTheme.warning;
    if (status == 'COMPLETED') color = AppTheme.success;
    if (status == 'RETURNED') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _updateStatus(String taskId, String status, {String? notes}) async {
    try {
      await ref.read(tasksRepositoryProvider).updateTaskStatus(taskId, status, notes: notes);
      ref.invalidate(allTasksProvider(null));
      ref.invalidate(myTasksProvider);
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

  void _showCreateTaskDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'MEDIUM';
    String? selectedStaffId;
    String? selectedProjectId;

    final staffList = await ref.read(staffRepositoryProvider).getStaffList();
    final projectsList = await ref.read(projectsRepositoryProvider).getProjects();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: const Text('Create New Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Task Title *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => priority = val!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedProjectId,
                  decoration: const InputDecoration(labelText: 'Project (Optional)'),
                  items: projectsList
                      .map((prj) => DropdownMenuItem(value: prj.id, child: Text(prj.name)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedProjectId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStaffId,
                  decoration: const InputDecoration(labelText: 'Assignee Staff'),
                  items: staffList
                      .map((s) => DropdownMenuItem(value: s.id, child: Text('${s.fullName} (${s.employeeId})')))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedStaffId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await ref.read(tasksRepositoryProvider).createTask({
                    'title': titleController.text.trim(),
                    'description': descController.text.trim(),
                    'priority': priority,
                    'projectId': selectedProjectId,
                    'assigneeStaffId': selectedStaffId,
                  });
                  ref.invalidate(allTasksProvider(null));
                  ref.invalidate(myTasksProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                  }
                }
              },
              child: const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }
}
