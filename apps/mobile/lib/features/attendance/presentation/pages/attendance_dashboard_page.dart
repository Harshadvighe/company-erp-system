import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttendanceDashboardPage extends ConsumerWidget {
  const AttendanceDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance - Biometric Punching Device'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
            tooltip: 'Sync Attendance',
          ),
        ],
      ),
      body: const Center(
        child: Text('Attendance Module - Device Sync Ready'),
      ),
    );
  }
}
