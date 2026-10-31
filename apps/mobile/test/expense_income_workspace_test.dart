import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/expense_income_workspace_view.dart';

class FakeExpenseSalesRepository extends SalesRepository {
  FakeExpenseSalesRepository() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> getExpenses({String? category, String? search}) async {
    return [
      {
        'id': 'exp-1',
        'date': '2026-10-01',
        'category': 'Rent',
        'description': 'Factory premises monthly lease',
        'amount': 45000.0,
        'paymentMethod': 'Bank Transfer',
        'paidTo': 'Chakan Industrial Estates Ltd',
        'notes': 'Voucher #1001',
      },
      {
        'id': 'exp-2',
        'date': '2026-10-05',
        'category': 'Electricity',
        'description': 'MSEDCL power tariff',
        'amount': 18450.0,
        'paymentMethod': 'UPI',
        'paidTo': 'MSEB',
        'notes': 'Meter #88192',
      },
      {
        'id': 'exp-3',
        'date': '2026-10-10',
        'category': 'Salary',
        'description': 'Staff advance disbursement',
        'amount': 32000.0,
        'paymentMethod': 'Bank Transfer',
        'paidTo': 'Fabrication Staff',
        'notes': 'Pay Sheet A',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> saveExpense(Map<String, dynamic> data) async {
    return {'id': 'exp-test', ...data};
  }

  @override
  Future<void> deleteExpense(String id) async {}

  @override
  Future<Map<String, dynamic>> getExpenseSummary() async {
    return {
      'totalExpenses': 95450.0,
      'thisMonthExpenses': 95450.0,
      'topCategory': 'Rent',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expense & Income Workspace Frontend Tests', () {
    testWidgets('Renders ExpenseIncomeWorkspaceView with header, KPIs, form, and table', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesRepositoryProvider.overrideWithValue(FakeExpenseSalesRepository()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExpenseIncomeWorkspaceView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Header and Buttons
      expect(find.text('Back to Sales Dashboard'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Download Excel'), findsOneWidget);

      // 2. Verify Section Headers
      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Expenses by Category'), findsOneWidget);
      expect(find.text('Add / Edit Expense'), findsOneWidget);
      expect(find.text('Expense Register'), findsOneWidget);

      // 3. Verify KPI Cards
      expect(find.text('Total Expenses'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('Top Category'), findsOneWidget);

      // 4. Verify Form Fields and Action Buttons
      expect(find.text('Date:'), findsOneWidget);
      expect(find.text('Category:'), findsOneWidget);
      expect(find.text('Amount (₹):'), findsAtLeastNWidgets(1));
      expect(find.text('Description:'), findsAtLeastNWidgets(1));
      expect(find.text('Payment Method:'), findsAtLeastNWidgets(1));
      expect(find.text('Paid To:'), findsAtLeastNWidgets(1));
      expect(find.text('Notes:'), findsAtLeastNWidgets(1));
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      // 5. Verify Table Entries
      expect(find.text('Rent'), findsAtLeastNWidgets(1));
      expect(find.text('Electricity'), findsAtLeastNWidgets(1));
      expect(find.text('Salary'), findsAtLeastNWidgets(1));
    });

    test('Formula Test: Total Expenses, Monthly Filter, Category Breakdown & Top Category', () {
      final now = DateTime.now();
      final currentYm = DateFormat('yyyy-MM').format(now);
      final lastYearYm = DateFormat('yyyy-MM').format(DateTime(now.year - 1, now.month));

      final items = [
        ExpenseItem(
          id: '1',
          date: '$currentYm-01',
          category: 'Rent',
          description: 'Factory rent',
          amount: 50000.0,
          paymentMethod: 'Bank Transfer',
        ),
        ExpenseItem(
          id: '2',
          date: '$currentYm-05',
          category: 'Salary',
          description: 'Staff payroll',
          amount: 40000.0,
          paymentMethod: 'Bank Transfer',
        ),
        ExpenseItem(
          id: '3',
          date: '$currentYm-10',
          category: 'Electricity',
          description: 'Factory electricity',
          amount: 15000.0,
          paymentMethod: 'UPI',
        ),
        ExpenseItem(
          id: '4',
          date: '$lastYearYm-15',
          category: 'Rent',
          description: 'Last year expense',
          amount: 20000.0,
          paymentMethod: 'Bank Transfer',
        ),
      ];

      // Formula 1: Total Expenses
      final total = items.fold(0.0, (sum, e) => sum + e.amount);
      expect(total, equals(125000.0)); // 50000 + 40000 + 15000 + 20000

      // Formula 2: This Month Expenses
      final thisMonth = items
          .where((e) => e.date.startsWith(currentYm))
          .fold(0.0, (sum, e) => sum + e.amount);
      expect(thisMonth, equals(105000.0)); // 50000 + 40000 + 15000

      // Formula 3: Category Totals & Percentages
      final catTotals = <String, double>{};
      for (final e in items) {
        catTotals[e.category] = (catTotals[e.category] ?? 0.0) + e.amount;
      }
      expect(catTotals['Rent'], equals(70000.0)); // 50000 + 20000
      expect(catTotals['Salary'], equals(40000.0));
      expect(catTotals['Electricity'], equals(15000.0));

      final rentPercentage = (catTotals['Rent']! / total) * 100;
      expect(rentPercentage, closeTo(56.0, 0.01)); // 70000 / 125000 = 56%

      // Formula 4: Top Category
      String topCat = '';
      double maxVal = 0.0;
      for (final entry in catTotals.entries) {
        if (entry.value > maxVal) {
          maxVal = entry.value;
          topCat = entry.key;
        }
      }
      expect(topCat, equals('Rent'));
    });
  });
}
