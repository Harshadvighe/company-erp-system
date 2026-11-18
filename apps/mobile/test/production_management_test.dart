import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saark_erp_mobile/features/production/data/panel_manufacturing_repository.dart';
import 'package:saark_erp_mobile/features/production/presentation/pages/production_management_page.dart';

class FakePanelManufacturingRepository extends PanelManufacturingRepository {
  FakePanelManufacturingRepository() : super(Dio());

  final List<Map<String, dynamic>> batches = [];
  Map<String, dynamic>? createdBatchPayload;

  @override
  Future<List<Map<String, dynamic>>> getBatches() async => batches;

  @override
  Future<List<Map<String, dynamic>>> getTestedOkProducts() async => [];

  @override
  Future<List<Map<String, dynamic>>> getDispatchLogs() async => [];

  @override
  Future<List<Map<String, dynamic>>> getAssemblyJobs() async => [];

  @override
  Future<List<Map<String, dynamic>>> getTestingRecords({String? batchId}) async => [];

  @override
  Future<Map<String, dynamic>> createBatch(
    Map<String, dynamic> batchData,
  ) async {
    createdBatchPayload = Map<String, dynamic>.from(batchData);
    final batch = {
      'id': 'batch-test-1',
      ...batchData,
      'status': 'IN_PROGRESS',
      'materials': <Map<String, dynamic>>[],
      'completedQuantity': 0,
    };
    batches.insert(0, batch);
    return batch;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates a batch from the simplified mobile-friendly form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakePanelManufacturingRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          panelRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ProductionManagementPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start a production batch'), findsOneWidget);
    expect(find.text('View production batches'), findsOneWidget);

    await tester.tap(find.text('Start a production batch'));
    await tester.pumpAndSettle();

    expect(find.text('Batch details'), findsOneWidget);
    expect(find.text('Batch ID'), findsOneWidget);
    expect(find.text('Choose a product'), findsOneWidget);
    expect(find.text('Quantity to produce'), findsOneWidget);
    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('Target completion date'), findsOneWidget);
    expect(find.text('People assigned (optional)'), findsOneWidget);
    expect(find.text('Notes (optional)'), findsOneWidget);
    expect(find.text('Kickoff / Meeting Date'), findsNothing);
    expect(find.textContaining('SOP-FAT-Panel'), findsNothing);
    expect(find.text('Initial Bill of Materials (BOM) Initialization Preview'), findsNothing);
    expect(find.textContaining('Rahul Verma'), findsNothing);
    expect(tester.takeException(), isNull);

    final startBatchButton = find.widgetWithText(ElevatedButton, 'Start batch');
    await tester.ensureVisible(startBatchButton);
    await tester.pumpAndSettle();
    await tester.tap(startBatchButton);
    await tester.pumpAndSettle();

    expect(repository.createdBatchPayload, isNotNull);
    expect(repository.createdBatchPayload!['productName'], isNotEmpty);
    expect(repository.createdBatchPayload!['targetQuantity'], greaterThan(0));
    expect(repository.createdBatchPayload!['assignedPersonnel'], isEmpty);
    expect(repository.createdBatchPayload!['notes'], isEmpty);
    expect(repository.createdBatchPayload!.containsKey('meetingDate'), isFalse);
    expect(find.textContaining('created & initialized successfully'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
