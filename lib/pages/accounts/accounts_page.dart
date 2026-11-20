import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/accounts_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/account.dart';
import '../../core/utils/currency_formatter.dart';
import '../../widgets/common/glassmorphism_card.dart';
import '../../widgets/common/toast_notification.dart';
import 'account_card.dart';
import 'account_form.dart';
import 'account_transactions_page.dart';

class AccountsPage extends ConsumerStatefulWidget {
  const AccountsPage({super.key});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  bool _showArchived = false;

  void _openAccountForm(BuildContext context, [Account? account]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AccountForm(account: account),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsProvider);
    final authState = ref.watch(authProvider);

    final currency = authState.profile?.preferredCurrency ?? 'USD';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayedAccounts = _showArchived 
        ? accountsState.archivedAccounts 
        : accountsState.activeAccounts;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 26, width: 26),
            const SizedBox(width: 8),
            const Text('Accounts'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _openAccountForm(context),
            icon: const Icon(Icons.add_card),
            tooltip: 'Add Account',
          ),
        ],
      ),
      body: accountsState.isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeOutQuart,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: CustomScrollView(
                slivers: [
                  // Total Balance Summary Card (Bento style)
                  SliverPadding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE53935), Color(0xFFD4AF37)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE53935).withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AGGREGATE LIQUIDITY',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  CurrencyFormatter.format(
                                    accountsState.activeAccounts.fold<double>(
                                      0.0,
                                      (sum, acc) => acc.type != 'Credit Card' ? sum + acc.balance : sum,
                                    ),
                                    currency,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                                Icon(Icons.account_balance_wallet, color: Colors.white.withValues(alpha: 0.8), size: 24),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${accountsState.activeAccounts.length} Active Accounts${accountsState.archivedAccounts.isNotEmpty ? ' (${accountsState.archivedAccounts.length} archived)' : ''}',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Credit Utilization Card (Shown only if credit cards exist)
                  ...[
                    (() {
                      final ccAccounts = accountsState.activeAccounts.where((a) => a.type == 'Credit Card').toList();
                      if (ccAccounts.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                      double totalLimit = 0.0;
                      double totalUsed = 0.0;
                      for (var cc in ccAccounts) {
                        totalLimit += cc.limitAmount ?? 0.0;
                        totalUsed += cc.pendingPayment;
                      }

                      if (totalLimit <= 0.0) return const SliverToBoxAdapter(child: SizedBox.shrink());

                      final utilization = (totalUsed / totalLimit) * 100.0;
                      final isOverLimit = utilization > 100.0;
                      final isHighUtilization = utilization >= 30.0;
                      
                      final Color progressColor = isOverLimit 
                          ? const Color(0xFFE53935) 
                          : (isHighUtilization ? Colors.orange : Colors.green);

                      return SliverPadding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0),
                        sliver: SliverToBoxAdapter(
                          child: GlassmorphismCard(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'CREDIT UTILIZATION',
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black87,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    Text(
                                      '${utilization.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: progressColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (utilization / 100.0).clamp(0.0, 1.0),
                                    backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Used: ${CurrencyFormatter.format(totalUsed, currency)}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    Text(
                                      'Limit: ${CurrencyFormatter.format(totalLimit, currency)}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                                if (isHighUtilization) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        isOverLimit ? Icons.error_outline : Icons.warning_amber_outlined, 
                                        color: progressColor, 
                                        size: 12
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          isOverLimit 
                                              ? 'Over limit! Pay back immediately.' 
                                              : 'High utilization (>30%). May affect credit score.',
                                          style: TextStyle(
                                            color: progressColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }()),
                  ],

                  // Filter Row: Active Accounts vs Archived Accounts
                  SliverPadding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 18.0, bottom: 8.0),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  'Active Accounts (${accountsState.activeAccounts.length})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              selected: !_showArchived,
                              onSelected: (val) {
                                if (val) setState(() => _showArchived = false);
                              },
                              selectedColor: const Color(0xFFE53935).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: !_showArchived ? const Color(0xFFE53935) : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: Center(
                                child: Text(
                                  'Archived (${accountsState.archivedAccounts.length})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              selected: _showArchived,
                              onSelected: (val) {
                                if (val) setState(() => _showArchived = true);
                              },
                              selectedColor: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                              labelStyle: TextStyle(
                                color: _showArchived ? const Color(0xFFD4AF37) : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_showArchived)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.25)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 14),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Archived accounts preserve all history & balances. Long-press to edit or restore.',
                                  style: TextStyle(fontSize: 10, color: Color(0xFFD4AF37)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // My Accounts Grid
                  if (displayedAccounts.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              _showArchived ? 'No archived accounts.' : 'No active financial accounts created yet.',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: ((MediaQuery.of(context).size.width - 32 - 12) / 2) / 172.0,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final account = displayedAccounts[index];
                            final cardItem = AccountCard(
                              account: account,
                              currency: currency,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AccountTransactionsPage(account: account),
                                  ),
                                );
                              },
                              onLongPress: () => _openAccountForm(context, account),
                            );

                            return Dismissible(
                              key: ValueKey(account.id ?? account.createdAt.millisecondsSinceEpoch),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20.0),
                                decoration: BoxDecoration(
                                  color: account.isArchived ? const Color(0xFFD4AF37) : const Color(0xFFE53935),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  account.isArchived ? Icons.unarchive : Icons.archive,
                                  color: Colors.white,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                if (account.isArchived) {
                                  // Restore account
                                  await ref.read(accountsProvider.notifier).restoreAccount(account.id!);
                                  ToastNotification.show(context, 'Account "${account.name}" restored.');
                                  return false;
                                }

                                final txCount = await ref.read(accountsProvider.notifier).getTransactionCount(account.id!);
                                if (txCount > 0) {
                                  // Offer archive instead of deletion
                                  final shouldArchive = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                                      title: const Text('Account Has Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      content: Text('Account "${account.name}" has $txCount transactions. To safeguard your financial history, it cannot be permanently deleted.\n\nArchive it instead?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFD4AF37),
                                            foregroundColor: Colors.black,
                                          ),
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Archive'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (shouldArchive == true) {
                                    await ref.read(accountsProvider.notifier).archiveAccount(account.id!);
                                    if (context.mounted) {
                                      ToastNotification.show(context, 'Archived "${account.name}".');
                                    }
                                  }
                                  return false;
                                }

                                // 0 transactions: allow delete confirmation
                                return await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                                    title: const Text('Delete Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    content: Text('Delete empty account "${account.name}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFE53935),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (direction) async {
                                await ref.read(accountsProvider.notifier).deleteAccount(account.id!);
                              },
                              child: cardItem,
                            );
                          },
                          childCount: displayedAccounts.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 40),
                  ),
                ],
              ),
            ),
    );
  }
}
