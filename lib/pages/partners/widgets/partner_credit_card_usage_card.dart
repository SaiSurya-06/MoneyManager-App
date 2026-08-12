import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../widgets/common/glassmorphism_card.dart';
import '../../../widgets/common/animated_counter.dart';
import '../../../providers/partner_sync_provider.dart';
import '../../../models/transaction.dart';
import '../../transactions/transaction_list_item.dart';

class PartnerCreditCardUsageCard extends StatelessWidget {
  final PartnerSyncState syncState;

  const PartnerCreditCardUsageCard({
    super.key,
    required this.syncState,
  });

  void _openCombinedSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PartnerCombinedCreditCardSheet(syncState: syncState),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = syncState.partnerCurrency;
    final partnerName = (syncState.partnerName == "Connecting..." || syncState.partnerName == "Waiting...")
        ? "Partner"
        : syncState.partnerName;

    final creditCardAccounts = syncState.partnerAccounts.where(
      (a) => a.type == 'Credit Card' || a.type.toLowerCase().contains('credit card')
    ).toList();

    if (creditCardAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final ccAccountNames = creditCardAccounts.map((a) => a.name.toLowerCase()).toSet();
    final now = DateTime.now();

    final currentMonthCcTxs = syncState.partnerTransactions.where((tx) {
      if (tx.date.year != now.year || tx.date.month != now.month) return false;
      final accMatch = ccAccountNames.contains(tx.accountName.toLowerCase());
      return accMatch && tx.type == 'expense';
    }).toList();

    final ccSpendThisMonth = currentMonthCcTxs.fold(0.0, (sum, tx) => sum + tx.amount);

    final totalMonthlyExpenses = syncState.partnerTransactions.where((tx) {
      return tx.date.year == now.year && tx.date.month == now.month && tx.type == 'expense';
    }).fold(0.0, (sum, tx) => sum + tx.amount);

    final pctOfExpenses = totalMonthlyExpenses > 0 ? (ccSpendThisMonth / totalMonthlyExpenses) * 100.0 : 0.0;

    return GlassmorphismCard(
      padding: EdgeInsets.zero,
      borderRadius: 20,
      color: isDark
          ? const Color(0xFFE53935).withValues(alpha: 0.08)
          : const Color(0xFFE53935).withValues(alpha: 0.04),
      borderColor: const Color(0xFFE53935).withValues(alpha: 0.2),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openCombinedSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFFFD700)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53935).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.credit_card, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "$partnerName's Credit Card Usage".toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : const Color(0xFF6C6C7D),
                              letterSpacing: 0.8,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${creditCardAccounts.length} Card${creditCardAccounts.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE53935),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedCounter(
                          value: ccSpendThisMonth,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE53935),
                            fontFamily: 'Inter',
                          ),
                          formatter: (val) => CurrencyFormatter.format(val, currency),
                        ),
                        Text(
                          '${pctOfExpenses.toStringAsFixed(0)}% of total',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                color: isDark ? Colors.white38 : Colors.black38,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerCombinedCreditCardSheet extends StatefulWidget {
  final PartnerSyncState syncState;

  const _PartnerCombinedCreditCardSheet({required this.syncState});

  @override
  State<_PartnerCombinedCreditCardSheet> createState() => _PartnerCombinedCreditCardSheetState();
}

class _PartnerCombinedCreditCardSheetState extends State<_PartnerCombinedCreditCardSheet> {
  late DateTime _selectedMonth;
  String _searchQuery = '';
  String? _filterAccountName;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.syncState.partnerCurrency;
    final partnerName = (widget.syncState.partnerName == "Connecting..." || widget.syncState.partnerName == "Waiting...")
        ? "Partner"
        : widget.syncState.partnerName;

    final creditCardAccounts = widget.syncState.partnerAccounts.where(
      (a) => a.type == 'Credit Card' || a.type.toLowerCase().contains('credit card')
    ).toList();

    final ccAccountNames = creditCardAccounts.map((a) => a.name.toLowerCase()).toSet();

    final matchingTxs = widget.syncState.partnerTransactions.where((tx) {
      if (tx.date.year != _selectedMonth.year || tx.date.month != _selectedMonth.month) return false;
      if (!ccAccountNames.contains(tx.accountName.toLowerCase())) return false;
      if (_filterAccountName != null && tx.accountName.toLowerCase() != _filterAccountName!.toLowerCase()) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = tx.title.toLowerCase().contains(q);
        final matchNote = tx.note?.toLowerCase().contains(q) ?? false;
        final matchCategory = tx.categoryName.toLowerCase().contains(q);
        if (!matchTitle && !matchNote && !matchCategory) return false;
      }
      return true;
    }).toList();

    final totalExpense = matchingTxs
        .where((tx) => tx.type == 'expense')
        .fold(0.0, (sum, tx) => sum + tx.amount);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141420) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header with Title & Close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE53935).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.credit_card, color: Color(0xFFE53935), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$partnerName's Credit Card Usage",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF161622),
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        'Combined activity across ${creditCardAccounts.length} credit card account${creditCardAccounts.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Month Navigator Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? const Color(0xFF1C1C2E) : const Color(0xFFF8F9FA),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF161622),
                    fontFamily: 'Inter',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),

          // Card Selector Pills (if multiple cards exist)
          if (creditCardAccounts.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  FilterChip(
                    selected: _filterAccountName == null,
                    label: const Text('All Partner Cards'),
                    onSelected: (_) => setState(() => _filterAccountName = null),
                    selectedColor: const Color(0xFFE53935).withValues(alpha: 0.2),
                    checkmarkColor: const Color(0xFFE53935),
                  ),
                  const SizedBox(width: 8),
                  ...creditCardAccounts.map((acc) {
                    final isSel = _filterAccountName?.toLowerCase() == acc.name.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        selected: isSel,
                        label: Text(acc.name),
                        onSelected: (_) {
                          setState(() {
                            _filterAccountName = isSel ? null : acc.name;
                          });
                        },
                        selectedColor: const Color(0xFFE53935).withValues(alpha: 0.2),
                        checkmarkColor: const Color(0xFFE53935),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search credit card transactions...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),

          // Total Expense Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE53935).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TOTAL SPEND THIS MONTH',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
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
                Text(
                  '${matchingTxs.length} transaction${matchingTxs.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Transaction list
          Expanded(
            child: matchingTxs.isEmpty
                ? const Center(
                    child: Text(
                      'No credit card transactions logged for this period.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: matchingTxs.length,
                    itemBuilder: (context, index) {
                      final pTx = matchingTxs[index];
                      final modelTx = Transaction(
                        title: pTx.title,
                        amount: pTx.amount,
                        type: pTx.type,
                        date: pTx.date,
                        note: pTx.note,
                        recurrence: pTx.recurrence,
                        isPrivate: false,
                        accountId: 0,
                        categoryId: 0,
                        createdAt: pTx.date,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TransactionListItem(
                          transaction: modelTx,
                          categoryName: pTx.categoryName,
                          categoryColorHex: '#E53935',
                          categoryIconKey: 'credit_card',
                          accountName: pTx.accountName,
                          currency: currency,
                          onTap: () {},
                          onLongPress: () {},
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
