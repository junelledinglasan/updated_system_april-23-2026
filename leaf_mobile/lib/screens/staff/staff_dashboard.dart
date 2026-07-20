import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/reports_service.dart';
import '../../services/loans_service.dart';
import '../../services/payments_service.dart';
import '../../services/members_service.dart';
import '../../services/activity_service.dart';
import '../../widgets/staff_scaffold_helpers.dart';
import '../../widgets/staff_drawer.dart';

class _SDColors {
  static const dark   = Color(0xFF1B5E20);
  static const green  = Color(0xFF2E7D32);
  static const sub    = Color(0xFF8A9A7A);
  static const border = Color(0xFFDDEEDD);
}

String _peso(num v) {
  final fixed = v.toStringAsFixed(0);
  final isNeg = fixed.startsWith('-');
  final digits = isNeg ? fixed.substring(1) : fixed;
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '₱${isNeg ? '-' : ''}$buf';
}

const Map<String, Color> _activityDotColors = {
  'payment': Color(0xFF4CAF50), 'application': Color(0xFF1565C0),
  'pending': Color(0xFFF57C00), 'register': Color(0xFF4CAF50), 'declined': Color(0xFFE53935),
};

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  bool _loading = true;
  double _todayCollection = 0;
  int _activeMembers = 0;
  int _pendingLoanApprovals = 0;
  int _activeLoans = 0;
  int _overdueLoans = 0;
  int _onlineApplicants = 0;
  List<dynamic> _monthly = [];
  Map<String, dynamic> _loanStatus = {};
  Map<String, dynamic> _loanType = {};
  List<dynamic> _activityLog = [];

  int _maturMonths = 3;
  Map<String, dynamic> _dueDates = {};
  DateTime _calDate = DateTime.now();
  bool _calLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadDueDates();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final currentYear = '${DateTime.now().year}';
    Map<String, dynamic> overview = {};
    List<dynamic> monthly = [];
    Map<String, dynamic> loanStatus = {};
    Map<String, dynamic> loanType = {};
    List<dynamic> apps = [];
    List<dynamic> activity = [];
    List<dynamic> allLoans = [];
    List<dynamic> payments = [];

    await Future.wait([
      () async { try { overview = await ReportsService.getOverview(currentYear); } catch (_) {} }(),
      () async { try { monthly = await ReportsService.getMonthlyCollection(currentYear); } catch (_) {} }(),
      () async { try { loanStatus = await ReportsService.getLoanStatus(currentYear); } catch (_) {} }(),
      () async { try { loanType = await ReportsService.getLoanType(currentYear); } catch (_) {} }(),
      () async { try { apps = await MembersService.getApplications(); } catch (_) {} }(),
      () async { try { activity = await ActivityService.getActivityLog(limit: 7); } catch (_) {} }(),
      () async { try { allLoans = await LoansService.getLoans(); } catch (_) {} }(),
      () async { try { payments = await PaymentsService.getPayments(); } catch (_) {} }(),
    ]);

    final activeLoansList = allLoans.where((l) => l['status'] == 'Active').toList();
    final overdueLoansList = allLoans.where((l) => l['status'] == 'Overdue').toList();
    final pendingLoansList = allLoans.where((l) => l['status'] == 'Pending' || l['status'] == 'For Review').toList();
    final pendingAppsList = apps.where((a) => a['status'] == 'Pending' || a['application_status'] == 'Pending').toList();

    final todayStr = DateTime.now().toIso8601String().split('T').first;
    final todayTotal = payments.where((p) => '${p['paid_at'] ?? ''}'.startsWith(todayStr)).fold<double>(0, (s, p) => s + (double.tryParse('${p['amount'] ?? 0}') ?? 0));

    Map<String, dynamic> loanTypeBreakdown = {};
    for (final l in activeLoansList) {
      final t = '${l['loan_type'] ?? 'Other'}';
      loanTypeBreakdown[t] = (loanTypeBreakdown[t] ?? 0) + 1;
    }
    if (loanTypeBreakdown.isEmpty) loanTypeBreakdown = loanType;

    if (mounted) {
      setState(() {
        _todayCollection = todayTotal;
        _activeMembers = (overview['active_members'] as int?) ?? 0;
        _pendingLoanApprovals = pendingLoansList.length;
        _activeLoans = activeLoansList.length;
        _overdueLoans = overdueLoansList.length;
        _onlineApplicants = pendingAppsList.length;
        _monthly = monthly;
        _loanStatus = loanStatus;
        _loanType = loanTypeBreakdown;
        _activityLog = activity;
        _loading = false;
      });
    }
  }

  Future<void> _loadDueDates() async {
    setState(() => _calLoading = true);
    try {
      final mm = '${_calDate.year}-${_calDate.month.toString().padLeft(2, '0')}';
      final data = await LoansService.getDueDates(month: mm);
      if (mounted) setState(() => _dueDates = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _calLoading = false);
    }
  }

  void _showDueDateSheet(String dateKey, List<dynamic> members) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
          DateTime d;
          try { d = DateTime.parse(dateKey); } catch (_) { d = DateTime.now(); }
          final total = members.fold<double>(0, (s, m) => s + (double.tryParse('${m['monthly_due'] ?? 0}') ?? 0));
          return Column(
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('📅 Collection Due', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12, color: _SDColors.sub)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: members.isEmpty
                    ? const Center(child: Text('No members due on this date.', style: TextStyle(color: _SDColors.sub)))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        itemCount: members.length,
                        itemBuilder: (context, i) {
                          final m = members[i];
                          final isOverdue = m['status'] == 'Overdue';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: isOverdue ? const Color(0xFFFFF8F8) : const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: isOverdue ? const Color(0xFFFFCDD2) : const Color(0xFFE8F5E9))),
                            child: Row(children: [
                              CircleAvatar(radius: 18, backgroundColor: isOverdue ? const Color(0xFFC62828) : _SDColors.green, child: Text('${m['member_name'] ?? 'M'}'.isNotEmpty ? '${m['member_name']}'[0] : 'M', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${m['member_name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text('${m['member_id'] ?? ''} · ${m['loan_type'] ?? ''}', style: const TextStyle(fontSize: 11, color: _SDColors.sub)),
                                ]),
                              ),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(_peso(double.tryParse('${m['monthly_due'] ?? 0}') ?? 0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _SDColors.green)),
                                if (isOverdue) const Text('OVERDUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFC62828))),
                              ]),
                            ]),
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F4F1)))),
                child: Text('Total: ${_peso(total)} from ${members.length} member${members.length != 1 ? 's' : ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF555555))),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final staffRole = auth.staffRole ?? '';
    final roleLabel = kStaffRoleLabels[staffRole] ?? 'Staff';
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const mons = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final dateStr = '${days[now.weekday % 7]}, ${mons[now.month - 1]} ${now.day}, ${now.year} — ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return StaffScreenScaffold(
      activeRouteKey: 'home',
      body: RefreshIndicator(
        onRefresh: () async { await _load(); await _loadDueDates(); },
        color: _SDColors.green,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _SDColors.green))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Banner ──────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_SDColors.dark, _SDColors.green, Color(0xFF388E3C)], stops: [0.0, 0.6, 1.0]), borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$greeting, ${auth.name ?? 'Staff'}! 👋', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(dateStr, style: const TextStyle(color: Color(0xFFA5D6A7), fontSize: 10, fontFamily: 'monospace')),
                          const SizedBox(height: 4),
                          const Text("Here's what needs your attention today.", style: TextStyle(color: Color(0xFFC8E6C9), fontSize: 12)),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              CircleAvatar(radius: 18, backgroundColor: Colors.white.withOpacity(0.25), child: Text((auth.name?.isNotEmpty == true ? auth.name![0] : 'S').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                              const SizedBox(width: 10),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(auth.name ?? 'Staff', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('$roleLabel · Leaf MPC', style: const TextStyle(color: Color(0xFFA5D6A7), fontSize: 10.5)),
                              ]),
                            ]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Quick Actions ───────────────────────────────
                    if (_quickActions(staffRole).isNotEmpty) ...[
                      const Text('QUICK ACTIONS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _SDColors.sub, letterSpacing: 0.6)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: _quickActions(staffRole)),
                      const SizedBox(height: 16),
                    ],

                    // ── Stat cards ──────────────────────────────────
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: _statCards(staffRole),
                    ),
                    const SizedBox(height: 16),

                    // ── Charts ──────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _SDColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Overall Collection', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B3A1B))),
                          const Text('Monthly collection trend', style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                          const SizedBox(height: 12),
                          SizedBox(height: 180, child: _buildLineChart()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _SDColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Loan Status Summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B3A1B))),
                          const Text('Current distribution', style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                          const SizedBox(height: 12),
                          SizedBox(height: 180, child: _buildBarChart()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Collection Calendar ─────────────────────────
                    _buildCalendarCard(),
                    const SizedBox(height: 12),

                    // ── Activity Log ────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _SDColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recent Activity Log', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B3A1B))),
                          const Text('Latest system events', style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                          const SizedBox(height: 10),
                          if (_activityLog.isEmpty)
                            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('No recent activity yet.', style: TextStyle(color: _SDColors.sub, fontSize: 12))))
                          else
                            ..._activityLog.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: _activityDotColors['${item['type']}'] ?? const Color(0xFFAAAAAA), shape: BoxShape.circle)),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text('${item['text'] ?? ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF333333), fontWeight: FontWeight.w500, height: 1.45)),
                                        Text('${item['time'] ?? ''}', style: const TextStyle(fontSize: 10, color: Color(0xFFBBBBBB))),
                                      ]),
                                    ),
                                  ]),
                                )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Loan Type Breakdown ─────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _SDColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Loan Type Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B3A1B))),
                          const Text('By category', style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                          const SizedBox(height: 12),
                          SizedBox(height: 200, child: _buildDoughnutChart()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _quickActions(String staffRole) {
    switch (staffRole) {
      case 'cashier':
      case 'collector':
        return [_QuickActionBtn(icon: Icons.credit_card, label: 'Record F2F Payment', color: _SDColors.green, bg: const Color(0xFFF1F8E9), border: const Color(0xFFC8E6C9), onTap: () => Navigator.pushNamed(context, '/staff/loan-payment'))];
      case 'bookkeeper':
        return [_QuickActionBtn(icon: Icons.bar_chart, label: 'View Reports', color: const Color(0xFF0D47A1), bg: const Color(0xFFE3F2FD), border: const Color(0xFFBBDEFB), onTap: () => Navigator.pushNamed(context, '/staff/reports'))];
      case 'admin_clerk':
        return [
          _QuickActionBtn(icon: Icons.description, label: 'Review Applications', color: const Color(0xFF0D47A1), bg: const Color(0xFFE3F2FD), border: const Color(0xFFBBDEFB), onTap: () => Navigator.pushNamed(context, '/staff/applications')),
          _QuickActionBtn(icon: Icons.checklist, label: 'Process Loan Approval', color: const Color(0xFF004D40), bg: const Color(0xFFE0F2F1), border: const Color(0xFFB2DFDB), onTap: () => Navigator.pushNamed(context, '/staff/loan-approval')),
          _QuickActionBtn(icon: Icons.people, label: 'Manage Members', color: const Color(0xFF4A148C), bg: const Color(0xFFF3E5F5), border: const Color(0xFFE1BEE7), onTap: () => Navigator.pushNamed(context, '/staff/members')),
          _QuickActionBtn(icon: Icons.campaign, label: 'Post Announcement', color: const Color(0xFFE65100), bg: const Color(0xFFFFF3E0), border: const Color(0xFFFFE0B2), onTap: () => Navigator.pushNamed(context, '/staff/announcement')),
          _QuickActionBtn(icon: Icons.bar_chart, label: 'View Reports', color: const Color(0xFF004D40), bg: const Color(0xFFE0F2F1), border: const Color(0xFFB2DFDB), onTap: () => Navigator.pushNamed(context, '/staff/reports')),
        ];
      default:
        return [];
    }
  }

  List<Widget> _statCards(String staffRole) {
    if (staffRole == 'cashier' || staffRole == 'collector') {
      return [
        _StatCard(label: "Today's Collections", value: _peso(_todayCollection), icon: '💰'),
        _StatCard(label: 'Active Loans', value: '$_activeLoans', icon: '📋'),
        _StatCard(label: 'Overdue Loans', value: '$_overdueLoans', icon: '⚠️'),
      ];
    }
    if (staffRole == 'bookkeeper') {
      return [
        _StatCard(label: "Today's Collections", value: _peso(_todayCollection), icon: '💰'),
        _StatCard(label: 'Active Members', value: '$_activeMembers', icon: '👤'),
        _StatCard(label: 'Active Loans', value: '$_activeLoans', icon: '📋'),
      ];
    }
    return [
      _StatCard(label: 'Pending Loan Approvals', value: '$_pendingLoanApprovals', icon: '⏳'),
      _StatCard(label: 'Online Applicants', value: '$_onlineApplicants', icon: '🌐'),
      _StatCard(label: 'Active Members', value: '$_activeMembers', icon: '👤'),
      _StatCard(label: 'Overdue Loans', value: '$_overdueLoans', icon: '⚠️'),
    ];
  }

  Widget _buildLineChart() {
    if (_monthly.isEmpty) return const Center(child: Text('No data yet.', style: TextStyle(color: _SDColors.sub)));
    final values = _monthly.map((m) => double.tryParse('${m['total'] ?? 0}') ?? 0.0).toList();
    final maxY = values.isEmpty ? 100.0 : values.reduce((a, b) => a > b ? a : b) * 1.3;
    return LineChart(LineChartData(
      minY: 0, maxY: maxY == 0 ? 100 : maxY,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF0F4F1), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text('₱${(v / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 8, color: _SDColors.sub)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 18, interval: 1, getTitlesWidget: (v, m) {
          final i = v.toInt();
          if (i < 0 || i >= _monthly.length) return const SizedBox.shrink();
          return Text('${_monthly[i]['month'] ?? ''}', style: const TextStyle(fontSize: 8, color: _SDColors.sub));
        })),
      ),
      lineBarsData: [LineChartBarData(spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])), isCurved: true, color: _SDColors.green, barWidth: 2, dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: true, color: const Color(0x142E7D32)))],
    ));
  }

  Widget _buildBarChart() {
    final labels = _loanStatus.keys.toList();
    if (labels.isEmpty) return const Center(child: Text('No data yet.', style: TextStyle(color: _SDColors.sub)));
    final values = _loanStatus.values.map((v) => (double.tryParse('$v') ?? 0)).toList();
    final maxY = values.reduce((a, b) => a > b ? a : b) * 1.3;
    const colors = [Color(0xFF2E7D32), Color(0xFFF57C00), Color(0xFFE53935), Color(0xFF1565C0), Color(0xFFA5D6A7)];
    return BarChart(BarChartData(
      maxY: maxY == 0 ? 10 : maxY,
      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF0F4F1), strokeWidth: 1)),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
          final i = v.toInt();
          if (i < 0 || i >= labels.length) return const SizedBox.shrink();
          return Padding(padding: const EdgeInsets.only(top: 4), child: Text(labels[i], style: const TextStyle(fontSize: 7.5, color: _SDColors.sub)));
        })),
      ),
      barGroups: List.generate(labels.length, (i) => BarChartGroupData(x: i, barRods: [BarChartRodData(toY: values[i], color: colors[i % colors.length], width: 18, borderRadius: BorderRadius.circular(4))])),
    ));
  }

  Widget _buildDoughnutChart() {
    if (_loanType.isEmpty) return const Center(child: Text('No data yet.', style: TextStyle(color: _SDColors.sub)));
    const colors = [Color(0xFF2E7D32), Color(0xFF4CAF50), Color(0xFFF57C00), Color(0xFF1565C0), Color(0xFFA5D6A7)];
    final entries = _loanType.entries.toList();
    return Row(children: [
      Expanded(
        flex: 3,
        child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 40, sections: List.generate(entries.length, (i) => PieChartSectionData(value: (double.tryParse('${entries[i].value}') ?? 0), color: colors[i % colors.length], title: '', radius: 30)))),
      ),
      Expanded(
        flex: 2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${e.value.key}', style: const TextStyle(fontSize: 10, color: Color(0xFF555555)), overflow: TextOverflow.ellipsis)),
                ]),
              )).toList(),
        ),
      ),
    ]);
  }

  Widget _buildCalendarCard() {
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final firstDay = DateTime(_calDate.year, _calDate.month, 1).weekday % 7;
    final totalDays = DateTime(_calDate.year, _calDate.month + 1, 0).day;
    final today = DateTime.now();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _SDColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Collection Calendar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B3A1B))),
          Text('${monthNames[_calDate.month - 1]} ${_calDate.year}', style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 18),
              onPressed: () { setState(() => _calDate = DateTime(_calDate.year, _calDate.month - 1, 1)); _loadDueDates(); },
            ),
            Text('${monthNames[_calDate.month - 1]} ${_calDate.year}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 18),
              onPressed: () { setState(() => _calDate = DateTime(_calDate.year, _calDate.month + 1, 1)); _loadDueDates(); },
            ),
          ]),
          if (_calLoading) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ...['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((d) => Center(child: Text(d, style: const TextStyle(fontSize: 9, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w700)))),
              ...List.generate(firstDay, (i) => const SizedBox.shrink()),
              ...List.generate(totalDays, (i) {
                final d = i + 1;
                final key = '${_calDate.year}-${_calDate.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
                final isToday = d == today.day && _calDate.month == today.month && _calDate.year == today.year;
                final dueList = (_dueDates[key] as List?) ?? [];
                final hasOverdue = dueList.any((m) => m['status'] == 'Overdue');
                final hasDue = dueList.isNotEmpty;
                Color? bg;
                Color textColor = const Color(0xFF555555);
                if (isToday) { bg = _SDColors.green; textColor = Colors.white; }
                else if (hasOverdue) { bg = const Color(0xFFFCE4EC); textColor = const Color(0xFFC62828); }
                else if (hasDue) { bg = const Color(0xFFC8E6C9); textColor = _SDColors.dark; }
                return GestureDetector(
                  onTap: hasDue ? () => _showDueDateSheet(key, dueList) : null,
                  child: Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                    alignment: Alignment.center,
                    child: Stack(alignment: Alignment.center, children: [
                      Text('$d', style: TextStyle(fontSize: 10, color: textColor, fontWeight: isToday || hasDue ? FontWeight.w700 : FontWeight.w500)),
                      if (hasDue)
                        Positioned(top: 0, right: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: hasOverdue ? const Color(0xFFC62828) : _SDColors.green, shape: BoxShape.circle), alignment: Alignment.center, child: Text('${dueList.length}', style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.w700)))),
                    ]),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg, border;
  final VoidCallback onTap;
  const _QuickActionBtn({required this.icon, required this.label, required this.color, required this.bg, required this.border, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: border, width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _SDColors.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(fontSize: 8.5, color: Color(0xFF8AAA8A), fontWeight: FontWeight.w700, letterSpacing: 0.4), maxLines: 2),
                const SizedBox(height: 6),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _SDColors.dark))),
              ],
            ),
          ),
          Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xFFC8E6C9))), alignment: Alignment.center, child: Text(icon, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}