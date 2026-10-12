import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/features/tasks/data/tasks_repository.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;

  const TaskDetailPage({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _task;
  bool _isLoading = true;
  String? _error;
  final _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTask();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(tasksRepositoryProvider);
      final data = await repo.getTaskDetail(widget.taskId);
      setState(() {
        _task = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _updateStatus(String status, {String? notes}) async {
    try {
      await ref
          .read(tasksRepositoryProvider)
          .updateTaskStatus(widget.taskId, status, notes: notes);
      ref.invalidate(allTasksProvider(null));
      ref.invalidate(myTasksProvider);
      _loadTask();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task status updated to $status')),
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

  Future<void> _submitComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    setState(() => _isSubmittingComment = true);
    try {
      await ref
          .read(tasksRepositoryProvider)
          .addComment(widget.taskId, comment);
      _commentController.clear();
      _loadTask();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  void _showReturnDialog() {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return Task for Changes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provide feedback on what needs modification:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Dimensions do not match customer specification...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus('RETURNED', notes: notesController.text.trim());
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Return Task'),
          ),
        ],
      ),
    );
  }

  void _showSubmitReviewDialog() {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Task for Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Completion summary or test results:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Wiring completed, dielectric test passed, photos uploaded...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus('REVIEW', notes: notesController.text.trim());
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white),
            child: const Text('Submit for Review'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'IN_PROGRESS':
        return AppTheme.primary;
      case 'REVIEW':
        return AppTheme.warning;
      case 'COMPLETED':
        return AppTheme.success;
      case 'RETURNED':
        return Colors.red;
      case 'ACCEPTED':
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'MEDIUM':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task Detail')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Error: ${_error ?? "Task not found"}',
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _loadTask, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final task = _task!;
    final taskNumber = task['taskNumber'] ?? 'TSK';
    final title = task['title'] ?? '';
    final description = task['description'] ?? 'No description provided.';
    final status = task['status'] ?? 'CREATED';
    final priority = task['priority'] ?? 'MEDIUM';
    final progress = task['progress'] ?? 0;
    final estimatedHours = task['estimatedHours'] ?? 0;
    final actualHours = task['actualHours'] ?? 0;

    final project = task['project'] as Map<String, dynamic>?;
    final team = task['team'] is Map
        ? Map<String, dynamic>.from(task['team'] as Map)
        : null;
    final assignee = task['assignee'] as Map<String, dynamic>?;
    final creator = task['creator'] as Map<String, dynamic>?;
    final department = task['department'] as Map<String, dynamic>?;
    final comments = (task['comments'] as List<dynamic>? ?? []);
    final activities = (task['activities'] as List<dynamic>? ?? []);

    final isAssignee =
        user?.staffId != null && task['assigneeStaffId'] == user!.staffId;
    final currentStaffId = user?.staffId;
    final teamRole = team == null || currentStaffId == null
        ? null
        : (team['leaderStaffId'] == currentStaffId ||
                (team['leader'] as Map?)?['id'] == currentStaffId)
            ? 'Team Leader'
            : (team['members'] as List? ?? []).whereType<Map>().any(
                    (membership) =>
                        (membership['staff'] as Map?)?['id'] == currentStaffId)
                ? 'Team Member'
                : 'Team Assignment';
    final canManage = user?.isProjectManager == true ||
        user?.isAdmin == true ||
        teamRole == 'Team Leader';

    DateTime? dueDate;
    if (task['dueDate'] != null) {
      dueDate = DateTime.tryParse(task['dueDate'].toString());
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(taskNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _loadTask,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          tabs: [
            const Tab(icon: Icon(Icons.info_outline), text: 'Overview'),
            Tab(
                icon: const Icon(Icons.forum_outlined),
                text: 'Comments (${comments.length})'),
            Tab(
                icon: const Icon(Icons.history),
                text: 'Activity (${activities.length})'),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionBottomBar(status, isAssignee, canManage),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview Tab
          _buildOverviewTab(
            title: title,
            description: description,
            status: status,
            priority: priority,
            progress: progress,
            estimatedHours: estimatedHours,
            actualHours: actualHours,
            dueDate: dueDate,
            project: project,
            team: team,
            teamRole: teamRole,
            assignee: assignee,
            creator: creator,
            department: department,
          ),
          // Comments Tab
          _buildCommentsTab(comments),
          // Activity Tab
          _buildActivityTab(activities),
        ],
      ),
    );
  }

  Widget? _buildActionBottomBar(
      String status, bool isAssignee, bool canManage) {
    final actions = <Widget>[];

    if (isAssignee && status == 'ASSIGNED') {
      actions.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Accept Task'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          onPressed: () => _updateStatus('ACCEPTED'),
        ),
      );
    }

    if (isAssignee && status == 'ACCEPTED') {
      actions.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow_outlined, size: 18),
          label: const Text('Start Work'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          onPressed: () => _updateStatus('IN_PROGRESS'),
        ),
      );
    }

    if (isAssignee && (status == 'IN_PROGRESS' || status == 'RETURNED')) {
      actions.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.send_outlined, size: 18),
          label: const Text('Submit for Review'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning, foregroundColor: Colors.white),
          onPressed: _showSubmitReviewDialog,
        ),
      );
    }

    if (canManage && status == 'REVIEW') {
      actions.add(
        OutlinedButton.icon(
          icon: const Icon(Icons.undo, size: 18, color: Colors.red),
          label: const Text('Return for Changes',
              style: TextStyle(color: Colors.red)),
          onPressed: _showReturnDialog,
        ),
      );
      actions.add(const SizedBox(width: 12));
      actions.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.verified, size: 18),
          label: const Text('Approve & Complete'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success, foregroundColor: Colors.white),
          onPressed: () =>
              _updateStatus('COMPLETED', notes: 'Approved by Manager'),
        ),
      );
    }

    if (actions.isEmpty) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: const Border(top: BorderSide(color: AppTheme.darkBorder)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: actions,
      ),
    );
  }

  Widget _buildOverviewTab({
    required String title,
    required String description,
    required String status,
    required String priority,
    required int progress,
    required dynamic estimatedHours,
    required dynamic actualHours,
    required DateTime? dueDate,
    required Map<String, dynamic>? project,
    required Map<String, dynamic>? team,
    required String? teamRole,
    required Map<String, dynamic>? assignee,
    required Map<String, dynamic>? creator,
    required Map<String, dynamic>? department,
  }) {
    final statusColor = _getStatusColor(status);
    final priorityColor = _getPriorityColor(priority);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: priorityColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                      color: priorityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Progress Completion',
                        style: TextStyle(
                            color: AppTheme.darkText,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                    Text('$progress%',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress / 100.0,
                    minHeight: 10,
                    backgroundColor: AppTheme.darkBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Metadata Grid Cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (project != null)
                _buildInfoCard(
                  Icons.folder_outlined,
                  'Project',
                  project['name'] ?? '',
                  subtitle: project['projectNumber'],
                  onTap: () => context.go('/projects/${project['id']}'),
                ),
              if (team != null)
                _buildInfoCard(
                  Icons.groups_outlined,
                  'Team',
                  team['name']?.toString() ?? 'Team',
                  subtitle: teamRole ?? 'Team assignment',
                ),
              _buildInfoCard(
                Icons.person_outline,
                'Assignee',
                assignee?['fullName'] ?? 'Unassigned',
                subtitle: assignee?['designation']?['name'] ??
                    assignee?['employeeId'],
              ),
              _buildInfoCard(
                Icons.calendar_today_outlined,
                'Due Date',
                dueDate != null
                    ? DateFormat('dd MMM yyyy').format(dueDate)
                    : 'No due date',
                subtitle: dueDate != null
                    ? (DateUtils.dateOnly(dueDate)
                            .isBefore(DateUtils.dateOnly(DateTime.now()))
                        ? 'OVERDUE'
                        : 'Scheduled')
                    : null,
                alert: dueDate != null &&
                    DateUtils.dateOnly(dueDate)
                        .isBefore(DateUtils.dateOnly(DateTime.now())),
              ),
              _buildInfoCard(
                Icons.timer_outlined,
                'Work Hours',
                '$actualHours / $estimatedHours hrs',
                subtitle: 'Actual vs Estimated',
              ),
              if (department != null)
                _buildInfoCard(
                  Icons.corporate_fare_outlined,
                  'Department',
                  department['name'] ?? '',
                ),
              _buildInfoCard(
                Icons.history_edu_outlined,
                'Created By',
                creator?['fullName'] ?? 'System',
                subtitle: creator?['employeeId'],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Description Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notes,
                        size: 20, color: AppTheme.darkTextSecondary),
                    SizedBox(width: 8),
                    Text('Task Specifications & Notes',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.darkTextSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value,
      {String? subtitle, VoidCallback? onTap, bool alert = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: alert ? Colors.red.shade300 : AppTheme.darkBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (alert ? Colors.red : AppTheme.primary)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  size: 20, color: alert ? Colors.red : AppTheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.darkTextSecondary,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                        color: AppTheme.darkText,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: alert ? Colors.red : AppTheme.darkTextSecondary,
                        fontWeight: alert ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsTab(List<dynamic> comments) {
    return Column(
      children: [
        Expanded(
          child: comments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.forum_outlined,
                          size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No comments yet',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkText)),
                      const SizedBox(height: 4),
                      const Text('Start a collaboration thread below',
                          style: TextStyle(
                              color: AppTheme.darkTextSecondary, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final c = comments[index] as Map<String, dynamic>;
                    final staff = c['staff'] as Map<String, dynamic>?;
                    final author = staff?['fullName'] ?? 'Staff Member';
                    final initial = author.isNotEmpty ? author[0] : 'S';
                    final text = c['comment'] ?? '';
                    DateTime? time;
                    if (c['createdAt'] != null) {
                      time = DateTime.tryParse(c['createdAt'].toString());
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  AppTheme.primary.withValues(alpha: 0.15),
                              child: Text(initial,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(author,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      if (time != null)
                                        Text(
                                            DateFormat('dd MMM, hh:mm a')
                                                .format(time),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme
                                                    .darkTextSecondary)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(text,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.darkTextSecondary,
                                          height: 1.3)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppTheme.darkSurface,
            border: Border(top: BorderSide(color: AppTheme.darkBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: 'Add an update, test result or query...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: _isSubmittingComment
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, size: 18),
                label: const Text('Post'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: _isSubmittingComment ? null : _submitComment,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab(List<dynamic> activities) {
    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off,
                size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('No activity log recorded yet',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.darkText)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final act = activities[index] as Map<String, dynamic>;
        final staff = act['staff'] as Map<String, dynamic>?;
        final actor = staff?['fullName'] ?? 'System';
        final action = act['action'] ?? 'UPDATED';
        final oldValue = act['oldValue'];
        final newValue = act['newValue'];
        DateTime? time;
        if (act['createdAt'] != null) {
          time = DateTime.tryParse(act['createdAt'].toString());
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppTheme.darkBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.change_circle_outlined,
                    size: 20, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$actor performed $action',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      if (oldValue != null || newValue != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${oldValue != null ? "$oldValue → " : ""}$newValue',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.darkTextSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (time != null)
                  Text(
                    DateFormat('dd MMM, hh:mm a').format(time),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.darkTextSecondary),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
