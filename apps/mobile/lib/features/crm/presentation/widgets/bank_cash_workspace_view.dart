import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/sales_repository.dart';

// ─── Domain Models ─────────────────────────────────────────────────────────────
class BankAccount {
  final String id;
  String accountName;
  String bankName;
  String accountNumber;
  double openingBalance;
  String notes;

  BankAccount({
    required this.id,
    required this.accountName,
    required this.bankName,
    required this.accountNumber,
    required this.openingBalance,
    this.notes = '',
  });

  BankAccount copyWith({
    String? id,
    String? accountName,
    String? bankName,
    String? accountNumber,
    double? openingBalance,
    String? notes,
  }) {
    return BankAccount(
      id: id ?? this.id,
      accountName: accountName ?? this.accountName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      openingBalance: openingBalance ?? this.openingBalance,
      notes: notes ?? this.notes,
    );
  }
}

class BankTransaction {
  final String id;
  String date; // YYYY-MM-DD
  String accountName;
  String type; // Deposit, Withdrawal, Bank Charge, Cash In, Cash Out, Transfer
  double amount;
  String description;
  String reference;
  String notes;

  BankTransaction({
    required this.id,
    required this.date,
    required this.accountName,
    required this.type,
    required this.amount,
    this.description = '',
    this.reference = '',
    this.notes = '',
  });

  BankTransaction copyWith({
    String? id,
    String? date,
    String? accountName,
    String? type,
    double? amount,
    String? description,
    String? reference,
    String? notes,
  }) {
    return BankTransaction(
      id: id ?? this.id,
      date: date ?? this.date,
      accountName: accountName ?? this.accountName,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
    );
  }
}

// ─── Workspace View ───────────────────────────────────────────────────────────
class BankCashWorkspaceView extends ConsumerStatefulWidget {
  final VoidCallback? onBackToDashboard;
  const BankCashWorkspaceView({super.key, this.onBackToDashboard});

  @override
  ConsumerState<BankCashWorkspaceView> createState() =>
      _BankCashWorkspaceViewState();
}

class _BankCashWorkspaceViewState extends ConsumerState<BankCashWorkspaceView> {
  // ─── Active Tab (0 = Accounts & Balances, 1 = Transactions) ──────────────────
  int _activeTab = 0;
  bool _isLoading = false;

  // ─── Accounts State ────────────────────────────────────────────────────────
  final List<BankAccount> _accounts = [];
  int? _selectedAccountIndex;

  // Account Form Controllers
  final _accNameCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accNumberCtrl = TextEditingController();
  final _openingBalCtrl = TextEditingController(text: '0.00');
  final _accNotesCtrl = TextEditingController();

  // ─── Transactions State ────────────────────────────────────────────────────
  final List<BankTransaction> _transactions = [];
  int? _selectedTransactionIndex;

  // Transaction Form Controllers
  final _txDateCtrl = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  String? _selectedTxAccount;
  String _selectedTxType = 'Deposit';
  final _txAmountCtrl = TextEditingController(text: '0.00');
  final _txDescCtrl = TextEditingController();
  final _txRefCtrl = TextEditingController();
  final _txNotesCtrl = TextEditingController();

  // Sort State for Transactions Table
  int _sortColumnIndex = 0; // 0 = Date, 1 = Account, 2 = Type, 3 = Amount
  bool _sortAscending = false;

  // Constants
  static const Set<String> _creditTypes = {'Deposit', 'Cash In'};
  static const Set<String> _debitTypes = {'Withdrawal', 'Cash Out', 'Bank Charge'};
  static const List<String> _transactionTypes = [
    'Deposit',
    'Withdrawal',
    'Bank Charge',
    'Cash In',
    'Cash Out',
    'Transfer',
  ];

  @override
  void initState() {
    super.initState();
    _initializeData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLiveBackendData();
    });
  }

  Future<void> _fetchLiveBackendData({bool showToast = false}) async {
    try {
      final repo = ref.read(salesRepositoryProvider);
      final rawAccounts = await repo.getBankAccounts();
      final rawTxs = await repo.getBankTransactions();

      if (!mounted) return;
      setState(() {
        if (rawAccounts.isNotEmpty) {
          _accounts.clear();
          for (final a in rawAccounts) {
            _accounts.add(
              BankAccount(
                id: a['id']?.toString() ?? 'acc-${DateTime.now().millisecondsSinceEpoch}',
                accountName: a['accountName']?.toString() ?? '',
                bankName: a['bankName']?.toString() ?? 'Bank',
                accountNumber: a['accountNumber']?.toString() ?? '',
                openingBalance: (a['openingBalance'] is num)
                    ? (a['openingBalance'] as num).toDouble()
                    : (double.tryParse(a['openingBalance']?.toString() ?? '0') ?? 0.0),
                notes: a['notes']?.toString() ?? '',
              ),
            );
          }
        }

        if (rawTxs.isNotEmpty) {
          _transactions.clear();
          for (final t in rawTxs) {
            _transactions.add(
              BankTransaction(
                id: t['id']?.toString() ?? 'tx-${DateTime.now().millisecondsSinceEpoch}',
                date: t['date']?.toString() ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
                accountName: t['accountName']?.toString() ?? '',
                type: t['type']?.toString() ?? 'Deposit',
                amount: (t['amount'] is num)
                    ? (t['amount'] as num).toDouble()
                    : (double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0),
                description: t['description']?.toString() ?? '',
                reference: t['reference']?.toString() ?? '',
                notes: t['notes']?.toString() ?? '',
              ),
            );
          }
        }

        if (_accounts.isNotEmpty &&
            (_selectedTxAccount == null || !_accounts.any((a) => a.accountName == _selectedTxAccount))) {
          _selectedTxAccount = _accounts.first.accountName;
        }
      });

      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accounts and live transactions synchronized with backend!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to sync bank/cash data: $e');
      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded cached offline data ($e)'),
            backgroundColor: const Color(0xFFE57A38),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initializeData() {
    // Populate default baseline accounts
    _accounts.addAll([
      BankAccount(
        id: 'acc-1',
        accountName: 'HDFC Current',
        bankName: 'HDFC Bank',
        accountNumber: '50200012345678',
        openingBalance: 150000.00,
        notes: 'MIDC Chakan Branch, IFSC: HDFC0001234',
      ),
      BankAccount(
        id: 'acc-2',
        accountName: 'Cash in Hand',
        bankName: 'Cash',
        accountNumber: 'CASH-MAIN-01',
        openingBalance: 25000.00,
        notes: 'Main Office Petty Cash Register',
      ),
      BankAccount(
        id: 'acc-3',
        accountName: 'SBI Operations',
        bankName: 'State Bank of India',
        accountNumber: '38192038475',
        openingBalance: 85000.00,
        notes: 'Bhosari Industrial Branch, IFSC: SBIN0004512',
      ),
    ]);

    _selectedTxAccount = _accounts.first.accountName;

    // Populate baseline ledger transactions
    _transactions.addAll([
      BankTransaction(
        id: 'tx-1',
        date: '2026-10-10',
        accountName: 'HDFC Current',
        type: 'Deposit',
        amount: 54000.00,
        description: 'Payment receipt against INV-2026-081',
        reference: 'CMS-NEFT-99182',
        notes: 'Customer: Satyam Engineering',
      ),
      BankTransaction(
        id: 'tx-2',
        date: '2026-10-12',
        accountName: 'HDFC Current',
        type: 'Withdrawal',
        amount: 22000.00,
        description: 'Vendor payment for Copper Busbars',
        reference: 'RTGS-00291-VND',
        notes: 'Vendor: Metal Craft Supplies',
      ),
      BankTransaction(
        id: 'tx-3',
        date: '2026-10-14',
        accountName: 'Cash in Hand',
        type: 'Cash Out',
        amount: 3500.00,
        description: 'Workshop maintenance & consumable tools',
        reference: 'VCH-8812',
        notes: 'Admin Petty Voucher',
      ),
      BankTransaction(
        id: 'tx-4',
        date: '2026-10-15',
        accountName: 'HDFC Current',
        type: 'Bank Charge',
        amount: 590.00,
        description: 'Quarterly bank ledger maintenance & GST',
        reference: 'BNK-CHG-Q2',
        notes: 'Auto Debit',
      ),
      BankTransaction(
        id: 'tx-5',
        date: '2026-10-15',
        accountName: 'SBI Operations',
        type: 'Deposit',
        amount: 30000.00,
        description: 'Advance received for Solar Control Panel',
        reference: 'IMPS-20261015-812',
        notes: 'Client: Apex Solar Solutions',
      ),
    ]);
  }

  @override
  void dispose() {
    _accNameCtrl.dispose();
    _bankNameCtrl.dispose();
    _accNumberCtrl.dispose();
    _openingBalCtrl.dispose();
    _accNotesCtrl.dispose();

    _txDateCtrl.dispose();
    _txAmountCtrl.dispose();
    _txDescCtrl.dispose();
    _txRefCtrl.dispose();
    _txNotesCtrl.dispose();
    super.dispose();
  }

  // ─── Mathematical Formulas ─────────────────────────────────────────────────
  /// Formula 1: Real-time Account Balance
  /// Current_Balance = Opening_Balance + Sum(Credit_Types) - Sum(Debit_Types)
  double _computeAccountBalance(BankAccount acc) {
    double balance = acc.openingBalance;
    for (final tx in _transactions) {
      if (tx.accountName.toLowerCase().trim() ==
          acc.accountName.toLowerCase().trim()) {
        if (_creditTypes.contains(tx.type)) {
          balance += tx.amount;
        } else if (_debitTypes.contains(tx.type)) {
          balance -= tx.amount;
        }
      }
    }
    return balance;
  }

  /// Formula 2: Aggregated Total Cash & Bank Balance
  /// Total_Balance = Sum(Current_Balance of all registered Accounts)
  double get _totalBalance {
    return _accounts.fold(0.0, (sum, acc) => sum + _computeAccountBalance(acc));
  }

  String _formatCurrency(double amount) {
    try {
      final formatter = NumberFormat('#,##,##0.00');
      return '₹${formatter.format(amount)}';
    } catch (_) {
      return '₹${amount.toStringAsFixed(2)}';
    }
  }

  // ─── Account Actions ───────────────────────────────────────────────────────
  void _selectAccount(int index) {
    setState(() {
      _selectedAccountIndex = index;
      final acc = _accounts[index];
      _accNameCtrl.text = acc.accountName;
      _bankNameCtrl.text = acc.bankName;
      _accNumberCtrl.text = acc.accountNumber;
      _openingBalCtrl.text = acc.openingBalance.toStringAsFixed(2);
      _accNotesCtrl.text = acc.notes;
    });
  }

  void _clearAccountForm() {
    setState(() {
      _selectedAccountIndex = null;
      _accNameCtrl.clear();
      _bankNameCtrl.clear();
      _accNumberCtrl.clear();
      _openingBalCtrl.text = '0.00';
      _accNotesCtrl.clear();
    });
  }

  Future<void> _saveAccount() async {
    final name = _accNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Account Name.'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    final bank = _bankNameCtrl.text.trim().isEmpty
        ? 'Bank'
        : _bankNameCtrl.text.trim();
    final accNo = _accNumberCtrl.text.trim();
    final opening = double.tryParse(_openingBalCtrl.text.trim()) ?? 0.0;
    final notes = _accNotesCtrl.text.trim();

    final isEdit = _selectedAccountIndex != null &&
        _selectedAccountIndex! < _accounts.length;
    final targetId = isEdit ? _accounts[_selectedAccountIndex!].id : null;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(salesRepositoryProvider);
      await repo.saveBankAccount({
        if (targetId != null) 'id': targetId,
        'accountName': name,
        'bankName': bank,
        'accountNumber': accNo,
        'openingBalance': opening,
        'notes': notes,
      });

      await _fetchLiveBackendData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account "$name" saved to backend successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _clearAccountForm();
      }
    } catch (e) {
      setState(() {
        if (isEdit) {
          final oldName = _accounts[_selectedAccountIndex!].accountName;
          _accounts[_selectedAccountIndex!] =
              _accounts[_selectedAccountIndex!].copyWith(
            accountName: name,
            bankName: bank,
            accountNumber: accNo,
            openingBalance: opening,
            notes: notes,
          );
          if (oldName != name) {
            for (int i = 0; i < _transactions.length; i++) {
              if (_transactions[i].accountName == oldName) {
                _transactions[i] = _transactions[i].copyWith(accountName: name);
              }
            }
          }
        } else {
          _accounts.add(BankAccount(
            id: 'acc-${DateTime.now().millisecondsSinceEpoch}',
            accountName: name,
            bankName: bank,
            accountNumber: accNo,
            openingBalance: opening,
            notes: notes,
          ));
        }
        if (_selectedTxAccount == null || !_accounts.any((a) => a.accountName == _selectedTxAccount)) {
          _selectedTxAccount = _accounts.first.accountName;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account saved locally ($e)'),
            backgroundColor: const Color(0xFFE57A38),
          ),
        );
        _clearAccountForm();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _deleteAccount() {
    if (_selectedAccountIndex == null ||
        _selectedAccountIndex! >= _accounts.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an account from the table to delete.'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    final target = _accounts[_selectedAccountIndex!];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2025),
        title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "${target.accountName}"? All linked records will be affected.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              try {
                final repo = ref.read(salesRepositoryProvider);
                await repo.deleteBankAccount(target.id);
                await _fetchLiveBackendData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Account "${target.accountName}" removed from backend.'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  _accounts.removeWhere((a) => a.id == target.id);
                  if (_accounts.isNotEmpty) {
                    _selectedTxAccount = _accounts.first.accountName;
                  } else {
                    _selectedTxAccount = null;
                  }
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Account removed locally ($e).'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              } finally {
                _clearAccountForm();
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Transaction Actions ───────────────────────────────────────────────────
  void _selectTransaction(int index) {
    setState(() {
      _selectedTransactionIndex = index;
      final tx = _transactions[index];
      _txDateCtrl.text = tx.date;
      _selectedTxAccount = tx.accountName;
      _selectedTxType = tx.type;
      _txAmountCtrl.text = tx.amount.toStringAsFixed(2);
      _txDescCtrl.text = tx.description;
      _txRefCtrl.text = tx.reference;
      _txNotesCtrl.text = tx.notes;
    });
  }

  void _clearTransactionForm() {
    setState(() {
      _selectedTransactionIndex = null;
      _txDateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_accounts.isNotEmpty) {
        _selectedTxAccount = _accounts.first.accountName;
      }
      _selectedTxType = 'Deposit';
      _txAmountCtrl.text = '0.00';
      _txDescCtrl.clear();
      _txRefCtrl.clear();
      _txNotesCtrl.clear();
    });
  }

  Future<void> _saveTransaction() async {
    if (_selectedTxAccount == null || _selectedTxAccount!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an Account for this transaction.'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    final amt = double.tryParse(_txAmountCtrl.text.trim()) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction Amount must be greater than 0.'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    final date = _txDateCtrl.text.trim().isEmpty
        ? DateFormat('yyyy-MM-dd').format(DateTime.now())
        : _txDateCtrl.text.trim();
    final desc = _txDescCtrl.text.trim();
    final refNo = _txRefCtrl.text.trim();
    final notes = _txNotesCtrl.text.trim();

    final isEdit = _selectedTransactionIndex != null &&
        _selectedTransactionIndex! < _transactions.length;
    final targetId = isEdit ? _transactions[_selectedTransactionIndex!].id : null;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(salesRepositoryProvider);
      await repo.saveBankTransaction({
        if (targetId != null) 'id': targetId,
        'date': date,
        'accountName': _selectedTxAccount,
        'type': _selectedTxType,
        'amount': amt,
        'description': desc,
        'reference': refNo,
        'notes': notes,
      });

      await _fetchLiveBackendData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction saved to backend & balances updated!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _clearTransactionForm();
      }
    } catch (e) {
      setState(() {
        if (isEdit) {
          _transactions[_selectedTransactionIndex!] =
              _transactions[_selectedTransactionIndex!].copyWith(
            date: date,
            accountName: _selectedTxAccount,
            type: _selectedTxType,
            amount: amt,
            description: desc,
            reference: refNo,
            notes: notes,
          );
        } else {
          _transactions.insert(
            0,
            BankTransaction(
              id: 'tx-${DateTime.now().millisecondsSinceEpoch}',
              date: date,
              accountName: _selectedTxAccount!,
              type: _selectedTxType,
              amount: amt,
              description: desc,
              reference: refNo,
              notes: notes,
            ),
          );
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction saved locally ($e)'),
            backgroundColor: const Color(0xFFE57A38),
          ),
        );
        _clearTransactionForm();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTransaction() async {
    if (_selectedTransactionIndex == null ||
        _selectedTransactionIndex! >= _transactions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a transaction to delete.'),
          backgroundColor: Color(0xFFE57A38),
        ),
      );
      return;
    }

    final target = _transactions[_selectedTransactionIndex!];
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(salesRepositoryProvider);
      await repo.deleteBankTransaction(target.id);
      await _fetchLiveBackendData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted from backend.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _transactions.removeWhere((t) => t.id == target.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction deleted locally ($e).'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      _clearTransactionForm();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sortTransactions(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }

      switch (columnIndex) {
        case 0: // Date
          _transactions.sort((a, b) => _sortAscending
              ? a.date.compareTo(b.date)
              : b.date.compareTo(a.date));
          break;
        case 1: // Account
          _transactions.sort((a, b) => _sortAscending
              ? a.accountName.compareTo(b.accountName)
              : b.accountName.compareTo(a.accountName));
          break;
        case 2: // Type
          _transactions.sort((a, b) => _sortAscending
              ? a.type.compareTo(b.type)
              : b.type.compareTo(a.type));
          break;
        case 3: // Amount
          _transactions.sort((a, b) => _sortAscending
              ? a.amount.compareTo(b.amount)
              : b.amount.compareTo(a.amount));
          break;
      }
    });
  }

  Future<void> _handleRefresh() async {
    setState(() => _isLoading = true);
    await _fetchLiveBackendData(showToast: true);
  }

  void _handleDownloadExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Exporting ${_transactions.length} transactions across ${_accounts.length} bank accounts to Excel...',
        ),
        backgroundColor: const Color(0xFFF15A24),
      ),
    );
  }

  // ─── Main Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 960;

    return Container(
      color: const Color(0xFF191A1E),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. Back to Sales Dashboard Button ───────────────────────────
            _buildBackToDashboardButton(context),

            const SizedBox(height: 12),

            // ─── 2. Page Header & Global Action Buttons ──────────────────────
            _buildPageHeader(context, isCompact),

            const SizedBox(height: 16),

            // ─── 3. Workspace Notebook Tabs (Accounts vs Transactions) ───────
            _buildNotebookTabs(),

            const SizedBox(height: 12),

            // ─── 4. Active Tab Body ──────────────────────────────────────────
            if (_activeTab == 0)
              _buildAccountsAndBalancesTab(isCompact)
            else
              _buildTransactionsTab(isCompact),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ─── 1. Back Button ────────────────────────────────────────────────────────
  Widget _buildBackToDashboardButton(BuildContext context) {
    return InkWell(
      onTap: widget.onBackToDashboard ?? () => context.go('/dashboard'),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF22242B),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF383C46), width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Back to Sales Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2. Page Header Bar ────────────────────────────────────────────────────
  Widget _buildPageHeader(BuildContext context, bool isCompact) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Title: 🏦 Bank & Cash
        const Row(
          children: [
            Icon(Icons.account_balance, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Bank & Cash',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),

        const Spacer(),

        // [🔄 Refresh]
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15A24),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            elevation: 0,
          ),
          onPressed: _isLoading ? null : _handleRefresh,
          icon: _isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh, size: 15),
          label: const Text(
            'Refresh',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),

        const SizedBox(width: 10),

        // [⬇ Download Excel]
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15A24),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            elevation: 0,
          ),
          onPressed: _handleDownloadExcel,
          icon: const Icon(Icons.download, size: 15),
          label: const Text(
            'Download Excel',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // ─── 3. Notebook Tabs ──────────────────────────────────────────────────────
  Widget _buildNotebookTabs() {
    return Row(
      children: [
        // Tab 1: [ 🏦 Accounts & Balances ]
        _buildNotebookTabItem(
          index: 0,
          icon: Icons.account_balance_wallet_outlined,
          title: 'Accounts & Balances',
        ),

        const SizedBox(width: 4),

        // Tab 2: [ 💳 Transactions ]
        _buildNotebookTabItem(
          index: 1,
          icon: Icons.receipt_long_outlined,
          title: 'Transactions',
        ),
      ],
    );
  }

  Widget _buildNotebookTabItem({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final isActive = _activeTab == index;

    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF15A24) : const Color(0xFF22242B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          border: Border.all(
            color: isActive ? const Color(0xFFF15A24) : const Color(0xFF383C46),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 1: ACCOUNTS & BALANCES ────────────────────────────────────────────
  Widget _buildAccountsAndBalancesTab(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Section 1: Total Balance Summary ──────────────────────────────
        const Text(
          'Total Balance',
          style: TextStyle(
            color: Color(0xFFE57A38),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        _buildTotalBalanceSection(),

        const SizedBox(height: 18),

        // ─── Section 2: Add / Edit Account Form ────────────────────────────
        const Text(
          'Add / Edit Account',
          style: TextStyle(
            color: Color(0xFFE57A38),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        _buildAccountFormSection(isCompact),

        const SizedBox(height: 18),

        // ─── Section 3: Accounts Register Table ────────────────────────────
        const Text(
          'Accounts',
          style: TextStyle(
            color: Color(0xFFE57A38),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        _buildAccountsTableSection(isCompact),
      ],
    );
  }

  Widget _buildTotalBalanceSection() {
    final total = _totalBalance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36), width: 1.2),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          // All Accounts Aggregate Card
          Container(
            width: 220,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF151619),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF2A2D35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'All Accounts',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(total),
                  style: TextStyle(
                    color: total >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Individual Registered Account Cards
          ..._accounts.map((acc) {
            final bal = _computeAccountBalance(acc);
            return Container(
              width: 220,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF151619),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF2A2D35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${acc.accountName} (${acc.bankName})',
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(bal),
                    style: TextStyle(
                      color: bal >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAccountFormSection(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36), width: 1.2),
      ),
      child: Column(
        children: [
          // Row 0: Account Name, Bank Name, Account Number, Opening Balance
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Account Name:',
                  child: TextFormField(
                    controller: _accNameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'e.g. HDFC Main Current'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Bank Name:',
                  child: TextFormField(
                    controller: _bankNameCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'e.g. HDFC Bank Ltd'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Account Number:',
                  child: TextFormField(
                    controller: _accNumberCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'e.g. 50200012345678'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Opening Balance:',
                  child: TextFormField(
                    controller: _openingBalCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 1: Notes on left, [Save Account], [Delete Account], [Clear] on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Notes:',
                  child: TextFormField(
                    controller: _accNotesCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'Branch, IFSC, or remarks'),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _saveAccount,
                icon: const Icon(Icons.save_outlined, size: 15),
                label: Text(
                  _selectedAccountIndex != null ? 'Update Account' : 'Save Account',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _deleteAccount,
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text(
                  'Delete Account',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _clearAccountForm,
                icon: const Icon(Icons.close, size: 15),
                label: const Text(
                  'Clear',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsTableSection(bool isCompact) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36), width: 1.2),
      ),
      child: Column(
        children: [
          // Table Header (5 Columns)
          Container(
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF16171A),
              border: Border(bottom: BorderSide(color: Color(0xFF2B2D33))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: const Row(
              children: [
                Expanded(flex: 3, child: _ColHeader('Account Name')),
                Expanded(flex: 3, child: _ColHeader('Bank')),
                Expanded(flex: 3, child: _ColHeader('Account Number')),
                Expanded(flex: 2, child: _ColHeader('Opening Balance', align: TextAlign.right)),
                Expanded(flex: 2, child: _ColHeader('Current Balance', align: TextAlign.right)),
              ],
            ),
          ),

          // Table Rows
          _accounts.isEmpty
              ? Container(
                  height: 120,
                  alignment: Alignment.center,
                  child: const Text(
                    'No accounts registered yet. Use form above to add an account.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _accounts.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFF26282E),
                  ),
                  itemBuilder: (context, index) {
                    final it = _accounts[index];
                    final isSelected = _selectedAccountIndex == index;
                    final currentBal = _computeAccountBalance(it);

                    return InkWell(
                      onTap: () => _selectAccount(index),
                      child: Container(
                        height: 38,
                        color: isSelected
                            ? const Color(0xFF2C3240)
                            : (index.isEven ? Colors.transparent : const Color(0xFF1B1C20)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                it.accountName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                it.bankName,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                it.accountNumber,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _formatCurrency(it.openingBalance),
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _formatCurrency(currentBal),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: currentBal >= 0
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // ─── TAB 2: TRANSACTIONS REGISTER ──────────────────────────────────────────
  Widget _buildTransactionsTab(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Section 1: Add / Edit Transaction Form ────────────────────────
        const Text(
          'Add / Edit Transaction',
          style: TextStyle(
            color: Color(0xFFE57A38),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        _buildTransactionFormSection(isCompact),

        const SizedBox(height: 18),

        // ─── Section 2: Transaction Register Table ─────────────────────────
        const Text(
          'Transaction Register',
          style: TextStyle(
            color: Color(0xFFE57A38),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        _buildTransactionTableSection(isCompact),
      ],
    );
  }

  Widget _buildTransactionFormSection(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36), width: 1.2),
      ),
      child: Column(
        children: [
          // Row 0: Date, Account, Type, Amount (₹)
          Row(
            children: [
              // Date
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Date:',
                  child: TextFormField(
                    controller: _txDateCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() {
                              _txDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Account Dropdown
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Account:',
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('tx-acc-$_selectedTxAccount'),
                    initialValue: _selectedTxAccount,
                    dropdownColor: const Color(0xFF22242B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _accounts.map((a) {
                      return DropdownMenuItem<String>(
                        value: a.accountName,
                        child: Text(
                          a.accountName,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedTxAccount = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Type Dropdown (Deposit, Withdrawal, Bank Charge, Cash In, Cash Out, Transfer)
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Type:',
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('tx-type-$_selectedTxType'),
                    initialValue: _selectedTxType,
                    dropdownColor: const Color(0xFF22242B),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                    items: _transactionTypes.map((t) {
                      return DropdownMenuItem<String>(
                        value: t,
                        child: Text(
                          t,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedTxType = v ?? 'Deposit'),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Amount (₹)
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Amount (₹):',
                  child: TextFormField(
                    controller: _txAmountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 1: Description, Reference, Notes, Action Buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: _buildFormField(
                  label: 'Description:',
                  child: TextFormField(
                    controller: _txDescCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'Narration / Party / Purpose'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Reference:',
                  child: TextFormField(
                    controller: _txRefCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'UTR / Cheque / Ref #'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'Notes:',
                  child: TextFormField(
                    controller: _txNotesCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: _inputDecoration(hintText: 'Internal remarks'),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Actions
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _saveTransaction,
                icon: const Icon(Icons.save_outlined, size: 15),
                label: Text(
                  _selectedTransactionIndex != null ? 'Update' : 'Save',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _deleteTransaction,
                icon: const Icon(Icons.delete_outline, size: 15),
                label: const Text(
                  'Delete',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF15A24),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: _clearTransactionForm,
                icon: const Icon(Icons.close, size: 15),
                label: const Text(
                  'Clear',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTableSection(bool isCompact) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2025),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2C2F36), width: 1.2),
      ),
      child: Column(
        children: [
          // Table Header (7 Columns) with interactive sorting
          Container(
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF16171A),
              border: Border(bottom: BorderSide(color: Color(0xFF2B2D33))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: InkWell(
                    onTap: () => _sortTransactions(0),
                    child: _buildSortableHeader('Date', 0),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _sortTransactions(1),
                    child: _buildSortableHeader('Account', 1),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _sortTransactions(2),
                    child: _buildSortableHeader('Type', 2),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: InkWell(
                    onTap: () => _sortTransactions(3),
                    child: _buildSortableHeader('Amount (₹)', 3, align: TextAlign.right),
                  ),
                ),
                const Expanded(flex: 3, child: _ColHeader('Description')),
                const Expanded(flex: 2, child: _ColHeader('Reference')),
                const Expanded(flex: 2, child: _ColHeader('Notes')),
              ],
            ),
          ),

          // Table Rows
          _transactions.isEmpty
              ? Container(
                  height: 120,
                  alignment: Alignment.center,
                  child: const Text(
                    'No transactions recorded yet.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _transactions.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFF26282E),
                  ),
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    final isSelected = _selectedTransactionIndex == index;
                    final isCredit = _creditTypes.contains(tx.type);

                    return InkWell(
                      onTap: () => _selectTransaction(index),
                      child: Container(
                        height: 36,
                        color: isSelected
                            ? const Color(0xFF2C3240)
                            : (index.isEven ? Colors.transparent : const Color(0xFF1B1C20)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 90,
                              child: Text(
                                tx.date,
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                tx.accountName,
                                style: const TextStyle(color: Colors.white, fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                tx.type,
                                style: TextStyle(
                                  color: isCredit
                                      ? const Color(0xFF10B981)
                                      : (tx.type == 'Transfer'
                                          ? const Color(0xFF60A5FA)
                                          : const Color(0xFFF87171)),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(
                                _formatCurrency(tx.amount),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: isCredit
                                      ? const Color(0xFF10B981)
                                      : Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  tx.description,
                                  style: const TextStyle(color: Colors.white, fontSize: 11.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                tx.reference,
                                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                tx.notes,
                                style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String title, int colIndex, {TextAlign align = TextAlign.left}) {
    final isCurrent = _sortColumnIndex == colIndex;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          align == TextAlign.right ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE2E4E9),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 2),
        Icon(
          isCurrent
              ? (_sortAscending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
              : Icons.sort,
          size: 14,
          color: isCurrent ? const Color(0xFFF15A24) : Colors.white38,
        ),
      ],
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD0D3DA),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      isDense: true,
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 11.5),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF22242B),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFF353942)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFF353942)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFFF15A24), width: 1.2),
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String title;
  final TextAlign align;

  const _ColHeader(this.title, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: align,
      style: const TextStyle(
        color: Color(0xFFE2E4E9),
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
