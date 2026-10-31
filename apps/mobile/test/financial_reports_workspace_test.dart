import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/financial_reports_workspace_view.dart';

class FakeFinancialReportsSalesRepository extends SalesRepository {
  FakeFinancialReportsSalesRepository() : super(Dio());

  @override
  Future<Map<String, dynamic>> getFinancialReports({String? period}) async {
    return {
      'period': period ?? '2026-10',
      'dashboard': {
        'todaySales': 118100.0,
        'monthlySales': 348100.0,
        'bankBalance': 450000.0,
        'cashBalance': 25000.0,
        'customerOutstanding': 150000.0,
        'vendorOutstanding': 133000.0,
        'monthlyExpense': 114950.0,
        'monthlyProfit': 233150.0,
        'gstPayable': 26218.0,
      },
      'profitAndLoss': {
        'incomeRows': [
          {'category': 'Sales', 'description': 'Total Sales / Revenue', 'amount': 348100.0},
          {'category': 'Sales', 'description': 'Amount Received', 'amount': 265000.0},
          {'category': 'Sales', 'description': 'Pending Receivable', 'amount': 83100.0},
        ],
        'expenseRows': [
          {'category': 'Expense', 'description': 'Rent', 'amount': 45000.0},
          {'category': 'Expense', 'description': 'Electricity', 'amount': 18450.0},
          {'category': 'Expense', 'description': 'Salary', 'amount': 32000.0},
          {'category': 'Expense', 'description': 'Repairs', 'amount': 8500.0},
          {'category': 'Expense', 'description': 'Travel', 'amount': 6800.0},
          {'category': 'Expense', 'description': 'Internet / Mobile', 'amount': 4200.0},
          {'category': 'Expense', 'description': 'Salary Payable', 'amount': 28500.0},
        ],
        'totalIncome': 348100.0,
        'totalExpenses': 143450.0,
        'netProfit': 204650.0,
      },
      'cashFlow': {
        'inflowRows': [
          {'section': 'Operating', 'description': 'Cash received from customers', 'amount': 265000.0},
          {'section': 'Financing', 'description': 'Bank deposits / Cash in', 'amount': 50000.0},
        ],
        'outflowRows': [
          {'section': 'Operating', 'description': 'Business Expenses', 'amount': 114950.0},
          {'section': 'Operating', 'description': 'Vendor / Supplier Payments', 'amount': 65000.0},
          {'section': 'Payroll', 'description': 'Salary Paid', 'amount': 32000.0},
        ],
        'totalInflow': 315000.0,
        'totalOutflow': 211950.0,
        'netCashFlow': 103050.0,
      },
      'balanceSheet': {
        'assetRows': [
          {'section': 'Current Assets', 'item': 'Bank Balance', 'amount': 450000.0},
          {'section': 'Current Assets', 'item': 'Cash in Hand', 'amount': 25000.0},
          {'section': 'Current Assets', 'item': 'Accounts Receivable (AR)', 'amount': 150000.0},
          {'section': 'Current Assets', 'item': 'Inventory / Stock Value', 'amount': 345000.0},
        ],
        'liabilityRows': [
          {'section': 'Current Liabilities', 'item': 'Accounts Payable (AP)', 'amount': 133000.0},
          {'section': 'Current Liabilities', 'item': 'Salary Payable', 'amount': 28500.0},
          {'section': 'Current Liabilities', 'item': 'GST Payable', 'amount': 26218.0},
        ],
        'equityRows': [
          {'section': "Owner's Equity", 'item': 'Net Company Capital', 'amount': 757282.0},
        ],
        'totalAssets': 970000.0,
        'totalLiabilities': 187718.0,
        'totalEquity': 782282.0,
      },
      'outstanding': {
        'totalCustomerOutstanding': 150000.0,
        'totalVendorOutstanding': 133000.0,
        'customerPending': [
          {
            'customer': 'Win Win Distribution Pvt Ltd',
            'invoiceNumber': 'INV-2026-1001',
            'invoiceDate': '2026-10-02',
            'dueDate': '2026-10-25',
            'invoiceAmount': 145000.0,
            'amountReceived': 100000.0,
            'pendingAmount': 45000.0,
            'status': 'Partial',
          },
          {
            'customer': 'TechMech Automation',
            'invoiceNumber': 'INV-2026-1003',
            'invoiceDate': '2026-10-15',
            'dueDate': '2026-11-05',
            'invoiceAmount': 65000.0,
            'amountReceived': 30000.0,
            'pendingAmount': 35000.0,
            'status': 'Partial',
          },
        ],
        'vendorPending': [
          {
            'vendor': 'Apex Copper Conductors Ltd',
            'billNumber': 'BILL-2026-881',
            'billDate': '2026-09-28',
            'dueDate': '2026-10-15',
            'billAmount': 68000.0,
            'amountPaid': 20000.0,
            'pendingAmount': 48000.0,
            'status': 'Overdue',
          },
        ],
      },
    };
  }
}

void main() {
  testWidgets('FinancialReportsWorkspaceView renders all 5 audit tabs and calculates financial metrics', (tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1400, 1000);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(tester.binding.window.clearPhysicalSizeTestValue);

    final fakeRepo = FakeFinancialReportsSalesRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FinancialReportsWorkspaceView(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Navigation & Header
    expect(find.text('Back to Sales Dashboard'), findsOneWidget);
    expect(find.text('Financial Reports'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Export All to Excel'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Refresh All'), findsOneWidget);

    // 2. 5 Audit Notebook Tabs presence
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Profit & Loss'), findsOneWidget);
    expect(find.text('Cash Flow'), findsOneWidget);
    expect(find.text('Balance Sheet'), findsOneWidget);
    expect(find.text('Outstanding'), findsOneWidget);

    // 3. Tab 1: Dashboard 9 KPI Cards
    expect(find.text("Today's Financial Snapshot"), findsOneWidget);
    expect(find.text("Today's Sales"), findsOneWidget);
    expect(find.text('Monthly Sales'), findsOneWidget);
    expect(find.text('Bank Balance'), findsOneWidget);
    expect(find.text('Cash in Hand'), findsOneWidget);
    expect(find.text('Customer Outstanding'), findsOneWidget);
    expect(find.text('Vendor Outstanding'), findsOneWidget);
    expect(find.text('Monthly Expenses'), findsOneWidget);
    expect(find.text('Monthly Profit / Loss'), findsOneWidget);
    expect(find.text('GST Payable'), findsOneWidget);

    // Values formatted in INR ₹
    expect(find.text('₹118,100.00'), findsOneWidget); // Today's Sales
    expect(find.text('₹348,100.00'), findsOneWidget); // Monthly Sales
    expect(find.text('₹233,150.00'), findsOneWidget); // Monthly Profit (348,100 - 114,950)

    // 4. Test Tab 2: Profit & Loss Statement
    await tester.tap(find.text('Profit & Loss'));
    await tester.pumpAndSettle();

    expect(find.text('Profit & Loss Statement'), findsOneWidget);
    expect(find.text('INCOME'), findsOneWidget);
    expect(find.text('Total Income'), findsOneWidget);
    expect(find.text('EXPENSES'), findsOneWidget);
    expect(find.text('Total Expenses'), findsOneWidget);
    expect(find.text('NET OPERATING PROFIT'), findsOneWidget);
    expect(find.text('₹204,650.00'), findsOneWidget);

    // 5. Test Tab 3: Cash Flow Statement
    await tester.tap(find.text('Cash Flow'));
    await tester.pumpAndSettle();

    expect(find.text('Cash Flow Statement'), findsOneWidget);
    expect(find.text('CASH INFLOWS'), findsOneWidget);
    expect(find.text('Total Cash In'), findsOneWidget);
    expect(find.text('CASH OUTFLOWS'), findsOneWidget);
    expect(find.text('Total Cash Out'), findsOneWidget);
    expect(find.text('NET CASH FLOW'), findsOneWidget);
    expect(find.text('₹103,050.00'), findsOneWidget);

    // 6. Test Tab 4: Balance Sheet
    await tester.tap(find.text('Balance Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Balance Sheet'), findsWidgets);
    expect(find.text('ASSETS'), findsOneWidget);
    expect(find.text('Total Assets'), findsOneWidget);
    expect(find.text('LIABILITIES'), findsOneWidget);
    expect(find.text('Total Liabilities'), findsOneWidget);
    expect(find.text('EQUITY'), findsOneWidget);
    expect(find.text("TOTAL EQUITY (Owner's Capital)"), findsOneWidget);

    // 7. Test Tab 5: Outstanding Report
    await tester.tap(find.text('Outstanding'));
    await tester.pumpAndSettle();

    expect(find.text('Outstanding Report'), findsOneWidget);
    expect(find.text('Total Customer Outstanding'), findsOneWidget);
    expect(find.text('Total Vendor Outstanding'), findsOneWidget);
    expect(find.text('Customer Pending Payments'), findsOneWidget);
    expect(find.text('Vendor Pending Payments'), findsOneWidget);
    expect(find.text('Win Win Distribution Pvt Ltd'), findsOneWidget);
    expect(find.text('Apex Copper Conductors Ltd'), findsOneWidget);
  });
}
