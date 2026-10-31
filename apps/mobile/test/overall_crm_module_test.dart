import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';
import 'package:saark_erp_mobile/features/crm/presentation/pages/sales_marketing_portal_page.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/customer_vendor_crm_view.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/sales_invoice_workspace_view.dart';
import 'package:saark_erp_mobile/features/products/presentation/widgets/products_services_workspace_view.dart';
import 'package:saark_erp_mobile/features/purchase/presentation/widgets/purchase_procurement_workspace_view.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/bank_cash_workspace_view.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/expense_income_workspace_view.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/other_documents_workspace_view.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/financial_reports_workspace_view.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/company_sorting_workspace_view.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/company_graph_workspace_view.dart';

class FakeCombinedSalesRepository extends SalesRepository {
  FakeCombinedSalesRepository() : super(Dio());

  @override
  Future<List<Map<String, dynamic>>> getBankAccounts() async {
    return [
      {
        'id': 'acc-1',
        'accountName': 'HDFC Current',
        'bankName': 'HDFC Bank',
        'accountNumber': '50200012345678',
        'openingBalance': 150000.0,
        'notes': 'MIDC Chakan Branch',
      },
      {
        'id': 'acc-2',
        'accountName': 'Cash in Hand',
        'bankName': 'Cash',
        'accountNumber': 'CASH-MAIN-01',
        'openingBalance': 25000.0,
        'notes': 'Petty Cash',
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getBankTransactions() async {
    return [
      {
        'id': 'tx-1',
        'date': '2026-10-10',
        'accountName': 'HDFC Current',
        'type': 'Deposit',
        'amount': 54000.0,
        'description': 'Payment receipt against INV-2026-081',
        'reference': 'CMS-NEFT-99182',
        'notes': 'Customer receipt',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> saveBankAccount(Map<String, dynamic> data) async {
    return {'id': 'acc-test', ...data};
  }

  @override
  Future<Map<String, dynamic>> saveBankTransaction(Map<String, dynamic> data) async {
    return {'id': 'tx-test', ...data};
  }

  @override
  Future<Map<String, dynamic>> getBankCashSummary() async {
    return {
      'totalBalance': 175000.0,
      'bankBalance': 150000.0,
      'cashBalance': 25000.0,
      'monthlyDeposit': 265000.0,
      'monthlyWithdrawal': 211950.0,
    };
  }

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
      'totalExpenses': 45000.0,
      'thisMonthExpenses': 45000.0,
      'todayExpenses': 0.0,
      'categoryBreakdown': [
        {'category': 'Rent', 'amount': 45000.0, 'percentage': 100.0},
      ],
    };
  }

  @override
  Future<List<String>> getOutwardCustomers() async {
    return ['Win Win Distribution Pvt Ltd', 'TechMech Automation'];
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
    ];
  }

  @override
  Future<String> getNextOutwardNumber(String type, String date) async {
    return 'DC-20261016-001';
  }

  @override
  Future<Map<String, dynamic>> saveOutwardDocument(Map<String, dynamic> data) async {
    return {'success': true, 'documentNo': data['documentNo'], 'totalAmount': 50000};
  }

  @override
  Future<List<Map<String, dynamic>>> getOutwardEntries() async {
    return [];
  }

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
        ],
        'expenseRows': [
          {'category': 'Expense', 'description': 'Rent', 'amount': 45000.0},
        ],
        'totalIncome': 348100.0,
        'totalExpenses': 45000.0,
        'netProfit': 303100.0,
      },
      'cashFlow': {
        'inflowRows': [
          {'section': 'Operating', 'description': 'Cash received from customers', 'amount': 265000.0},
        ],
        'outflowRows': [
          {'section': 'Operating', 'description': 'Business Expenses', 'amount': 114950.0},
        ],
        'totalInflow': 265000.0,
        'totalOutflow': 114950.0,
        'netCashFlow': 150050.0,
      },
      'balanceSheet': {
        'assetRows': [
          {'section': 'Current Assets', 'item': 'Bank Balance', 'amount': 450000.0},
        ],
        'liabilityRows': [
          {'section': 'Current Liabilities', 'item': 'Accounts Payable (AP)', 'amount': 133000.0},
        ],
        'equityRows': [
          {'section': 'Equity', 'item': 'Current Period Profit', 'amount': 317000.0},
        ],
        'totalAssets': 450000.0,
        'totalLiabilities': 133000.0,
        'totalEquity': 317000.0,
      },
      'outstanding': {
        'receivableRows': [],
        'payableRows': [],
        'totalReceivable': 150000.0,
        'totalPayable': 133000.0,
        'netReceivable': 17000.0,
      },
    };
  }
}

Widget createTestApp({int initialTab = 1}) {
  return ProviderScope(
    overrides: [
      salesRepositoryProvider.overrideWithValue(FakeCombinedSalesRepository()),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1280, 800)),
        child: Scaffold(
          body: SalesMarketingPortalPage(initialTab: initialTab),
        ),
      ),
    ),
  );
}

void main() {
  group('Overall CRM & Sales Portal Mobile Workspace Tests', () {
    void setDesktopViewport(WidgetTester tester) {
      tester.binding.window.physicalSizeTestValue = const Size(1600, 1000);
      tester.binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
    }

    testWidgets('Tab 0 renders Category Selection Pills', (WidgetTester tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(createTestApp(initialTab: 0));
      await tester.pumpAndSettle();

      expect(find.text('Select Product Category'), findsOneWidget);
      expect(find.text('Customer CRM & Leads'), findsOneWidget);
      expect(find.text('Saark Product Sector'), findsOneWidget);
    });

    testWidgets('Tab 1 renders CustomerVendorCrmView and switches sub-modules', (WidgetTester tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(createTestApp(initialTab: 1));
      await tester.pumpAndSettle();

      expect(find.byType(CustomerVendorCrmView), findsOneWidget);

      // Verify Tab 0 (CRM Management) initially active
      expect(find.text('Customer Management & Lead Tracker'), findsOneWidget);

      // Switch to Company Sorting (Tab 2)
      final companySortingTab = find.text('Company Sorting');
      expect(companySortingTab, findsOneWidget);
      await tester.tap(companySortingTab);
      await tester.pumpAndSettle();

      expect(find.byType(CompanySortingWorkspaceView), findsOneWidget);
      expect(find.text('Company Sorting - Filter / Sort Companies'), findsOneWidget);
      expect(find.text('Total: 40 / 40'), findsOneWidget);

      // Switch to Graph (Tab 3)
      final graphTab = find.text('Graph');
      expect(graphTab, findsOneWidget);
      await tester.tap(graphTab);
      await tester.pumpAndSettle();

      expect(find.byType(CompanyGraphWorkspaceView), findsOneWidget);
      expect(find.text('Company Sorting - Graphical Report'), findsOneWidget);
      expect(find.text('Circular Chart'), findsOneWidget);
      expect(find.text('Colour Legend'), findsOneWidget);
      expect(find.text('Product & System | Total: 40'), findsOneWidget);
    });

    testWidgets('Tab 2 renders ProductsServicesWorkspaceView', (WidgetTester tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(createTestApp(initialTab: 2));
      await tester.pumpAndSettle();

      expect(find.byType(ProductsServicesWorkspaceView), findsOneWidget);
    });

    testWidgets('Tab 3 renders SaleInvoiceWorkspaceView', (WidgetTester tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(createTestApp(initialTab: 3));
      await tester.pumpAndSettle();

      expect(find.byType(SaleInvoiceWorkspaceView), findsOneWidget);
    });

    testWidgets('Tab 4 renders PurchaseProcurementWorkspaceView', (WidgetTester tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(createTestApp(initialTab: 4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PurchaseProcurementWorkspaceView), findsOneWidget);
    });

    testWidgets('Tab 5 renders BankCashWorkspaceView with liquidity data', (WidgetTester tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(createTestApp(initialTab: 5));
      await tester.pumpAndSettle();

      expect(find.byType(BankCashWorkspaceView), findsOneWidget);
      expect(find.text('HDFC Current'), findsOneWidget);
      expect(find.text('Cash in Hand'), findsOneWidget);
    });

    testWidgets('Tab 6 renders ExpenseIncomeWorkspaceView with ledger data', (WidgetTester tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(createTestApp(initialTab: 6));
      await tester.pumpAndSettle();

      expect(find.byType(ExpenseIncomeWorkspaceView), findsOneWidget);
      expect(find.text('Chakan Industrial Estates Ltd'), findsOneWidget);
    });

    testWidgets('Tab 7 renders OtherDocumentsWorkspaceView', (WidgetTester tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(createTestApp(initialTab: 7));
      await tester.pumpAndSettle();

      expect(find.byType(OtherDocumentsWorkspaceView), findsOneWidget);
      expect(find.text('Outward Document Details'), findsOneWidget);
    });

    testWidgets('Tab 8 renders FinancialReportsWorkspaceView with 5 financial tabs', (WidgetTester tester) async {
      setDesktopViewport(tester);
      await tester.pumpWidget(createTestApp(initialTab: 8));
      await tester.pumpAndSettle();

      expect(find.byType(FinancialReportsWorkspaceView), findsOneWidget);
      expect(find.text('Financial Reports'), findsOneWidget);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Profit & Loss'), findsOneWidget);
      expect(find.text('Cash Flow'), findsOneWidget);
      expect(find.text('Balance Sheet'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);
    });
  });
}
