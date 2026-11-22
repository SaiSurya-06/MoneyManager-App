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

  Future<void> _reorderAccounts(List<Account> accounts) async {
    final draft = [...accounts];
    final order = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.8,
        child: SafeArea(
          top: false,
          child: StatefulBuilder(
            builder: (context, update) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  title: const Text('Reorder accounts'),
                  subtitle: const Text('Drag the handles to arrange your active accounts.'),
                  trailing: IconButton(
                    tooltip: 'Cancel reorder',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: draft.length,
                    onReorder: (oldIndex, newIndex) {
                      update(() {
                        if (newIndex > oldIndex) newIndex--;
                        draft.insert(newIndex, draft.removeAt(oldIndex));
                      });
                    },
                    itemBuilder: (context, index) {
                      final account = draft[index];
                      return ListTile(
                        key: ValueKey(account.id),
                        title: Text(account.name),
                        subtitle: Text(account.type),
                        trailing: ReorderableDragStartListener(
                          index: index,
                          child: const ColoredBox(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(Icons.drag_handle, semanticLabel: 'Drag to reorder'),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      draft.map((account) => account.id!).toList(),
                    ),
                    child: const Text('Save order'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (order == null || !mounted) return;
    try {
      await ref.read(accountsProvider.notifier).saveActiveAccountOrder(order);
    } catch (_) {
      if (mounted) {
        ToastNotification.show(
          context,
          'Could not save the order. Reopen Reorder and try again.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(accountsProvider);
    final authState = ref.watch(authProvider);

    final currency = authState.profile?.preferredCurrency ?? 'USD';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final summaryCaption = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final displayedAccounts = _showArchived 
        ? accountsState.archivedAccounts 
        : accountsState.activeAccounts;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 26, width: 26),
            const SizedBox(width: 8),
            const Flexible(
              child: Text('Accounts', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
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
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 750),
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
                          gradient: LinearGradient(
                            colors: [
                              Color.alphaBlend(
                                const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                theme.colorScheme.surface,
                              ),
                              theme.colorScheme.surface,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.32),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total balance', style: summaryCaption),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    CurrencyFormatter.format(
                                      accountsState.activeAccounts.fold<double>(
                                        0.0,
                                        (sum, acc) => acc.type != 'Credit Card' ? sum + acc.balance : sum,
                                      ),
                                      currency,
                                    ),
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.account_balance_wallet,
                                  color: isDark
                                      ? const Color(0xFFD4AF37)
                                      : const Color(0xFF7A5A00),
                                  size: 24,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${accountsState.activeAccounts.length} Active Accounts${accountsState.archivedAccounts.isNotEmpty ? ' (${accountsState.archivedAccounts.length} archived)' : ''}',
                              style: summaryCaption,
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
                                    Expanded(
                                      child: Text(
                                        'Credit utilization',
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Used: ${CurrencyFormatter.format(totalUsed, currency)}',
                                        style: summaryCaption,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Limit: ${CurrencyFormatter.format(totalLimit, currency)}',
                                        textAlign: TextAlign.end,
                                        style: summaryCaption,
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

                  if (!_showArchived &&
                      displayedAccounts.length > 1 &&
                      displayedAccounts.every((account) => account.id != null))
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: () => _reorderAccounts(displayedAccounts),
                            icon: const Icon(Icons.reorder),
                            label: const Text('Reorder'),
                          ),
                        ),
                      ),
                    ),

                  // Account list
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
                      sliver: SliverList.separated(
                        itemCount: displayedAccounts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
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
