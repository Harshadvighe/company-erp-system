import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/features/staff/data/staff_repository.dart';

class StaffDirectoryPage extends ConsumerStatefulWidget {
  const StaffDirectoryPage({super.key});

  @override
  ConsumerState<StaffDirectoryPage> createState() => _StaffDirectoryPageState();
}

class _StaffDirectoryPageState extends ConsumerState<StaffDirectoryPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final staffAsync = ref.watch(staffListProvider(_searchQuery));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Directory'),
        actions: [
          if (user?.canCreate('STAFF') == true)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1),
              tooltip: 'Add Staff Member',
              onPressed: () => _showAddStaffDialog(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Name, Employee ID, or Email...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
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
              onSubmitted: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // Staff List
          Expanded(
            child: staffAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error loading directory: $err', style: const TextStyle(color: AppTheme.error)),
              ),
              data: (staffList) {
                if (staffList.isEmpty) {
                  return const Center(
                    child: Text('No staff records found.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: staffList.length,
                  itemBuilder: (context, index) {
                    final staff = staffList[index];
                    return Card(
                      color: AppTheme.darkSurface,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.primary.withOpacity(0.2),
                          child: Text(
                            staff.fullName.isNotEmpty ? staff.fullName[0].toUpperCase() : 'S',
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(staff.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                staff.employeeId,
                                style: const TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${staff.designationName ?? "Role Unassigned"} • ${staff.departmentName ?? "No Dept"}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(staff.email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                if (staff.mobile != null) ...[
                                  const SizedBox(width: 12),
                                  const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(staff.mobile!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ],
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: staff.status == 'ACTIVE'
                                ? AppTheme.success.withOpacity(0.15)
                                : Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            staff.status,
                            style: TextStyle(
                              color: staff.status == 'ACTIVE' ? AppTheme.success : Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    final empIdController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Add Staff Member'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: empIdController,
                decoration: const InputDecoration(labelText: 'Employee ID (e.g. EMP008)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Work Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Mobile Phone'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (empIdController.text.isEmpty || nameController.text.isEmpty || emailController.text.isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              try {
                // Fetch first dept and desig for default setup
                final depts = await ref.read(staffRepositoryProvider).getDepartments();
                final desigs = await ref.read(staffRepositoryProvider).getDesignations();
                if (depts.isNotEmpty && desigs.isNotEmpty) {
                  await ref.read(staffRepositoryProvider).createStaff({
                    'employeeId': empIdController.text.trim(),
                    'fullName': nameController.text.trim(),
                    'email': emailController.text.trim(),
                    'mobile': phoneController.text.trim(),
                    'departmentId': depts.first['id'],
                    'designationId': desigs.first['id'],
                  });
                  ref.invalidate(staffListProvider(_searchQuery));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add staff: $e')));
                }
              }
            },
            child: const Text('Save Staff'),
          ),
        ],
      ),
    );
  }
}
