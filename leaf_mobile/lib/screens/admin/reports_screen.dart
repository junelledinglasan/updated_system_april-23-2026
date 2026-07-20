import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/reports_service.dart';
import '../../widgets/admin/admin_scaffold_helpers.dart';

class _RPColors {
  static const title  = Color(0xFF1B5E20);
  static const sub    = Color(0xFFAAAAAA);
  static const green  = Color(0xFF2E7D32);
  static const border = Color(0xFFC8DDC8);
  static const blue   = Color(0xFF1565C0);
  static const orange = Color(0xFFE65100);
  static const purple = Color(0xFF6A1B9A);
  static const teal   = Color(0xFF00796B);
  static const red    = Color(0xFFC62828);
}

const List<String> kReportTabs = ['overview', 'charts', 'classification', 'performance', 'generate', 'audit'];
const Map<String, String> kReportTabLabels = {
  'overview': 'Overview',
  'charts': 'Charts',
  'classification': 'Classification',
  'performance': 'Performance',
  'generate': 'Generate Report',
  'audit': 'Audit Log',
};
const Map<String, IconData> kReportTabIcons = {
  'overview': Icons.bar_chart_outlined,
  'charts': Icons.trending_up,
  'classification': Icons.pie_chart_outline,
  'performance': Icons.groups_outlined,
  'generate': Icons.description_outlined,
  'audit': Icons.link,
};

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _activeTab = 'overview';
  String _selectedYear = '${DateTime.now().year}';
  bool _loading = true;

  Map<String, dynamic> _overview = {};
  List<dynamic> _monthly = [];
  List<dynamic> _yearlyComp = [];
  List<dynamic> _monthlyLoans = [];
  Map<String, dynamic> _efficiency = {'data': [], 'expected_monthly': 0};
  Map<String, dynamic> _maturities = {'count': 0, 'data': []};
  Map<String, dynamic> _memberGrowth = {'data': [], 'total_members': 0};
  int _maturMonths = 3;

  // ── Charts tab state ────────────────────────────────────────────────────
  bool _chartsLoading = true;
  bool _chartsFetched = false;
  Map<String, dynamic> _loanStatus = {};
  Map<String, dynamic> _loanType = {};
  Map<String, dynamic> _paymentBehavior = {};
  List<dynamic> _loanDistribution = [];
  List<dynamic> _overdueAnalysis = [];
  Map<String, dynamic> _approvalRate = {};
  List<dynamic> _repaymentProgress = [];

  // ── Classification tab state ────────────────────────────────────────────
  bool _classLoading = true;
  bool _classFetched = false;
  List<dynamic> _classification = [];
  Map<String, dynamic> _topBorrowers = {};
  Map<String, dynamic> _firstTimeBorrowers = {};

  // ── Performance tab state ───────────────────────────────────────────────
  bool _perfLoading = true;
  bool _perfFetched = false;
  List<dynamic> _memberPerformance = [];
  List<dynamic> _shareCapitalGrowth = [];
  Map<String, dynamic> _delinquency = {'count': 0, 'data': []};
  Map<String, dynamic> _riskAssessment = {'summary': {}, 'data': []};
  int _delinqMonths = 1;

  // ── Generate Report tab state ───────────────────────────────────────────
  String _genType = 'Member Report';
  DateTime _genFrom = DateTime(DateTime.now().year, 1, 1);
  DateTime _genTo = DateTime.now();
  bool _genLoading = false;
  Map<String, dynamic>? _genPreview;

  // ── Audit Log tab state ─────────────────────────────────────────────────
  bool _auditLoading = true;
  bool _auditFetched = false;
  List<dynamic> _auditLog = [];
  String _auditSearch = '';

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        () async { try { return await ReportsService.getOverview(_selectedYear); } catch (_) { return <String, dynamic>{}; } }(),
        () async { try { return await ReportsService.getMonthlyCollection(_selectedYear); } catch (_) { return <dynamic>[]; } }(),
        () async { try { return await ReportsService.getYearlyComparison(); } catch (_) { return <dynamic>[]; } }(),
        () async { try { return await ReportsService.getMonthlyLoans(_selectedYear); } catch (_) { return <dynamic>[]; } }(),
        () async { try { return await ReportsService.getCollectionEfficiency(_selectedYear); } catch (_) { return {'data': [], 'expected_monthly': 0}; } }(),
        () async { try { return await ReportsService.getUpcomingMaturities(months: _maturMonths); } catch (_) { return {'count': 0, 'data': []}; } }(),
        () async { try { return await ReportsService.getMemberGrowth(_selectedYear); } catch (_) { return {'data': [], 'total_members': 0}; } }(),
      ]);
      if (mounted) {
        setState(() {
          _overview = results[0] as Map<String, dynamic>;
          _monthly = results[1] as List<dynamic>;
          _yearlyComp = results[2] as List<dynamic>;
          _monthlyLoans = results[3] as List<dynamic>;
          _efficiency = results[4] as Map<String, dynamic>;
          _maturities = results[5] as Map<String, dynamic>;
          _memberGrowth = results[6] as Map<String, dynamic>;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadMaturities() async {
    try {
      final data = await ReportsService.getUpcomingMaturities(months: _maturMonths);
      if (mounted) setState(() => _maturities = data);
    } catch (_) {}
  }

  Future<void> _loadCharts({bool silent = false}) async {
    if (!silent) setState(() => _chartsLoading = true);
    try {
      final results = await Future.wait([
        () async { try { return await ReportsService.getLoanStatus('$_selectedYear'); } catch (_) { return <String, dynamic>{}; } }(),
        () async { try { return await ReportsService.getLoanType('$_selectedYear'); } catch (_) { return <String, dynamic>{}; } }(),
        () async { try { return await ReportsService.getPaymentBehavior(_selectedYear); } catch (_) { return <String, dynamic>{}; } }(),
        () async { try { return await ReportsService.getLoanDistribution(_selectedYear); } catch (_) { return <dynamic>[]; } }(),
        () async { try { return await ReportsService.getOverdueAnalysis(_selectedYear); } catch (_) { return <dynamic>[]; } }(),
        () async { try { return await ReportsService.getLoanApprovalRate(_selectedYear); } catch (_) { return <String, dynamic>{}; } }(),
        () async { try { return await ReportsService.getRepaymentProgress(_selectedYear); } catch (_) { return <dynamic>[]; } }(),
      ]);
      if (mounted) {
        setState(() {
          _loanStatus = results[0] as Map<String, dynamic>;
          _loanType = results[1] as Map<String, dynamic>;
          _paymentBehavior = results[2] as Map<String, dynamic>;
          _loanDistribution = results[3] as List<dynamic>;
          _overdueAnalysis = results[4] as List<dynamic>;
          _approvalRate = results[5] as Map<String, dynamic>;
          _repaymentProgress = results[6] as List<dynamic>;
          _chartsFetched = true;
        });
      }
    } finally {
      if (mounted) setState(() => _chartsLoading = false);
    }
  }

  Future<void> _loadClassification({bool silent = false}) async {
    if (!silent) setState(() => _classLoading = true);
    try {
      final results = await Future.wait([
        () async { try { return await ReportsService.getClassification(_selectedYear); } catch (_) { return <dynamic>[]; } }(),
        () async { try { return await ReportsService.getTopBorrowers(_selectedYear); } catch (_) { return <String, dynamic>{}; } }(),
        () async { try { return await ReportsService.getFirstTimeBorrowers(_selectedYear); } catch (_) { return <String, dynamic>{}; } }(),
      ]);
      if (mounted) {
        setState(() {
          _classification = results[0] as List<dynamic>;
          _topBorrowers = results[1] as Map<String, dynamic>;
          _firstTimeBorrowers = results[2] as Map<String, dynamic>;
          _classFetched = true;
        });
      }
    } finally {
      if (mounted) setState(() => _classLoading = false);
    }
  }

  Future<void> _loadPerformance({bool silent = false}) async {
    if (!silent) setState(() => _perfLoading = true);
    try {
      final results = await Future.wait([
        () async { try { return await ReportsService.getMemberPerformance(_selectedYear); } catch (_) { return <dynamic>[]; } }(),
        () async { try { return await ReportsService.getShareCapitalGrowth(_selectedYear); } catch (_) { return <dynamic>[]; } }(),
        () async { try { return await ReportsService.getDelinquency(months: _delinqMonths); } catch (_) { return {'count': 0, 'data': []}; } }(),
        () async { try { return await ReportsService.getRiskAssessment(); } catch (_) { return {'summary': {}, 'data': []}; } }(),
      ]);
      if (mounted) {
        setState(() {
          _memberPerformance = results[0] as List<dynamic>;
          _shareCapitalGrowth = results[1] as List<dynamic>;
          _delinquency = results[2] as Map<String, dynamic>;
          _riskAssessment = results[3] as Map<String, dynamic>;
          _perfFetched = true;
        });
      }
    } finally {
      if (mounted) setState(() => _perfLoading = false);
    }
  }

  Future<void> _reloadDelinquency() async {
    try {
      final data = await ReportsService.getDelinquency(months: _delinqMonths);
      if (mounted) setState(() => _delinquency = data);
    } catch (_) {}
  }

  Future<void> _loadPreview() async {
    setState(() { _genLoading = true; _genPreview = null; });
    try {
      final from = '${_genFrom.year}-${_genFrom.month.toString().padLeft(2, '0')}-${_genFrom.day.toString().padLeft(2, '0')}';
      final to = '${_genTo.year}-${_genTo.month.toString().padLeft(2, '0')}-${_genTo.day.toString().padLeft(2, '0')}';
      final data = await ReportsService.previewReport(_genType, from, to);
      if (mounted) setState(() => _genPreview = data);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load preview.'), backgroundColor: _RPColors.red));
    } finally {
      if (mounted) setState(() => _genLoading = false);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _genFrom : _genTo,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _genFrom = picked;
        } else {
          _genTo = picked;
        }
      });
    }
  }

  Future<void> _loadAudit({bool silent = false}) async {
    if (!silent) setState(() => _auditLoading = true);
    try {
      final data = await ReportsService.getAuditLog(_selectedYear);
      if (mounted) setState(() { _auditLog = data; _auditFetched = true; });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _auditLoading = false);
    }
  }

  void _onYearChange(String? y) {
    if (y == null) return;
    setState(() { _selectedYear = y; _chartsFetched = false; _classFetched = false; _perfFetched = false; _auditFetched = false; });
    if (_activeTab == 'overview') _loadOverview();
    if (_activeTab == 'charts') _loadCharts();
    if (_activeTab == 'classification') _loadClassification();
    if (_activeTab == 'performance') _loadPerformance();
    if (_activeTab == 'audit') _loadAudit();
  }

  void _onTabTap(String key) {
    setState(() => _activeTab = key);
    if (key == 'charts' && !_chartsFetched) _loadCharts();
    if (key == 'classification' && !_classFetched) _loadClassification();
    if (key == 'performance' && !_perfFetched) _loadPerformance();
    if (key == 'audit' && !_auditFetched) _loadAudit();
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = ['All', ...List.generate(12, (i) => '${currentYear + 1 - i}')]; // All, tapos current+1 pababa hanggang 10 taon nakaraan

    return AdminScreenScaffold(
      activeRouteKey: 'reports',
      body: RefreshIndicator(
        onRefresh: () => _loadOverview(),
        color: _RPColors.green,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reports & Analytics', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _RPColors.title)),
                  SizedBox(height: 2),
                  Text('Financial analytics, loan performance, member insights.', style: TextStyle(fontSize: 10.5, color: _RPColors.sub)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(8), color: Colors.white),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedYear,
                    isExpanded: true,
                    icon: const Icon(Icons.calendar_today, size: 14),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
                    items: years.map((y) => DropdownMenuItem(value: y, child: Text(y == 'All' ? 'All Years' : 'Year: $y'))).toList(),
                    onChanged: _onYearChange,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kReportTabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final key = kReportTabs[i];
                    final active = _activeTab == key;
                    return ChoiceChip(
                      avatar: Icon(kReportTabIcons[key], size: 13, color: active ? Colors.white : const Color(0xFF888888)),
                      label: Text(kReportTabLabels[key]!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white : const Color(0xFF888888))),
                      selected: active,
                      selectedColor: _RPColors.green,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: active ? _RPColors.green : _RPColors.border),
                      onSelected: (_) => _onTabTap(key),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              if (_activeTab == 'overview') ..._buildOverviewTab()
              else if (_activeTab == 'charts') ..._buildChartsTab()
              else if (_activeTab == 'classification') ..._buildClassificationTab()
              else if (_activeTab == 'performance') ..._buildPerformanceTab()
              else if (_activeTab == 'generate') ..._buildGenerateTab()
              else ..._buildAuditTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoon() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _RPColors.border)),
      child: Column(
        children: [
          Icon(kReportTabIcons[_activeTab], size: 32, color: const Color(0xFFCCCCCC)),
          const SizedBox(height: 10),
          Text('${kReportTabLabels[_activeTab]} — darating pa sa susunod na phase.', style: const TextStyle(color: _RPColors.sub, fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  List<Widget> _buildOverviewTab() {
    if (_loading) {
      return [const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator(color: _RPColors.green)))];
    }

    final kpis = [
      {'icon': Icons.account_balance_wallet_outlined, 'bg': const Color(0xFFE8F5E9), 'color': _RPColors.green, 'val': '₱${(double.tryParse('${_overview['total_collection'] ?? 0}') ?? 0).toStringAsFixed(0)}', 'label': 'Total Collection (YTD)'},
      {'icon': Icons.arrow_upward, 'bg': const Color(0xFFE3F2FD), 'color': _RPColors.blue, 'val': '₱${(double.tryParse('${_overview['total_releases'] ?? 0}') ?? 0).toStringAsFixed(0)}', 'label': 'Total Loan Releases'},
      {'icon': Icons.savings_outlined, 'bg': const Color(0xFFFFF8E1), 'color': _RPColors.orange, 'val': '₱${(double.tryParse('${_overview['total_savings_balance'] ?? 0}') ?? 0).toStringAsFixed(0)}', 'label': 'Total Savings Balance'},
      {'icon': Icons.monetization_on_outlined, 'bg': const Color(0xFFF3E5F5), 'color': _RPColors.purple, 'val': '₱${(double.tryParse('${_overview['total_share_capital'] ?? 0}') ?? 0).toStringAsFixed(0)}', 'label': 'Total Share Capital'},
      {'icon': Icons.percent, 'bg': const Color(0xFFE8F5E9), 'color': _RPColors.green, 'val': '${_overview['collection_rate'] ?? 0}%', 'label': 'Collection Rate'},
      {'icon': Icons.bar_chart, 'bg': const Color(0xFFE0F2F1), 'color': _RPColors.teal, 'val': '₱${(double.tryParse('${_overview['avg_loan_amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', 'label': 'Average Loan Amount'},
    ];

    return [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.3,
        children: kpis.map((k) => _KpiCard(icon: k['icon'] as IconData, bg: k['bg'] as Color, color: k['color'] as Color, value: k['val'] as String, label: k['label'] as String)).toList(),
      ),
      const SizedBox(height: 14),

      _ChartCard(
        title: 'Monthly Collection Trend',
        sub: '$_selectedYear — total payments collected per month',
        child: _monthly.isEmpty ? const _NoData() : BarChart(_buildMonthlyCollectionBarData()),
      ),
      const SizedBox(height: 14),
      _ChartCard(
        title: 'Monthly Loan Applications',
        sub: '$_selectedYear — number of loans applied per month',
        child: _monthlyLoans.isEmpty ? const _NoData() : LineChart(_buildMonthlyLoansLineData()),
      ),
      const SizedBox(height: 14),
      _ChartCard(
        title: 'Year-over-Year Comparison',
        sub: 'Collections · Loan Releases · Savings Deposits',
        legend: const Wrap(spacing: 10, children: [
          _LegendDot(color: _RPColors.green, label: 'Collections'),
          _LegendDot(color: _RPColors.blue, label: 'Loan Releases'),
          _LegendDot(color: _RPColors.orange, label: 'Savings'),
        ]),
        child: _yearlyComp.isEmpty ? const _NoData() : LineChart(_buildYearlyComparisonLineData()),
      ),
      const SizedBox(height: 14),

      _ChartCard(
        title: 'Collection Efficiency ($_selectedYear)',
        sub: 'Actual collected vs expected monthly collection',
        trailing: _buildEfficiencyList(),
      ),
      const SizedBox(height: 14),

      _ChartCard(
        title: 'Upcoming Loan Maturities',
        sub: 'Loans completing within the next $_maturMonths month${_maturMonths > 1 ? "s" : ""} — ${_maturities['count'] ?? 0} loans',
        headerTrailing: Wrap(
          spacing: 4,
          children: [1, 2, 3, 6].map((m) {
            final active = _maturMonths == m;
            return ChoiceChip(
              label: Text('${m}mo', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: active ? Colors.white : const Color(0xFF888888))),
              selected: active,
              selectedColor: _RPColors.blue,
              backgroundColor: Colors.white,
              side: BorderSide(color: active ? _RPColors.blue : _RPColors.border),
              visualDensity: VisualDensity.compact,
              onSelected: (_) { setState(() => _maturMonths = m); _reloadMaturities(); },
            );
          }).toList(),
        ),
        trailing: _buildMaturitiesList(),
      ),
      const SizedBox(height: 14),

      _ChartCard(
        title: 'Member Growth Timeline ($_selectedYear)',
        sub: 'New registrations · Total members: ${_memberGrowth['total_members'] ?? 0}',
        child: (_memberGrowth['data'] as List?)?.isEmpty ?? true ? const _NoData() : LineChart(_buildMemberGrowthLineData()),
      ),
    ];
  }

  List<Widget> _buildChartsTab() {
    if (_chartsLoading) {
      return [const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator(color: _RPColors.green)))];
    }

    // ── Loan Status counts (Map: {"For Review": n, "Active": n, ...}) ──────
    final statusLabels = ['For Review', 'Active', 'Declined', 'Completed', 'Overdue'];
    final statusValues = statusLabels.map((s) => (int.tryParse('${_loanStatus[s] ?? 0}') ?? 0).toDouble()).toList();
    const statusColors = [_RPColors.orange, _RPColors.green, _RPColors.red, _RPColors.blue, Color(0xFFB71C1C)];

    // ── Loan Type breakdown (Map: {"Regular Loan": n, ...}) ────────────────
    final typeEntries = _loanType.entries.where((e) => (int.tryParse('${e.value}') ?? 0) > 0).toList();
    const typeColors = [_RPColors.green, Color(0xFF4CAF50), _RPColors.orange, _RPColors.blue, _RPColors.purple, _RPColors.teal];

    // ── Payment Behavior (Map na hindi 100% sigurado ang exact keys — ──────
    // sinusubukan nating basahin lahat ng numeric entries bilang segments,
    // kaya kahit anong pangalan ng field, gagana pa rin ito.)
    final behaviorEntries = _paymentBehavior.entries.where((e) => e.value is num || double.tryParse('${e.value}') != null).toList();

    // ── Approval Rate stats ─────────────────────────────────────────────────
    final totalApps = int.tryParse('${_approvalRate['total'] ?? 0}') ?? 0;
    final approvedApps = int.tryParse('${_approvalRate['approved'] ?? 0}') ?? 0;
    final declinedApps = int.tryParse('${_approvalRate['declined'] ?? 0}') ?? 0;
    final approvalPct = double.tryParse('${_approvalRate['approval_rate'] ?? 0}') ?? 0;
    final byType = (_approvalRate['by_type'] as List?) ?? [];

    return [
      _ChartCard(
        title: 'Loan Status Summary',
        sub: '$_selectedYear — distribution by status',
        child: statusValues.every((v) => v == 0)
            ? const _NoData()
            : BarChart(BarChartData(
                maxY: (statusValues.reduce((a, b) => a > b ? a : b)) * 1.3,
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF0F4F1), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 8, color: _RPColors.sub)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= statusLabels.length) return const SizedBox.shrink();
                    final short = statusLabels[i].length > 6 ? statusLabels[i].substring(0, 6) : statusLabels[i];
                    return Padding(padding: const EdgeInsets.only(top: 4), child: Text(short, style: const TextStyle(fontSize: 7.5, color: _RPColors.sub)));
                  })),
                ),
                barGroups: List.generate(statusLabels.length, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: statusValues[i], color: statusColors[i % statusColors.length], width: 18, borderRadius: BorderRadius.circular(5))])),
              )),
      ),
      const SizedBox(height: 14),

      _ChartCard(
        title: 'Loan Type Breakdown',
        sub: '$_selectedYear — active & overdue by category',
        child: typeEntries.isEmpty
            ? const _NoData()
            : Row(children: [
                Expanded(
                  flex: 3,
                  child: PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: List.generate(typeEntries.length, (i) => PieChartSectionData(value: (double.tryParse('${typeEntries[i].value}') ?? 0), color: typeColors[i % typeColors.length], title: '', radius: 34)),
                  )),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(typeEntries.length, (i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: typeColors[i % typeColors.length], shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Expanded(child: Text('${typeEntries[i].key}', style: const TextStyle(fontSize: 9, color: Color(0xFF666666)), overflow: TextOverflow.ellipsis)),
                          ]),
                        )),
                  ),
                ),
              ]),
      ),
      const SizedBox(height: 14),

      _ChartCard(
        title: 'Payment Behavior',
        sub: '$_selectedYear — on-time vs late payment pattern',
        child: behaviorEntries.isEmpty
            ? const _NoData()
            : Row(children: [
                Expanded(
                  flex: 3,
                  child: PieChart(PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: List.generate(behaviorEntries.length, (i) => PieChartSectionData(value: (double.tryParse('${behaviorEntries[i].value}') ?? 0), color: typeColors[i % typeColors.length], title: '', radius: 34)),
                  )),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(behaviorEntries.length, (i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: typeColors[i % typeColors.length], shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Expanded(child: Text('${behaviorEntries[i].key}', style: const TextStyle(fontSize: 9, color: Color(0xFF666666)), overflow: TextOverflow.ellipsis)),
                          ]),
                        )),
                  ),
                ),
              ]),
      ),
      const SizedBox(height: 14),

      _ChartCard(
        title: 'Loan Distribution by Amount',
        sub: '$_selectedYear — number of loans per amount range',
        child: _loanDistribution.isEmpty
            ? const _NoData()
            : BarChart(BarChartData(
                maxY: (_loanDistribution.map((d) => (double.tryParse('${d['count'] ?? 0}') ?? 0)).reduce((a, b) => a > b ? a : b)) * 1.3,
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF0F4F1), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 8, color: _RPColors.sub)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= _loanDistribution.length) return const SizedBox.shrink();
                    return Padding(padding: const EdgeInsets.only(top: 4), child: Text('${_loanDistribution[i]['range'] ?? ''}', style: const TextStyle(fontSize: 7, color: _RPColors.sub)));
                  })),
                ),
                barGroups: List.generate(_loanDistribution.length, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: double.tryParse('${_loanDistribution[i]['count'] ?? 0}') ?? 0, color: _RPColors.blue, width: 16, borderRadius: BorderRadius.circular(4))])),
              )),
      ),
      const SizedBox(height: 14),

      _ChartCard(
        title: 'Overdue Analysis by Classification',
        sub: '$_selectedYear — overdue loans by member classification',
        child: _overdueAnalysis.isEmpty
            ? const _NoData(text: 'No overdue loans. 🎉')
            : BarChart(BarChartData(
                maxY: (_overdueAnalysis.map((d) => (double.tryParse('${d['count'] ?? 0}') ?? 0)).reduce((a, b) => a > b ? a : b)) * 1.3,
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF0F4F1), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 8, color: _RPColors.sub)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= _overdueAnalysis.length) return const SizedBox.shrink();
                    final label = '${_overdueAnalysis[i]['classification'] ?? ''}';
                    return Padding(padding: const EdgeInsets.only(top: 4), child: Text(label.length > 6 ? label.substring(0, 6) : label, style: const TextStyle(fontSize: 7, color: _RPColors.sub)));
                  })),
                ),
                barGroups: List.generate(_overdueAnalysis.length, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: double.tryParse('${_overdueAnalysis[i]['count'] ?? 0}') ?? 0, color: _RPColors.red, width: 16, borderRadius: BorderRadius.circular(4))])),
              )),
      ),
      const SizedBox(height: 14),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Loan Approval Rate', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _RPColors.title)),
            Text('$_selectedYear — application outcomes', style: const TextStyle(fontSize: 10, color: _RPColors.sub)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _MiniStatBox(label: 'Total Apps', value: '$totalApps', color: _RPColors.title)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStatBox(label: 'Approved', value: '$approvedApps', color: _RPColors.green)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStatBox(label: 'Declined', value: '$declinedApps', color: _RPColors.red)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStatBox(label: 'Rate', value: '${approvalPct.toStringAsFixed(0)}%', color: _RPColors.blue)),
            ]),
            if (byType.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...byType.map((t) {
                final pct = double.tryParse('${t['approval_rate'] ?? 0}') ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${t['loan_type'] ?? ''}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _RPColors.green)),
                      ]),
                      const SizedBox(height: 3),
                      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1), backgroundColor: const Color(0xFFF0F0F0), color: _RPColors.green, minHeight: 5)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      const SizedBox(height: 14),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Repayment Progress', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _RPColors.title)),
            Text('$_selectedYear — % of loan amount already repaid', style: const TextStyle(fontSize: 10, color: _RPColors.sub)),
            const SizedBox(height: 12),
            if (_repaymentProgress.isEmpty)
              const _NoData()
            else
              ..._repaymentProgress.take(10).map((row) {
                final pct = double.tryParse('${row['progress_pct'] ?? 0}') ?? 0;
                final color = pct >= 75 ? _RPColors.green : pct >= 40 ? _RPColors.orange : _RPColors.red;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Text('${row['member_name'] ?? row['loan_id'] ?? ''}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                      ]),
                      const SizedBox(height: 3),
                      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1), backgroundColor: const Color(0xFFF0F0F0), color: color, minHeight: 5)),
                    ],
                  ),
                );
              }),
            if (_repaymentProgress.length > 10) ...[
              const SizedBox(height: 6),
              Text('+ ${_repaymentProgress.length - 10} more loans', style: const TextStyle(fontSize: 10, color: _RPColors.sub)),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildClassificationTab() {
    if (_classLoading) {
      return [const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator(color: _RPColors.green)))];
    }

    const classColors = {'Student': _RPColors.blue, 'Senior': _RPColors.purple, 'Employed': _RPColors.green};
    const classIcons = {'Student': Icons.school_outlined, 'Senior': Icons.elderly_outlined, 'Employed': Icons.work_outline};

    final topList = (_topBorrowers['data'] as List?) ?? [];
    final firstTimeList = (_firstTimeBorrowers['data'] as List?) ?? [];
    final firstTimeCount = _firstTimeBorrowers['count'] ?? firstTimeList.length;

    return [
      _ChartCard(
        title: 'Payment Performance by Classification',
        sub: '$_selectedYear — on-time payment rate per member type',
        child: _classification.isEmpty
            ? const _NoData()
            : BarChart(BarChartData(
                maxY: 105,
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF0F4F1), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (v, m) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 8, color: _RPColors.sub)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= _classification.length) return const SizedBox.shrink();
                    return Padding(padding: const EdgeInsets.only(top: 4), child: Text('${_classification[i]['classification'] ?? ''}', style: const TextStyle(fontSize: 8, color: _RPColors.sub)));
                  })),
                ),
                barGroups: List.generate(_classification.length, (i) {
                  final c = _classification[i]['classification'] ?? '';
                  final pct = double.tryParse('${_classification[i]['on_time_pct'] ?? _classification[i]['performance_pct'] ?? 0}') ?? 0;
                  return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: pct, color: classColors[c] ?? _RPColors.green, width: 26, borderRadius: BorderRadius.circular(6))]);
                }),
              )),
      ),
      const SizedBox(height: 14),

      Row(
        children: ['Student', 'Senior', 'Employed'].map((c) {
          final row = _classification.firstWhere((x) => x['classification'] == c, orElse: () => null);
          final count = row != null ? (row['total'] ?? row['count'] ?? 0) : 0;
          final color = classColors[c] ?? _RPColors.green;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Icon(classIcons[c], color: color, size: 20),
                  const SizedBox(height: 6),
                  Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
                  Text(c, style: const TextStyle(fontSize: 9, color: _RPColors.sub, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 14),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.emoji_events_outlined, size: 15, color: _RPColors.orange), SizedBox(width: 6), Text('Top Borrowers', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _RPColors.title))]),
            Text('$_selectedYear — members with highest total loan amounts', style: const TextStyle(fontSize: 10, color: _RPColors.sub)),
            const SizedBox(height: 10),
            if (topList.isEmpty)
              const _NoData()
            else
              ...topList.take(10).toList().asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final row = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Container(
                      width: 22, height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: rank <= 3 ? const Color(0xFFFFF3E0) : const Color(0xFFF0F0F0), shape: BoxShape.circle),
                      child: Text('$rank', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: rank <= 3 ? _RPColors.orange : const Color(0xFF888888))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${row['member_name'] ?? ''}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    Text('₱${(double.tryParse('${row['total_amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _RPColors.green)),
                  ]),
                );
              }),
          ],
        ),
      ),
      const SizedBox(height: 14),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.person_add_alt_1_outlined, size: 15, color: _RPColors.blue),
              const SizedBox(width: 6),
              const Text('First-Time Borrowers', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _RPColors.title)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20)), child: Text('$firstTimeCount', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _RPColors.blue))),
            ]),
            Text('$_selectedYear — members who took their first loan', style: const TextStyle(fontSize: 10, color: _RPColors.sub)),
            const SizedBox(height: 10),
            if (firstTimeList.isEmpty)
              const _NoData()
            else
              ...firstTimeList.take(10).map((row) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      CircleAvatar(radius: 12, backgroundColor: _RPColors.blue, child: Text('${row['member_name'] ?? 'M'}'.isNotEmpty ? '${row['member_name']}'[0].toUpperCase() : 'M', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${row['member_name'] ?? ''}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      Text('${row['loan_id'] ?? ''}', style: const TextStyle(fontSize: 10, color: _RPColors.sub, fontFamily: 'monospace')),
                    ]),
                  )),
            if (firstTimeList.length > 10) Padding(padding: const EdgeInsets.only(top: 4), child: Text('+ ${firstTimeList.length - 10} more', style: const TextStyle(fontSize: 10, color: _RPColors.sub))),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildPerformanceTab() {
    if (_perfLoading) {
      return [const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator(color: _RPColors.green)))];
    }

    final riskSummary = (_riskAssessment['summary'] as Map?) ?? {};
    final riskData = (_riskAssessment['data'] as List?) ?? [];
    final delinqData = (_delinquency['data'] as List?) ?? [];

    return [
      // ── Member Performance ────────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Member Performance', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _RPColors.title)),
            Text('$_selectedYear — top members by payment reliability', style: const TextStyle(fontSize: 10, color: _RPColors.sub)),
            const SizedBox(height: 10),
            if (_memberPerformance.isEmpty)
              const _NoData()
            else
              ..._memberPerformance.take(10).map((row) {
                final onTimePct = double.tryParse('${row['on_time_pct'] ?? row['performance_pct'] ?? 0}') ?? 0;
                final rating = onTimePct >= 90 ? 'Excellent' : onTimePct >= 75 ? 'Good' : onTimePct >= 50 ? 'Fair' : 'Poor';
                final color = onTimePct >= 90 ? _RPColors.green : onTimePct >= 75 ? _RPColors.blue : onTimePct >= 50 ? _RPColors.orange : _RPColors.red;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${row['member_name'] ?? ''}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                          Text('${row['member_id'] ?? ''}', style: const TextStyle(fontSize: 9.5, color: _RPColors.sub, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${onTimePct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: Text(rating, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: color)),
                      ),
                    ]),
                  ]),
                );
              }),
            if (_memberPerformance.length > 10)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('+ ${_memberPerformance.length - 10} more members', style: const TextStyle(fontSize: 10, color: _RPColors.sub))),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // ── Share Capital Growth ──────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share Capital Growth', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _RPColors.title)),
            Text('$_selectedYear — top contributors', style: const TextStyle(fontSize: 10, color: _RPColors.sub)),
            const SizedBox(height: 10),
            if (_shareCapitalGrowth.isEmpty)
              const _NoData()
            else
              ..._shareCapitalGrowth.take(10).map((row) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Expanded(child: Text('${row['member_name'] ?? ''}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      Text('₱${(double.tryParse('${row['total_deposit'] ?? row['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _RPColors.purple)),
                    ]),
                  )),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // ── Delinquency Report ────────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.warning_amber_rounded, size: 15, color: _RPColors.red),
              const SizedBox(width: 6),
              const Text('Delinquency Report', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _RPColors.title)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(20)), child: Text('${_delinquency['count'] ?? 0}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _RPColors.red))),
            ]),
            Text('Loans overdue by $_delinqMonths+ month${_delinqMonths > 1 ? "s" : ""}', style: const TextStyle(fontSize: 10, color: _RPColors.sub)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [1, 2, 3].map((m) {
                final active = _delinqMonths == m;
                return ChoiceChip(
                  label: Text('${m}mo+', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: active ? Colors.white : const Color(0xFF888888))),
                  selected: active,
                  selectedColor: _RPColors.red,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: active ? _RPColors.red : _RPColors.border),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) { setState(() => _delinqMonths = m); _reloadDelinquency(); },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            if (delinqData.isEmpty)
              const _NoData(text: 'No delinquent loans found. 🎉')
            else
              ...delinqData.take(10).map((row) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFFFF8F8), border: Border.all(color: const Color(0xFFFFCDD2)), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${row['member_name'] ?? ''}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                            Text('${row['loan_id'] ?? ''}', style: const TextStyle(fontSize: 9.5, color: _RPColors.sub, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                      Text('₱${(double.tryParse('${row['balance'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _RPColors.red)),
                    ]),
                  )),
          ],
        ),
      ),
      const SizedBox(height: 14),

      // ── Risk Assessment ───────────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.security_outlined, size: 15, color: _RPColors.orange), SizedBox(width: 6), Text('Risk Assessment', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _RPColors.title))]),
            const Text('Members flagged for higher lending risk', style: TextStyle(fontSize: 10, color: _RPColors.sub)),
            const SizedBox(height: 10),
            if (riskSummary.isNotEmpty)
              Row(
                children: riskSummary.entries.take(3).map((e) => Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
                        child: Column(children: [
                          Text('${e.value}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _RPColors.orange)),
                          Text('${e.key}', style: const TextStyle(fontSize: 8, color: _RPColors.orange, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                        ]),
                      ),
                    )).toList(),
              ),
            const SizedBox(height: 10),
            if (riskData.isEmpty)
              const _NoData(text: 'No high-risk members flagged.')
            else
              ...riskData.take(10).map((row) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFFFFF8F0), border: Border.all(color: const Color(0xFFFFE0B2)), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Expanded(child: Text('${row['member_name'] ?? ''}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      Text('${row['risk_level'] ?? row['risk_score'] ?? ''}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _RPColors.orange)),
                    ]),
                  )),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildGenerateTab() {
    const reportTypes = ['Financial Summary', 'Collection Report', 'Loan Summary', 'Member Report', 'Payment Behavior', 'Blockchain Audit Log', 'Member Performance Report', 'Classification Analytics', 'Savings Report'];
    const typeIcons = {
      'Financial Summary': Icons.account_balance_wallet_outlined,
      'Collection Report': Icons.trending_up,
      'Loan Summary': Icons.assignment_outlined,
      'Member Report': Icons.people_outline,
      'Payment Behavior': Icons.credit_card_outlined,
      'Blockchain Audit Log': Icons.link,
      'Member Performance Report': Icons.emoji_events_outlined,
      'Classification Analytics': Icons.bar_chart_outlined,
      'Savings Report': Icons.savings_outlined,
    };

    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Report Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _RPColors.title)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: reportTypes.map((t) {
                final active = _genType == t;
                return ChoiceChip(
                  avatar: Icon(typeIcons[t], size: 13, color: active ? Colors.white : _RPColors.green),
                  label: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF555555))),
                  selected: active,
                  selectedColor: _RPColors.green,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: active ? _RPColors.green : _RPColors.border),
                  onSelected: (_) => setState(() { _genType = t; _genPreview = null; }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            const Text('Date Range', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _RPColors.title)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: true),
                  icon: const Icon(Icons.calendar_today, size: 13),
                  label: Text('${_genFrom.year}-${_genFrom.month.toString().padLeft(2, '0')}-${_genFrom.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF555555), side: const BorderSide(color: Color(0xFFDDDDDD))),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('to', style: TextStyle(fontSize: 11, color: _RPColors.sub))),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(isFrom: false),
                  icon: const Icon(Icons.calendar_today, size: 13),
                  label: Text('${_genTo.year}-${_genTo.month.toString().padLeft(2, '0')}-${_genTo.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF555555), side: const BorderSide(color: Color(0xFFDDDDDD))),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _RPColors.green, foregroundColor: Colors.white),
                onPressed: _genLoading ? null : _loadPreview,
                icon: _genLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.visibility_outlined, size: 16),
                label: Text(_genLoading ? 'Loading...' : 'Preview Report'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      if (_genPreview != null) ...[
        Builder(builder: (context) {
          final columns = (_genPreview!['columns'] as List?)?.map((c) => '$c').toList() ?? [];
          final rows = (_genPreview!['rows'] as List?) ?? [];
          final totalRows = int.tryParse('${_genPreview!['total_rows'] ?? rows.length}') ?? rows.length;
          final summaryPairs = (_genPreview!['summary'] as List?) ?? [];

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text('$_genType Preview', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _RPColors.title))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                    child: Text('$totalRows records', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _RPColors.green)),
                  ),
                ]),
                const SizedBox(height: 10),

                // ── Summary — array ng [label, value] pairs ────────────────
                if (summaryPairs.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0EAD8))),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 10,
                      children: summaryPairs.map((pair) {
                        final label = pair is List && pair.isNotEmpty ? '${pair[0]}' : '';
                        final value = pair is List && pair.length > 1 ? '${pair[1]}' : '';
                        return SizedBox(
                          width: (MediaQuery.of(context).size.width - 90) / 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF5A7A5A))),
                              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _RPColors.title)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // ── Table — columns + rows (bawat row ay array ng cells) ───
                if (columns.isEmpty || rows.isEmpty)
                  const _NoData(text: 'No records found for this range.')
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 34,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 40,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F8E9)),
                      columnSpacing: 18,
                      columns: columns.map((c) => DataColumn(label: Text(c, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _RPColors.title)))).toList(),
                      rows: rows.take(50).map<DataRow>((row) {
                        final cells = row is List ? row : [row];
                        return DataRow(
                          cells: List.generate(columns.length, (i) {
                            final val = i < cells.length ? cells[i] : '';
                            return DataCell(Text('$val', style: const TextStyle(fontSize: 10.5, color: Color(0xFF444444))));
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                if (totalRows > 50)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text('Showing 50 of $totalRows — i-export para sa kumpletong data.', style: const TextStyle(fontSize: 10, color: _RPColors.sub))),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),

        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel export — kailangan pa ng file-download support (path_provider/share_plus). Darating pa.'))),
              icon: const Icon(Icons.grid_on, size: 15, color: _RPColors.green),
              label: const Text('Export Excel', style: TextStyle(fontSize: 11.5)),
              style: OutlinedButton.styleFrom(foregroundColor: _RPColors.green, side: const BorderSide(color: Color(0xFFC8E6C9))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF export — kailangan pa ng file-download support (path_provider/share_plus). Darating pa.'))),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 15, color: _RPColors.red),
              label: const Text('Export PDF', style: TextStyle(fontSize: 11.5)),
              style: OutlinedButton.styleFrom(foregroundColor: _RPColors.red, side: const BorderSide(color: Color(0xFFFFCDD2))),
            ),
          ),
        ]),
      ],
    ];
  }

  List<Widget> _buildAuditTab() {
    if (_auditLoading) {
      return [const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator(color: _RPColors.green)))];
    }

    final filtered = _auditLog.where((row) {
      final q = _auditSearch.toLowerCase();
      return '${row['member_name'] ?? ''}'.toLowerCase().contains(q) ||
          '${row['member_id'] ?? ''}'.toLowerCase().contains(q) ||
          '${row['hash'] ?? ''}'.toLowerCase().contains(q) ||
          '${row['tx_id'] ?? ''}'.toLowerCase().contains(q);
    }).toList();

    final onChainCount = _auditLog.where((r) => r['polygon_tx'] != null).length;
    final totalAmount = _auditLog.fold<double>(0, (s, r) => s + (double.tryParse('${r['amount'] ?? 0}') ?? 0));

    return [
      Row(children: [
        Expanded(child: _MiniStatBox(label: 'Transactions', value: '${_auditLog.length}', color: _RPColors.title)),
        const SizedBox(width: 8),
        Expanded(child: _MiniStatBox(label: 'On Blockchain', value: '$onChainCount', color: _RPColors.green)),
        const SizedBox(width: 8),
        Expanded(child: _MiniStatBox(label: 'Total Amount', value: '₱${totalAmount.toStringAsFixed(0)}', color: _RPColors.blue)),
      ]),
      const SizedBox(height: 12),

      Container(
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(8)),
        child: TextField(
          onChanged: (v) => setState(() => _auditSearch = v),
          decoration: const InputDecoration(hintText: 'Search by member, hash, or TX ID...', hintStyle: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)), prefixIcon: Icon(Icons.search, size: 16, color: Color(0xFFAAAAAA)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10)),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      const SizedBox(height: 12),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF0F1923), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.link, size: 15, color: Color(0xFFE8F5E9)),
              const SizedBox(width: 6),
              const Text('Blockchain Audit Trail', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFE8F5E9))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x4069F0AE))),
                child: Text(_selectedYear == 'All' ? 'All Years' : _selectedYear, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF69F0AE))),
              ),
            ]),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No transactions found.', style: TextStyle(color: Color(0x66FFFFFF), fontSize: 13))))
            else
              ...filtered.map((row) {
                final amount = double.tryParse('${row['amount'] ?? 0}') ?? 0;
                final hash = '${row['hash'] ?? ''}';
                final shortHash = hash.length > 16 ? '${hash.substring(0, 8)}…${hash.substring(hash.length - 6)}' : hash;
                final onChain = row['polygon_tx'] != null;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF131F28)))),
                  child: Row(children: [
                    Icon(onChain ? Icons.verified_outlined : Icons.pending_outlined, size: 14, color: onChain ? const Color(0xFF69F0AE) : const Color(0xFF888888)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text('${row['paid_at'] ?? ''}'.split('T').first, style: const TextStyle(fontSize: 10, color: Color(0xFF3D5A6A))),
                            const SizedBox(width: 8),
                            Text('${row['member_name'] ?? row['member_id'] ?? ''}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF7A8FA0), fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 3),
                          Text(shortHash, style: const TextStyle(fontSize: 10, color: Color(0xFF3D5A6A), fontFamily: 'monospace', letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                    Text('₱${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF69F0AE))),
                  ]),
                );
              }),
          ],
        ),
      ),
    ];
  }

  BarChartData _buildMonthlyCollectionBarData() {
    final values = List<double>.filled(12, 0);
    for (var i = 0; i < _monthly.length && i < 12; i++) {
      values[i] = double.tryParse('${_monthly[i]['total'] ?? 0}') ?? 0;
    }
    final maxY = (values.reduce((a, b) => a > b ? a : b)) * 1.2;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return BarChartData(
      maxY: maxY == 0 ? 100 : maxY,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF0F4F1), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38, getTitlesWidget: (v, m) => Text('₱${(v / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 8, color: _RPColors.sub)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 18, interval: 1, getTitlesWidget: (v, m) { final i = v.toInt(); if (i < 0 || i > 11) return const SizedBox.shrink(); return Text(months[i], style: const TextStyle(fontSize: 8, color: _RPColors.sub)); })),
      ),
      barGroups: List.generate(12, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: values[i], color: _RPColors.green, width: 10, borderRadius: BorderRadius.circular(3))])),
    );
  }

  LineChartData _buildMonthlyLoansLineData() {
    final values = List<double>.filled(12, 0);
    for (var i = 0; i < _monthlyLoans.length && i < 12; i++) {
      values[i] = double.tryParse('${_monthlyLoans[i]['count'] ?? 0}') ?? 0;
    }
    final maxY = (values.reduce((a, b) => a > b ? a : b)) * 1.2;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return LineChartData(
      minY: 0,
      maxY: maxY == 0 ? 10 : maxY,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF0F4F1), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 8, color: _RPColors.sub)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 18, interval: 1, getTitlesWidget: (v, m) { final i = v.toInt(); if (i < 0 || i > 11) return const SizedBox.shrink(); return Text(months[i], style: const TextStyle(fontSize: 8, color: _RPColors.sub)); })),
      ),
      lineBarsData: [
        LineChartBarData(spots: List.generate(12, (i) => FlSpot(i.toDouble(), values[i])), isCurved: true, color: _RPColors.blue, barWidth: 2, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: const Color(0x141565C0))),
      ],
    );
  }

  LineChartData _buildYearlyComparisonLineData() {
    final years = _yearlyComp.map((y) => '${y['year']}').toList();
    final collections = _yearlyComp.map((y) => double.tryParse('${y['collections'] ?? 0}') ?? 0).toList();
    final releases = _yearlyComp.map((y) => double.tryParse('${y['loan_amount'] ?? 0}') ?? 0).toList();
    final savings = _yearlyComp.map((y) => double.tryParse('${y['savings_dep'] ?? 0}') ?? 0).toList();
    final allVals = [...collections, ...releases, ...savings];
    final maxY = allVals.isEmpty ? 100.0 : (allVals.reduce((a, b) => a > b ? a : b)) * 1.2;

    return LineChartData(
      minY: 0,
      maxY: maxY == 0 ? 100 : maxY,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF0F4F1), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38, getTitlesWidget: (v, m) => Text('₱${(v / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 8, color: _RPColors.sub)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 18, interval: 1, getTitlesWidget: (v, m) { final i = v.toInt(); if (i < 0 || i >= years.length) return const SizedBox.shrink(); return Text(years[i], style: const TextStyle(fontSize: 8, color: _RPColors.sub)); })),
      ),
      lineBarsData: [
        LineChartBarData(spots: List.generate(collections.length, (i) => FlSpot(i.toDouble(), collections[i])), isCurved: true, color: _RPColors.green, barWidth: 2, dotData: const FlDotData(show: true)),
        LineChartBarData(spots: List.generate(releases.length, (i) => FlSpot(i.toDouble(), releases[i])), isCurved: true, color: _RPColors.blue, barWidth: 2, dotData: const FlDotData(show: true)),
        LineChartBarData(spots: List.generate(savings.length, (i) => FlSpot(i.toDouble(), savings[i])), isCurved: true, color: _RPColors.orange, barWidth: 2, dotData: const FlDotData(show: true)),
      ],
    );
  }

  LineChartData _buildMemberGrowthLineData() {
    final data = (_memberGrowth['data'] as List?) ?? [];
    final newVals = data.map((m) => double.tryParse('${m['new'] ?? 0}') ?? 0).toList();
    final cumVals = data.map((m) => double.tryParse('${m['cumulative'] ?? 0}') ?? 0).toList();
    final allVals = [...newVals, ...cumVals];
    final maxY = allVals.isEmpty ? 10.0 : (allVals.reduce((a, b) => a > b ? a : b)) * 1.2;

    return LineChartData(
      minY: 0,
      maxY: maxY == 0 ? 10 : maxY,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF0F4F1), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, getTitlesWidget: (v, m) => Text('${v.toInt()}', style: const TextStyle(fontSize: 8, color: _RPColors.sub)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 18, interval: 1, getTitlesWidget: (v, m) { final i = v.toInt(); if (i < 0 || i >= data.length) return const SizedBox.shrink(); return Text('${data[i]['month'] ?? ''}', style: const TextStyle(fontSize: 7, color: _RPColors.sub)); })),
      ),
      lineBarsData: [
        LineChartBarData(spots: List.generate(newVals.length, (i) => FlSpot(i.toDouble(), newVals[i])), isCurved: true, color: const Color(0xFF4CAF50), barWidth: 2, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: const Color(0x144CAF50))),
        LineChartBarData(spots: List.generate(cumVals.length, (i) => FlSpot(i.toDouble(), cumVals[i])), isCurved: true, color: _RPColors.blue, barWidth: 2, dotData: const FlDotData(show: true)),
      ],
    );
  }

  Widget _buildEfficiencyList() {
    final data = (_efficiency['data'] as List?) ?? [];
    if (data.isEmpty) return const _NoData();
    return Column(
      children: data.map<Widget>((row) {
        final pct = int.tryParse('${row['efficiency_pct'] ?? 0}') ?? 0;
        final color = pct >= 90 ? _RPColors.green : pct >= 70 ? _RPColors.orange : _RPColors.red;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${row['month'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text('$pct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1), backgroundColor: const Color(0xFFF0F0F0), color: color, minHeight: 6),
              ),
              const SizedBox(height: 4),
              Text('Expected \u20b1${(double.tryParse('${row['expected'] ?? 0}') ?? 0).toStringAsFixed(0)} \u00b7 Collected \u20b1${(double.tryParse('${row['collected'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 9.5, color: _RPColors.sub)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMaturitiesList() {
    final data = (_maturities['data'] as List?) ?? [];
    if (data.isEmpty) return const _NoData(text: 'No upcoming maturities.');
    return Column(
      children: data.map<Widget>((row) {
        final daysLeft = int.tryParse('${row['days_left'] ?? 0}') ?? 0;
        final color = daysLeft <= 30 ? _RPColors.red : daysLeft <= 60 ? _RPColors.orange : _RPColors.green;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${row['member_name'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  Text('${row['loan_id'] ?? ''} \u00b7 ${row['loan_type'] ?? ''}', style: const TextStyle(fontSize: 9.5, color: _RPColors.sub)),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\u20b1${(double.tryParse('${row['balance'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _RPColors.red)),
              Text('${daysLeft}d left', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
            ]),
          ]),
        );
      }).toList(),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;
  final String value;
  final String label;
  const _KpiCard({required this.icon, required this.bg, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 16)),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 8.5, color: _RPColors.sub, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String sub;
  final Widget? child;
  final Widget? trailing;
  final Widget? legend;
  final Widget? headerTrailing;
  const _ChartCard({required this.title, required this.sub, this.child, this.trailing, this.legend, this.headerTrailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _RPColors.border), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _RPColors.title)),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(fontSize: 10, color: _RPColors.sub)),
                ],
              ),
            ),
            if (legend != null) legend!,
          ]),
          if (headerTrailing != null) ...[const SizedBox(height: 8), headerTrailing!],
          const SizedBox(height: 12),
          if (child != null) SizedBox(height: 220, child: child),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          FittedBox(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color))),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
    ]);
  }
}

class _NoData extends StatelessWidget {
  final String text;
  const _NoData({this.text = 'No data yet.'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(text, style: const TextStyle(color: _RPColors.sub, fontSize: 12, fontStyle: FontStyle.italic))),
    );
  }
}