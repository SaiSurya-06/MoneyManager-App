import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/analytics/daily_budget_calculator.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../models/category.dart';
import '../../../providers/accounts_provider.dart';
import '../../../providers/budgets_provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/planning_state_provider.dart';
import '../../../providers/transactions_provider.dart';
import '../../../widgets/common/glassmorphism_card.dart';

class DailySpendingCalendar extends ConsumerStatefulWidget {
  const DailySpendingCalendar({super.key});

  @override
  ConsumerState<DailySpendingCalendar> createState() => _DailySpendingCalendarState();
}

class _DailySpendingCalendarState extends ConsumerState<DailySpendingCalendar> {
  late DateTime _selectedMonthDate;
  int? _selectedCategoryId; // null = All Categories (Overall Budget)
  bool _isAgendaView = false; // Toggle between Calendar Grid and List/Agenda

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonthDate = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonthDate = DateTime(
        _selectedMonthDate.year,
        _selectedMonthDate.month - 1,
        1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonthDate = DateTime(
        _selectedMonthDate.year,
        _selectedMonthDate.month + 1,
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    const currency = 'INR';

    final budgetsState = ref.watch(budgetsProvider);
    final categories = ref.watch(categoriesProvider).categories;
    final transactions = ref.watch(transactionsProvider).transactions;
    final accounts = ref.watch(accountsProvider).accounts;

    final accountMap = {for (var a in accounts) a.id: a.name};
    final categoryMap = {for (var c in categories) c.id: c.name};

    // Determine the monthly budget for the selected month and category
    int monthlyBudgetMinor = 0;

    if (_selectedCategoryId == null) {
      // Overall monthly budget: sum of all category budgets for this month
      for (var b in budgetsState.budgets) {
        monthlyBudgetMinor += b.limitAmountMinor;
      }
      // If no category budgets are configured, check planning state
      if (monthlyBudgetMinor == 0) {
        final plan = ref.watch(planningStateProvider);
        final totalNeedsWants = (plan.salary + plan.otherIncome) * ((plan.needsPct + plan.wantsPct) / 100.0);
        monthlyBudgetMinor = (totalNeedsWants * 100).toInt();
      }
    } else {
      final b = budgetsState.budgets.where((b) => b.categoryId == _selectedCategoryId).firstOrNull;
      monthlyBudgetMinor = b?.limitAmountMinor ?? 0;
    }

    // Filter transactions for this month
    final monthTxs = transactions.where((tx) {
      return tx.date.year == _selectedMonthDate.year &&
          tx.date.month == _selectedMonthDate.month;
    }).toList();

    // Calculate daily breakdown using exact minor units
    final summary = DailySpendingCalculator.calculate(
      year: _selectedMonthDate.year,
      month: _selectedMonthDate.month,
      monthlyBudgetMinor: monthlyBudgetMinor,
      transactions: monthTxs,
      categoryId: _selectedCategoryId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Month Selector & View Toggle Header
        _buildMonthHeader(context, isDark, textColor),

        const SizedBox(height: 12),

        // 2. Category Filter Chips Row
        _buildCategoryFilterRow(categories, isDark),

        const SizedBox(height: 14),

        // 3. Monthly Summary Card
        _buildMonthlySummaryCard(summary, currency, isDark, textColor),

        const SizedBox(height: 16),

        // 4. Calendar Grid or Agenda View
        _isAgendaView
            ? _buildAgendaView(summary, currency, isDark, textColor, accountMap, categoryMap)
            : _buildCalendarGridView(summary, currency, isDark, textColor, accountMap, categoryMap),
      ],
    );
  }

  Widget _buildMonthHeader(BuildContext context, bool isDark, Color textColor) {
    final monthTitle = DateFormat('MMMM yyyy').format(_selectedMonthDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 24),
              onPressed: _previousMonth,
              tooltip: 'Previous Month',
            ),
            Text(
              monthTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
                color: textColor,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 24),
              onPressed: _nextMonth,
              tooltip: 'Next Month',
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                _isAgendaView ? Icons.calendar_view_month : Icons.view_agenda_outlined,
                size: 22,
                color: const Color(0xFFE53935),
              ),
              tooltip: _isAgendaView ? 'Switch to Calendar Grid' : 'Switch to Agenda List',
              onPressed: () {
                setState(() {
                  _isAgendaView = !_isAgendaView;
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryFilterRow(List<Category> categories, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All Categories'),
            selected: _selectedCategoryId == null,
            onSelected: (selected) {
              if (selected) setState(() => _selectedCategoryId = null);
            },
            selectedColor: const Color(0xFFE53935).withValues(alpha: 0.2),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: _selectedCategoryId == null ? FontWeight.bold : FontWeight.normal,
              color: _selectedCategoryId == null ? const Color(0xFFE53935) : null,
            ),
          ),
          const SizedBox(width: 8),
          ...categories.where((c) => c.type == 'expense' || c.type == 'both').map((cat) {
            final isSelected = _selectedCategoryId == cat.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text(cat.name),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategoryId = selected ? cat.id : null;
                  });
                },
                selectedColor: const Color(0xFFE53935).withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFFE53935) : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMonthlySummaryCard(
    DailyBudgetMonthSummary summary,
    String currency,
    bool isDark,
    Color textColor,
  ) {
    final isUnder = summary.netRolloverBalanceMinor >= 0;
    final statusColor = isUnder ? const Color(0xFF43A047) : const Color(0xFFE53935);

    return GlassmorphismCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daily Rollover Tracking',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.3),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUnder ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      summary.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildSummaryMetric(
                'Total Budget',
                CurrencyFormatter.format(summary.totalBudget, currency),
                textColor,
              ),
              _buildSummaryMetric(
                'Spent So Far',
                CurrencyFormatter.format(summary.totalSpent, currency),
                const Color(0xFFE53935),
              ),
              _buildSummaryMetric(
                'Rollover Balance',
                CurrencyFormatter.format(summary.netRolloverBalance, currency),
                statusColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGridView(
    DailyBudgetMonthSummary summary,
    String currency,
    bool isDark,
    Color textColor,
    Map<int?, String> accountMap,
    Map<int?, String> categoryMap,
  ) {
    final firstDayOfWeek = DateTime(_selectedMonthDate.year, _selectedMonthDate.month, 1).weekday; // 1 = Mon, 7 = Sun
    final offset = firstDayOfWeek - 1; // 0 to 6

    const weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        // Weekday Headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekDays.map((d) {
            return SizedBox(
              width: 38,
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Calendar Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: offset + summary.totalDays,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            if (index < offset) {
              return const SizedBox.shrink(); // Empty padding for first week
            }
            final dayIndex = index - offset;
            final day = summary.days[dayIndex];
            return _buildDayCell(context, day, currency, isDark, textColor, accountMap, categoryMap);
          },
        ),
      ],
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DailyBudgetDay day,
    String currency,
    bool isDark,
    Color textColor,
    Map<int?, String> accountMap,
    Map<int?, String> categoryMap,
  ) {
    final Color cellColor;
    final Color badgeColor;

    if (day.isFuture) {
      cellColor = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
      badgeColor = Colors.grey;
    } else if (day.isUnderBudget || day.isAtBudget) {
      cellColor = const Color(0xFF43A047).withValues(alpha: 0.12);
      badgeColor = const Color(0xFF43A047);
    } else {
      cellColor = const Color(0xFFE53935).withValues(alpha: 0.12);
      badgeColor = const Color(0xFFE53935);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showDayDetail(context, day, currency, isDark, accountMap, categoryMap),
      child: Container(
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: day.isFuture ? Colors.transparent : badgeColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${day.dayNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: day.isFuture ? Colors.grey : textColor,
                  ),
                ),
                if (!day.isFuture)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badgeColor,
                    ),
                  ),
              ],
            ),
            if (!day.isFuture) ...[
              Text(
                CurrencyFormatter.format(day.actualSpent, currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
              Text(
                'Avail: ${CurrencyFormatter.format(day.available, currency)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 7.5, color: Colors.grey),
              ),
            ] else ...[
              Text(
                'Proj: ${CurrencyFormatter.format(day.baseAllowance, currency)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 7.5, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaView(
    DailyBudgetMonthSummary summary,
    String currency,
    bool isDark,
    Color textColor,
    Map<int?, String> accountMap,
    Map<int?, String> categoryMap,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: summary.days.length,
      itemBuilder: (context, idx) {
        final day = summary.days[idx];
        final isUnder = day.isUnderBudget || day.isAtBudget;
        final color = day.isFuture
            ? Colors.grey
            : (isUnder ? const Color(0xFF43A047) : const Color(0xFFE53935));

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: GlassmorphismCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: InkWell(
              onTap: () => _showDayDetail(context, day, currency, isDark, accountMap, categoryMap),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${day.dayNumber}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, MMM d').format(day.date),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          day.isFuture
                              ? 'Projected Base: ${CurrencyFormatter.format(day.baseAllowance, currency)}'
                              : 'Spent: ${CurrencyFormatter.format(day.actualSpent, currency)} • Avail: ${CurrencyFormatter.format(day.available, currency)}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (!day.isFuture)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Carried Out: ${CurrencyFormatter.format(day.carriedOut, currency)}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                        ),
                        Text(
                          day.status.toUpperCase(),
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDayDetail(
    BuildContext context,
    DailyBudgetDay day,
    String currency,
    bool isDark,
    Map<int?, String> accountMap,
    Map<int?, String> categoryMap,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: ListView(
                controller: scrollController,
                children: [
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
                  const SizedBox(height: 16),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(day.date),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    day.isFuture ? 'Future Budget Day' : 'Daily Rollover Accounting',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // Financial Breakdown Grid
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161625) : const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _buildBreakdownRow('Base Daily Allowance', CurrencyFormatter.format(day.baseAllowance, currency)),
                        const Divider(height: 14),
                        _buildBreakdownRow('Carried In from Prev Day', CurrencyFormatter.format(day.carriedIn, currency)),
                        const Divider(height: 14),
                        _buildBreakdownRow('Total Available Today', CurrencyFormatter.format(day.available, currency), isBold: true),
                        const Divider(height: 14),
                        _buildBreakdownRow('Actual Eligible Spend', CurrencyFormatter.format(day.actualSpent, currency), color: const Color(0xFFE53935)),
                        const Divider(height: 14),
                        _buildBreakdownRow(
                          'Carried Out to Next Day',
                          CurrencyFormatter.format(day.carriedOut, currency),
                          isBold: true,
                          color: day.carriedOutMinor >= 0 ? const Color(0xFF43A047) : const Color(0xFFE53935),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Transaction List
                  Text(
                    'Transactions (${day.transactions.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  if (day.transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text(
                          'No budget-deductible expenses logged on this day.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    ...day.transactions.map((tx) {
                      final accName = accountMap[tx.accountId] ?? 'Account';
                      final catName = categoryMap[tx.categoryId] ?? 'Category';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161625) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_downward, color: Color(0xFFE53935), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('$catName • $accName', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(tx.amount, currency),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFE53935)),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
