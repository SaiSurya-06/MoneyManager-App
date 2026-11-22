import 'package:flutter/material.dart';

import '../../core/utils/currency_formatter.dart';
import '../../models/account.dart';
import '../../widgets/common/glassmorphism_card.dart';

class AccountCard extends StatelessWidget {
  final Account account;
  final String currency;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const AccountCard({
    super.key,
    required this.account,
    required this.currency,
    required this.onTap,
    this.onLongPress,
  });

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'account_balance':
        return Icons.account_balance;
      case 'payments':
        return Icons.payments;
      case 'credit_card':
        return Icons.credit_card;
      case 'savings':
        return Icons.savings;
      case 'trending_up':
        return Icons.trending_up;
      default:
        return Icons.wallet;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accountColor = Color(
      int.tryParse('0xFF${account.color.replaceAll('#', '')}') ?? 0xFFE53935,
    );
    final accent = Color.alphaBlend(
      colors.onSurface.withValues(alpha: isDark ? 0.20 : 0.35),
      accountColor,
    );
    final detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final amountStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
    );
    final limit = account.limitAmount ?? 0;
    final showsCreditDetails = account.type == 'Credit Card' && limit > 0;
    final utilization = showsCreditDetails ? account.balance.abs() / limit : 0.0;
    final usedColor = utilization > 0.8
        ? colors.error
        : utilization > 0.5
            ? (isDark ? Colors.orangeAccent : Colors.brown)
            : (isDark ? Colors.greenAccent : Colors.green.shade800);
    final amount = showsCreditDetails
        ? limit - account.balance.abs()
        : account.balance;

    return GlassmorphismCard(
      padding: EdgeInsets.zero,
      blur: 0,
      color: Color.alphaBlend(
        accountColor.withValues(alpha: isDark ? 0.13 : 0.08),
        colors.surface,
      ),
      borderColor: accountColor.withValues(alpha: isDark ? 0.34 : 0.26),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: accountColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(_getIconData(account.icon), size: 20, color: accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        account.type,
                        textAlign: TextAlign.end,
                        style: detailStyle?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  account.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                if (account.isArchived)
                  Text('Archived', style: detailStyle),
                const SizedBox(height: 4),
                if (showsCreditDetails)
                  Text('Remaining limit', style: detailStyle),
                Text(
                  CurrencyFormatter.format(amount, currency),
                  style: amountStyle?.copyWith(
                    color: amount < 0 ? colors.error : colors.onSurface,
                  ),
                ),
                if (showsCreditDetails) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Pending payment: ${CurrencyFormatter.format(account.pendingPayment < 0 ? 0.0 : account.pendingPayment, currency)}',
                    style: detailStyle?.copyWith(
                      color: account.pendingPayment > 0 ? colors.error : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedCreditProgressBar(
                    ratio: utilization.clamp(0.0, 1.0),
                    activeColor: usedColor,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Utilized: ${(utilization * 100).toStringAsFixed(0)}% of ${CurrencyFormatter.format(limit, currency)}',
                    style: detailStyle,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays out only visible rows and lets each row grow to fit its tallest card.
class SliverAccountGrid extends StatelessWidget {
  const SliverAccountGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final enlargedText = MediaQuery.textScalerOf(context).scale(16) > 22;
        final columns = enlargedText || constraints.crossAxisExtent < 344
            ? 1
            : constraints.crossAxisExtent >= 720
                ? 3
                : 2;
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, rowIndex) {
              final first = rowIndex * columns;
              return Padding(
                padding: EdgeInsets.only(top: rowIndex == 0 ? 0 : gap),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) const SizedBox(width: gap),
                        Expanded(
                          child: first + column < itemCount
                              ? itemBuilder(context, first + column)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
            childCount: (itemCount + columns - 1) ~/ columns,
          ),
        );
      },
    );
  }
}

class AnimatedCreditProgressBar extends StatelessWidget {
  const AnimatedCreditProgressBar({
    super.key,
    required this.ratio,
    required this.activeColor,
  });

  final double ratio;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: ratio),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return LinearProgressIndicator(
          value: value,
          minHeight: 6,
          borderRadius: BorderRadius.circular(6),
          backgroundColor: colors.onSurface.withValues(alpha: 0.12),
          color: activeColor,
        );
      },
    );
  }
}
