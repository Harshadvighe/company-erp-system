import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

class BirthdayCelebrationDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> birthdayData;
  final VoidCallback? onDismissed;

  const BirthdayCelebrationDialog({
    super.key,
    required this.birthdayData,
    this.onDismissed,
  });

  static Future<void> show(BuildContext context, Map<String, dynamic> data) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BirthdayCelebrationDialog(birthdayData: data),
    );
  }

  @override
  ConsumerState<BirthdayCelebrationDialog> createState() => _BirthdayCelebrationDialogState();
}

class _BirthdayCelebrationDialogState extends ConsumerState<BirthdayCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late TextEditingController _wishMessageController;

  bool _isSending = false;
  String? _selectedEmployeeId;
  String? _successBanner;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);

    final celebrants = widget.birthdayData['celebrants'] as List? ?? [];
    if (celebrants.isNotEmpty) {
      _selectedEmployeeId = celebrants[0]['id']?.toString();
      final firstName = celebrants[0]['firstName'] ?? celebrants[0]['fullName'] ?? 'Colleague';
      _wishMessageController = TextEditingController(
        text: '🎂 Wishing you a very Happy Birthday, $firstName! May your year be filled with happiness, good health, and continued success! 🎉',
      );
    } else {
      _wishMessageController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _wishMessageController.dispose();
    super.dispose();
  }

  Future<void> _sendWish(String employeeId, String celebrantName) async {
    final msg = _wishMessageController.text.trim();
    if (msg.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/hr/birthdays/wish', data: {
        'employeeId': employeeId,
        'message': msg,
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        setState(() {
          _successBanner = 'Your birthday wish has been delivered to $celebrantName! 🎂🎉';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.cake, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Birthday wish sent to $celebrantName! 🎁',
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send wish: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMyBirthday = widget.birthdayData['isMyBirthday'] == true;
    final celebrants = widget.birthdayData['celebrants'] as List? ?? [];
    final currentUser = ref.watch(currentUserProvider);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          decoration: BoxDecoration(
            color: const Color(0xFF181B20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF26522).withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF26522).withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Festive Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFF26522), Color(0xFFFF8A00), Color(0xFFFF5252)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cake, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    isMyBirthday ? 'HAPPY BIRTHDAY TO YOU!' : "TODAY'S BIRTHDAY CELEBRATION",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onDismissed?.call();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isMyBirthday
                              ? '🎂 Happy Birthday, ${currentUser?.fullName ?? 'Celebrant'}! 🎉'
                              : '🎉 Celebrating Our Team Today! 🎂',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isMyBirthday
                              ? 'Wishing you a magnificent year ahead from all of us at Saark Exploration!'
                              : 'Take a moment to send your warmest wishes and blessings to your colleague!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body Content
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SCENARIO A: Logged-in user is the Birthday Celebrant
                        if (isMyBirthday) ...[
                          _buildCelebrantSelfCard(),
                        ]
                        // SCENARIO B: Other colleagues wishing the celebrant
                        else ...[
                          ...celebrants.map((cel) => _buildCelebrantWishesCard(cel, currentUser)),
                        ],

                        const SizedBox(height: 18),

                        // Close button
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Color(0xFF383B42)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onDismissed?.call();
                            },
                            child: Text(
                              isMyBirthday ? 'Thank You Everyone! 🙏' : 'Close & Continue Working',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrantSelfCard() {
    final myCel = widget.birthdayData['myCelebration'] as Map<String, dynamic>? ?? {};
    final wishes = myCel['wishes'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF22262E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF26522).withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFFF26522), Color(0xFFFF8A00)]),
                ),
                child: const Icon(Icons.cake, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      myCel['fullName'] ?? 'Celebrant',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${myCel['designation'] ?? 'Staff'} • ${myCel['department'] ?? 'Department'}',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Received ${wishes.length} birthday wish${wishes.length == 1 ? '' : 'es'} today! 🎁',
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Wishes from your Colleagues & Management:',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (wishes.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2024),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'Wishes are rolling in! Check back throughout the day. 🎈',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          )
        else
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: wishes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final w = wishes[i] as Map<String, dynamic>;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2024),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2C3038)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            w['sender_name'] ?? 'Colleague',
                            style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const Icon(Icons.favorite, color: Colors.pinkAccent, size: 14),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        w['message'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCelebrantWishesCard(dynamic cel, AuthUser? currentUser) {
    final celMap = cel as Map<String, dynamic>;
    final empId = celMap['id']?.toString() ?? '';
    final fullName = celMap['fullName'] ?? 'Colleague';
    final designation = celMap['designation'] ?? 'Employee';
    final dept = celMap['department'] ?? 'Operations';
    final wishesCount = celMap['wishesCount'] ?? 0;
    final hasSentWish = celMap['hasSentWish'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2127),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D313A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Celebrant Info Row
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF26522).withOpacity(0.2),
                child: const Text('🎂', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$designation • $dept',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.celebration, color: Color(0xFFFF8A00), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Birthday Today! ($wishesCount wish${wishesCount == 1 ? '' : 'es'} sent)',
                          style: const TextStyle(color: Color(0xFFFF8A00), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Success Confirmation
          if (_successBanner != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _successBanner!,
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Message input & send button
          if (!hasSentWish && _successBanner == null) ...[
            const Text(
              'Your Birthday Message / Wishes:',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _wishMessageController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF14161A),
                hintText: 'Write a warm birthday message...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF333742)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFF26522)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF26522),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSending ? null : () => _sendWish(empId, fullName),
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.card_giftcard, size: 18),
                label: Text(
                  _isSending ? 'Sending Wishes...' : 'Send Birthday Wishes 🎁',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else if (hasSentWish || _successBanner != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.done_all, color: Color(0xFF00E676), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'You have sent your warm birthday wishes to this colleague!',
                    style: TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

