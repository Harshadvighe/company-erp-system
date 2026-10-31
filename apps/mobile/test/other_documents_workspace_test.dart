import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/other_documents_workspace_view.dart';

class FakeOtherDocumentsSalesRepository extends SalesRepository {
  FakeOtherDocumentsSalesRepository() : super(Dio());

  Map<String, dynamic>? lastSavedPayload;

  @override
  Future<List<String>> getOutwardCustomers() async {
    return [
      'Win Win Distribution Pvt Ltd',
      'Naga Pumps Private Limited',
      'TechMech Automation',
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getOutwardCatalog() async {
    return [
      {
        'id': 'cat-1',
        'name': 'AI-PCU02 WITH HMI DISPLAY',
        'capacity': '1 Nos',
        'supplier': 'Saark Exploration Pvt Ltd',
        'price': 50000,
        'label': 'AI-PCU02 WITH HMI DISPLAY | 1 Nos | Saark Exploration Pvt Ltd',
      },
      {
        'id': 'cat-2',
        'name': 'AIPCU HMI CONTROLLER MULTIVFD',
        'capacity': '3 Nos',
        'supplier': 'Saark Exploration Pvt Ltd',
        'price': 80000,
        'label': 'AIPCU HMI CONTROLLER MULTIVFD | 3 Nos | Saark Exploration Pvt Ltd',
      },
    ];
  }

  @override
  Future<String> getNextOutwardNumber(String type, String date) async {
    if (type == 'Quotation') return 'Q-20261015-001';
    if (type == 'Delivery Challan') return 'DC-20261015-001';
    return 'DOC-20261015-001';
  }

  @override
  Future<Map<String, dynamic>> saveOutwardDocument(Map<String, dynamic> data) async {
    lastSavedPayload = data;
    return {
      'success': true,
      'documentNo': data['documentNo'],
      'totalAmount': 180000,
    };
  }

  @override
  Future<void> deleteOutwardDocument(String docNo) async {}
}

void main() {
  testWidgets('OtherDocumentsWorkspaceView renders all sections, handles items, and computes totals', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1400, 1000);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    final fakeRepo = FakeOtherDocumentsSalesRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: OtherDocumentsWorkspaceView(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Navigation Button
    expect(find.text('Back to Sales Dashboard'), findsOneWidget);

    // 2. Section 1: Outward Document Details
    expect(find.text('Outward Document Details'), findsOneWidget);
    expect(find.text('Document Type:'), findsOneWidget);
    expect(find.text('Document Date:'), findsOneWidget);
    expect(find.text('Document No.:'), findsOneWidget);
    expect(find.text('Customer Name:'), findsOneWidget);
    expect(find.text('Department:'), findsOneWidget);

    // Default Document Type should be Quotation and Document No should start with Q-
    expect(find.text('Quotation'), findsWidgets);
    expect(find.text('Q-20261015-001'), findsOneWidget);

    // 3. Section 2: Add Product / Material
    expect(find.text('Add Product / Material'), findsOneWidget);
    expect(find.text('Existing Product:'), findsOneWidget);
    expect(find.text('Description:'), findsOneWidget);
    expect(find.text('Qty:'), findsOneWidget);
    expect(find.text('Rate:'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Add Item'), findsOneWidget);

    // 4. Section 3: Items in This Document
    expect(find.text('Items in This Document'), findsOneWidget);
    expect(find.text('Product / Material'), findsOneWidget);
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Document Total: '), findsOneWidget);
    expect(find.text('0.00'), findsOneWidget);
    expect(find.text('No items added to this document yet.'), findsOneWidget);

    // 5. Section 4: Notes and Bottom Actions
    expect(find.text('Notes:'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Save Outward Document'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Back'), findsOneWidget);

    // 6. Test Adding Line Items and Formula: Amount = Qty * Rate, Total = Sum(Amount)
    // Fill description, qty, rate
    final descField = find.widgetWithText(TextFormField, 'Enter part name, specs, capacity, or details');
    await tester.enterText(descField, 'AI-PCU02 WITH HMI DISPLAY 1 Nos');

    // Enter Qty: 2
    final qtyField = find.widgetWithText(TextFormField, '1');
    await tester.enterText(qtyField, '2');

    // Enter Rate: 50000
    final rateField = find.widgetWithText(TextFormField, '0');
    await tester.enterText(rateField, '50000');

    // Tap Add Item
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Item'));
    await tester.pumpAndSettle();

    // Verify first item is added: Amount = 2 * 50000 = 100,000.00
    expect(find.text('AI-PCU02 WITH HMI DISPLAY 1 Nos'), findsOneWidget);
    expect(find.text('100,000.00'), findsWidgets);

    // Add second item: Qty 1, Rate 80000
    await tester.enterText(descField, 'AIPCU HMI CONTROLLER MULTIVFD 3 Nos');
    await tester.enterText(qtyField, '1');
    await tester.enterText(rateField, '80000');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add Item'));
    await tester.pumpAndSettle();

    // Verify Document Total: 100,000 + 80,000 = 180,000.00
    expect(find.text('180,000.00'), findsOneWidget);

    // 7. Test Save Outward Document with Customer Name
    // Enter Customer Name in Autocomplete
    final customerFields = find.byType(TextFormField);
    // Find the customer input field and enter customer name
    await tester.enterText(customerFields.at(2), 'Win Win Distribution Pvt Ltd');
    await tester.pumpAndSettle();

    // Tap Save Outward Document
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save Outward Document'));
    await tester.pumpAndSettle();

    // Verify repo received save payload with 2 items and correct values
    expect(fakeRepo.lastSavedPayload, isNotNull);
    expect(fakeRepo.lastSavedPayload!['documentType'], equals('Quotation'));
    expect(fakeRepo.lastSavedPayload!['customer'], equals('Win Win Distribution Pvt Ltd'));
    final items = fakeRepo.lastSavedPayload!['items'] as List;
    expect(items.length, equals(2));
    expect(items[0]['amount'], equals(100000.0));
    expect(items[1]['amount'], equals(80000.0));
  });
}
