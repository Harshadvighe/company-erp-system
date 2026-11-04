import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/auth/auth_provider.dart';
import 'package:saark_erp_mobile/core/network/dio_client.dart';

// ─── Model ──────────────────────────────────────────────────────────────────

class BirthdayCelebrant {
  final String id;
  final String employeeCode;
  final String fullName;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String designation;
  final String departmentName;
  final String? userId;
  final String? username;
  final String? avatarUrl;

  const BirthdayCelebrant({
    required this.id,
    required this.employeeCode,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    required this.designation,
    required this.departmentName,
    this.userId,
    this.username,
    this.avatarUrl,
  });

  factory BirthdayCelebrant.fromJson(Map<String, dynamic> json) {
    return BirthdayCelebrant(
      id: json['id']?.toString() ?? '',
      employeeCode: json['employeeCode']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      designation: json['designation']?.toString() ?? 'Team Member',
      departmentName: json['departmentName']?.toString() ?? 'Saark Operations',
      userId: json['userId']?.toString(),
      username: json['username']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final todayBirthdaysProvider = FutureProvider<List<BirthdayCelebrant>>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/dashboard/birthdays/today');
    final rawData = response.data['data'] ?? response.data;
    if (rawData is List) {
      return rawData
          .map((e) => BirthdayCelebrant.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  } catch (_) {
    return [];
  }
});

// ─── Main Birthday Banner Widget ─────────────────────────────────────────────

class BirthdayCelebrationBanner extends ConsumerStatefulWidget {
  const BirthdayCelebrationBanner({super.key});

  @override
  ConsumerState<BirthdayCelebrationBanner> createState() =>
      _BirthdayCelebrationBannerState();
}

class _BirthdayCelebrationBannerState
    extends ConsumerState<BirthdayCelebrationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<_ConfettiPiece> _confetti = [];
  bool _dialogShown = false;
  final Set<String> _wishedEmployees = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final rng = math.Random();
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFFF5722), // Orange
      const Color(0xFFFF4081), // Pink
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFF76FF03), // Lime
      const Color(0xFFE040FB), // Purple
      Colors.white,
    ];

    for (int i = 0; i < 45; i++) {
      _confetti.add(_ConfettiPiece(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: rng.nextDouble() * 7 + 4,
        speed: rng.nextDouble() * 0.4 + 0.2,
        color: colors[rng.nextInt(colors.length)],
        rotation: rng.nextDouble() * math.pi * 2,
        isCircle: rng.nextBool(),
      ));
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool _isMe(AuthUser? user, BirthdayCelebrant celebrant) {
    if (user == null) return false;
    if (celebrant.userId != null && celebrant.userId == user.id) return true;
    if (celebrant.username != null &&
        celebrant.username!.toLowerCase() == user.username.toLowerCase()) {
      return true;
    }
    if (celebrant.email != null &&
        celebrant.email!.toLowerCase() == user.email.toLowerCase()) {
      return true;
    }
    if (user.employeeId != null &&
        user.employeeId!.isNotEmpty &&
        celebrant.employeeCode.toLowerCase() == user.employeeId!.toLowerCase()) {
      return true;
    }
    return false;
  }

  void _triggerSurpriseDialog(BirthdayCelebrant me) {
    if (_dialogShown) return;
    _dialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => _SurpriseBirthdayDialog(
          celebrant: me,
          confetti: _confetti,
          controller: _animController,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final birthdaysAsync = ref.watch(todayBirthdaysProvider);

    return birthdaysAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (celebrants) {
        if (celebrants.isEmpty) return const SizedBox.shrink();

        // Check if the current user has a birthday today
        final myBirthday = celebrants.where((c) => _isMe(user, c)).toList();
        final isMyBday = myBirthday.isNotEmpty;

        if (isMyBday) {
          final me = myBirthday.first;
          _triggerSurpriseDialog(me);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;

            if (isMyBday) {
              return _buildMyBirthdayHero(
                celebrant: myBirthday.first,
                isMobile: isMobile,
              );
            } else {
              return _buildTeamBirthdayCard(
                celebrants: celebrants,
                isMobile: isMobile,
              );
            }
          },
        );
      },
    );
  }

  // ─── Case A: The Current Logged-In User's Birthday ─────────────────────────

  Widget _buildMyBirthdayHero({
    required BirthdayCelebrant celebrant,
    required bool isMobile,
  }) {
    final displayName = celebrant.firstName.isNotEmpty
        ? celebrant.firstName
        : celebrant.fullName;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2E1500),
            Color(0xFF451E00),
            Color(0xFF220C00),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFFFB300).withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8F00).withValues(alpha: 0.35),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Animated falling confetti background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _ConfettiPainter(
                      confetti: _confetti,
                      progress: _animController.value,
                    ),
                  );
                },
              ),
            ),

            // Content Container
            Padding(
              padding: EdgeInsets.all(isMobile ? 18.0 : 26.0),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildBirthdayHeroContent(displayName, isMobile: true),
                        const SizedBox(height: 16),
                        _buildHeroButtons(celebrant, isMobile: true),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildBirthdayHeroContent(displayName, isMobile: false),
                        ),
                        const SizedBox(width: 24),
                        _buildHeroButtons(celebrant, isMobile: false),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBirthdayHeroContent(String name, {required bool isMobile}) {
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Festive Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB300).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFFB300).withValues(alpha: 0.6),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎉', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text(
                'TODAY IS YOUR SPECIAL DAY',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              SizedBox(width: 6),
              Text('🎂', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Personalized Birthday Title
        Text(
          'Happy Birthday, $name! 🎈',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: isMobile ? 22 : 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.3,
            shadows: [
              Shadow(
                color: const Color(0xFFFF8F00).withValues(alpha: 0.8),
                blurRadius: 16,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Inspiring Message
        Text(
          'The entire Saark Exploration family sends you our warmest wishes! May this milestone year bring you robust health, immense happiness, personal triumphs, and every success in your career. Have an unforgettable day!',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            color: Color(0xFFFFECB3),
            fontSize: 13.5,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroButtons(BirthdayCelebrant celebrant, {required bool isMobile}) {
    return Wrap(
      alignment: isMobile ? WrapAlignment.center : WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            _animController.forward(from: 0.0);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '🎊 Happy Birthday ${celebrant.firstName}! Keep shining brightly at Saark Exploration! ✨🎂',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: const Color(0xFFF26522),
                duration: const Duration(seconds: 4),
              ),
            );
          },
          icon: const Icon(Icons.celebration_rounded, color: Colors.white, size: 18),
          label: const Text(
            'Pop Confetti!',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF26522),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => _SurpriseBirthdayDialog(
                celebrant: celebrant,
                confetti: _confetti,
                controller: _animController,
              ),
            );
          },
          icon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFD54F), size: 18),
          label: const Text(
            'View Celebration Card',
            style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFFD54F), width: 1.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Case B: Colleague Birthdays Card ──────────────────────────────────────

  Widget _buildTeamBirthdayCard({
    required List<BirthdayCelebrant> celebrants,
    required bool isMobile,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E172E),
            Color(0xFF281E3D),
            Color(0xFF181324),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFA855F7).withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.6)),
                  ),
                  child: const Text('🎂', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Birthday Celebration! 🎉",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        celebrants.length == 1
                            ? "Join us in wishing our colleague a fantastic Happy Birthday today:"
                            : "Join us in celebrating our colleagues' birthdays today:",
                        style: const TextStyle(
                          color: Color(0xFFD1C4E9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Celebrant List
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: celebrants.map((c) {
                final alreadyWished = _wishedEmployees.contains(c.id);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF140F22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA855F7).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFF26522),
                        child: Text(
                          c.firstName.isNotEmpty ? c.firstName[0].toUpperCase() : 'E',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              c.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${c.designation} • ${c.departmentName}',
                              style: const TextStyle(
                                color: Color(0xFFB39DDB),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Wish Button
                      TextButton.icon(
                        onPressed: alreadyWished
                            ? null
                            : () {
                                setState(() => _wishedEmployees.add(c.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '🎈 You sent your warmest birthday wishes to ${c.fullName}! 🎉',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    backgroundColor: const Color(0xFF8B5CF6),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              },
                        icon: Icon(
                          alreadyWished ? Icons.check_circle_rounded : Icons.favorite_rounded,
                          size: 15,
                          color: alreadyWished ? Colors.greenAccent : const Color(0xFFFF4081),
                        ),
                        label: Text(
                          alreadyWished ? 'Wished' : 'Send Wishes',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: alreadyWished ? Colors.greenAccent : Colors.white,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: alreadyWished
                              ? Colors.green.withValues(alpha: 0.15)
                              : const Color(0xFFFF4081).withValues(alpha: 0.2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Surprise Birthday Dialog Overlay ────────────────────────────────────────

class _SurpriseBirthdayDialog extends StatelessWidget {
  final BirthdayCelebrant celebrant;
  final List<_ConfettiPiece> confetti;
  final AnimationController controller;

  const _SurpriseBirthdayDialog({
    required this.celebrant,
    required this.confetti,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = celebrant.firstName.isNotEmpty
        ? celebrant.firstName
        : celebrant.fullName;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1002),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFD54F),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8F00).withValues(alpha: 0.5),
              blurRadius: 36,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Confetti canvas
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _ConfettiPainter(
                        confetti: confetti,
                        progress: controller.value,
                      ),
                    );
                  },
                ),
              ),

              // Card Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎂', style: TextStyle(fontSize: 54)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFD54F)),
                      ),
                      child: const Text(
                        '✨ SPECIAL BIRTHDAY CELEBRATION ✨',
                        style: TextStyle(
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Happy Birthday, $displayName!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Warmest and happiest birthday wishes from all of us at Saark Exploration Private Limited!\n\nMay this year grant you outstanding achievements, enduring prosperity, and great health. Thank you for being a vital pillar of our success.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFFFECB3),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.celebration_rounded, color: Colors.white),
                      label: const Text(
                        'Thank You, Saark Family! 🎉',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF26522),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Confetti Animation Helpers ──────────────────────────────────────────────

class _ConfettiPiece {
  final double x;
  final double y;
  final double size;
  final double speed;
  final Color color;
  final double rotation;
  final bool isCircle;

  _ConfettiPiece({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
    required this.rotation,
    required this.isCircle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> confetti;
  final double progress;

  _ConfettiPainter({required this.confetti, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in confetti) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;

      final currentY = ((p.y + progress * p.speed) % 1.0) * size.height;
      final currentX = (p.x * size.width) + math.sin(progress * math.pi * 2 + p.x * 10) * 12;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(p.rotation + progress * math.pi * 2);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
