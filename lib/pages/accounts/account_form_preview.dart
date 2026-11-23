import 'package:flutter/material.dart';

import '../../core/utils/currency_formatter.dart';
import '../../models/account.dart';
import '../../widgets/common/glassmorphism_card.dart';
import 'account_card.dart';

/// The original tinted card styling for the live Add/Edit preview.
class AccountFormPreview extends StatelessWidget {
  const AccountFormPreview({
    super.key,
    required this.account,
    required this.currency,
  });

  final Account account;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = Color(
      int.tryParse('0xFF${account.color.replaceAll('#', '')}') ?? 0xFFE53935,
    );
    final limit = account.limitAmount ?? 0;
    final credit = account.type == 'Credit Card' && limit > 0;
    final used = credit ? account.balance.abs() / limit : 0.0;
    final amount = credit ? limit - account.balance.abs() : account.balance;
    const icons = {
      'account_balance': Icons.account_balance,
      'payments': Icons.payments,
      'credit_card': Icons.credit_card,
      'savings': Icons.savings,
      'trending_up': Icons.trending_up,
    };

    return GlassmorphismCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: accent.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.12 : 0.08,
      ),
      borderColor: accent.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withValues(alpha: 0.2),
                child: Icon(icons[account.icon] ?? Icons.wallet, color: accent, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  account.type.toUpperCase(),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(account.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          if (account.isArchived)
            Text('Archived', style: theme.textTheme.bodySmall),
          if (credit)
            Text('Remaining Limit', style: theme.textTheme.bodySmall),
          Text(
            CurrencyFormatter.format(amount, currency),
            style: theme.textTheme.titleLarge?.copyWith(
              color: amount < 0 ? theme.colorScheme.error : null,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (credit) ...[
            const SizedBox(height: 6),
            Text('Pending Payment: ${CurrencyFormatter.format(account.pendingPayment, currency)}'),
            const SizedBox(height: 8),
            AnimatedCreditProgressBar(
              ratio: used.clamp(0.0, 1.0),
              activeColor: accent,
            ),
            const SizedBox(height: 6),
            Text(
              'Utilized: ${(used * 100).toStringAsFixed(0)}% of ${CurrencyFormatter.format(limit, currency)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
