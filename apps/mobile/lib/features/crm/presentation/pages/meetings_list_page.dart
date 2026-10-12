import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';
import 'package:saark_erp_mobile/features/staff/data/staff_repository.dart';

class MeetingsListPage extends ConsumerStatefulWidget {
  const MeetingsListPage({super.key});

  @override
  ConsumerState<MeetingsListPage> createState() => _MeetingsListPageState();
}

class _MeetingsListPageState extends ConsumerState<MeetingsListPage>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  final _statusFilters = ['ALL', 'REQUESTED', 'ACCEPTED', 'SCHEDULED', 'RESCHEDULE_PROPOSED', 'COMPLETED', 'DECLINED'];

  List<dynamic> _meetings = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadMeetings();
      }
    });
    _loadMeetings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMeetings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final selectedStatus = _statusFilters[_tabController.index];
      final repo = ref.read(crmRepositoryProvider);
      final res = await repo.getMeetings(
        status: selectedStatus == 'ALL' ? null : selectedStatus,
        search: _searchController.text.trim(),
      );

      setState(() {
        _meetings = res['items'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACCEPTED':
      case 'SCHEDULED':
        return Colors.green;
      case 'REQUESTED':
        return Colors.blue;
      case 'RESCHEDULE_PROPOSED':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.teal;
      case 'DECLINED':
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _respondMeeting(String meetingId, String action) async {
    DateTime? newStartTime;
    final reasonController = TextEditingController();

    if (action == 'RESCHEDULE') {
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)),
      );
      if (pickedDate == null) return;

      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 11, minute: 0),
      );
      if (pickedTime == null) return;

      newStartTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'ACCEPT'
            ? 'Accept Meeting Invitation?'
            : action == 'DECLINE'
                ? 'Decline Meeting?'
                : 'Propose New Meeting Time'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (newStartTime != null) ...[
              Text(
                'Proposed Time: ${DateFormat('dd MMM yyyy, hh:mm a').format(newStartTime)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: action == 'ACCEPT' ? 'Notes (Optional)' : 'Reason *',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'DECLINE' ? Colors.red : Colors.green,
            ),
            child: Text(action, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(crmRepositoryProvider);
      await repo.respondMeeting(
        meetingId,
        action: action,
        newStartTime: newStartTime?.toIso8601String(),
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Meeting status updated: $action')),
        );
      }
      _loadMeetings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update meeting: $e')),
        );
      }
    }
  }

  void _openScheduleDialog() async {
    final customersRepo = ref.read(customersRepositoryProvider);
    final staffRepo = ref.read(staffRepositoryProvider);

    final customersRes = await customersRepo.getCustomers(limit: 100);
    final customersList = customersRes['items'] as List<dynamic>? ?? [];

    final staffList = await staffRepo.getStaffList();

    if (!mounted) return;

    String? selectedCustomerId;
    String? selectedHostStaffId;
    String meetingType = 'OFFLINE';
    final agendaController = TextEditingController();
    final locationController = TextEditingController(text: 'Client Office / Facility');
    DateTime meetingTime = DateTime.now().add(const Duration(hours: 3));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Schedule Meeting & Host Assignment'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Company / Customer *', border: OutlineInputBorder()),
                    items: customersList.map((c) => DropdownMenuItem<String>(
                      value: c['id'],
                      child: Text(c['companyName'] ?? ''),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedCustomerId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Assign Host / Technical Specialist *', border: OutlineInputBorder()),
                    items: staffList.map((s) => DropdownMenuItem<String>(
                      value: s.id,
                      child: Text('${s.fullName} (${s.designationName ?? 'Staff'})'),
                    )).toList(),
                    onChanged: (v) => setModalState(() => selectedHostStaffId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: meetingType,
                    decoration: const InputDecoration(labelText: 'Meeting Type', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'OFFLINE', child: Text('Offline / Physical')),
                      DropdownMenuItem(value: 'CLIENT_OFFICE', child: Text('Client Office Visit')),
                      DropdownMenuItem(value: 'ONLINE_TEAMS', child: Text('Online Microsoft Teams')),
                      DropdownMenuItem(value: 'ONLINE_ZOOM', child: Text('Online Zoom Call')),
                    ],
                    onChanged: (v) => setModalState(() => meetingType = v ?? 'OFFLINE'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Location / Link', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: agendaController,
                    decoration: const InputDecoration(labelText: 'Agenda / Discussion Points *', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: meetingTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)),
                      );
                      if (pickedDate != null && mounted) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(meetingTime),
                        );
                        if (pickedTime != null) {
                          setModalState(() {
                            meetingTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date & Time *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.event)),
                      child: Text(DateFormat('dd MMM yyyy, hh:mm a').format(meetingTime)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (agendaController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter meeting agenda')));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final repo = ref.read(crmRepositoryProvider);
                  await repo.createMeeting({
                    'customerId': selectedCustomerId,
                    'hostStaffId': selectedHostStaffId,
                    'meetingType': meetingType,
                    'location': locationController.text.trim(),
                    'agenda': agendaController.text.trim(),
                    'startTime': meetingTime.toIso8601String(),
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Meeting scheduled successfully!')));
                  _loadMeetings();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Schedule Meeting'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/crm/dashboard');
            }
          },
        ),
        title: const Text('Meetings & Host Scheduling'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadMeetings),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: _statusFilters.map((s) => Tab(text: s.replaceAll('_', ' '))).toList(),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search meetings by agenda, company, location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadMeetings();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
              onSubmitted: (_) => _loadMeetings(),
            ),
          ),

          // Meetings List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _meetings.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text('No Meetings Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text('Schedule client meetings and assign technical hosts.', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadMeetings,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _meetings.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final m = _meetings[index];
                                final activity = m['activity'] as Map<String, dynamic>?;
                                final customer = activity?['customer'] as Map<String, dynamic>?;
                                final host = m['hostStaff'] as Map<String, dynamic>?;
                                final status = m['meetingStatus'] as String? ?? 'SCHEDULED';
                                final startTime = m['startTime'] != null
                                    ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(m['startTime']))
                                    : '-';

                                return Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header: Type + Status
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  m['meetingType']?.toString().contains('ONLINE') == true
                                                      ? Icons.videocam_outlined
                                                      : Icons.handshake_outlined,
                                                  color: AppTheme.primaryColor,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  (m['meetingType'] ?? 'OFFLINE').toString().replaceAll('_', ' '),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(status).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.4)),
                                              ),
                                              child: Text(
                                                status.replaceAll('_', ' '),
                                                style: TextStyle(color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),

                                        // Agenda & Customer
                                        Text(m['agenda'] ?? activity?['subject'] ?? 'Client Meeting', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        if (customer != null)
                                          InkWell(
                                            onTap: () => context.push('/crm/companies/${customer['id']}'),
                                            child: Text(
                                              customer['companyName'] ?? '',
                                              style: TextStyle(fontSize: 13, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        const SizedBox(height: 8),

                                        // Time & Location
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(startTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                            const SizedBox(width: 16),
                                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(m['location'] ?? 'Client Facility', style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),

                                        // Host Staff
                                        if (host != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.person, size: 14, color: Colors.indigo),
                                                const SizedBox(width: 6),
                                                Text('Host: ${host['fullName']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                              ],
                                            ),
                                          ),

                                        // Reschedule History indicator
                                        if ((m['rescheduleCount'] ?? 0) > 0) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Rescheduled ${m['rescheduleCount']} times: ${m['rescheduleReason'] ?? ''}',
                                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.orange.shade900),
                                          ),
                                        ],

                                        const Divider(height: 20),

                                        // Action buttons
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (status != 'ACCEPTED' && status != 'COMPLETED')
                                              TextButton.icon(
                                                onPressed: () => _respondMeeting(m['id'], 'ACCEPT'),
                                                icon: const Icon(Icons.check, size: 16, color: Colors.green),
                                                label: const Text('Accept', style: TextStyle(color: Colors.green)),
                                              ),
                                            TextButton.icon(
                                              onPressed: () => _respondMeeting(m['id'], 'RESCHEDULE'),
                                              icon: const Icon(Icons.schedule, size: 16, color: Colors.orange),
                                              label: const Text('Reschedule', style: TextStyle(color: Colors.orange)),
                                            ),
                                            if (status != 'DECLINED' && status != 'COMPLETED')
                                              TextButton.icon(
                                                onPressed: () => _respondMeeting(m['id'], 'DECLINE'),
                                                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                                label: const Text('Decline', style: TextStyle(color: Colors.red)),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScheduleDialog,
        icon: const Icon(Icons.add),
        label: const Text('Schedule Meeting'),
      ),
    );
  }
}

