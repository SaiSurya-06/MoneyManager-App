import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/account.dart';
import '../../models/transaction.dart';
import '../../providers/transactions_provider.dart' hide DateTimeRange;
import '../../providers/categories_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/glassmorphism_card.dart';
import '../../core/utils/currency_formatter.dart';
import '../transactions/transaction_list_item.dart';
import '../transactions/transaction_form.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../widgets/common/toast_notification.dart';

class AccountTransactionsPage extends ConsumerStatefulWidget {
  final Account account;

  const AccountTransactionsPage({super.key, required this.account});

  @override
  ConsumerState<AccountTransactionsPage> createState() => _AccountTransactionsPageState();
}

class _AccountTransactionsPageState extends ConsumerState<AccountTransactionsPage> {
  DateTimeRange? _selectedDateRange;
  int _selectedViewTab = 0; // 0: All, 1: Payments (for CC)

  void _openTransactionForm(BuildContext context, [Transaction? tx]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TransactionForm(
        transaction: tx,
        initialType: tx == null && widget.account.type == 'Credit Card' ? 'transfer' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final txState = ref.watch(transactionsProvider);
    final categoriesState = ref.watch(categoriesProvider);
    final authState = ref.watch(authProvider);

    final currency = authState.profile?.preferredCurrency ?? 'USD';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCreditCard = account.type == 'Credit Card';

    // Filter transactions that affect this account
    final List<Transaction> allAccountTxs = txState.transactions.where((tx) {
      bool matchesAccount = false;
      if (tx.accountId == account.id) {
        matchesAccount = true;
      } else if (tx.type == 'transfer' && tx.effectiveDestinationAccountId == account.id) {
        matchesAccount = true;
      } else if (tx.note != null && tx.note!.contains('Credit Card Payment to target account ID: ${account.id}')) {
        matchesAccount = true;
      }

      if (!matchesAccount) return false;

      if (_selectedDateRange != null) {
        return (tx.date.isAfter(_selectedDateRange!.start) || tx.date.isAtSameMomentAs(_selectedDateRange!.start)) &&
               (tx.date.isBefore(_selectedDateRange!.end) || tx.date.isAtSameMomentAs(_selectedDateRange!.end));
      }
      return true;
    }).toList();

    // Specific payment transactions into this credit card
    final List<Transaction> paymentTxs = allAccountTxs.where((tx) {
      final isTransferIn = tx.type == 'transfer' && tx.effectiveDestinationAccountId == account.id;
      final isCcPaymentIn = tx.note != null && tx.note!.contains('Credit Card Payment to target account ID: ${account.id}');
      return isTransferIn || isCcPaymentIn;
    }).toList();

    final displayedTxs = (isCreditCard && _selectedViewTab == 1) ? paymentTxs : allAccountTxs;

    // Map categories for quick lookup
    final Map<int, Map<String, dynamic>> categoryMap = {};
    for (var cat in categoriesState.categories) {
      categoryMap[cat.id!] = {
        'name': cat.name,
        'color': cat.color,
        'icon': cat.icon,
      };
    }

    final hex = '0xFF${account.color.replaceAll("#", "")}';
    final cardColor = Color(int.tryParse(hex) ?? 0xFFE53935);

    // Calculate running balance history
    final List<FlSpot> spots = [];
    if (allAccountTxs.isNotEmpty) {
      double running = account.balance;
      final List<double> values = [running];
      
      final backwardsTxs = List<Transaction>.from(allAccountTxs)..sort((a, b) => b.date.compareTo(a.date));
      for (var tx in backwardsTxs) {
        double change = 0.0;
        if (tx.type == 'income') {
          change = tx.amount;
        } else if (tx.type == 'expense') {
          change = -tx.amount;
        } else if (tx.type == 'transfer') {
          if (tx.effectiveDestinationAccountId == account.id) {
            change = tx.amount;
          } else {
            change = -tx.amount;
          }
        }
        running -= change;
        values.insert(0, running);
      }
      
      final int showCount = values.length > 15 ? 15 : values.length;
      final startIdx = values.length - showCount;
      for (int i = 0; i < showCount; i++) {
        spots.add(FlSpot(i.toDouble(), values[startIdx + i]));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.date_range,
              color: _selectedDateRange != null ? const Color(0xFFE53935) : null,
            ),
            tooltip: 'Filter by Date Range',
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                initialDateRange: _selectedDateRange ?? DateTimeRange(
                  start: DateTime(now.year, now.month, 1),
                  end: DateTime(now.year, now.month, now.day),
                ),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: const Color(0xFFE53935),
                        onPrimary: Colors.white,
                        surface: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() {
                  _selectedDateRange = picked;
                });
              }
            },
          ),
          if (isCreditCard)
            IconButton(
              icon: const Icon(Icons.payment),
              tooltip: 'Make CC Payment',
              onPressed: () => _openTransactionForm(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Account Summary Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: GlassmorphismCard(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isCreditCard ? 'AVAILABLE CREDIT' : 'CURRENT BALANCE',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          letterSpacing: 1.0,
                          fontFamily: 'Inter',
                        ),
                      ),
                      if (account.isArchived)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ARCHIVED',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isCreditCard 
                        ? CurrencyFormatter.format(account.availableCredit, currency)
                        : CurrencyFormatter.format(account.balance, currency),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isCreditCard
                          ? (account.availableCredit >= 0 ? (isDark ? Colors.white : const Color(0xFF1A1A26)) : const Color(0xFFE53935))
                          : (account.balance >= 0 ? (isDark ? Colors.white : const Color(0xFF1A1A26)) : const Color(0xFFE53935)),
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (isCreditCard) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Outstanding Debt: ${CurrencyFormatter.format(account.pendingPayment, currency)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: account.pendingPayment > 0 ? const Color(0xFFE53935) : Colors.green,
                          ),
                        ),
                        Text(
                          'Limit: ${CurrencyFormatter.format(account.limitAmount ?? 0, currency)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    if (account.billingCycleStartDay != null || account.statementDueDay != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Billing Cycle: Day ${account.billingCycleStartDay ?? '-'} • Payment Due: Day ${account.statementDueDay ?? '-'}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'Inter'),
                      ),
                    ],
                    if (account.minimumDue != null && account.minimumDue! > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Minimum Due: ${CurrencyFormatter.format(account.minimumDue!, currency)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD4AF37)),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),

          if (isCreditCard)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text('All Activity (${allAccountTxs.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      selected: _selectedViewTab == 0,
                      onSelected: (val) {
                        if (val) setState(() => _selectedViewTab = 0);
                      },
                      selectedColor: const Color(0xFFE53935).withValues(alpha: 0.15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: Center(
                        child: Text('Payment History (${paymentTxs.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      selected: _selectedViewTab == 1,
                      onSelected: (val) {
                        if (val) setState(() => _selectedViewTab = 1);
                      },
                      selectedColor: Colors.green.withValues(alpha: 0.15),
                      labelStyle: TextStyle(color: _selectedViewTab == 1 ? Colors.green : null),
                    ),
                  ),
                ],
              ),
            ),

          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtered: ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, fontFamily: 'Inter'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedDateRange = null),
                    child: const Text('Clear Filter', style: TextStyle(color: Color(0xFFE53935), fontSize: 11, fontFamily: 'Inter')),
                  ),
                ],
              ),
            ),

          // Transactions / Payment List
          Expanded(
            child: txState.isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
                : displayedTxs.isEmpty
                    ? Center(
                        child: Text(
                          isCreditCard && _selectedViewTab == 1
                              ? 'No bill payments recorded yet for this card.'
                              : 'No transactions logged for this account.',
                          style: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: displayedTxs.length,
                        itemBuilder: (context, index) {
                          final tx = displayedTxs[index];
                          
                          // Resolve category details
                          final cat = categoryMap[tx.categoryId] ?? {
                            'name': 'Other',
                            'color': '757575',
                            'icon': 'category'
                          };

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: TransactionListItem(
                              transaction: tx,
                              categoryName: cat['name'] as String,
                              categoryColorHex: cat['color'] as String,
                              categoryIconKey: cat['icon'] as String,
                              accountName: account.name,
                              currency: currency,
                              filterAccountId: account.id,
                              onTap: () {
                                _openTransactionForm(context, tx);
                              },
                              onLongPress: () {
                                _openTransactionForm(context, tx);
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
