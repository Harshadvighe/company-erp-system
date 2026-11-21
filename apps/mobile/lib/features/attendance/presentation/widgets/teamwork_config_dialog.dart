import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/attendance/data/attendance_repository.dart';

class TeamworkConfigDialog extends ConsumerStatefulWidget {
  final VoidCallback onSaved;

  const TeamworkConfigDialog({super.key, required this.onSaved});

  @override
  ConsumerState<TeamworkConfigDialog> createState() => _TeamworkConfigDialogState();
}

class _TeamworkConfigDialogState extends ConsumerState<TeamworkConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _siteUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();

  bool _autoSync = true;
  bool _isLoading = true;
  bool _isTesting = false;
  bool _isSaving = false;
  bool _isSyncing = false;
  String? _testStatusMessage;
  bool _testSuccess = false;
  String? _maskedApiKey;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _siteUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    final repo = ref.read(attendanceRepositoryProvider);

    try {
      final config = await repo.getTeamworkConfig();
      if (mounted) {
        setState(() {
          _siteUrlCtrl.text = config['siteUrl'] ?? '';
          _maskedApiKey = config['apiKeyMasked'] ?? '';
          _autoSync = config['autoSyncEnabled'] ?? true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleTestConnection() async {
    final siteUrl = _siteUrlCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text.trim();

    if (siteUrl.isEmpty) {
      setState(() {
        _testStatusMessage = 'Please enter your Teamwork Site URL (e.g. https://yourcompany.teamwork.com)';
        _testSuccess = false;
      });
      return;
    }

    if (apiKey.isEmpty && (_maskedApiKey == null || _maskedApiKey!.isEmpty)) {
      setState(() {
        _testStatusMessage = 'Please enter your Teamwork API Key or Personal Access Token';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testStatusMessage = 'Connecting to Teamwork API...';
      _testSuccess = false;
    });

    final repo = ref.read(attendanceRepositoryProvider);
    final res = await repo.testTeamworkConnection(
      siteUrl: siteUrl,
      apiKey: apiKey.isNotEmpty ? apiKey : (_maskedApiKey ?? ''),
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = res['success'] == true;
        _testStatusMessage = res['message'] ?? (res['success'] == true ? 'Connection Verified!' : 'Connection Failed');
      });
    }
  }

  Future<void> _handleSaveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final siteUrl = _siteUrlCtrl.text.trim();
    final apiKey = _apiKeyCtrl.text.trim();

    if (apiKey.isEmpty && (_maskedApiKey == null || _maskedApiKey!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide your Teamwork API key')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final repo = ref.read(attendanceRepositoryProvider);

    try {
      final res = await repo.saveTeamworkConfig(
        siteUrl: siteUrl,
        apiKey: apiKey.isNotEmpty ? apiKey : (_maskedApiKey ?? ''),
        autoSync: _autoSync,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(res['message'] ?? 'Teamwork credentials saved successfully!')),
              ],
            ),
            backgroundColor: const Color(0xFF1E222B),
          ),
        );
        widget.onSaved();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleSyncNow() async {
    setState(() => _isSyncing = true);
    final repo = ref.read(attendanceRepositoryProvider);

    try {
      final res = await repo.syncTeamworkPunches();
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(res['message'] ?? 'Teamwork punches synced successfully!')),
              ],
            ),
            backgroundColor: const Color(0xFF1E222B),
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: ${e.toString()}'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF16191F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF262C38), width: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: _isLoading
              ? const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF60A5FA), size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Teamwork Cloud Punching Integration',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Real-time employee manual punching & time-tracking bridge',
                                  style: TextStyle(fontSize: 11, color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF262C38), height: 24),

                      // Site URL Field
                      const Text(
                        'Teamwork Site URL',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _siteUrlCtrl,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'https://yourcompany.teamwork.com',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                          prefixIcon: const Icon(Icons.link_rounded, size: 16, color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF1E222B),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2E3440)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2E3440)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.primary),
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your Teamwork domain' : null,
                      ),
                      const SizedBox(height: 14),

                      // API Key Field
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'API Key / Personal Access Token',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                          ),
                          if (_maskedApiKey != null && _maskedApiKey!.isNotEmpty)
                            Text(
                              'Current: $_maskedApiKey',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _apiKeyCtrl,
                        obscureText: true,
                        style: const TextStyle(fontSize: 13, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _maskedApiKey != null && _maskedApiKey!.isNotEmpty
                              ? 'Enter new API Key (leave blank to keep current)'
                              : 'twp_xxxxxxxxxxxxxxxxxxxxxxxx',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                          prefixIcon: const Icon(Icons.key_rounded, size: 16, color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF1E222B),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2E3440)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF2E3440)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Auto Sync Switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E222B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2E3440)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Automatic Background Sync',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Polls Teamwork time entries every 15 minutes',
                                  style: TextStyle(fontSize: 11, color: Colors.white54),
                                ),
                              ],
                            ),
                            Switch(
                              value: _autoSync,
                              activeColor: AppTheme.primary,
                              onChanged: (val) => setState(() => _autoSync = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Test Status Feedback Message
                      if (_testStatusMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: _testSuccess
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _testSuccess ? Colors.greenAccent : Colors.redAccent,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _testSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                size: 16,
                                color: _testSuccess ? Colors.greenAccent : Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _testStatusMessage!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: _testSuccess ? Colors.greenAccent : Colors.redAccent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Action Buttons
                      Row(
                        children: [
                          // Test Connection
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF38BDF8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isTesting ? null : _handleTestConnection,
                            icon: _isTesting
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF38BDF8)),
                                  )
                                : const Icon(Icons.network_check_rounded, size: 16),
                            label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                          ),
                          const SizedBox(width: 8),

                          // Sync Now
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF3A3D46)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isSyncing ? null : _handleSyncNow,
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                  )
                                : const Icon(Icons.sync_rounded, size: 16),
                            label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                          ),
                          const Spacer(),

                          // Save Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isSaving ? null : _handleSaveConfig,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                  )
                                : const Icon(Icons.save_rounded, size: 16),
                            label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

