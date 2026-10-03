import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
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
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
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
            child: Text('Error loading workspace: $e', style: const TextStyle(color: AppTheme.error)),
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
                  _buildProfileHeader(user),
                  const SizedBox(height: 20),

                  // Stat Counters
                  _buildStatCounters(taskStats),
                  const SizedBox(height: 24),

                  // Pending Approvals (For PM / Admin)
                  if (pendingApprovals.isNotEmpty) ...[
                    _buildSectionHeader('Pending Approvals', Icons.approval, count: pendingApprovals.length),
                    const SizedBox(height: 10),
                    ...pendingApprovals.map((item) => _buildApprovalCard(context, ref, item)),
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
                          child: Text('You have no pending tasks! Great job.', style: TextStyle(color: Colors.grey)),
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
                          child: Text('No active projects assigned.', style: TextStyle(color: Colors.grey)),
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

  Widget _buildProfileHeader(AuthUser? user) {
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
                user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? 'Employee',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${user?.designation ?? "Designation Unassigned"} • ${user?.department ?? "Dept"}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  if (user?.employeeId != null) ...[
                    const SizedBox(height: 4),
                    Text('Employee ID: ${user!.employeeId}',
                        style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ],
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
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {int? count, String? actionText, VoidCallback? onAction}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
        const Spacer(),
        if (actionText != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionText, style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildApprovalCard(BuildContext context, WidgetRef ref, dynamic item) {
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Submitted by: ${item['assignee']?['fullName'] ?? "Staff"} • ${item['project']?['name'] ?? ""}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Return for Changes',
              onPressed: () async {
                await ref.read(tasksRepositoryProvider).updateTaskStatus(item['id'], 'RETURNED', notes: 'Needs revision');
                ref.invalidate(myWorkSummaryProvider);
              },
            ),
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppTheme.success),
              tooltip: 'Approve & Complete',
              onPressed: () async {
                await ref.read(tasksRepositoryProvider).updateTaskStatus(item['id'], 'COMPLETED', notes: 'Approved');
                ref.invalidate(myWorkSummaryProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, WidgetRef ref, dynamic t) {
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(t['title'] ?? ''),
        subtitle: Text('Priority: ${t['priority']} • Status: ${t['status']}'),
        trailing: t['status'] == 'ASSIGNED'
            ? ElevatedButton(
                onPressed: () async {
                  await ref.read(tasksRepositoryProvider).updateTaskStatus(t['id'], 'ACCEPTED');
                  ref.invalidate(myWorkSummaryProvider);
                },
                child: const Text('Accept'),
              )
            : t['status'] == 'ACCEPTED'
                ? ElevatedButton(
                    onPressed: () async {
                      await ref.read(tasksRepositoryProvider).updateTaskStatus(t['id'], 'IN_PROGRESS');
                      ref.invalidate(myWorkSummaryProvider);
                    },
                    child: const Text('Start'),
                  )
                : t['status'] == 'IN_PROGRESS'
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
                        onPressed: () async {
                          await ref.read(tasksRepositoryProvider).updateTaskStatus(t['id'], 'REVIEW');
                          ref.invalidate(myWorkSummaryProvider);
                        },
                        child: const Text('Submit'),
                      )
                    : null,
      ),
    );
  }

  Widget _buildProjectItem(BuildContext context, dynamic p) {
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.go('/projects/${p['id']}'),
        leading: const Icon(Icons.folder, color: AppTheme.primary),
        title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Tasks: ${p['_count']?['tasks'] ?? 0} • Members: ${p['_count']?['members'] ?? 0}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }
}
