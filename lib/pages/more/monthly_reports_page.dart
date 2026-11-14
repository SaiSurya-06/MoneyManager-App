import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/services/monthly_pdf_report_service.dart';
import '../../widgets/common/glassmorphism_card.dart';

class MonthlyReportsPage extends ConsumerStatefulWidget {
  const MonthlyReportsPage({super.key});

  @override
  ConsumerState<MonthlyReportsPage> createState() => _MonthlyReportsPageState();
}

class _MonthlyReportsPageState extends ConsumerState<MonthlyReportsPage> {
  bool _isLoading = true;
  List<MonthlyReportRecord> _reports = [];
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month - 1, 1);
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final history = await MonthlyPdfReportService.instance.getReportHistory();
    if (mounted) {
      setState(() {
        _reports = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _generateReports({bool force = false}) async {
    final monthStr = DateFormat('yyyy-MM').format(_selectedMonth);
    setState(() => _isLoading = true);
    try {
      await MonthlyPdfReportService.instance.generateReportsForMonth(
        monthStr,
        forceRegenerate: force,
      );
      await _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reports for $monthStr generated successfully!'),
            backgroundColor: const Color(0xFF43A047),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate reports: $e'),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monthly Financial Reports',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Reports',
            onPressed: _loadReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935)))
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // 1. Generation Card
                GlassmorphismCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Generate Monthly Reports',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Automated reports are created on the 1st of every month. You can also generate or re-generate reports for any past month below.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: () {
                                  setState(() {
                                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                                  });
                                },
                              ),
                              Text(
                                DateFormat('MMMM yyyy').format(_selectedMonth),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () {
                                  setState(() {
                                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                                  });
                                },
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                            label: const Text('Generate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => _generateReports(force: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Report History List Header
                Text(
                  'Generated Reports History (${_reports.length})',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 10),

                if (_reports.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.description_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No monthly reports generated yet.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _generateReports(),
                            child: const Text('Generate Previous Month Report Now'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ..._reports.map((report) => _buildReportCard(report, isDark, textColor)),
              ],
            ),
    );
  }

  Widget _buildReportCard(MonthlyReportRecord report, bool isDark, Color textColor) {
    final isIncExp = report.reportType == 'income_expense';
    final reportTitle = isIncExp ? 'Income & Expense Analysis' : 'Budget Performance Report';
    final iconColor = isIncExp ? const Color(0xFF43A047) : const Color(0xFFE53935);
    final sizeKb = (report.fileSizeBytes / 1024).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassmorphismCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.picture_as_pdf, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reportTitle,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Period: ${report.reportingMonth} • $sizeKb KB • ${report.isAutoGenerated ? "Auto" : "Manual"}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share, size: 20),
                  tooltip: 'Share Report',
                  onPressed: () async {
                    try {
                      await MonthlyPdfReportService.instance.shareReport(report.filePath);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to share: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'SHA-256: ${report.checksum.substring(0, 16)}...',
                    style: const TextStyle(fontSize: 9, color: Colors.grey, fontFamily: 'monospace'),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      final result = await OpenFilex.open(report.filePath);
                      if (result.type != ResultType.done && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open file: ${result.message}')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Open error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Open PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
