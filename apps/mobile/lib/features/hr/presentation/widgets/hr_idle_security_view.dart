import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class HrIdleSecurityView extends ConsumerStatefulWidget {
  const HrIdleSecurityView({super.key});

  @override
  ConsumerState<HrIdleSecurityView> createState() => _HrIdleSecurityViewState();
}

class _HrIdleSecurityViewState extends ConsumerState<HrIdleSecurityView> {
  bool _isLoading = true;
  String _searchQuery = '';
  bool _lockedOnly = false;
  List<dynamic> _users = [];
  Map<String, dynamic> _stats = {};
  final Set<String> _resettingUserIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final queryParams = <String, String>{};
      if (_searchQuery.trim().isNotEmpty) {
        queryParams['search'] = _searchQuery.trim();
      }
      if (_lockedOnly) {
        queryParams['lockedOnly'] = 'true';
      }

      final uri = Uri(path: '/hr/idle-lockouts', queryParameters: queryParams.isEmpty ? null : queryParams).toString();
      final response = await dio.get(uri);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data['data'] ?? response.data;
        if (data is Map) {
          _users = (data['users'] as List<dynamic>?) ?? [];
          _stats = (data['stats'] as Map<String, dynamic>?) ?? {};
        } else if (data is List) {
          _users = data;
        }
      }
    } catch (e) {
      debugPrint('[HrIdleSecurityView] Error fetching users: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load user idle security data: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetUserLimit(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    final fullName = user['fullName'] ?? user['username'] ?? 'User';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.lock_open_rounded, color: Color(0xFF00E5FF), size: 24),
            const SizedBox(width: 10),
            const Text(
              'Grant Login Access & Reset Limit',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to restore login access for $fullName (${user['username']})?',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF26282E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF383B42)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• Current Inactivity Logouts: ${user['idleLogoutCount'] ?? 0} / 10',
                    style: TextStyle(
                      color: (user['idleLogoutCount'] ?? 0) >= 10 ? Colors.redAccent : Colors.orangeAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• New Counter: 0 / 10 (Reset)',
                    style: TextStyle(color: Color(0xFF00E676), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• Status: UNLOCKED & ACTIVE',
                    style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Grant Access & Reset', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _resettingUserIds.add(userId));
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/hr/users/$userId/reset-idle-limit');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Access granted! Inactivity counter for $fullName reset to 0/10.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF00E676),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        await _fetchUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset limit for $fullName: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resettingUserIds.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 900;

    final totalUsers = _stats['totalUsers'] ?? _users.length;
    final lockedCount = _stats['lockedCount'] ??
        _users.where((u) => u['isIdleLocked'] == true || (u['idleLogoutCount'] ?? 0) >= 10).length;
    final atRiskCount = _stats['atRiskCount'] ??
        _users.where((u) => (u['idleLogoutCount'] ?? 0) >= 5 && u['isIdleLocked'] != true).length;

    return Container(
      color: const Color(0xFF141517),
      child: Column(
        children: [
          // Sub-Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E2024),
              border: Border(bottom: BorderSide(color: Color(0xFF26282E))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock_clock_outlined, color: Color(0xFF00E5FF), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Idle Security & Inactivity Lockouts',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Monitor 30-minute inactivity auto-logouts, view locked accounts (10-limit reached), and restore login permissions.',
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh User List',
                  onPressed: _fetchUsers,
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KPI Stat Cards
                        _buildStatCards(isDesktop, totalUsers, lockedCount, atRiskCount),
                        const SizedBox(height: 20),

                        // Policy Notice Box
                        _buildPolicyBanner(),
                        const SizedBox(height: 20),

                        // Search and Filter Bar
                        _buildSearchAndFilterBar(),
                        const SizedBox(height: 16),

                        // Users Table or Empty State
                        if (_users.isEmpty)
                          _buildEmptyState()
                        else
                          _buildUsersTable(isDesktop),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(bool isDesktop, dynamic totalUsers, dynamic lockedCount, dynamic atRiskCount) {
    final cards = [
      _buildCard('Total Monitored Users', '$totalUsers', Icons.people_outline, const Color(0xFF00E5FF)),
      _buildCard('Locked Out Accounts (10/10)', '$lockedCount', Icons.lock_rounded, const Color(0xFFEF4444)),
      _buildCard('At-Risk Accounts (5-9 / 10)', '$atRiskCount', Icons.warning_amber_rounded, const Color(0xFFF59E0B)),
      _buildCard('Idle Timeout Period', '30 Minutes', Icons.timer_outlined, const Color(0xFF10B981)),
      _buildCard('Max Inactivity Limit', '10 Logouts', Icons.shield_outlined, const Color(0xFFA855F7)),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c)))
            .toList(),
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => SizedBox(width: 170, child: c)).toList(),
      );
    }
  }

  Widget _buildCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2024),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2D3038)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2430),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFF00E5FF), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automated Inactivity Security Rule Active',
                  style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'When any employee is inactive for 30 continuous minutes with no interaction recorded in the software, the session auto-terminates and logs an audit event. Reaching 10 inactivity timeouts locks the user account permanently until an HR administrator clicks "Grant Access & Reset Limit" below.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2024),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2D3038)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by employee name, username, email or designation...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _fetchUsers();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (val) {
                setState(() => _searchQuery = val);
                _fetchUsers();
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilterChip(
          label: const Text('Locked Accounts Only'),
          selected: _lockedOnly,
          selectedColor: const Color(0xFFEF4444).withOpacity(0.2),
          checkmarkColor: const Color(0xFFEF4444),
          labelStyle: TextStyle(
            color: _lockedOnly ? const Color(0xFFEF4444) : Colors.white60,
            fontSize: 12,
            fontWeight: _lockedOnly ? FontWeight.bold : FontWeight.normal,
          ),
          backgroundColor: const Color(0xFF1E2024),
          side: BorderSide(
            color: _lockedOnly ? const Color(0xFFEF4444) : const Color(0xFF2D3038),
          ),
          onSelected: (val) {
            setState(() => _lockedOnly = val);
            _fetchUsers();
          },
        ),
      ],
    );
  }

  Widget _buildUsersTable(bool isDesktop) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2024),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF26282E)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF24272D),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('User / Employee', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Department & Role', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Inactivity Count', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Lockout Status', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Last Activity / Lock', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('HR Action', textAlign: TextAlign.right, style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _users.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFF26282E), height: 1),
            itemBuilder: (ctx, idx) {
              final user = _users[idx] as Map<String, dynamic>;
              final count = (user['idleLogoutCount'] as num?)?.toInt() ?? 0;
              final isLocked = user['isIdleLocked'] == true || count >= 10;
              final isResetting = _resettingUserIds.contains(user['id']);

              Color countColor = const Color(0xFF10B981);
              if (count >= 10) {
                countColor = const Color(0xFFEF4444);
              } else if (count >= 5) {
                countColor = const Color(0xFFF59E0B);
              }

              String lastLockTime = '—';
              if (user['idleLockedAt'] != null) {
                try {
                  final dt = DateTime.parse(user['idleLockedAt'].toString()).toLocal();
                  lastLockTime = DateFormat('dd MMM, hh:mm a').format(dt);
                } catch (_) {}
              } else if (user['lastActivityAt'] != null) {
                try {
                  final dt = DateTime.parse(user['lastActivityAt'].toString()).toLocal();
                  lastLockTime = DateFormat('dd MMM, hh:mm a').format(dt);
                } catch (_) {}
              }

              final deptName = user['department']?['name'] ?? 'General';
              final userRoles = user['userRoles'] as List?;
              String roleName = user['designation']?.toString() ?? 'Staff';
              if (userRoles != null && userRoles.isNotEmpty) {
                final rName = userRoles[0]?['role']?['name'];
                if (rName != null) {
                  roleName = rName.toString();
                }
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: isLocked ? const Color(0xFFEF4444).withOpacity(0.04) : Colors.transparent,
                child: Row(
                  children: [
                    // User / Employee
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isLocked
                                ? const Color(0xFFEF4444).withOpacity(0.2)
                                : const Color(0xFF00E5FF).withOpacity(0.15),
                            child: Icon(
                              isLocked ? Icons.lock_outline : Icons.person_outline,
                              size: 16,
                              color: isLocked ? const Color(0xFFEF4444) : const Color(0xFF00E5FF),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['fullName'] ?? user['username'] ?? 'User',
                                  style: TextStyle(
                                    color: isLocked ? Colors.redAccent : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '@${user['username']} • ${user['email'] ?? ''}',
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Department & Role
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(deptName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Text(roleName, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),

                    // Inactivity Count
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: countColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: countColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              '$count / 10',
                              style: TextStyle(color: countColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: (count / 10).clamp(0.0, 1.0),
                                backgroundColor: const Color(0xFF2A2D35),
                                valueColor: AlwaysStoppedAnimation<Color>(countColor),
                                minHeight: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Lockout Status
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isLocked ? const Color(0xFFEF4444).withOpacity(0.15) : const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isLocked ? const Color(0xFFEF4444).withOpacity(0.4) : const Color(0xFF10B981).withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLocked ? Icons.lock : Icons.check_circle,
                                size: 12,
                                color: isLocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isLocked ? 'LOCKED' : 'ACTIVE',
                                style: TextStyle(
                                  color: isLocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Last Activity / Lock
                    Expanded(
                      flex: 2,
                      child: Text(
                        lastLockTime,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),

                    // HR Action: Grant Access / Reset Limit
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: isResetting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                              )
                            : (isLocked || count > 0)
                                ? ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isLocked ? const Color(0xFF00E5FF) : const Color(0xFF26282E),
                                      foregroundColor: isLocked ? Colors.black : const Color(0xFF00E5FF),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(
                                          color: isLocked ? const Color(0xFF00E5FF) : const Color(0xFF00E5FF).withOpacity(0.4),
                                        ),
                                      ),
                                    ),
                                    onPressed: () => _resetUserLimit(user),
                                    icon: Icon(
                                      isLocked ? Icons.lock_open_rounded : Icons.restart_alt_rounded,
                                      size: 14,
                                    ),
                                    label: Text(
                                      isLocked ? 'Grant Access' : 'Reset Limit',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF26282E),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Clean (0/10)',
                                      style: TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2024),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF26282E)),
      ),
      child: Column(
        children: [
          const Icon(Icons.security, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          const Text(
            'No Users Matching Filter',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _lockedOnly ? 'No accounts are currently locked by inactivity!' : 'No system users match the query.',
            style: const TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

