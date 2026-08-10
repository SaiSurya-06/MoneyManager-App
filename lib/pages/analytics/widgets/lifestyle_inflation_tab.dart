import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/category_icon_helper.dart';
import '../../../widgets/common/glassmorphism_card.dart';
import '../../../providers/categories_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/category.dart';
import '../trend_analytics_page.dart';

class LifestyleInflationTab extends ConsumerStatefulWidget {
  const LifestyleInflationTab({super.key});

  @override
  ConsumerState<LifestyleInflationTab> createState() => _LifestyleInflationTabState();
}

enum InflationTimeframe { monthly, yearly }
enum MonthlyBaseline { previousMonth, sameMonthLastYear, threeMonthAverage }

class CategoryInflationData {
  final Category category;
  final double currentSpend;
  final double baselineSpend;
  final double dollarChange;
  final double inflationRate; // Percentage

  CategoryInflationData({
    required this.category,
    required this.currentSpend,
    required this.baselineSpend,
    required this.dollarChange,
    required this.inflationRate,
  });
}

class _LifestyleInflationTabState extends ConsumerState<LifestyleInflationTab> {
  InflationTimeframe _timeframe = InflationTimeframe.monthly;
  MonthlyBaseline _monthlyBaseline = MonthlyBaseline.previousMonth;
  String _searchQuery = '';

  Color _parseCategoryColor(String colorStr) {
    final hex = '0xFF${colorStr.replaceAll("#", "")}';
    return Color(int.tryParse(hex) ?? 0xFFE53935);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = ref.watch(authProvider).profile?.preferredCurrency ?? 'USD';
    final categories = ref.watch(categoriesProvider).categories;
    final derivedValues = ref.watch(derivedAnalyticsProvider);
    final transactions = derivedValues.filteredTransactions;

    final now = DateTime.now();

    // 1. Calculate Baseline and Current Spends based on Timeframe and Baseline selection
    double totalCurrentSpend = 0.0;
    double totalBaselineSpend = 0.0;
    final List<CategoryInflationData> itemBreakdown = [];

    final expenseCategories = categories.where((c) => c.type == 'expense' || c.type == 'both').toList();

    for (var cat in expenseCategories) {
      if (cat.type == 'person') continue;
      double currentSpend = 0.0;
      double baselineSpend = 0.0;

      if (_timeframe == InflationTimeframe.monthly) {
        // Current Month: this month's expense
        currentSpend = transactions.where((tx) =>
            tx.type == 'expense' &&
            tx.categoryId == cat.id &&
            tx.date.year == now.year &&
            tx.date.month == now.month
        ).fold(0.0, (sum, tx) => sum + tx.amount);

        if (_monthlyBaseline == MonthlyBaseline.previousMonth) {
          final prevMonthDate = DateTime(now.year, now.month - 1, 1);
          baselineSpend = transactions.where((tx) =>
              tx.type == 'expense' &&
              tx.categoryId == cat.id &&
              tx.date.year == prevMonthDate.year &&
              tx.date.month == prevMonthDate.month
          ).fold(0.0, (sum, tx) => sum + tx.amount);
        } else if (_monthlyBaseline == MonthlyBaseline.sameMonthLastYear) {
          baselineSpend = transactions.where((tx) =>
              tx.type == 'expense' &&
              tx.categoryId == cat.id &&
              tx.date.year == now.year - 1 &&
              tx.date.month == now.month
          ).fold(0.0, (sum, tx) => sum + tx.amount);
        } else if (_monthlyBaseline == MonthlyBaseline.threeMonthAverage) {
          double sum3m = 0.0;
          for (int i = 1; i <= 3; i++) {
            final pastDate = DateTime(now.year, now.month - i, 1);
            sum3m += transactions.where((tx) =>
                tx.type == 'expense' &&
                tx.categoryId == cat.id &&
                tx.date.year == pastDate.year &&
                tx.date.month == pastDate.month
            ).fold(0.0, (sum, tx) => sum + tx.amount);
          }
          baselineSpend = sum3m / 3.0;
        }
      } else {
        // Yearly View: Current Year vs Previous Year
        currentSpend = transactions.where((tx) =>
            tx.type == 'expense' &&
            tx.categoryId == cat.id &&
            tx.date.year == now.year
        ).fold(0.0, (sum, tx) => sum + tx.amount);

        baselineSpend = transactions.where((tx) =>
            tx.type == 'expense' &&
            tx.categoryId == cat.id &&
            tx.date.year == now.year - 1
        ).fold(0.0, (sum, tx) => sum + tx.amount);
      }

      final dollarChange = currentSpend - baselineSpend;
      double inflationRate = 0.0;
      if (baselineSpend > 0) {
        inflationRate = (dollarChange / baselineSpend) * 100.0;
      } else if (currentSpend > 0) {
        inflationRate = 100.0; // New spending started
      }

      totalCurrentSpend += currentSpend;
      totalBaselineSpend += baselineSpend;

      if (currentSpend > 0 || baselineSpend > 0) {
        itemBreakdown.add(CategoryInflationData(
          category: cat,
          currentSpend: currentSpend,
          baselineSpend: baselineSpend,
          dollarChange: dollarChange,
          inflationRate: inflationRate,
        ));
      }
    }

    // Sort categories by highest dollar increase first
    itemBreakdown.sort((a, b) => b.dollarChange.compareTo(a.dollarChange));

    final totalDollarChange = totalCurrentSpend - totalBaselineSpend;
    double overallInflationRate = 0.0;
    if (totalBaselineSpend > 0) {
      overallInflationRate = (totalDollarChange / totalBaselineSpend) * 100.0;
    } else if (totalCurrentSpend > 0) {
      overallInflationRate = 100.0;
    }

    final topInflatedCategory = itemBreakdown.isNotEmpty ? itemBreakdown.first : null;

    // Risk Rating
    String riskRating = 'Low';
    Color riskColor = Colors.green;
    if (overallInflationRate > 25.0) {
      riskRating = 'Severe';
      riskColor = const Color(0xFFE53935);
    } else if (overallInflationRate > 15.0) {
      riskRating = 'High';
      riskColor = Colors.orange;
    } else if (overallInflationRate > 5.0) {
      riskRating = 'Moderate';
      riskColor = Colors.amber;
    }

    // Filter by search query
    final filteredBreakdown = itemBreakdown.where((item) =>
        item.category.name.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title & info banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LIFESTYLE INFLATION ANALYZER',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    _timeframe == InflationTimeframe.monthly ? 'Monthly Creep Analysis' : 'Yearly Creep Analysis',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: riskColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      overallInflationRate > 0 ? Icons.local_fire_department : Icons.verified_user,
                      size: 14,
                      color: riskColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Risk: $riskRating',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: riskColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Controls Row: Timeframe switch & Baseline selection
          Row(
            children: [
              // Segmented Control for Timeframe
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _timeframe = InflationTimeframe.monthly;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _timeframe == InflationTimeframe.monthly
                                  ? const Color(0xFFE53935)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Monthly View',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _timeframe == InflationTimeframe.monthly ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _timeframe = InflationTimeframe.yearly;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _timeframe == InflationTimeframe.yearly
                                  ? const Color(0xFFE53935)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Yearly View',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _timeframe == InflationTimeframe.yearly ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_timeframe == InflationTimeframe.monthly)
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: DropdownButton<MonthlyBaseline>(
                      value: _monthlyBaseline,
                      isDense: true,
                      dropdownColor: isDark ? const Color(0xFF161625) : Colors.white,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                      items: const [
                        DropdownMenuItem(
                          value: MonthlyBaseline.previousMonth,
                          child: Text('vs Prev Month'),
                        ),
                        DropdownMenuItem(
                          value: MonthlyBaseline.sameMonthLastYear,
                          child: Text('vs Same Month Last Year'),
                        ),
                        DropdownMenuItem(
                          value: MonthlyBaseline.threeMonthAverage,
                          child: Text('vs 3-Mo Average'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _monthlyBaseline = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Hero KPI Cards Grid (4 Cards)
          Row(
            children: [
              // Overall Inflation Rate KPI Card
              Expanded(
                child: GlassmorphismCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OVERALL INFLATION',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            overallInflationRate > 0 ? Icons.trending_up : Icons.trending_down,
                            color: overallInflationRate > 0 ? const Color(0xFFE53935) : Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${overallInflationRate >= 0 ? "+" : ""}${overallInflationRate.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: overallInflationRate > 0 ? const Color(0xFFE53935) : Colors.green,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        overallInflationRate > 0 ? 'Creep detected' : 'Spending reduced',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Spend Change KPI Card
              Expanded(
                child: GlassmorphismCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NET SPEND DELTA',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${totalDollarChange >= 0 ? "+" : ""}${CurrencyFormatter.format(totalDollarChange, currency)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: totalDollarChange > 0 ? const Color(0xFFE53935) : Colors.green,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'vs baseline (${CurrencyFormatter.format(totalBaselineSpend, currency)})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              // Top Driver KPI Card
              Expanded(
                child: GlassmorphismCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOP CREEP DRIVER',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        topInflatedCategory != null && topInflatedCategory.dollarChange > 0
                            ? topInflatedCategory.category.name
                            : 'None',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        topInflatedCategory != null && topInflatedCategory.dollarChange > 0
                            ? '+${CurrencyFormatter.format(topInflatedCategory.dollarChange, currency)} increase'
                            : 'No inflation driver',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Current Period Total Spend
              Expanded(
                child: GlassmorphismCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CURRENT PERIOD SPEND',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyFormatter.format(totalCurrentSpend, currency),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeframe == InflationTimeframe.monthly ? DateFormat('MMMM yyyy').format(now) : '${now.year}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Visual FL Chart: Top 5 Categories Baseline vs Current
          if (itemBreakdown.isNotEmpty) ...[
            Text(
              'TOP CATEGORIES: BASELINE vs CURRENT',
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),
            GlassmorphismCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Spending Comparison', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Row(
                        children: [
                          _buildLegendDot(Colors.grey.withValues(alpha: 0.5), 'Baseline'),
                          const SizedBox(width: 12),
                          _buildLegendDot(const Color(0xFFE53935), 'Current'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (itemBreakdown.take(5).map((e) => mathMax(e.currentSpend, e.baselineSpend)).fold(0.0, (m, v) => v > m ? v : m)) * 1.2,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final catData = itemBreakdown.take(5).toList()[groupIndex];
                              final isBaseline = rodIndex == 0;
                              return BarTooltipItem(
                                '${catData.category.name}\n${isBaseline ? "Baseline" : "Current"}: ${CurrencyFormatter.format(rod.toY, currency)}',
                                TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                final top5 = itemBreakdown.take(5).toList();
                                if (idx >= 0 && idx < top5.length) {
                                  final name = top5[idx].category.name;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      name.length > 7 ? '${name.substring(0, 6)}…' : name,
                                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: itemBreakdown.take(5).toList().asMap().entries.map((entry) {
                          final idx = entry.key;
                          final data = entry.value;
                          return BarChartGroupData(
                            x: idx,
                            barRods: [
                              BarChartRodData(
                                toY: data.baselineSpend,
                                color: isDark ? Colors.white24 : Colors.black12,
                                width: 12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              BarChartRodData(
                                toY: data.currentSpend,
                                color: const Color(0xFFE53935),
                                width: 12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Category Breakdown List Header & Search
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CATEGORY BREAKDOWN (${filteredBreakdown.length})',
                style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Search Field
          Container(
            height: 40,
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
                icon: Icon(Icons.search, size: 18, color: Colors.grey),
                hintText: 'Search categories...',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Category Inflation Cards List
          if (filteredBreakdown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text('No categories with spending data found.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredBreakdown.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = filteredBreakdown[index];
                final catColor = _parseCategoryColor(item.category.color);
                final isInflated = item.dollarChange > 0;
                final isDeflated = item.dollarChange < 0;

                return GlassmorphismCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: catColor.withValues(alpha: 0.15),
                        child: Icon(
                          CategoryIconHelper.getIcon(item.category.icon),
                          color: catColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.category.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Inter'),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isInflated
                                        ? const Color(0xFFE53935).withValues(alpha: 0.15)
                                        : (isDeflated ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${item.inflationRate >= 0 ? "+" : ""}${item.inflationRate.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isInflated
                                          ? const Color(0xFFE53935)
                                          : (isDeflated ? Colors.green : Colors.grey),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Current: ${CurrencyFormatter.format(item.currentSpend, currency)}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                Text(
                                  'Baseline: ${CurrencyFormatter.format(item.baselineSpend, currency)}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Delta change bar
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: (item.baselineSpend > 0 ? (item.currentSpend / (item.baselineSpend * 1.5)) : 1.0).clamp(0.0, 1.0),
                                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isInflated ? const Color(0xFFE53935) : Colors.green,
                                      ),
                                      minHeight: 4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${isInflated ? "+" : ""}${CurrencyFormatter.format(item.dollarChange, currency)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isInflated ? const Color(0xFFE53935) : (isDeflated ? Colors.green : Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),

          // AI Lifestyle Creep Recommendations Card
          GlassmorphismCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'AI Lifestyle Creep Insights',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _generateAIRecommendation(overallInflationRate, topInflatedCategory, currency),
                  style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  double mathMax(double a, double b) => a > b ? a : b;

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  String _generateAIRecommendation(double inflationRate, CategoryInflationData? topDriver, String currency) {
    if (inflationRate > 20.0) {
      final driverName = topDriver?.category.name ?? 'discretionary items';
      final driverAmount = topDriver != null ? CurrencyFormatter.format(topDriver.dollarChange, currency) : '';
      return '⚠️ High Lifestyle Inflation Alert! Your spending grew by ${inflationRate.toStringAsFixed(1)}% compared to your baseline. The primary driver is "$driverName" with an extra $driverAmount in spending. Consider capping budgets for non-essential categories to protect your monthly savings buffer.';
    } else if (inflationRate > 5.0) {
      return '⚡ Moderate Creep Notice: Your lifestyle expenses have grown by ${inflationRate.toStringAsFixed(1)}%. Reviewing subscription fees and recurring dining expenses can easily bring your spending back inline with historical baselines.';
    } else {
      return '🎉 Excellent Expense Control! Your spending is well within or below your historical baseline (${inflationRate.toStringAsFixed(1)}% change). You are effectively preventing lifestyle creep!';
    }
  }
}
