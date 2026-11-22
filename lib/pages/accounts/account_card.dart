import 'package:flutter/material.dart';

import '../../core/utils/currency_formatter.dart';
import '../../models/account.dart';

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

    final amountText = Text(
      CurrencyFormatter.format(amount, currency),
      style: amountStyle?.copyWith(
        color: amount < 0 ? colors.error : colors.onSurface,
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          account.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          account.isArchived ? '${account.type} · Archived' : account.type,
          style: detailStyle,
        ),
      ],
    );

    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 320 ||
                  MediaQuery.textScalerOf(context).scale(16) > 21;
              final amountBlock = Column(
                crossAxisAlignment:
                    stacked ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  if (showsCreditDetails) Text('Remaining limit', style: detailStyle),
                  amountText,
                ],
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accountColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_getIconData(account.icon), size: 20, color: accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: stacked
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  details,
                                  const SizedBox(height: 6),
                                  amountBlock,
                                ],
                              )
                            : details,
                      ),
                      if (!stacked) ...[
                        const SizedBox(width: 12),
                        Flexible(child: amountBlock),
                      ],
                    ],
                  ),
                  if (showsCreditDetails) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: colors.outlineVariant),
                    const SizedBox(height: 10),
                    Text(
                      'Pending payment: ${CurrencyFormatter.format(account.pendingPayment, currency)}',
                      style: detailStyle?.copyWith(
                        color: account.pendingPayment > 0 ? colors.error : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Utilized: ${(utilization * 100).toStringAsFixed(0)}% of ${CurrencyFormatter.format(limit, currency)}',
                      style: detailStyle,
                    ),
                    const SizedBox(height: 8),
                    AnimatedCreditProgressBar(
                      ratio: utilization.clamp(0.0, 1.0),
                      activeColor: usedColor,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
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
