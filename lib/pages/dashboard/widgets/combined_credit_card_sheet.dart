import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/account.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../widgets/common/glassmorphism_card.dart';
import '../../transactions/transaction_list_item.dart';
import '../../transactions/transaction_form.dart';

class CombinedCreditCardSheet extends ConsumerStatefulWidget {
  const CombinedCreditCardSheet({super.key});

  @override
  ConsumerState<CombinedCreditCardSheet> createState() => _CombinedCreditCardSheetState();
}

class _CombinedCreditCardSheetState extends ConsumerState<CombinedCreditCardSheet> {
  late DateTime _selectedMonth;
  String _searchQuery = '';
  int? _selectedAccountId; // null = all credit cards

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(authProvider).profile?.preferredCurrency ?? 'USD';
    final accounts = ref.watch(accountsProvider).accounts;
    final transactionsState = ref.watch(transactionsProvider);
    final categoriesState = ref.watch(categoriesProvider);

    final Map<int, Map<String, String>> categoryMap = {};
    for (var cat in categoriesState.categories) {
      if (cat.id != null) {
        categoryMap[cat.id!] = {
          'name': cat.name,
          'color': cat.color,
          'icon': cat.icon,
        };
      }
    }

    // Identify all credit card accounts
    final creditCardAccounts = accounts.where(
      (a) => a.type == 'Credit Card' || a.type.toLowerCase().contains('credit card')
    ).toList();

    final creditCardIds = creditCardAccounts.map((a) => a.id).whereType<int>().toSet();

    final Map<int, Account> creditCardMap = {
      for (var a in creditCardAccounts) if (a.id != null) a.id!: a
    };

    // Filter transactions for credit cards in the selected month
    final monthTxs = transactionsState.transactions.where((tx) {
      if (tx.date.year != _selectedMonth.year || tx.date.month != _selectedMonth.month) {
        return false;
      }

      // Must belong to a Credit Card account
      bool isCreditCardTx = creditCardIds.contains(tx.accountId);
      if (!isCreditCardTx && tx.type == 'transfer') {
        final destId = tx.effectiveDestinationAccountId;
        if (destId != null && creditCardIds.contains(destId)) {
          isCreditCardTx = true;
        }
      }

      if (!isCreditCardTx) return false;

      // Filter by specific credit card if selected
      if (_selectedAccountId != null && tx.accountId != _selectedAccountId) {
        return false;
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = tx.title.toLowerCase().contains(q);
        final matchNote = tx.note?.toLowerCase().contains(q) ?? false;
        final matchAmt = tx.amount.toString().contains(q);
        if (!matchTitle && !matchNote && !matchAmt) return false;
      }

      return true;
    }).toList();

    monthTxs.sort((a, b) => b.date.compareTo(a.date));

    // Calculate total credit card spending for month
    final totalExpense = monthTxs.where((tx) => tx.type == 'expense').fold(0.0, (sum, tx) => sum + tx.amount);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161625) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle indicator
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.credit_card, color: Color(0xFFE53935), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Combined Credit Card Usage',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                      ),
                      Text(
                        '${creditCardAccounts.length} Credit Card Accounts Combined',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Month Switcher Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 22),
                  onPressed: _previousMonth,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 22),
                  onPressed: _nextMonth,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Monthly Total Summary Banner
          GlassmorphismCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL USAGE THIS MONTH',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(totalExpense, currency),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFE53935),
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${monthTxs.length} Transactions',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Across ${creditCardAccounts.length} Cards',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Specific Credit Card Filter Pills
          if (creditCardAccounts.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Credit Cards'),
                    selected: _selectedAccountId == null,
                    selectedColor: const Color(0xFFE53935),
                    onSelected: (_) {
                      setState(() {
                        _selectedAccountId = null;
                      });
                    },
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: _selectedAccountId == null ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: _selectedAccountId == null ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...creditCardAccounts.map((acc) {
                    final isSel = _selectedAccountId == acc.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(acc.name),
                        selected: isSel,
                        selectedColor: const Color(0xFFE53935),
                        onSelected: (_) {
                          setState(() {
                            _selectedAccountId = acc.id;
                          });
                        },
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Search Field
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                icon: Icon(Icons.search, size: 16, color: Colors.grey),
                hintText: 'Search credit card transactions...',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Transactions List
          Expanded(
            child: monthTxs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.credit_card_off, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text(
                          'No credit card transactions found for this month.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: monthTxs.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final tx = monthTxs[index];
                      final acc = creditCardMap[tx.accountId];
                      final accName = acc?.name ?? 'Credit Card';
                      final catInfo = categoryMap[tx.categoryId] ?? {
                        'name': 'Other',
                        'color': '757575',
                        'icon': 'category'
                      };

                      return TransactionListItem(
                        transaction: tx,
                        categoryName: catInfo['name'] ?? 'Other',
                        categoryColorHex: catInfo['color'] ?? '757575',
                        categoryIconKey: catInfo['icon'] ?? 'category',
                        currency: currency,
                        accountName: accName,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => TransactionForm(transaction: tx),
                          );
                        },
                        onLongPress: () {},
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
