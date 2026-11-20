import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';
import 'package:saark_erp_mobile/core/widgets/birthday_celebration_dialog.dart';

class HrBirthdaysView extends ConsumerStatefulWidget {
  const HrBirthdaysView({super.key});

  @override
  ConsumerState<HrBirthdaysView> createState() => _HrBirthdaysViewState();
}

class _HrBirthdaysViewState extends ConsumerState<HrBirthdaysView> {
  bool _isLoading = true;
  bool _isBroadcasting = false;
  Map<String, dynamic> _birthdayData = {};

  @override
  void initState() {
    super.initState();
    _fetchBirthdays();
  }

  Future<void> _fetchBirthdays() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/hr/birthdays/today');
      if (res.statusCode == 200 && res.data != null) {
        final d = res.data['data'] ?? res.data;
        if (d is Map<String, dynamic>) {
          _birthdayData = d;
        }
      }
    } catch (e) {
      debugPrint('[HrBirthdaysView] Error fetching birthdays: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _broadcastWishes() async {
    setState(() => _isBroadcasting = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/hr/birthdays/broadcast', data: {});
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.campaign, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '🎉 Company-wide birthday broadcast dispatched to all employees!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF00E676),
              duration: Duration(seconds: 4),
            ),
          );
        }
        await _fetchBirthdays();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to broadcast birthday: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final celebrants = _birthdayData['celebrants'] as List? ?? [];
    final upcoming = _birthdayData['upcoming'] as List? ?? [];
    final currentUser = ref.watch(currentUserProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

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
                    color: const Color(0xFFF26522).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.cake, color: Color(0xFFF26522), size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Birthdays & Team Celebrations',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Celebrate team milestones, send personal birthday greetings, and view upcoming birthdays across all departments.',
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Refresh Celebrations',
                  onPressed: _fetchBirthdays,
                ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFF26522)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Section: Today's Celebrants
                        if (celebrants.isNotEmpty) ...[
                          _buildTodayCelebrantsHero(celebrants, currentUser, isDesktop),
                          const SizedBox(height: 24),
                        ] else ...[
                          _buildNoBirthdaysTodayCard(),
                          const SizedBox(height: 24),
                        ],

                        // Upcoming Birthdays Section
                        _buildUpcomingBirthdaysSection(upcoming),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCelebrantsHero(List<dynamic> celebrants, AuthUser? currentUser, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E222A),
            const Color(0xFF241B26),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF26522).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF26522).withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF26522),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.celebration, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'TODAY\'S BIRTHDAYS',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (currentUser?.isAdmin == true)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isBroadcasting ? null : _broadcastWishes,
                  icon: _isBroadcasting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.campaign, size: 16),
                  label: const Text(
                    'Broadcast Company Greetings',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Cards for each celebrant today
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: celebrants.map((cel) {
              final c = cel as Map<String, dynamic>;
              final wishesCount = c['wishesCount'] ?? 0;
              final wishes = c['wishes'] as List? ?? [];
              final age = c['age'];

              return Container(
                width: isDesktop ? 360 : double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF14161A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2E323C)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFFF26522).withOpacity(0.2),
                          child: const Text('🎂', style: TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['fullName'] ?? 'Celebrant',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c['designation'] ?? 'Staff'} • ${c['department'] ?? 'Department'}',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                              if (age != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Turning $age years young today! 🎈',
                                  style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF26282E),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$wishesCount wish${wishesCount == 1 ? '' : 'es'} received',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF26522),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () {
                            BirthdayCelebrationDialog.show(context, _birthdayData);
                          },
                          icon: const Icon(Icons.card_giftcard, size: 14),
                          label: const Text('Send Wish 🎁', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    if (wishes.isNotEmpty) ...[
                      const Divider(color: Color(0xFF26282E), height: 24),
                      const Text(
                        'Recent Wishes:',
                        style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      ...wishes.take(2).map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '• ${w['sender_name']}: "${w['message']}"',
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBirthdaysTodayCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2024),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF26282E)),
      ),
      child: const Row(
        children: [
          Icon(Icons.calendar_month, color: Colors.white38, size: 36),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Employee Birthdays Today',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'There are no birthdays registered for today. Check upcoming team birthdays below to plan ahead!',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingBirthdaysSection(List<dynamic> upcoming) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2024),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF26282E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: Color(0xFF00E5FF), size: 18),
                const SizedBox(width: 10),
                const Text(
                  'Upcoming Birthdays (Next 30 Days)',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF26282E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${upcoming.length} upcoming',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF26282E), height: 1),
          if (upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No upcoming birthdays in the next 30 days.', style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: upcoming.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF26282E), height: 1),
              itemBuilder: (ctx, i) {
                final item = upcoming[i] as Map<String, dynamic>;
                final daysAway = item['daysAway'] ?? 0;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF00E5FF).withOpacity(0.15),
                    child: const Icon(Icons.cake, color: Color(0xFF00E5FF), size: 18),
                  ),
                  title: Text(
                    item['fullName'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${item['designation'] ?? ''} • ${item['department'] ?? ''}',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item['birthdayFormatted'] ?? '',
                        style: const TextStyle(color: Color(0xFFFF8A00), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'In $daysAway day${daysAway == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
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
}

