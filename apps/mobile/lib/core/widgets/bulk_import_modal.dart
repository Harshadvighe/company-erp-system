import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/core/theme/app_theme.dart';
import 'package:saark_erp_mobile/core/utils/web_utils.dart';
import 'package:saark_erp_mobile/core/network/bulk_import_repository.dart';

class BulkImportModal extends ConsumerStatefulWidget {
  final String target; // 'CUSTOMER' | 'VENDOR'
  final VoidCallback onImportComplete;

  const BulkImportModal({
    super.key,
    required this.target,
    required this.onImportComplete,
  });

  static Future<void> show(
    BuildContext context, {
    required String target,
    required VoidCallback onImportComplete,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleRadius(16),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1100,
            maxHeight: 750,
          ),
          child: BulkImportModal(
            target: target,
            onImportComplete: onImportComplete,
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<BulkImportModal> createState() => _BulkImportModalState();
}

class _BulkImportModalState extends ConsumerState<BulkImportModal> {
  int _currentStep =
      0; // 0 = Upload, 1 = Preview & Mapping, 2 = Execution/Results
  String? _selectedFileName;
  List<int>? _selectedFileBytes;
  bool _isLoading = false;
  String? _errorMessage;

  // Options
  bool _enableGstEnrichment = true;
  bool _checkDuplicates = true;
  bool _skipDuplicates = true;
  bool _updateExisting = false;

  // Preview Data
  Map<String, dynamic>? _previewData;
  List<Map<String, dynamic>> _rows = [];
  String _previewFilter = 'ALL'; // ALL, VALID, REVIEW, DUPLICATE, INVALID
  final _previewSearchCtrl = TextEditingController();

  // Execution Result
  Map<String, dynamic>? _executionResult;
  bool _isImporting = false;
  double _importProgress = 0.0;

  @override
  void dispose() {
    _previewSearchCtrl.dispose();
    super.dispose();
  }

  String get _targetTitle =>
      widget.target == 'CUSTOMER' ? 'Customer / Company' : 'Vendor';

  void _pickSpreadsheetFile() {
    pickAndUploadWebFile(
      fieldType: 'EXCEL',
      onFilePicked: (fileName, bytes) {
        setState(() {
          _selectedFileName = fileName;
          _selectedFileBytes = bytes;
          _errorMessage = null;
        });
      },
    );
  }

  Future<void> _startParsingAndPreview() async {
    if (_selectedFileBytes == null || _selectedFileName == null) {
      setState(() => _errorMessage =
          'Please select a spreadsheet file (.xlsx or .csv) first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(bulkImportRepositoryProvider);
      final result = await repo.parseAndPreview(
        target: widget.target,
        fileName: _selectedFileName!,
        bytes: _selectedFileBytes!,
        enableGstEnrichment: _enableGstEnrichment,
        checkDuplicates: _checkDuplicates,
      );

      final rawRows = (result['rows'] as List? ?? [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();

      setState(() {
        _previewData = result;
        _rows = rawRows;
        _currentStep = 1;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to parse file: $e';
      });
    }
  }

  Future<void> _executeImport() async {
    final selectedRows = _rows.where((r) => r['isIncluded'] == true).toList();
    if (selectedRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rows selected for import')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _currentStep = 2;
      _importProgress = 0.3;
    });

    try {
      final repo = ref.read(bulkImportRepositoryProvider);
      final rowsPayload = selectedRows.map((r) {
        return {
          'rowNumber': r['rowNumber'],
          'data': r['enrichedData'] ?? r['mappedData'] ?? {},
          'gstData': r['gstDetails'],
          'gstVerificationToken': r['gstDetails']?['verificationToken'],
          'isIncluded': true,
        };
      }).toList();

      setState(() => _importProgress = 0.7);

      final result = await repo.executeImport(
        target: widget.target,
        rows: rowsPayload,
        skipDuplicates: _skipDuplicates,
        updateExisting: _updateExisting,
        fileName: _selectedFileName,
      );

      setState(() {
        _executionResult = result;
        _isImporting = false;
        _importProgress = 1.0;
      });

      final importedCount = (result['successCount'] as num?)?.toInt() ?? 0;
      final updatedCount = (result['updatedCount'] as num?)?.toInt() ?? 0;
      if (importedCount > 0 || updatedCount > 0) {
        widget.onImportComplete();
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _errorMessage = 'Import execution error: $e';
      });
    }
  }

  List<Map<String, dynamic>> _collectImportIssues() {
    final errors = <Map<String, dynamic>>[];
    final reportedRows = <String>{};
    final executionStatusByRow = <String, String>{};
    if (_executionResult != null && _executionResult!['errors'] is List) {
      for (final item in _executionResult!['errors']) {
        final error = Map<String, dynamic>.from(item as Map);
        errors.add(error);
        reportedRows.add(error['rowNumber'].toString());
      }
    }
    if (_executionResult != null && _executionResult!['rowResults'] is List) {
      for (final item in _executionResult!['rowResults']) {
        final row = Map<String, dynamic>.from(item as Map);
        executionStatusByRow[row['rowNumber'].toString()] =
            row['status']?.toString() ?? '';
        if ((row['status'] == 'SKIPPED' || row['status'] == 'FAILED') &&
            reportedRows.add(row['rowNumber'].toString())) {
          errors.add({
            'rowNumber': row['rowNumber'],
            'companyName': row['companyName'],
            'code': row['status'],
            'message': row['error'] ?? 'Import row was not created',
            'recommendation': 'Review the row and retry if appropriate',
          });
        }
      }
    }
    for (final row in _rows) {
      final lookupFailed = row['gstLookupStatus'] == 'LOOKUP_FAILED' ||
          row['gstLookupStatus'] == 'INVALID';
      final duplicate = row['validationStatus'] == 'DUPLICATE_EXACT' ||
          row['validationStatus'] == 'DUPLICATE_POSSIBLE';
      final rowStatus = executionStatusByRow[row['rowNumber'].toString()];
      final hasImportIssue = row['validationStatus'] == 'INVALID' ||
          (duplicate && rowStatus != 'IMPORTED' && rowStatus != 'UPDATED') ||
          lookupFailed;
      if (hasImportIssue && reportedRows.add(row['rowNumber'].toString())) {
        errors.add({
          'rowNumber': row['rowNumber'],
          'companyName': row['enrichedData']?['companyName'] ??
              row['mappedData']?['companyName'],
          'gstin': row['mappedData']?['gstin'],
          'code':
              lookupFailed ? row['gstLookupStatus'] : row['validationStatus'],
          'message': [
            ...(row['errors'] as List? ?? []),
            ...(row['warnings'] as List? ?? []),
            if (row['gstStatusReason'] != null) row['gstStatusReason'],
          ].join('; '),
          'recommendation': lookupFailed
              ? 'Retry GST lookup or provide the company name'
              : 'Verify company details and GSTIN correctness',
        });
      }
    }

    return errors;
  }

  void _downloadErrorReport() {
    final errors = _collectImportIssues();
    ref.read(bulkImportRepositoryProvider).downloadErrorReport(
          target: widget.target,
          errors: errors,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildDialogHeader(),
        _buildStepIndicator(),
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _currentStep == 0
                  ? _buildUploadStep()
                  : _currentStep == 1
                      ? _buildPreviewStep()
                      : _buildResultsStep(),
        ),
        _buildDialogFooter(),
      ],
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.upload_file,
                color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk Import $_targetTitle Records',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Excel / CSV import with automatic GST data discovery, validation & conflict preview',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = [
      'Upload & Settings',
      'Data Preview & Review',
      'Import Execution'
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: AppTheme.darkBackground,
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = _currentStep == index;
          final isDone = _currentStep > index;
          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isDone
                      ? AppTheme.success
                      : isActive
                          ? AppTheme.primary
                          : Colors.grey.shade800,
                  child: isDone
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isActive ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? Colors.white
                        : isDone
                            ? Colors.grey.shade300
                            : Colors.grey,
                  ),
                ),
                if (index < steps.length - 1)
                  const Expanded(
                      child: Divider(
                          indent: 10,
                          endIndent: 10,
                          color: AppTheme.darkBorder)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Analyzing spreadsheet and verifying GST registrations...',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'Fetching legal names, trade names, addresses & GST status from portal',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ─── STEP 0: UPLOAD & SETTINGS ─────────────────────────────────────────────
  Widget _buildUploadStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.error),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppTheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: AppTheme.error))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Drop / Pick Card
          InkWell(
            onTap: _pickSpreadsheetFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedFileName != null
                      ? AppTheme.primary
                      : AppTheme.darkBorder,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFileName != null
                        ? Icons.task_alt
                        : Icons.cloud_upload_outlined,
                    size: 48,
                    color: _selectedFileName != null
                        ? AppTheme.primary
                        : Colors.grey,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFileName ??
                        'Click to choose an Excel (.xlsx) or CSV (.csv) file',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _selectedFileName != null
                          ? AppTheme.primary
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedFileBytes != null
                        ? '${(_selectedFileBytes!.length / 1024).toStringAsFixed(1)} KB selected'
                        : 'Supported formats: .xlsx, .csv (Max 1000 rows, 15MB)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Template & Info Bar
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(bulkImportRepositoryProvider)
                    .downloadSampleTemplate(widget.target),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download Sample Template (.csv)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent),
                ),
              ),
              const Spacer(),
              const Text(
                'Flexible headings & GST auto-detection supported',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Enrichment and Validation Options
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Import & Enrichment Settings',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-Fetch GST Portal Information',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                    'Automatically look up verified business name, trade name, registered address, PAN, and active GST status',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  value: _enableGstEnrichment,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (val) =>
                      setState(() => _enableGstEnrichment = val),
                ),
                const Divider(color: AppTheme.darkBorder),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Check Database for Duplicates',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                    'Flag matching GSTINs, phone numbers, and company names already present in system',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  value: _checkDuplicates,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (val) => setState(() => _checkDuplicates = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── STEP 1: PREVIEW & REVIEW ──────────────────────────────────────────────
  Widget _buildPreviewStep() {
    final meta = _previewData ?? {};
    final filtered = _getFilteredRows();

    return Column(
      children: [
        // Summary Count Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: AppTheme.darkCard,
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildCountChip(
                  'Total', meta['totalRows'] ?? 0, Colors.grey, 'ALL'),
              _buildCountChip(
                  'Valid', meta['validRows'] ?? 0, AppTheme.success, 'VALID'),
              _buildCountChip('Review / Warnings', meta['warningRows'] ?? 0,
                  Colors.amber, 'REVIEW'),
              _buildCountChip('Duplicates', meta['duplicateRows'] ?? 0,
                  Colors.orange, 'DUPLICATE'),
              _buildCountChip('Invalid', meta['invalidRows'] ?? 0,
                  AppTheme.error, 'INVALID'),
              _buildGstSummaryBadge(
                  meta['gstSuccessCount'] ?? 0, meta['gstFailCount'] ?? 0),
              if ((meta['gstFailCount'] as num? ?? 0) > 0)
                OutlinedButton.icon(
                  onPressed: _startParsingAndPreview,
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text('Retry GST lookups'),
                ),
            ],
          ),
        ),

        // Search & Options Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.darkBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _previewSearchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search within preview...',
                      prefixIcon: const Icon(Icons.search, size: 16),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: AppTheme.darkBorder),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _skipDuplicates,
                    activeColor: AppTheme.primary,
                    onChanged: (v) =>
                        setState(() => _skipDuplicates = v ?? true),
                  ),
                  const Text('Skip Duplicates', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 10),
                  Checkbox(
                    value: _updateExisting,
                    activeColor: AppTheme.primary,
                    onChanged: (v) =>
                        setState(() => _updateExisting = v ?? false),
                  ),
                  const Text('Update Existing on Match',
                      style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),

        // Table List
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('No records match the current filter',
                      style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(AppTheme.darkBackground),
                      columnSpacing: 16,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 56,
                      columns: const [
                        DataColumn(
                            label: Text('Inc',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Row #',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Company Name',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('GSTIN & Verification',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Contact Person & Phone',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Location',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Validation Status',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                        DataColumn(
                            label: Text('Details / Diff',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold))),
                      ],
                      rows: filtered.map((row) {
                        final isIncluded = row['isIncluded'] == true;
                        final mapped =
                            row['mappedData'] as Map<String, dynamic>? ?? {};
                        final enriched =
                            row['enrichedData'] as Map<String, dynamic>? ?? {};
                        final gstDetails =
                            row['gstDetails'] as Map<String, dynamic>?;
                        final rowNum = row['rowNumber'];
                        final valStatus =
                            row['validationStatus']?.toString() ?? 'VALID';
                        final gstStatus = row['gstLookupStatus']?.toString() ??
                            'NOT_APPLICABLE';
                        final warnings = row['warnings'] as List? ?? [];
                        final errors = row['errors'] as List? ?? [];
                        final conflicts = row['conflicts'] as List? ?? [];

                        return DataRow(
                          selected: isIncluded,
                          onSelectChanged: (val) {
                            setState(() {
                              row['isIncluded'] = val ?? false;
                            });
                          },
                          cells: [
                            DataCell(
                              Checkbox(
                                value: isIncluded,
                                activeColor: AppTheme.primary,
                                onChanged: (val) {
                                  setState(() {
                                    row['isIncluded'] = val ?? false;
                                  });
                                },
                              ),
                            ),
                            DataCell(Text('$rowNum',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey))),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    enriched['companyName'] ??
                                        mapped['companyName'] ??
                                        '(Missing Name)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: enriched['companyName'] != null
                                          ? Colors.white
                                          : AppTheme.error,
                                    ),
                                  ),
                                  if (gstDetails != null &&
                                      gstDetails['legalName'] != null &&
                                      gstDetails['legalName'] !=
                                          enriched['companyName'])
                                    Text('Legal: ${gstDetails['legalName']}',
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                            DataCell(
                              _buildGstCell(mapped['gstin'], gstStatus,
                                  row['gstStatusReason']),
                            ),
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                      enriched['contactPerson'] ??
                                          mapped['contactPerson'] ??
                                          '-',
                                      style: const TextStyle(fontSize: 12)),
                                  Text(
                                      enriched['phone'] ??
                                          mapped['phone'] ??
                                          '-',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                [
                                  enriched['city'] ?? mapped['city'],
                                  enriched['state'] ?? mapped['state']
                                ]
                                    .where((s) =>
                                        s != null && s.toString().isNotEmpty)
                                    .join(', '),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              _buildStatusBadge(
                                  valStatus, errors, warnings, conflicts),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.info_outline, size: 18),
                                tooltip: 'View Details & Conflicts',
                                onPressed: () => _showRowDetailsModal(row),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildGstCell(String? gstin, String status, String? reason) {
    if (gstin == null || gstin.isEmpty) {
      return const Text('NO GST',
          style: TextStyle(fontSize: 11, color: Colors.grey));
    }

    Color badgeColor = Colors.grey;
    IconData badgeIcon = Icons.help_outline;
    String label = 'Pending';

    if (status == 'VERIFIED') {
      badgeColor = AppTheme.success;
      badgeIcon = Icons.verified;
      label = 'Verified';
    } else if (status == 'INVALID') {
      badgeColor = AppTheme.error;
      badgeIcon = Icons.cancel;
      label = 'Invalid';
    } else if (status == 'LOOKUP_FAILED') {
      badgeColor = Colors.amber;
      badgeIcon = Icons.warning_amber;
      label = 'Lookup Failed';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(gstin,
            style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: badgeColor,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(
      String status, List errors, List warnings, List conflicts) {
    Color color = AppTheme.success;
    String text = 'Valid';
    if (status == 'INVALID') {
      color = AppTheme.error;
      text = 'Invalid';
    } else if (status == 'DUPLICATE_EXACT') {
      color = Colors.orange;
      text = 'Exact Duplicate';
    } else if (status == 'DUPLICATE_POSSIBLE') {
      color = Colors.orangeAccent;
      text = 'Possible Dup';
    } else if (status == 'WARNING' ||
        warnings.isNotEmpty ||
        conflicts.isNotEmpty) {
      color = Colors.amber;
      text = 'Review (${warnings.length + conflicts.length})';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCountChip(
      String label, int count, Color color, String filterKey) {
    final isSelected = _previewFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _previewFilter = filterKey),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.25)
              : AppTheme.darkBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? color : AppTheme.darkBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: ',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text('$count',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildGstSummaryBadge(int success, int fail) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blueAccent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 14, color: Colors.blueAccent),
          const SizedBox(width: 4),
          Text('GST Lookups: $success verified',
              style: const TextStyle(
                  fontSize: 11,
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold)),
          if (fail > 0)
            Text(' ($fail failed)',
                style: const TextStyle(fontSize: 11, color: Colors.amber)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredRows() {
    final q = _previewSearchCtrl.text.trim().toLowerCase();
    return _rows.where((row) {
      final status = row['validationStatus']?.toString() ?? '';
      if (_previewFilter == 'VALID' && status != 'VALID') return false;
      if (_previewFilter == 'INVALID' && status != 'INVALID') return false;
      if (_previewFilter == 'DUPLICATE' && !status.startsWith('DUPLICATE')) {
        return false;
      }
      if (_previewFilter == 'REVIEW' && status != 'WARNING') return false;

      if (q.isNotEmpty) {
        final mapped = row['mappedData'] as Map<String, dynamic>? ?? {};
        final enriched = row['enrichedData'] as Map<String, dynamic>? ?? {};
        final name = (enriched['companyName'] ?? mapped['companyName'] ?? '')
            .toString()
            .toLowerCase();
        final gst = (mapped['gstin'] ?? '').toString().toLowerCase();
        final phone = (mapped['phone'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !gst.contains(q) && !phone.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _showRowDetailsModal(Map<String, dynamic> row) {
    final enriched = row['enrichedData'] as Map<String, dynamic>? ?? {};
    final conflicts = row['conflicts'] as List? ?? [];
    final errors = row['errors'] as List? ?? [];
    final warnings = row['warnings'] as List? ?? [];
    final duplicateInfo = row['duplicateInfo'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: Text('Row #${row['rowNumber']} Details & Field Resolution'),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errors.isNotEmpty) ...[
                  const Text('Errors',
                      style: TextStyle(
                          color: AppTheme.error, fontWeight: FontWeight.bold)),
                  ...errors.map((e) => Text('• $e',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.error))),
                  const SizedBox(height: 12),
                ],
                if (duplicateInfo != null) ...[
                  const Text('Duplicate Match',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold)),
                  Text(duplicateInfo['description']?.toString() ?? '',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.orange)),
                  const SizedBox(height: 12),
                ],
                if (warnings.isNotEmpty) ...[
                  const Text('Warnings',
                      style: TextStyle(
                          color: Colors.amber, fontWeight: FontWeight.bold)),
                  ...warnings.map((w) => Text('• $w',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.amber))),
                  const SizedBox(height: 12),
                ],
                if (conflicts.isNotEmpty) ...[
                  const Text('Field Conflicts (Excel vs GST Portal)',
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold)),
                  ...conflicts.map((c) => Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: AppTheme.darkBackground,
                            borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                c['label']?.toString() ??
                                    c['field']?.toString() ??
                                    '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 11)),
                            Text('Spreadsheet value: "${c['userValue']}"',
                                style: const TextStyle(fontSize: 11)),
                            Text('GST Portal value: "${c['gstValue']}"',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.blueAccent)),
                          ],
                        ),
                      )),
                  const SizedBox(height: 12),
                ],
                const Text('Enriched Data Preview',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppTheme.darkBackground,
                      borderRadius: BorderRadius.circular(6)),
                  child: Column(
                    children: enriched.entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                      width: 120,
                                      child: Text(e.key,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey))),
                                  Expanded(
                                      child: Text('${e.value}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600))),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ─── STEP 2: EXECUTION & RESULTS ───────────────────────────────────────────
  Widget _buildResultsStep() {
    if (_isImporting) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
                value: _importProgress > 0 ? _importProgress : null),
            const SizedBox(height: 20),
            const Text('Importing approved records into database...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
                'Creating records, auto-assigning code sequences, contacts & valuations',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    final res = _executionResult ?? {};
    final successCount = res['successCount'] ?? 0;
    final updatedCount = res['updatedCount'] ?? 0;
    final totalRows = _previewData?['totalRows'] ?? res['totalProcessed'] ?? 0;
    final invalidRows = _previewData?['invalidRows'] ?? 0;
    final gstLookupFailures = _previewData?['gstFailCount'] ?? 0;
    final databaseErrorCount = res['databaseErrorCount'] ?? 0;
    final rowResults = (res['rowResults'] as List? ?? [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final skippedRows = <String>{};
    for (final row in rowResults) {
      if (row['status'] == 'SKIPPED') {
        skippedRows.add(row['rowNumber'].toString());
      }
    }
    for (final row in _rows) {
      if (row['isIncluded'] != true) {
        skippedRows.add(row['rowNumber'].toString());
      }
    }
    final duplicateSkippedCount = skippedRows.length;
    final errors = _collectImportIssues();
    final hasIssues = errors.isNotEmpty ||
        invalidRows > 0 ||
        gstLookupFailures > 0 ||
        duplicateSkippedCount > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: hasIssues ? Colors.amber : AppTheme.success),
            ),
            child: Column(
              children: [
                Icon(
                  hasIssues ? Icons.info : Icons.check_circle,
                  size: 48,
                  color: hasIssues ? Colors.amber : AppTheme.success,
                ),
                const SizedBox(height: 12),
                Text(
                  hasIssues
                      ? 'Bulk Import Completed with Some Warnings/Errors'
                      : 'Bulk Import Completed Successfully!',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildMetric('Excel rows', totalRows, Colors.grey),
                    _buildMetric('Imported', successCount, AppTheme.success),
                    _buildMetric('Updated', updatedCount, Colors.blueAccent),
                    _buildMetric('Duplicates / skipped', duplicateSkippedCount,
                        Colors.orange),
                    _buildMetric('Invalid rows', invalidRows, AppTheme.error),
                    _buildMetric(
                        'GST lookup failures', gstLookupFailures, Colors.amber),
                    _buildMetric('Database save failures', databaseErrorCount,
                        AppTheme.error),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (hasIssues) ...[
            Row(
              children: [
                const Text('Errors & Warnings Log',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _downloadErrorReport,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download Error Report (.csv)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: ListView.separated(
                itemCount: errors.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppTheme.darkBorder),
                itemBuilder: (ctx, i) {
                  final e = errors[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.error.withValues(alpha: 0.2),
                      child: Text('${e['rowNumber']}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.error,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(e['companyName'] ?? 'Row ${e['rowNumber']}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        e['error'] ?? e['message'] ?? 'Validation failure',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric(String label, int value, Color color) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // ─── FOOTER BUTTONS ────────────────────────────────────────────────────────
  Widget _buildDialogFooter() {
    final selectedCount = _rows.where((r) => r['isIncluded'] == true).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.darkBorder)),
      ),
      child: Row(
        children: [
          if (_currentStep == 1)
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text('Back to Upload'),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_currentStep == 2 ? 'Done' : 'Cancel'),
          ),
          const SizedBox(width: 12),
          if (_currentStep == 0)
            ElevatedButton.icon(
              onPressed:
                  _selectedFileBytes != null ? _startParsingAndPreview : null,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Scan & Preview Records'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          if (_currentStep == 1)
            ElevatedButton.icon(
              onPressed: selectedCount > 0 ? _executeImport : null,
              icon: const Icon(Icons.file_download_done, size: 16),
              label: Text('Import $selectedCount Selected Records'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class RoundedRectangleRadius extends RoundedRectangleBorder {
  RoundedRectangleRadius(double radius)
      : super(borderRadius: BorderRadius.circular(radius));
}
