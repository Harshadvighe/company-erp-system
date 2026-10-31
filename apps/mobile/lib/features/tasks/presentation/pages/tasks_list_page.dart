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

enum TaskViewMode { list, kanban }
enum TaskScopeFilter { all, myTasks, assignedByMe, overdue }
enum TaskSortBy { dueDate, priority, progress, newest }

class TasksListPage extends ConsumerStatefulWidget {
  const TasksListPage({super.key});

  @override
  ConsumerState<TasksListPage> createState() => _TasksListPageState();
}

class _TasksListPageState extends ConsumerState<TasksListPage> {
  TaskViewMode _viewMode = TaskViewMode.list;
  TaskScopeFilter _scopeFilter = TaskScopeFilter.all;
  String _selectedStatus = 'ALL';
  String _selectedPriority = 'ALL';
  TaskSortBy _sortBy = TaskSortBy.dueDate;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final allTasksAsync = ref.watch(allTasksProvider(null));

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.task_alt, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Task Manager', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Workforce & Project Tracking', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          // View Mode Switcher: List vs Kanban
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewToggleButton(
                  icon: Icons.view_agenda_outlined,
                  label: 'List',
                  isSelected: _viewMode == TaskViewMode.list,
                  onTap: () => setState(() => _viewMode = TaskViewMode.list),
                ),
                _buildViewToggleButton(
                  icon: Icons.view_kanban_outlined,
                  label: 'Kanban',
                  isSelected: _viewMode == TaskViewMode.kanban,
                  onTap: () => setState(() => _viewMode = TaskViewMode.kanban),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh tasks',
            onPressed: () {
              ref.invalidate(allTasksProvider(null));
              ref.invalidate(myTasksProvider);
              ref.invalidate(taskStatsProvider);
            },
          ),
          if (user?.staffId != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showCreateTaskDialog(context),
              ),
            ),
        ],
      ),
      body: allTasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Error loading tasks: $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(allTasksProvider(null)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (allTasks) {
          final stats = _computeTaskStats(allTasks, user?.staffId);
          final filteredTasks = _filterAndSortTasks(allTasks, user);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. KPI Analytics Summary Bar
              _buildKpiMetricsBar(stats),

              // 2. Search & Filter Bar
              _buildFilterAndSearchBar(allTasks.length, filteredTasks.length),

              // 3. Main View: List or Kanban
              Expanded(
                child: _viewMode == TaskViewMode.list
                    ? _buildListView(filteredTasks, user)
                    : _buildKanbanView(filteredTasks, user),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 1. KPI SUMMARY METRICS ─────────────────────────────────────────────

  Map<String, dynamic> _computeTaskStats(List<TaskItem> tasks, String? staffId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final total = tasks.length;
    final completed = tasks.where((t) => t.status == 'COMPLETED').length;
    final inProgress = tasks
        .where((t) => ['IN_PROGRESS', 'PENDING', 'ACCEPTED'].contains(t.status))
        .length;
    final inReview = tasks.where((t) => ['REVIEW', 'RETURNED'].contains(t.status)).length;
    final overdue = tasks.where((t) {
      if (t.status == 'COMPLETED' || t.status == 'CANCELLED' || t.dueDate == null) {
        return false;
      }
      final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return due.isBefore(today);
    }).length;

    final completionRate = total > 0 ? ((completed / total) * 100).round() : 0;

    return {
      'total': total,
      'inProgress': inProgress,
      'inReview': inReview,
      'completed': completed,
      'overdue': overdue,
      'completionRate': completionRate,
    };
  }

  Widget _buildKpiMetricsBar(Map<String, dynamic> stats) {
    final overdueCount = stats['overdue'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final cards = [
            _buildMetricCard(
              title: 'Total Tasks',
              value: stats['total'].toString(),
              icon: Icons.all_inbox_rounded,
              color: Colors.blue,
              isActive: _scopeFilter == TaskScopeFilter.all && _selectedStatus == 'ALL',
              onTap: () => setState(() {
                _scopeFilter = TaskScopeFilter.all;
                _selectedStatus = 'ALL';
              }),
            ),
            _buildMetricCard(
              title: 'In Progress',
              value: stats['inProgress'].toString(),
              icon: Icons.trending_up_rounded,
              color: AppTheme.primary,
              isActive: _selectedStatus == 'IN_PROGRESS',
              onTap: () => setState(() => _selectedStatus = 'IN_PROGRESS'),
            ),
            _buildMetricCard(
              title: 'Under Review',
              value: stats['inReview'].toString(),
              icon: Icons.assignment_late_outlined,
              color: AppTheme.warning,
              isActive: _selectedStatus == 'REVIEW',
              onTap: () => setState(() => _selectedStatus = 'REVIEW'),
            ),
            _buildMetricCard(
              title: 'Completed',
              value: '${stats['completed']} (${stats['completionRate']}%)',
              icon: Icons.task_alt,
              color: AppTheme.success,
              isActive: _selectedStatus == 'COMPLETED',
              onTap: () => setState(() => _selectedStatus = 'COMPLETED'),
            ),
            _buildMetricCard(
              title: 'Overdue Deadline',
              value: overdueCount.toString(),
              icon: Icons.warning_amber_rounded,
              color: overdueCount > 0 ? Colors.redAccent : Colors.teal,
              isAlert: overdueCount > 0,
              isActive: _scopeFilter == TaskScopeFilter.overdue,
              onTap: () => setState(() => _scopeFilter = TaskScopeFilter.overdue),
            ),
          ];

          if (isWide) {
            return Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            );
          } else {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    cards[i],
                  ],
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isAlert = false,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minWidth: 135),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : (isAlert ? color.withValues(alpha: 0.5) : AppTheme.darkBorder),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isAlert ? Colors.redAccent : Colors.white,
                    ),
                  ),
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? color : Colors.white60,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2. SEARCH & FILTER TOOLBAR ──────────────────────────────────────────

  Widget _buildFilterAndSearchBar(int totalCount, int filteredCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search row + Sort selector
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search tasks by title, code (TSK-...), project, or assignee...',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.darkBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppTheme.darkBorder),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Sort Menu
              PopupMenuButton<TaskSortBy>(
                initialValue: _sortBy,
                tooltip: 'Sort tasks',
                onSelected: (sort) => setState(() => _sortBy = sort),
                color: AppTheme.darkSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: TaskSortBy.dueDate,
                    child: Text('📅 Due Date (Urgent First)'),
                  ),
                  const PopupMenuItem(
                    value: TaskSortBy.priority,
                    child: Text('⚡ Priority (Critical First)'),
                  ),
                  const PopupMenuItem(
                    value: TaskSortBy.progress,
                    child: Text('📈 Progress (High to Low)'),
                  ),
                  const PopupMenuItem(
                    value: TaskSortBy.newest,
                    child: Text('🕒 Recently Created'),
                  ),
                ],
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sort, size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      Text(
                        _getSortLabel(_sortBy),
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Filters Row: Scope pills + Priority chips + Status chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Scope Filter Pills
                _buildScopeChip(TaskScopeFilter.all, 'All Tasks'),
                _buildScopeChip(TaskScopeFilter.myTasks, 'My Assigned'),
                _buildScopeChip(TaskScopeFilter.assignedByMe, 'Assigned by Me'),
                _buildScopeChip(TaskScopeFilter.overdue, '⚠️ Overdue'),

                const SizedBox(width: 12),

                // Priority Filter Dropdown/Menu
                PopupMenuButton<String>(
                  initialValue: _selectedPriority,
                  tooltip: 'Filter by priority',
                  onSelected: (val) => setState(() => _selectedPriority = val),
                  color: AppTheme.darkSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'ALL', child: Text('All Priorities')),
                    const PopupMenuItem(value: 'CRITICAL', child: Text('🔴 Critical')),
                    const PopupMenuItem(value: 'HIGH', child: Text('🟠 High')),
                    const PopupMenuItem(value: 'MEDIUM', child: Text('🔵 Medium')),
                    const PopupMenuItem(value: 'LOW', child: Text('⚪ Low')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedPriority != 'ALL'
                          ? _getPriorityColor(_selectedPriority).withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _selectedPriority != 'ALL'
                            ? _getPriorityColor(_selectedPriority)
                            : AppTheme.darkBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedPriority == 'ALL'
                              ? 'Priority: All'
                              : 'Priority: $_selectedPriority',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _selectedPriority != 'ALL'
                                ? _getPriorityColor(_selectedPriority)
                                : Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white70),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Status Chips
                ...['ALL', 'CREATED', 'ASSIGNED', 'IN_PROGRESS', 'REVIEW', 'COMPLETED']
                    .map((status) {
                  final isSelected = _selectedStatus == status;
                  final label = status == 'ALL'
                      ? 'All Statuses'
                      : (status == 'CREATED' ? 'Not Started' : status.replaceAll('_', ' '));
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: FilterChip(
                      label: Text(label, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      visualDensity: VisualDensity.compact,
                      onSelected: (val) => setState(() => _selectedStatus = status),
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      selectedColor: AppTheme.primary.withValues(alpha: 0.25),
                      checkmarkColor: AppTheme.primary,
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : AppTheme.darkBorder,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeChip(TaskScopeFilter scope, String label) {
    final isSelected = _scopeFilter == scope;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
        selected: isSelected,
        visualDensity: VisualDensity.compact,
        selectedColor: scope == TaskScopeFilter.overdue ? Colors.redAccent : AppTheme.primary,
        backgroundColor: Colors.white.withValues(alpha: 0.05),
        side: BorderSide(
          color: isSelected
              ? (scope == TaskScopeFilter.overdue ? Colors.redAccent : AppTheme.primary)
              : AppTheme.darkBorder,
        ),
        onSelected: (selected) {
          if (selected) setState(() => _scopeFilter = scope);
        },
      ),
    );
  }

  String _getSortLabel(TaskSortBy sort) {
    switch (sort) {
      case TaskSortBy.dueDate:
        return 'Due Date';
      case TaskSortBy.priority:
        return 'Priority';
      case TaskSortBy.progress:
        return 'Progress';
      case TaskSortBy.newest:
        return 'Newest';
    }
  }

  // ─── 3. FILTER & SORT LOGIC ──────────────────────────────────────────────

  List<TaskItem> _filterAndSortTasks(List<TaskItem> tasks, AuthUser? user) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final staffId = user?.staffId;

    var list = tasks.where((t) {
      // Scope Filter
      if (_scopeFilter == TaskScopeFilter.myTasks && t.assigneeStaffId != staffId) {
        return false;
      }
      if (_scopeFilter == TaskScopeFilter.assignedByMe &&
          t.assignedByStaffId != staffId &&
          t.createdByStaffId != staffId) {
        return false;
      }
      if (_scopeFilter == TaskScopeFilter.overdue) {
        if (t.status == 'COMPLETED' || t.status == 'CANCELLED' || t.dueDate == null) {
          return false;
        }
        final due = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        if (!due.isBefore(today)) return false;
      }

      // Status Filter
      if (_selectedStatus != 'ALL' && t.status != _selectedStatus) {
        return false;
      }

      // Priority Filter
      if (_selectedPriority != 'ALL' && t.priority != _selectedPriority) {
        return false;
      }

      // Search Query
      if (_searchQuery.isNotEmpty) {
        final title = t.title.toLowerCase();
        final code = t.taskNumber.toLowerCase();
        final project = (t.projectName ?? '').toLowerCase();
        final assignee = (t.assigneeName ?? '').toLowerCase();
        if (!title.contains(_searchQuery) &&
            !code.contains(_searchQuery) &&
            !project.contains(_searchQuery) &&
            !assignee.contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sorting
    list.sort((a, b) {
      switch (_sortBy) {
        case TaskSortBy.dueDate:
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);

        case TaskSortBy.priority:
          return _priorityWeight(b.priority).compareTo(_priorityWeight(a.priority));

        case TaskSortBy.progress:
          return b.progress.compareTo(a.progress);

        case TaskSortBy.newest:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return list;
  }

  int _priorityWeight(String p) {
    switch (p.toUpperCase()) {
      case 'CRITICAL':
        return 4;
      case 'HIGH':
        return 3;
      case 'MEDIUM':
        return 2;
      case 'LOW':
        return 1;
      default:
        return 0;
    }
  }

  // ─── 4. LIST VIEW ────────────────────────────────────────────────────────

  Widget _buildListView(List<TaskItem> tasks, AuthUser? user) {
    if (tasks.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildModernTaskCard(task, user);
      },
    );
  }

  // ─── 5. KANBAN BOARD VIEW ────────────────────────────────────────────────

  Widget _buildKanbanView(List<TaskItem> tasks, AuthUser? user) {
    final todoTasks = tasks
        .where((t) => ['CREATED', 'ASSIGNED', 'ACCEPTED'].contains(t.status))
        .toList();
    final inProgressTasks = tasks
        .where((t) => ['IN_PROGRESS', 'PENDING'].contains(t.status))
        .toList();
    final reviewTasks = tasks
        .where((t) => ['REVIEW', 'RETURNED'].contains(t.status))
        .toList();
    final completedTasks = tasks.where((t) => t.status == 'COMPLETED').toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth > 1200)
            ? (constraints.maxWidth - 50) / 4
            : 320.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKanbanColumn(
                title: 'To Do',
                subtitle: 'Assigned / Backlog',
                color: Colors.blueGrey,
                icon: Icons.checklist_rtl_rounded,
                tasks: todoTasks,
                user: user,
                width: columnWidth,
              ),
              const SizedBox(width: 12),
              _buildKanbanColumn(
                title: 'In Progress',
                subtitle: 'Active Execution',
                color: AppTheme.primary,
                icon: Icons.play_circle_fill_rounded,
                tasks: inProgressTasks,
                user: user,
                width: columnWidth,
              ),
              const SizedBox(width: 12),
              _buildKanbanColumn(
                title: 'Under Review',
                subtitle: 'Awaiting Sign-off',
                color: AppTheme.warning,
                icon: Icons.assignment_late_rounded,
                tasks: reviewTasks,
                user: user,
                width: columnWidth,
              ),
              const SizedBox(width: 12),
              _buildKanbanColumn(
                title: 'Completed',
                subtitle: 'Approved & Delivered',
                color: AppTheme.success,
                icon: Icons.task_alt_rounded,
                tasks: completedTasks,
                user: user,
                width: columnWidth,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanColumn({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required List<TaskItem> tasks,
    required AuthUser? user,
    required double width,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.25))),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cards list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 600),
            child: tasks.isEmpty
                ? Container(
                    height: 120,
                    alignment: Alignment.center,
                    child: Text(
                      'No tasks in $title',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: tasks.length,
                    itemBuilder: (context, i) => _buildKanbanCard(tasks[i], user),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanCard(TaskItem task, AuthUser? user) {
    final isOverdue = _isTaskOverdue(task);
    final priorityColor = _getPriorityColor(task.priority);

    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(
          color: isOverdue ? Colors.redAccent.withValues(alpha: 0.7) : AppTheme.darkBorder,
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.go('/tasks/${task.id}'),
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header tag: Task code + Priority Dot + Context Action Menu
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.taskNumber,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.priority,
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _buildQuickActionMenu(task, user),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),

              if (task.projectName != null || task.milestoneTitle != null) ...[
                const SizedBox(height: 5),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    if (task.projectName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_outlined, size: 10, color: Colors.blueAccent),
                            const SizedBox(width: 3),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: Text(
                                task.projectName!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Colors.blueAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (task.milestoneTitle != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flag_outlined, size: 10, color: Colors.tealAccent),
                            const SizedBox(width: 3),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
                              child: Text(
                                task.milestoneTitle!,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Colors.tealAccent),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 6),

              // Assigner -> Assignee delegation row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.outbox_rounded, size: 10, color: Colors.purpleAccent),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'From: ${task.assignerName ?? task.creatorName ?? "System"}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 9, color: Colors.white24),
                    const SizedBox(width: 4),
                    const Icon(Icons.inbox_rounded, size: 10, color: AppTheme.primary),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'To: ${task.assigneeName ?? "Queue"}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Hours badge & Progress Mini Bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: task.progress.clamp(0, 100) / 100.0,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          task.progress == 100 ? AppTheme.success : AppTheme.primary,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${task.progress}%',
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${task.actualHours.toStringAsFixed(1)}h/${task.estimatedHours.toStringAsFixed(1)}h',
                      style: const TextStyle(fontSize: 9, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Footer: Assignee & Due Date
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.25),
                    child: Text(
                      task.assigneeName?.isNotEmpty == true ? task.assigneeName![0] : '?',
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.assigneeName ?? 'Unassigned',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ),
                  if (task.dueDate != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOverdue ? Colors.red.withValues(alpha: 0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                        border: isOverdue ? Border.all(color: Colors.redAccent, width: 0.8) : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOverdue ? Icons.warning_amber_rounded : Icons.schedule,
                            size: 11,
                            color: isOverdue ? Colors.redAccent : Colors.grey,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _formatDueDate(task.dueDate!),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                              color: isOverdue ? Colors.redAccent : Colors.grey,
                            ),
                          ),
                        ],
                      ),
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

  // ─── 6. MODERN TASK CARD (LIST VIEW) ─────────────────────────────────────

  Widget _buildModernTaskCard(TaskItem task, AuthUser? user) {
    final priorityColor = _getPriorityColor(task.priority);
    final isOverdue = _isTaskOverdue(task);

    final isAssignee = user?.staffId != null && task.assigneeStaffId == user!.staffId;
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue ? Colors.redAccent.withValues(alpha: 0.5) : AppTheme.darkBorder,
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.go('/tasks/${task.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Code, Priority, Due Date alert, Status Pill, Menu
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      task.taskNumber,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          task.priority,
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isOverdue) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 12, color: Colors.redAccent),
                          SizedBox(width: 3),
                          Text(
                            'OVERDUE',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  _buildStatusChip(task.status),
                  const SizedBox(width: 4),
                  _buildQuickActionMenu(task, user),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              Text(
                task.title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),

              if (task.description?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],

              const SizedBox(height: 10),

              // Delegation Block: From (Issuer) -> To (Assignee)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    // From (Issuer)
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.outbox_rounded, size: 14, color: Colors.purpleAccent),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('FROM (ISSUER)', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text(
                                  task.assignerName ?? task.creatorName ?? 'System',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                if (task.assignerDesignation != null || task.creatorDesignation != null)
                                  Text(
                                    task.assignerDesignation ?? task.creatorDesignation!,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 32, color: Colors.white12),
                    const SizedBox(width: 10),
                    // To (Assignee)
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.inbox_rounded, size: 14, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TO (ASSIGNEE)', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                Text(
                                  task.assigneeName ?? 'Unassigned / Queue',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                if (task.assigneeDesignation != null || task.assigneeDepartment != null)
                                  Text(
                                    [task.assigneeDesignation, task.assigneeDepartment].whereType<String>().join(' · '),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (task.projectName != null || task.milestoneTitle != null || task.teamName != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (task.projectName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder_outlined, size: 11, color: Colors.blueAccent),
                            const SizedBox(width: 4),
                            Text(
                              task.projectNumber != null
                                  ? '${task.projectNumber} · ${task.projectName}'
                                  : task.projectName!,
                              style: const TextStyle(fontSize: 10, color: Colors.blueAccent),
                            ),
                          ],
                        ),
                      ),
                    if (task.milestoneTitle != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flag_outlined, size: 11, color: Colors.tealAccent),
                            const SizedBox(width: 4),
                            Text(
                              task.milestoneTitle!,
                              style: const TextStyle(fontSize: 10, color: Colors.tealAccent),
                            ),
                          ],
                        ),
                      ),
                    if (task.teamName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.groups_outlined, size: 11, color: Colors.indigoAccent),
                            const SizedBox(width: 4),
                            Text(
                              task.teamName!,
                              style: const TextStyle(fontSize: 10, color: Colors.indigoAccent),
                            ),
                          ],
                        ),
                      ),
                    // Hours badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_filled, size: 10, color: Colors.amberAccent),
                          const SizedBox(width: 4),
                          Text(
                            '${task.actualHours.toStringAsFixed(1)}h / ${task.estimatedHours.toStringAsFixed(1)}h logged',
                            style: const TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // Due Date row
              Row(
                children: [
                  const Spacer(),
                  if (task.dueDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOverdue ? Colors.red.withValues(alpha: 0.15) : Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOverdue ? Icons.alarm_on : Icons.calendar_today_outlined,
                            size: 13,
                            color: isOverdue ? Colors.redAccent : Colors.grey,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Due: ${_formatDueDate(task.dueDate!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isOverdue ? Colors.redAccent : Colors.grey,
                              fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Interactive Progress Bar (Tap to slide progress!)
              InkWell(
                onTap: () => _showQuickProgressDialog(task),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('Completion Progress',
                              style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const Spacer(),
                          Text(
                            '${task.progress}%  (tap to update)',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Contextual Action Buttons Row
              Row(
                children: [
                  // Log hours button
                  TextButton.icon(
                    onPressed: () => _showLogHoursDialog(task),
                    icon: const Icon(Icons.timer_outlined, size: 14),
                    label: Text('${task.actualHours} / ${task.estimatedHours} hrs',
                        style: const TextStyle(fontSize: 11)),
                  ),
                  const Spacer(),

                  if (canWorkTask && task.status == 'ASSIGNED')
                    ElevatedButton(
                      onPressed: () => _updateStatus(task.id, 'ACCEPTED'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      child: const Text('Accept Task'),
                    ),
                  if (canWorkTask && task.status == 'ACCEPTED')
                    ElevatedButton(
                      onPressed: () => _updateStatus(task.id, 'IN_PROGRESS'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      child: const Text('Start Work'),
                    ),
                  if (canWorkTask &&
                      (task.status == 'IN_PROGRESS' ||
                          task.status == 'PENDING' ||
                          task.status == 'RETURNED')) ...[
                    OutlinedButton(
                      onPressed: () => _updateStatus(
                        task.id,
                        task.status == 'IN_PROGRESS' ? 'PENDING' : 'IN_PROGRESS',
                      ),
                      child: Text(task.status == 'IN_PROGRESS' ? 'Pause' : 'Resume'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _updateStatus(
                        task.id,
                        'REVIEW',
                        notes: 'Submitted for managerial review',
                      ),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
                      child: const Text('Submit for Review'),
                    ),
                  ],
                  if (canManage && task.status == 'REVIEW') ...[
                    OutlinedButton(
                      onPressed: () => _updateStatus(task.id, 'RETURNED',
                          notes: 'Returned for revisions by manager'),
                      child: const Text('Return'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () =>
                          _updateStatus(task.id, 'COMPLETED', notes: 'Approved by Manager'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
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

  Widget _buildQuickActionMenu(TaskItem task, AuthUser? user) {
    final isAdmin = user?.isAdmin == true;
    final isCreator = task.createdByStaffId == user?.staffId || task.assignedByStaffId == user?.staffId;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
      tooltip: 'Task options',
      color: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (action) {
        if (action == 'VIEW') context.go('/tasks/${task.id}');
        if (action == 'PROGRESS') _showQuickProgressDialog(task);
        if (action == 'LOG_HOURS') _showLogHoursDialog(task);
        if (action == 'DELETE') _confirmDeleteTask(task);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'VIEW',
          child: Row(
            children: [
              Icon(Icons.open_in_new, size: 16, color: Colors.white70),
              SizedBox(width: 8),
              Text('View Details'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'PROGRESS',
          child: Row(
            children: [
              Icon(Icons.tune, size: 16, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('Update Progress'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'LOG_HOURS',
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: Colors.teal),
              SizedBox(width: 8),
              Text('Log Work Hours'),
            ],
          ),
        ),
        if (isAdmin || isCreator) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'DELETE',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                SizedBox(width: 8),
                Text('Delete Task', style: TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ─── 7. MODALS & INTERACTIVE OPERATIONS ──────────────────────────────────

  void _showQuickProgressDialog(TaskItem task) {
    var newProgress = task.progress.toDouble();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Update Progress: ${task.taskNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${newProgress.round()}%',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 14),
              Slider(
                value: newProgress,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: AppTheme.primary,
                label: '${newProgress.round()}%',
                onChanged: (val) => setDialogState(() => newProgress = val),
              ),
              const SizedBox(height: 8),
              // Preset buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [0, 25, 50, 75, 100].map((preset) {
                  return InkWell(
                    onTap: () => setDialogState(() => newProgress = preset.toDouble()),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: newProgress.round() == preset
                            ? AppTheme.primary
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$preset%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: newProgress.round() == preset ? Colors.white : Colors.white70,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final rounded = newProgress.round();
                Navigator.pop(ctx);
                try {
                  await ref
                      .read(tasksRepositoryProvider)
                      .updateTaskProgress(task.id, rounded);
                  ref.invalidate(allTasksProvider(null));
                  ref.invalidate(myTasksProvider);
                  ref.invalidate(taskStatsProvider);
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('✅ Progress set to $rounded%'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save Progress'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogHoursDialog(TaskItem task) {
    final hoursController = TextEditingController(text: '1.0');
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Log Work Hours (${task.taskNumber})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current: ${task.actualHours} hrs logged (Est: ${task.estimatedHours} hrs)',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: hoursController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Hours spent (e.g. 2.5) *',
                prefixIcon: Icon(Icons.timer),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Activity notes (optional)',
                hintText: 'e.g. Completed wiring and panel load tests',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final h = double.tryParse(hoursController.text.trim());
              if (h == null || h <= 0) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Please enter valid positive hours')),
                );
                return;
              }
              final notes = notesController.text.trim();
              Navigator.pop(ctx);
              try {
                await ref.read(tasksRepositoryProvider).logWorkHours(
                      task.id,
                      h,
                      notes: notes,
                    );
                ref.invalidate(allTasksProvider(null));
                ref.invalidate(myTasksProvider);
                ref.invalidate(taskStatsProvider);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('✅ Logged $h hours successfully!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Log Hours'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTask(TaskItem task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text('Delete ${task.taskNumber}?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete task "${task.title}"? All associated comments and activity logs will also be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await ref.read(tasksRepositoryProvider).deleteTask(task.id);
                ref.invalidate(allTasksProvider(null));
                ref.invalidate(myTasksProvider);
                ref.invalidate(taskStatsProvider);
                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('✅ Task deleted successfully'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete Task'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String taskId, String status, {String? notes}) async {
    try {
      await ref.read(tasksRepositoryProvider).updateTaskStatus(taskId, status, notes: notes);
      ref.invalidate(allTasksProvider(null));
      ref.invalidate(myTasksProvider);
      ref.invalidate(myWorkSummaryProvider);
      ref.invalidate(taskStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Task moved to ${status.replaceAll('_', ' ')}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── 8. CREATE TASK MODAL (PRESERVED TEAMS & DEPARTMENTS LOGIC) ──────────

  void _showCreateTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _CreateTaskModalDialog(),
    );
  }

  // ─── 9. HELPERS & FORMATTING ─────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.task_alt, size: 54, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            'No matching tasks found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try adjusting your search query, scope, or status filters.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.filter_alt_off),
            label: const Text('Reset Filters'),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _scopeFilter = TaskScopeFilter.all;
                _selectedStatus = 'ALL';
                _selectedPriority = 'ALL';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    if (status == 'IN_PROGRESS') color = AppTheme.primary;
    if (status == 'PENDING') color = AppTheme.warning;
    if (status == 'REVIEW') color = AppTheme.warning;
    if (status == 'COMPLETED') color = AppTheme.success;
    if (status == 'RETURNED') color = Colors.redAccent;
    if (status == 'ACCEPTED') color = Colors.teal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return Colors.redAccent;
      case 'HIGH':
        return Colors.orangeAccent;
      case 'MEDIUM':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  bool _isTaskOverdue(TaskItem task) {
    if (task.status == 'COMPLETED' || task.status == 'CANCELLED' || task.dueDate == null) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
    return due.isBefore(today);
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final dueDay = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (dueDay == today) return 'Today';
    if (dueDay == today.add(const Duration(days: 1))) return 'Tomorrow';
    if (dueDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─── 10. VALIDATED CREATE TASK MODAL (CLEAR FORM, ISSUER & WORKFORCE SCOPE) ──

class _CreateTaskModalDialog extends ConsumerStatefulWidget {
  const _CreateTaskModalDialog();

  @override
  ConsumerState<_CreateTaskModalDialog> createState() => _CreateTaskModalDialogState();
}

class _CreateTaskModalDialogState extends ConsumerState<_CreateTaskModalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _estHoursController = TextEditingController(text: '4.0');

  String _priority = 'MEDIUM';
  DateTime? _dueDate = DateTime.now().add(const Duration(days: 3));

  String? _selectedAssigneeStaffId;
  String? _selectedIssuerStaffId;
  bool _showDelegationOverride = false;
  String? _selectedProjectId;
  String? _selectedMilestoneId;
  String? _selectedDepartmentId;
  String? _selectedTeamId;

  bool _isLoadingOptions = true;
  bool _isSubmitting = false;

  Map<String, dynamic>? _currentUserStaff;
  List<Map<String, dynamic>> _staffList = [];
  List<Map<String, dynamic>> _projectsList = [];
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _teams = [];

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _estHoursController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    setState(() => _isLoadingOptions = true);
    try {
      final opts = await ref.read(tasksRepositoryProvider).getFormOptions();
      if (opts.isNotEmpty) {
        _currentUserStaff = opts['currentUser'] is Map ? Map<String, dynamic>.from(opts['currentUser'] as Map) : null;
        _staffList = (opts['staffList'] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _projectsList = (opts['projects'] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _departments = (opts['departments'] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _teams = (opts['teams'] as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        _selectedIssuerStaffId = _currentUserStaff?['staffId']?.toString();
      } else {
        final user = ref.read(currentUserProvider);
        final canManage = user?.canCreate('TASKS') == true;
        if (canManage) {
          final s = await ref.read(staffRepositoryProvider).getStaffList();
          _staffList = s.map((e) => {
            'id': e.id,
            'fullName': e.fullName,
            'employeeId': e.employeeId,
            'department': {'name': e.departmentName},
            'designation': {'name': e.designationName},
          }).toList();
          final p = await ref.read(projectsRepositoryProvider).getProjects();
          _projectsList = p.map((e) => {
            'id': e.id,
            'name': e.name,
            'projectNumber': e.projectNumber,
            'milestones': [],
          }).toList();
          _departments = await ref.read(adminRepositoryProvider).getOrganizationStructure();
        } else {
          final s = await ref.read(tasksRepositoryProvider).getAssignableStaff();
          _staffList = s;
        }
        _selectedIssuerStaffId = user?.staffId;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingOptions = false);
  }

  void _resetForm() {
    setState(() {
      _formKey.currentState?.reset();
      _titleController.clear();
      _descController.clear();
      _estHoursController.text = '4.0';
      _priority = 'MEDIUM';
      _selectedAssigneeStaffId = null;
      _selectedIssuerStaffId = _currentUserStaff?['staffId']?.toString() ?? ref.read(currentUserProvider)?.staffId;
      _showDelegationOverride = false;
      _selectedProjectId = null;
      _selectedMilestoneId = null;
      _selectedDepartmentId = null;
      _selectedTeamId = null;
      _dueDate = DateTime.now().add(const Duration(days: 3));
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.refresh_rounded, color: Colors.amberAccent, size: 18),
            SizedBox(width: 8),
            Text('Form cleared — all fields reset to clean state'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  List<Map<String, dynamic>> _getAvailableMilestones() {
    if (_selectedProjectId == null) return [];
    for (final p in _projectsList) {
      if (p['id']?.toString() == _selectedProjectId) {
        final ms = p['milestones'];
        if (ms is List) {
          return ms.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        }
      }
    }
    return [];
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return Colors.redAccent;
      case 'HIGH':
        return Colors.orangeAccent;
      case 'MEDIUM':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final dueDay = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    if (dueDay == today) return 'Today';
    if (dueDay == today.add(const Duration(days: 1))) return 'Tomorrow';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
      return;
    }

    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    final estH = double.tryParse(_estHoursController.text.trim()) ?? 4.0;

    setState(() => _isSubmitting = true);
    try {
      final payload = <String, dynamic>{
        'title': title,
        if (description.isNotEmpty) 'description': description,
        'priority': _priority,
        'estimatedHours': estH,
        if (_selectedProjectId != null) 'projectId': _selectedProjectId,
        if (_selectedMilestoneId != null) 'milestoneId': _selectedMilestoneId,
        if (_selectedDepartmentId != null) 'departmentId': _selectedDepartmentId,
        if (_selectedTeamId != null) 'teamId': _selectedTeamId,
        if (_selectedAssigneeStaffId != null) 'assigneeStaffId': _selectedAssigneeStaffId,
        if (_selectedIssuerStaffId != null) 'assignedByStaffId': _selectedIssuerStaffId,
        if (_dueDate != null)
          'dueDate': DateTime.utc(_dueDate!.year, _dueDate!.month, _dueDate!.day).toIso8601String(),
      };

      await ref.read(tasksRepositoryProvider).createTask(payload);

      ref.invalidate(allTasksProvider(null));
      ref.invalidate(myTasksProvider);
      ref.invalidate(taskStatsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Task successfully created with validated workforce delegation!'),
              ],
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = _currentUserStaff?['isAdmin'] == true || user?.isAdmin == true;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 880,
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1E222D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. STICKY MODAL HEADER ──
            _buildModalHeader(),

            // ── 2. SCROLLABLE CONTENT BODY (2-COLUMN RESPONSIVE LAYOUT) ──
            Expanded(
              child: _isLoadingOptions
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Loading workforce metadata...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )
                  : Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Form(
                          key: _formKey,
                          child: LayoutBuilder(
                            builder: (ctx, constraints) {
                              final isWide = constraints.maxWidth >= 640;
                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left Column: Task Core Details
                                    Expanded(
                                      flex: 6,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionLabel('1. TASK INFORMATION', Icons.assignment_outlined),
                                          const SizedBox(height: 10),
                                          _buildTitleField(),
                                          const SizedBox(height: 12),
                                          _buildDescriptionField(),
                                          const SizedBox(height: 12),
                                          _buildPrioritySelector(),
                                          const SizedBox(height: 14),
                                          _buildProjectMilestoneCard(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    // Right Column: Workforce, Schedule & Effort
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionLabel('2. WORKFORCE & DELEGATION', Icons.people_outline),
                                          const SizedBox(height: 10),
                                          _buildAssignedFromCard(isAdmin),
                                          const SizedBox(height: 12),
                                          _buildAssignedToCard(),
                                          const SizedBox(height: 16),
                                          _buildSectionLabel('3. SCHEDULE & EFFORT', Icons.schedule_outlined),
                                          const SizedBox(height: 10),
                                          _buildDueDateCard(),
                                          const SizedBox(height: 12),
                                          _buildEstimatedEffortCard(),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                // Mobile single-column stacked layout
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionLabel('1. TASK INFORMATION', Icons.assignment_outlined),
                                    const SizedBox(height: 10),
                                    _buildTitleField(),
                                    const SizedBox(height: 12),
                                    _buildDescriptionField(),
                                    const SizedBox(height: 12),
                                    _buildPrioritySelector(),
                                    const SizedBox(height: 14),
                                    _buildProjectMilestoneCard(),
                                    const SizedBox(height: 16),
                                    _buildSectionLabel('2. WORKFORCE & DELEGATION', Icons.people_outline),
                                    const SizedBox(height: 10),
                                    _buildAssignedFromCard(isAdmin),
                                    const SizedBox(height: 12),
                                    _buildAssignedToCard(),
                                    const SizedBox(height: 16),
                                    _buildSectionLabel('3. SCHEDULE & EFFORT', Icons.schedule_outlined),
                                    const SizedBox(height: 10),
                                    _buildDueDateCard(),
                                    const SizedBox(height: 12),
                                    _buildEstimatedEffortCard(),
                                  ],
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
            ),

            // ── 3. STICKY MODAL FOOTER ──
            _buildModalFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, IconData icon, [Color? iconColor]) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor ?? AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: iconColor ?? Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildModalHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_task_rounded, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Create New Task',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 11, color: AppTheme.success),
                          SizedBox(width: 3),
                          Text('Security Active', style: TextStyle(fontSize: 10, color: AppTheme.success, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Fill in task specifications, workforce assignment and target schedule',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.amberAccent),
            label: const Text('Clear Form', style: TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.amberAccent.withValues(alpha: 0.4)),
              backgroundColor: Colors.amberAccent.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildModalFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh_rounded, size: 15, color: Colors.amberAccent),
            label: const Text('Clear Form', style: TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            icon: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline, size: 16),
            label: Text(_isSubmitting ? 'Validating...' : 'Create Task', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _isSubmitting ? null : _submitTask,
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('Task Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(' *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _titleController,
          autofocus: false,
          style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'e.g. Assemble 15HP VFD control panel with safety interlocks',
            hintStyle: const TextStyle(fontSize: 12, color: Colors.white30),
            prefixIcon: const Icon(Icons.title_rounded, size: 18, color: AppTheme.primary),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
          ),
          validator: (val) {
            final text = val?.trim() ?? '';
            if (text.isEmpty) return 'Task title is required';
            if (text.length < 3) return 'Task title must be at least 3 characters';
            if (text.length > 150) return 'Task title cannot exceed 150 characters';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Description / Specifications', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descController,
          maxLines: 3,
          style: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Add component notes, milestones, safety measures, or acceptance criteria...',
            hintStyle: const TextStyle(fontSize: 11, color: Colors.white30),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Icon(Icons.notes_rounded, size: 18, color: Colors.grey),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.04),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
          ),
          validator: (val) {
            if (val != null && val.trim().length > 3000) {
              return 'Description cannot exceed 3000 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('Priority Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(' *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].map((p) {
            final isSelected = _priority == p;
            final color = _getPriorityColor(p);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: InkWell(
                  onTap: () => setState(() => _priority = p),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? color : Colors.white10,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: isSelected ? color : Colors.grey, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          p,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? color : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProjectMilestoneCard() {
    final availableMilestones = _getAvailableMilestones();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.folder_open_rounded, size: 14, color: Colors.blueAccent),
              SizedBox(width: 6),
              Text('Project & Milestone Alignment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _selectedProjectId,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Select Project (Optional)',
              hintStyle: const TextStyle(fontSize: 11, color: Colors.white30),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Stand-alone / No linked project', style: TextStyle(fontSize: 12)),
              ),
              ..._projectsList.map((p) => DropdownMenuItem<String?>(
                    value: p['id']?.toString(),
                    child: Text('${p['projectNumber'] ?? ''} · ${p['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  )),
            ],
            onChanged: (val) {
              setState(() {
                _selectedProjectId = val;
                _selectedMilestoneId = null;
              });
            },
          ),
          if (_selectedProjectId != null && availableMilestones.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _selectedMilestoneId,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Select Milestone (Optional)',
                hintStyle: const TextStyle(fontSize: 11, color: Colors.white30),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('General Project Scope / No milestone', style: TextStyle(fontSize: 12)),
                ),
                ...availableMilestones.map((m) => DropdownMenuItem<String?>(
                      value: m['id']?.toString(),
                      child: Text('${m['title']} (${m['status'] ?? 'PENDING'})', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedMilestoneId = val),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignedFromCard(bool isAdmin) {
    final issuerName = _currentUserStaff?['fullName'] ?? ref.read(currentUserProvider)?.fullName ?? 'Current User';
    final issuerEmpId = _currentUserStaff?['employeeId'] ?? '';
    final issuerDesignation = _currentUserStaff?['designation'] ?? 'Staff';
    final issuerDept = _currentUserStaff?['department'] ?? '';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.outbox_rounded, size: 14, color: Colors.purpleAccent),
              const SizedBox(width: 6),
              const Text(
                'ASSIGNED FROM (TASK ISSUER)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.purpleAccent),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 10, color: Colors.purpleAccent),
                    SizedBox(width: 3),
                    Text('Verified Issuer', style: TextStyle(fontSize: 9, color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.purpleAccent.withValues(alpha: 0.25),
                child: Text(
                  issuerName.isNotEmpty ? issuerName[0].toUpperCase() : 'U',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purpleAccent, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(issuerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(
                      [
                        if (issuerEmpId.isNotEmpty) issuerEmpId,
                        if (issuerDesignation.isNotEmpty) issuerDesignation,
                        if (issuerDept.isNotEmpty) issuerDept,
                      ].join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isAdmin && _staffList.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _showDelegationOverride = !_showDelegationOverride),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Icon(_showDelegationOverride ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded, size: 16, color: Colors.purpleAccent),
                    Text(
                      _showDelegationOverride ? 'Hide Delegation Override' : 'Delegate on behalf of another Staff / Manager ▾',
                      style: const TextStyle(fontSize: 10, color: Colors.purpleAccent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            if (_showDelegationOverride) ...[
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedIssuerStaffId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Override Issuer Staff',
                  labelStyle: const TextStyle(fontSize: 10, color: Colors.purpleAccent),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: _currentUserStaff?['staffId']?.toString() ?? ref.read(currentUserProvider)?.staffId,
                    child: Text('Myself ($issuerName)', style: const TextStyle(fontSize: 11)),
                  ),
                  ..._staffList.map((s) => DropdownMenuItem<String>(
                        value: s['id']?.toString(),
                        child: Text('${s['fullName']} (${s['employeeId'] ?? ''}) · ${s['designation']?['name'] ?? ''}', style: const TextStyle(fontSize: 11)),
                      )),
                ],
                onChanged: (val) => setState(() => _selectedIssuerStaffId = val),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAssignedToCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inbox_rounded, size: 14, color: AppTheme.primary),
              SizedBox(width: 6),
              Text(
                'ASSIGNED TO (TARGET WORKFORCE)',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: _selectedAssigneeStaffId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Staff Assignee',
              labelStyle: const TextStyle(fontSize: 11),
              prefixIcon: const Icon(Icons.person_outline, size: 16),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Unassigned / Pool queue', style: TextStyle(fontSize: 12)),
              ),
              ..._staffList.map((s) {
                final designation = s['designation'] is Map ? s['designation']['name'] : null;
                final dept = s['department'] is Map ? s['department']['name'] : null;
                final label = [
                  s['fullName'],
                  if (s['employeeId'] != null) '(${s['employeeId']})',
                  if (designation != null) '· $designation',
                  if (dept != null) '· $dept',
                ].join(' ');
                return DropdownMenuItem<String?>(
                  value: s['id']?.toString(),
                  child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                );
              }),
            ],
            onChanged: (val) => setState(() => _selectedAssigneeStaffId = val),
          ),
          if (_departments.isNotEmpty || _teams.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (_departments.isNotEmpty)
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedDepartmentId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Department',
                        labelStyle: const TextStyle(fontSize: 10),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No department link', style: TextStyle(fontSize: 11)),
                        ),
                        ..._departments.map((d) => DropdownMenuItem<String?>(
                              value: d['id']?.toString(),
                              child: Text('${d['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedDepartmentId = val),
                    ),
                  ),
                if (_departments.isNotEmpty && _teams.isNotEmpty) const SizedBox(width: 8),
                if (_teams.isNotEmpty)
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _selectedTeamId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Team',
                        labelStyle: const TextStyle(fontSize: 10),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.04),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No team assignment', style: TextStyle(fontSize: 11)),
                        ),
                        ..._teams.map((t) => DropdownMenuItem<String?>(
                              value: t['id']?.toString(),
                              child: Text('${t['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedTeamId = val),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDueDateCard() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_month_outlined, size: 14, color: AppTheme.primary),
                  SizedBox(width: 6),
                  Text('Target Due Date *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                ],
              ),
              if (_dueDate != null)
                InkWell(
                  onTap: () => setState(() => _dueDate = null),
                  child: const Text('Clear Date', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: _dueDate ?? now,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: DateTime(2100),
              );
              if (selected != null) {
                setState(() => _dueDate = selected);
              }
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 15, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    _dueDate == null ? 'Set Due Date (Click to pick)' : 'Target Due: ${_formatDate(_dueDate!)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _dueDate != null ? FontWeight.bold : FontWeight.normal,
                      color: _dueDate != null ? Colors.white : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildPresetChip('Today', DateTime(now.year, now.month, now.day)),
              _buildPresetChip('Tomorrow', DateTime(now.year, now.month, now.day).add(const Duration(days: 1))),
              _buildPresetChip('+3 Days', DateTime(now.year, now.month, now.day).add(const Duration(days: 3))),
              _buildPresetChip('+1 Wk', DateTime(now.year, now.month, now.day).add(const Duration(days: 7))),
              _buildPresetChip('End of Mo', DateTime(now.year, now.month + 1, 0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, DateTime targetDate) {
    final isSelected = _dueDate != null &&
        _dueDate!.year == targetDate.year &&
        _dueDate!.month == targetDate.month &&
        _dueDate!.day == targetDate.day;
    return InkWell(
      onTap: () => setState(() => _dueDate = targetDate),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? AppTheme.primary : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.primary : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildEstimatedEffortCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hourglass_empty_rounded, size: 14, color: Colors.amberAccent),
              SizedBox(width: 6),
              Text('Estimated Effort (Hours) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 90,
                child: TextFormField(
                  controller: _estHoursController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                  decoration: InputDecoration(
                    hintText: '4.0',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.04),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.white12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.white12)),
                  ),
                  validator: (val) {
                    final t = val?.trim() ?? '';
                    if (t.isEmpty) return 'Required';
                    final h = double.tryParse(t);
                    if (h == null || h <= 0) return 'Invalid';
                    if (h > 1000) return '> 1000';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildHourStepChip('+1h', 1.0),
                    _buildHourStepChip('+2h', 2.0),
                    _buildHourStepChip('+4h (½d)', 4.0),
                    _buildHourStepChip('+8h (1d)', 8.0),
                    _buildHourStepChip('+40h (1w)', 40.0),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHourStepChip(String label, double addHours) {
    return InkWell(
      onTap: () {
        final current = double.tryParse(_estHoursController.text.trim()) ?? 0.0;
        final next = (current + addHours).clamp(0.5, 1000.0);
        setState(() {
          _estHoursController.text = next.toStringAsFixed(1);
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ),
    );
  }
}


