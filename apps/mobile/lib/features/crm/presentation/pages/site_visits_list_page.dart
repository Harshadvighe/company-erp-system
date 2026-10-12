import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/features/crm/data/crm_repository.dart';
import 'package:saark_erp_mobile/features/customers/data/customers_repository.dart';

class SiteVisitsListPage extends ConsumerStatefulWidget {
  const SiteVisitsListPage({super.key});

  @override
  ConsumerState<SiteVisitsListPage> createState() => _SiteVisitsListPageState();
}

class _SiteVisitsListPageState extends ConsumerState<SiteVisitsListPage> {
  final _searchController = TextEditingController();
  List<dynamic> _siteVisits = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSiteVisits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSiteVisits() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(crmRepositoryProvider);
      final res = await repo.getSiteVisits(
        search: _searchController.text.trim(),
      );

      setState(() {
        _siteVisits = res['items'] as List<dynamic>? ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  List<String> _parsePhotos(dynamic rawPhotos) {
    if (rawPhotos == null) return [];
    if (rawPhotos is List) {
      return rawPhotos.map((e) => e.toString()).toList();
    }
    if (rawPhotos is String) {
      try {
        final decoded = jsonDecode(rawPhotos);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        if (rawPhotos.contains(',')) {
          return rawPhotos.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        return [rawPhotos];
      }
    }
    return [];
  }

  void _openLogSiteVisitDialog() async {
    final customersRepo = ref.read(customersRepositoryProvider);
    final customersRes = await customersRepo.getCustomers(limit: 100);
    final customersList = customersRes['items'] as List<dynamic>? ?? [];

    if (!mounted) return;

    String? selectedCustomerId;
    final subjectController = TextEditingController(text: 'Electrical & Panel Site Inspection');
    final locationController = TextEditingController();
    final siteConditionController = TextEditingController();
    final voltageController = TextEditingController(text: '415V AC (3-Phase)');
    final pumpHpController = TextEditingController(text: '15');
    final dimensionsController = TextEditingController(text: '800 x 600 x 250 mm');
    final notesController = TextEditingController();
    final photosController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_city_rounded, color: Colors.amber),
                ),
                const SizedBox(width: 12),
                const Text('Log Engineering Site Visit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Company / Customer *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCustomerId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'Select Customer',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: customersList.map<DropdownMenuItem<String>>((c) {
                        return DropdownMenuItem<String>(
                          value: c['id']?.toString(),
                          child: Text(
                            '${c['companyName'] ?? 'Unknown'} (${c['customerCode'] ?? 'CUS'})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedCustomerId = val),
                    ),
                    const SizedBox(height: 16),
                    const Text('Inspection Subject *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: subjectController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Water Treatment Plant Feasibility Visit',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Site Location / Address *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: locationController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Plot No 42, MIDC Industrial Area, Pune',
                        prefixIcon: const Icon(Icons.place_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Voltage Reading', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: voltageController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. 415V, 230V',
                                  prefixIcon: const Icon(Icons.bolt, size: 20, color: Colors.amber),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pump Rating (HP)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: pumpHpController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: 'e.g. 15',
                                  prefixIcon: const Icon(Icons.speed, size: 20, color: Colors.blue),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Panel Dimensions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: dimensionsController,
                                decoration: InputDecoration(
                                  hintText: 'W x H x D (mm)',
                                  prefixIcon: const Icon(Icons.aspect_ratio, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Site Environment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: siteConditionController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. Indoors / High Humidity / Dusty',
                                  prefixIcon: const Icon(Icons.thermostat, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Engineering Observations & Notes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Cable run length, space availability, busbar requirements, customer requests...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Site Photo URLs (comma-separated)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: photosController,
                      decoration: InputDecoration(
                        hintText: 'https://example.com/site1.jpg, https://example.com/site2.jpg',
                        prefixIcon: const Icon(Icons.photo_camera_back_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save Inspection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onPressed: () async {
                  if (selectedCustomerId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a customer')),
                    );
                    return;
                  }
                  if (locationController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter site location')),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  try {
                    final rawPhotos = photosController.text.trim();
                    List<String>? photoList;
                    if (rawPhotos.isNotEmpty) {
                      photoList = rawPhotos.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                    }

                    final repo = ref.read(crmRepositoryProvider);
                    await repo.createSiteVisit({
                      'customerId': selectedCustomerId,
                      'subject': subjectController.text.trim(),
                      'location': locationController.text.trim(),
                      'siteCondition': siteConditionController.text.trim(),
                      'voltageReading': voltageController.text.trim(),
                      'pumpRatingHp': double.tryParse(pumpHpController.text.trim()),
                      'panelDimensions': dimensionsController.text.trim(),
                      'inspectionNotes': notesController.text.trim(),
                      if (photoList != null && photoList.isNotEmpty) 'photoUrls': photoList,
                    });

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Site visit logged successfully!')),
                      );
                      _loadSiteVisits();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to log site visit: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Engineering Site Visits & Inspections'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _loadSiteVisits,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: const Text('Log Site Visit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: _openLogSiteVisitDialog,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryBar(),
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    final total = _siteVisits.length;
    int withPump = 0;
    int withVoltage = 0;
    for (final v in _siteVisits) {
      if (v['pumpRatingHp'] != null) withPump++;
      if (v['voltageReading'] != null && v['voltageReading'].toString().isNotEmpty) withVoltage++;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          _buildStatChip(Icons.location_on, 'Total Inspections', total.toString(), Colors.blue),
          const SizedBox(width: 16),
          _buildStatChip(Icons.speed, 'Pump Specs Logged', withPump.toString(), Colors.teal),
          const SizedBox(width: 16),
          _buildStatChip(Icons.bolt, 'Voltage Tested', withVoltage.toString(), Colors.amber.shade800),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppTheme.darkTextSecondary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      color: AppTheme.darkSurface,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search site visits by customer, location, or notes...',
          prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.darkTextSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _loadSiteVisits();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onSubmitted: (_) => _loadSiteVisits(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Error loading site visits: $_error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadSiteVisits, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_siteVisits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No engineering site visits found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blueGrey),
            ),
            const SizedBox(height: 8),
            Text(
              'Log electrical measurements, pump specs, and panel space on customer site.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Log First Site Visit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: _openLogSiteVisitDialog,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _siteVisits.length,
      itemBuilder: (context, index) {
        final visit = _siteVisits[index] as Map<String, dynamic>;
        return _buildSiteVisitCard(visit);
      },
    );
  }

  Widget _buildSiteVisitCard(Map<String, dynamic> visit) {
    final activity = visit['activity'] as Map<String, dynamic>? ?? {};
    final customer = activity['customer'] as Map<String, dynamic>? ?? {};
    final contact = activity['contact'] as Map<String, dynamic>? ?? {};
    final staff = activity['staff'] as Map<String, dynamic>? ?? {};

    final companyName = customer['companyName'] ?? 'General Inspection';
    final customerId = customer['id']?.toString();
    final customerCity = customer['city'] ?? '';
    final inspectorName = staff['fullName'] ?? 'Field Engineer';
    final location = visit['location'] ?? 'Customer Facility';
    final siteCondition = visit['siteCondition'];
    final voltage = visit['voltageReading'];
    final pumpHp = visit['pumpRatingHp'];
    final dimensions = visit['panelDimensions'];
    final notes = visit['inspectionNotes'] ?? activity['description'] ?? '';
    final photos = _parsePhotos(visit['photoUrls']);

    DateTime? createdAt;
    if (activity['createdAt'] != null) {
      createdAt = DateTime.tryParse(activity['createdAt'].toString());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.engineering_rounded, color: Colors.amber, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              companyName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          if (createdAt != null)
                            Text(
                              DateFormat('dd MMM yyyy, hh:mm a').format(createdAt),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.place, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$location${customerCity.isNotEmpty ? " • $customerCity" : ""}',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'Inspected by: $inspectorName',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Electrical Specs & Telemetry Grid
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                if (voltage != null && voltage.toString().isNotEmpty)
                  _buildSpecBadge(Icons.bolt, 'Voltage Reading', voltage.toString(), Colors.amber.shade800),
                if (pumpHp != null)
                  _buildSpecBadge(Icons.speed, 'Pump Rating', '${pumpHp.toString()} HP', Colors.blue),
                if (dimensions != null && dimensions.toString().isNotEmpty)
                  _buildSpecBadge(Icons.aspect_ratio, 'Panel Size', dimensions.toString(), Colors.deepPurple),
                if (siteCondition != null && siteCondition.toString().isNotEmpty)
                  _buildSpecBadge(Icons.thermostat, 'Site Environment', siteCondition.toString(), Colors.teal),
                if (contact['name'] != null)
                  _buildSpecBadge(Icons.person_pin, 'Contact Met', contact['name'].toString(), Colors.blueGrey),
              ],
            ),

            if (notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Inspection Observations:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      notes,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],

            if (photos.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Site Photos:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: photos.map((url) {
                  return InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppBar(
                                title: const Text('Site Inspection Photo'),
                                elevation: 0,
                                leading: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Image.network(
                                  url,
                                  errorBuilder: (_, __, ___) => Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Text('Unable to load photo from $url'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image, size: 16, color: Colors.blue),
                          SizedBox(width: 6),
                          Text('View Photo', style: TextStyle(fontSize: 12, color: Colors.blue)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (customerId != null)
                  TextButton.icon(
                    icon: const Icon(Icons.business, size: 16),
                    label: const Text('View Customer 360'),
                    onPressed: () => context.go('/customers/$customerId'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecBadge(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
