import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/features/authentication/presentation/widgets/change_password_dialog.dart';
import 'package:saark_erp_mobile/features/my_work/data/my_work_repository.dart';
import 'package:saark_erp_mobile/features/tasks/data/tasks_repository.dart';

class MyWorkPage extends ConsumerWidget {
  const MyWorkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final summaryAsync = ref.watch(myWorkSummaryProvider);

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
        title: const Text('My Work'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myWorkSummaryProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myWorkSummaryProvider),
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text('Error loading workspace: $e',
                style: const TextStyle(color: AppTheme.error)),
          ),
          data: (data) {
            final taskStats = data['taskStats'] as Map<String, dynamic>? ?? {};
            final myTasks = data['myTasks'] as List? ?? [];
            final myProjects = data['myProjects'] as List? ?? [];
            final pendingApprovals = data['pendingApprovals'] as List? ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting & Profile Header
                  _buildProfileHeader(context, user),
                  const SizedBox(height: 20),

                  // Stat Counters
                  _buildStatCounters(taskStats),
                  const SizedBox(height: 24),

                  // Pending Approvals (For PM / Admin)
                  if (pendingApprovals.isNotEmpty) ...[
                    _buildSectionHeader('Pending Approvals', Icons.approval,
                        count: pendingApprovals.length),
                    const SizedBox(height: 10),
                    ...pendingApprovals
                        .map((item) => _buildApprovalCard(context, ref, item)),
                    const SizedBox(height: 24),
                  ],

                  // My Immediate Tasks
                  _buildSectionHeader(
                    'My Tasks to Do',
                    Icons.task_alt,
                    actionText: 'View All',
                    onAction: () => context.go('/tasks'),
                  ),
                  const SizedBox(height: 10),
                  if (myTasks.isEmpty)
                    const Card(
                      color: AppTheme.darkSurface,
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(
                          child: Text('You have no pending tasks! Great job.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    )
                  else
                    ...myTasks.map((t) => _buildTaskItem(context, ref, t)),

                  const SizedBox(height: 24),

                  // My Assigned Projects
                  _buildSectionHeader(
                    'My Projects',
                    Icons.folder_outlined,
                    actionText: 'View Portfolio',
                    onAction: () => context.go('/projects'),
                  ),
                  const SizedBox(height: 10),
                  if (myProjects.isEmpty)
                    const Card(
                      color: AppTheme.darkSurface,
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(
                          child: Text('No active projects assigned.',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    )
                  else
                    ...myProjects.map((p) => _buildProjectItem(context, p)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AuthUser? user) {
    return Card(
      color: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primary,
              child: Text(
                user?.fullName.isNotEmpty == true
                    ? user!.fullName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? 'Employee',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${user?.designation ?? "Designation Unassigned"} • ${user?.department ?? "Dept"}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  if (user?.employeeId != null) ...[
                    const SizedBox(height: 4),
                    Text('Employee ID: ${user!.employeeId}',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => ChangePasswordDialog.show(context),
              icon: const Icon(Icons.lock_reset, size: 16, color: Color(0xFFF26522)),
              label: const Text('Change Password', style: TextStyle(color: Color(0xFFF26522), fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFF26522)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCounters(Map<String, dynamic> stats) {
    return Row(
      children: [
        _statBox('Assigned', stats['assigned'] ?? 0, Colors.blue),
        const SizedBox(width: 8),
        _statBox('In Progress', stats['inProgress'] ?? 0, AppTheme.primary),
        const SizedBox(width: 8),
        _statBox('Review', stats['pendingReview'] ?? 0, AppTheme.warning),
        const SizedBox(width: 8),
        _statBox('Done', stats['completed'] ?? 0, AppTheme.success),
      ],
    );
  }

  Widget _statBox(String label, dynamic count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon,
      {int? count, String? actionText, VoidCallback? onAction}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
        const Spacer(),
        if (actionText != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionText,
                style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildApprovalCard(BuildContext context, WidgetRef ref, dynamic item) {
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item['title'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            'Submitted by: ${item['assignee']?['fullName'] ?? "Staff"} • ${item['project']?['name'] ?? ""}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Return for Changes',
              onPressed: () async {
                await ref.read(tasksRepositoryProvider).updateTaskStatus(
                    item['id'], 'RETURNED',
                    notes: 'Needs revision');
                ref.invalidate(myWorkSummaryProvider);
              },
            ),
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppTheme.success),
              tooltip: 'Approve & Complete',
              onPressed: () async {
                await ref.read(tasksRepositoryProvider).updateTaskStatus(
                    item['id'], 'COMPLETED',
                    notes: 'Approved');
                ref.invalidate(myWorkSummaryProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, WidgetRef ref, dynamic t) {
    final status = t['status']?.toString() ?? 'CREATED';
    final progress = (t['progress'] as num?)?.toInt() ?? 0;
    final dueDate = DateTime.tryParse(t['dueDate']?.toString() ?? '');
    final assignmentContext = switch (t['assignmentScope']?.toString()) {
      'TEAM' =>
        'Team: ${t['team']?['name'] ?? 'Team'} · Your role: ${t['teamRole'] == 'LEADER' ? 'Team Leader' : 'Member'}',
      'DEPARTMENT' => 'Department: ${t['department']?['name'] ?? 'Department'}',
      _ => 'Directly assigned',
    };
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t['title']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 5),
            Text(assignmentContext,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Progress: $progress%',
                    style: const TextStyle(fontSize: 12)),
                const Spacer(),
                Text(
                  t['priority']?.toString() ?? 'MEDIUM',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11),
                ),
                const SizedBox(width: 10),
                Text(
                  status == 'CREATED'
                      ? 'NOT STARTED'
                      : status.replaceAll('_', ' '),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 100) / 100,
                minHeight: 5,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
              ),
            ),
            if (dueDate != null) ...[
              const SizedBox(height: 6),
              Text(
                'Due: ${_formatDueDate(dueDate)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
            if (status == 'ASSIGNED' ||
                status == 'ACCEPTED' ||
                status == 'IN_PROGRESS') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () async {
                    final nextStatus = switch (status) {
                      'ASSIGNED' => 'ACCEPTED',
                      'ACCEPTED' => 'IN_PROGRESS',
                      _ => 'REVIEW',
                    };
                    try {
                      await ref
                          .read(tasksRepositoryProvider)
                          .updateTaskStatus(t['id'].toString(), nextStatus);
                      ref.invalidate(myWorkSummaryProvider);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Could not update task: $error')),
                        );
                      }
                    }
                  },
                  style: status == 'IN_PROGRESS'
                      ? ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.warning)
                      : null,
                  child: Text(switch (status) {
                    'ASSIGNED' => 'Accept',
                    'ACCEPTED' => 'Start',
                    _ => 'Submit for Review',
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final dueDay = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (dueDay == today) return 'Today';
    if (dueDay == today.add(const Duration(days: 1))) return 'Tomorrow';
    return '${date.day} ${_monthName(date.month)}';
  }

  Widget _buildProjectItem(BuildContext context, dynamic p) {
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.go('/projects/${p['id']}'),
        leading: const Icon(Icons.folder, color: AppTheme.primary),
        title: Text(p['name'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            'Tasks: ${p['_count']?['tasks'] ?? 0} • Members: ${p['_count']?['members'] ?? 0}'),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }
}
