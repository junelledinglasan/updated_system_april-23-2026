import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class _ChartColors {
  static const cardBorder = Color(0xFFDDEEDD);
  static const title      = Color(0xFF1B3A1B);
  static const sub        = Color(0xFFAAAAAA);
  static const line       = Color(0xFF2E7D32);
  static const lineFill   = Color(0x142E7D32); // rgba(46,125,50,0.08)
  static const grid       = Color(0xFFF0F4F1);
}

const List<String> _kMonthShort = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

Widget _cardShell({required String title, required String sub, required Widget child, Widget? legend}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _ChartColors.cardBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ChartColors.title)),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(fontSize: 10, color: _ChartColors.sub)),
                ],
              ),
            ),
            if (legend != null) legend,
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(height: 200, child: child),
      ],
    ),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── Overall Collection — Line Chart ─────────────────────────────────────────
class CollectionLineChartCard extends StatelessWidget {
  final List<double> monthlyValues; // 12 values, Jan..Dec
  final bool loading;
  const CollectionLineChartCard({super.key, required this.monthlyValues, this.loading = false});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _cardShell(
        title: 'Overall Collection',
        sub: 'Monthly collection trend',
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final values = monthlyValues.length == 12 ? monthlyValues : List<double>.filled(12, 0);
    final maxY = (values.reduce((a, b) => a > b ? a : b)) * 1.2;

    return _cardShell(
      title: 'Overall Collection',
      sub: 'Monthly collection trend',
      legend: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: _ChartColors.line, label: 'Collection'),
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY == 0 ? 100 : maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY == 0 ? 100 : maxY) / 4,
            getDrawingHorizontalLine: (_) => const FlLine(color: _ChartColors.grid, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (v, meta) => Text(
                  '₱${(v / 1000).toStringAsFixed(0)}k',
                  style: const TextStyle(fontSize: 8, color: _ChartColors.sub),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 18,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i > 11) return const SizedBox.shrink();
                  return Text(_kMonthShort[i], style: const TextStyle(fontSize: 8, color: _ChartColors.sub));
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(12, (i) => FlSpot(i.toDouble(), values[i])),
              isCurved: true,
              color: _ChartColors.line,
              barWidth: 2,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: _ChartColors.lineFill),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem('₱${s.y.toStringAsFixed(0)}', const TextStyle(color: Colors.white, fontSize: 10)))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Loan Status Summary — Bar Chart ─────────────────────────────────────────
class LoanStatusBarChartCard extends StatelessWidget {
  final Map<String, int> statusCounts; // e.g. {"For Review":5,"Active":10,...}
  final bool loading;
  const LoanStatusBarChartCard({super.key, required this.statusCounts, this.loading = false});

  static const _labels = ['For Review','Active','Declined','Completed','Overdue'];
  static const _colors = [Color(0xFFF57C00), Color(0xFF2E7D32), Color(0xFFE53935), Color(0xFF1565C0), Color(0xFFC62828)];

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _cardShell(
        title: 'Loan Status Summary',
        sub: 'All-time distribution',
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final labels = statusCounts.isNotEmpty ? statusCounts.keys.toList() : _labels;
    final values = labels.map((l) => (statusCounts[l] ?? 0).toDouble()).toList();
    final maxY = (values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b)) * 1.3;

    return _cardShell(
      title: 'Loan Status Summary',
      sub: 'All-time distribution',
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 5 : maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: _ChartColors.grid, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 26,
                getTitlesWidget: (v, meta) => Text('${v.toInt()}', style: const TextStyle(fontSize: 8, color: _ChartColors.sub)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  final short = labels[i].length > 6 ? labels[i].substring(0, 6) : labels[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(short, style: const TextStyle(fontSize: 7.5, color: _ChartColors.sub)),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(labels.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: _colors[i % _colors.length],
                  width: 18,
                  borderRadius: BorderRadius.circular(5),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ─── Loan Type Breakdown — Doughnut Chart ────────────────────────────────────
class LoanTypeDoughnutChartCard extends StatelessWidget {
  final Map<String, int> typeCounts;
  final bool loading;
  const LoanTypeDoughnutChartCard({super.key, required this.typeCounts, this.loading = false});

  static const _labels = ['Regular Loan','Emergency','Salary','Housing','Business'];
  static const _colors = [Color(0xFF2E7D32), Color(0xFF4CAF50), Color(0xFFF57C00), Color(0xFF1565C0), Color(0xFFA5D6A7)];

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _cardShell(
        title: 'Loan Type Breakdown',
        sub: 'Active & Overdue by category',
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final labels = typeCounts.isNotEmpty ? typeCounts.keys.toList() : _labels;
    final values = labels.map((l) => (typeCounts[l] ?? 0).toDouble()).toList();
    final total = values.fold<double>(0, (a, b) => a + b);

    return _cardShell(
      title: 'Loan Type Breakdown',
      sub: 'Active & Overdue by category',
      child: total == 0
          ? const Center(child: Text('No data yet.', style: TextStyle(fontSize: 12, color: _ChartColors.sub)))
          : Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 32,
                      sections: List.generate(labels.length, (i) {
                        final v = values[i];
                        if (v == 0) return null;
                        return PieChartSectionData(
                          value: v,
                          color: _colors[i % _colors.length],
                          title: '',
                          radius: 34,
                        );
                      }).whereType<PieChartSectionData>().toList(),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(labels.length, (i) {
                      if (values[i] == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: _colors[i % _colors.length], shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(labels[i], style: const TextStyle(fontSize: 9, color: Color(0xFF666666)), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
    );
  }
}