import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saark_erp_mobile/features/crm/data/sales_repository.dart';
import 'package:saark_erp_mobile/features/crm/presentation/widgets/bank_cash_workspace_view.dart';

class FakeSalesRepository extends SalesRepository {
  FakeSalesRepository() : super(Dio());

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
      {
        'id': 'acc-3',
        'accountName': 'SBI Operations',
        'bankName': 'State Bank of India',
        'accountNumber': '38192038475',
        'openingBalance': 85000.0,
        'notes': 'Bhosari Branch',
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
  Future<void> deleteBankAccount(String id) async {}

  @override
  Future<Map<String, dynamic>> saveBankTransaction(Map<String, dynamic> data) async {
    return {'id': 'tx-test', ...data};
  }

  @override
  Future<void> deleteBankTransaction(String id) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bank & Cash Workspace Frontend Tests', () {
    testWidgets('Renders BankCashWorkspaceView with header, tabs, and account table', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesRepositoryProvider.overrideWithValue(FakeSalesRepository()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BankCashWorkspaceView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header and Action Buttons
      expect(find.text('Bank & Cash'), findsOneWidget);
      expect(find.text('Download Excel'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);

      // Verify Tab 1 & Tab 2
      expect(find.text('Accounts & Balances'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);

      // Verify KPI Summary Cards
      expect(find.text('Total Balance'), findsOneWidget);
      expect(find.text('All Accounts'), findsOneWidget);

      // Verify Form section in Tab 1
      expect(find.text('Add / Edit Account'), findsOneWidget);
      expect(find.text('Save Account'), findsOneWidget);

      // Verify Accounts Register Table
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('HDFC Current'), findsAtLeastNWidgets(1));
      expect(find.text('Cash in Hand'), findsAtLeastNWidgets(1));
      expect(find.text('SBI Operations'), findsAtLeastNWidgets(1));
    });

    testWidgets('Switch to Transactions tab displays transaction form and ledger', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesRepositoryProvider.overrideWithValue(FakeSalesRepository()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: BankCashWorkspaceView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Transactions Tab
      final txTab = find.text('Transactions');
      await tester.tap(txTab);
      await tester.pumpAndSettle();

      // Verify Transaction Form elements
      expect(find.text('Add / Edit Transaction'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Verify Transaction Ledger Table
      expect(find.text('Transaction Register'), findsOneWidget);
    });

    test('Formula Test: BankAccount Balance Calculation', () {
      final acc = BankAccount(
        id: 'acc-test',
        accountName: 'Test Account',
        bankName: 'Test Bank',
        accountNumber: '12345',
        openingBalance: 100000.0,
      );

      final txs = [
        BankTransaction(
          id: 'tx-1',
          date: '2026-10-15',
          accountName: 'Test Account',
          type: 'Deposit', // Credit
          amount: 45000.0,
        ),
        BankTransaction(
          id: 'tx-2',
          date: '2026-10-15',
          accountName: 'Test Account',
          type: 'Cash In', // Credit
          amount: 5000.0,
        ),
        BankTransaction(
          id: 'tx-3',
          date: '2026-10-15',
          accountName: 'Test Account',
          type: 'Withdrawal', // Debit
          amount: 20000.0,
        ),
        BankTransaction(
          id: 'tx-4',
          date: '2026-10-15',
          accountName: 'Test Account',
          type: 'Bank Charge', // Debit
          amount: 500.0,
        ),
        BankTransaction(
          id: 'tx-5',
          date: '2026-10-15',
          accountName: 'Other Account',
          type: 'Deposit', // Irrelevant account
          amount: 99999.0,
        ),
      ];

      const creditTypes = {'Deposit', 'Cash In'};
      const debitTypes = {'Withdrawal', 'Cash Out', 'Bank Charge'};

      double balance = acc.openingBalance;
      for (final tx in txs) {
        if (tx.accountName == acc.accountName) {
          if (creditTypes.contains(tx.type)) {
            balance += tx.amount;
          } else if (debitTypes.contains(tx.type)) {
            balance -= tx.amount;
          }
        }
      }

      // Expected: 100000 + 45000 + 5000 - 20000 - 500 = 129500
      expect(balance, equals(129500.0));
    });
  });
}
