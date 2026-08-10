import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../widgets/common/glassmorphism_card.dart';
import '../../../widgets/common/animated_counter.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../providers/auth_provider.dart';
import 'combined_credit_card_sheet.dart';

class CreditCardUsageCard extends ConsumerWidget {
  const CreditCardUsageCard({super.key});

  void _openCombinedSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CombinedCreditCardSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(authProvider).profile?.preferredCurrency ?? 'USD';
    final accounts = ref.watch(accountsProvider).accounts;
    final transactionsState = ref.watch(transactionsProvider);

    final creditCardAccounts = accounts.where(
      (a) => a.type == 'Credit Card' || a.type.toLowerCase().contains('credit card')
    ).toList();

    if (creditCardAccounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final creditCardIds = creditCardAccounts.map((a) => a.id).whereType<int>().toSet();
    final now = DateTime.now();

    // Transactions in current month for any credit card account
    final currentMonthCcTxs = transactionsState.transactions.where((tx) {
      if (tx.date.year != now.year || tx.date.month != now.month) return false;
      return creditCardIds.contains(tx.accountId) && tx.type == 'expense';
    }).toList();

    final ccSpendThisMonth = currentMonthCcTxs.fold(0.0, (sum, tx) => sum + tx.amount);

    // Total expenses across ALL accounts in current month for ratio
    final totalMonthlyExpenses = transactionsState.transactions.where((tx) {
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
                    colors: [Color(0xFFE53935), Color(0xFFFF6B6B)],
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
                        Text(
                          '${DateFormat('MMMM').format(now).toUpperCase()} CREDIT CARD USAGE',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 0.8,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const Row(
                          children: [
                            Text(
                              'All Cards',
                              style: TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedCounter(
                          value: ccSpendThisMonth,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1A1A26),
                            fontFamily: 'Inter',
                          ),
                          formatter: (val) => CurrencyFormatter.format(val, currency),
                        ),
                        if (pctOfExpenses > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${pctOfExpenses.toStringAsFixed(0)}% of expenses',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE53935),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
