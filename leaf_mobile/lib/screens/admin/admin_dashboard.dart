import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/reports_service.dart';
import '../../services/activity_service.dart';
import '../../services/loans_service.dart';
import '../../services/members_service.dart';
import '../../widgets/admin/admin_scaffold_helpers.dart';
import '../../widgets/admin/collection_calendar_card.dart';
import '../../widgets/admin/activity_log_card.dart';
import '../../widgets/admin/dashboard_charts.dart';

class _DashColors {
  static const cardBorder = Color(0xFFDDEEDD);
  static const label      = Color(0xFF8AAA8A);
  static const value      = Color(0xFF1B5E20);
  static const iconBg     = Color(0xFFE8F5E9);
  static const iconBorder = Color(0xFFC8E6C9);
  static const iconColor  = Color(0xFF2E7D32);
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _loading = true;

  double _totalShareCapital = 0;
  int _activeMembers = 0;
  // ── BAGO: Inactive Members + New Members This Month — kaparehong
  // idinagdag natin sa web dashboard. ─────────────────────────────────
  int _inactiveMembers = 0;
  int _newMembersThisMonth = 0;
  List<double> _memberGrowth = List.filled(12, 0);
  int _pendingLoanApprovals = 0;
  int _onlineApplicants = 0;
  int _gcashPending = 0;

  List<double> _monthlyValues = List.filled(12, 0);
  Map<String, int> _loanStatusCounts = {};
  Map<String, int> _loanTypeCounts = {};

  List<dynamic> _activityLog = [];
  // ── BAGO: "Overdue Alert" — para makita agad ng admin kung sinong
  // miyembro ang bagong-overdue, kasama ang kasalukuyang Loan
  // Multiplier nila, para makapag-desisyon kung babaguhin. ────────────
  List<Map<String, dynamic>> _overdueAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _loadGcashPending();
  }

  Future<void> _loadGcashPending() async {
    try {
      final list = await LoansService.getGCashRequests(status: 'Pending');
      if (mounted) setState(() => _gcashPending = list.length);
    } catch (_) {}
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    final currentYear = DateTime.now().year;

    Map<String, dynamic>? overview;
    List<dynamic>? monthly;
    Map<String, dynamic>? loanStatus;
    Map<String, dynamic>? loanType;
    List<dynamic>? activeLoans;
    List<dynamic>? onlineApps;
    List<dynamic>? activity;
    List<dynamic>? members;

    await Future.wait([
      () async { try { overview = await ReportsService.getOverview('$currentYear'); } catch (_) {} }(),
      () async { try { monthly = await ReportsService.getMonthlyCollection('$currentYear'); } catch (_) {} }(),
      () async { try { loanStatus = await ReportsService.getLoanStatus('All'); } catch (_) {} }(),
      () async { try { loanType = await ReportsService.getLoanType('All'); } catch (_) {} }(),
      () async { try { activeLoans = await LoansService.getLoans(); } catch (_) {} }(),
      () async { try { onlineApps = await MembersService.getOnlineApplications(); } catch (_) {} }(),
      () async { try { activity = await ActivityService.getActivityLog(limit: 7); } catch (_) {} }(),
      () async { try { members = await MembersService.getMembers(); } catch (_) {} }(),
    ]);

    if (overview != null) {
      int onlineCount = 0;
      if (onlineApps != null) {
        onlineCount = onlineApps!.where((a) => a['application_status'] == 'Pending').length;
      }
      _totalShareCapital = double.tryParse('${overview!['total_share_capital'] ?? 0}') ?? 0;
      _activeMembers = int.tryParse('${overview!['active_members'] ?? 0}') ?? 0;
      _pendingLoanApprovals = int.tryParse('${overview!['pending_loans'] ?? 0}') ?? 0;
      _onlineApplicants = onlineCount;
    }

    // ── BAGO: Active/Inactive counts + New This Month + buong-taong
    // growth trend — parehong base sa members list, kaparehong lohika
    // ng web dashboard. ───────────────────────────────────────────────
    if (members != null) {
      _activeMembers = members!.where((m) => m['status'] == 'Active' || m['membership_status'] == 'Active').length;
      _inactiveMembers = members!.where((m) => m['status'] == 'Inactive' || m['membership_status'] == 'Inactive').length;
      final now = DateTime.now();
      final growth = List<double>.filled(12, 0);
      int newThisMonth = 0;
      for (final m in members!) {
        final dateStr = m['membership_date'];
        if (dateStr == null) continue;
        try {
          final d = DateTime.parse('$dateStr');
          if (d.year == now.year) {
            growth[d.month - 1] += 1;
            if (d.month == now.month) newThisMonth++;
          }
        } catch (_) {}
      }
      _memberGrowth = growth;
      _newMembersThisMonth = newThisMonth;
    }

    if (monthly != null) {
      final values = List<double>.filled(12, 0);
      for (var i = 0; i < monthly!.length && i < 12; i++) {
        values[i] = double.tryParse('${monthly![i]['total'] ?? 0}') ?? 0;
      }
      _monthlyValues = values;
    }

    if (loanStatus != null) {
      _loanStatusCounts = loanStatus!.map((k, v) => MapEntry(k, int.tryParse('$v') ?? 0));
    }

    Map<String, int> breakdown = {};
    if (activeLoans != null) {
      final filtered = activeLoans!.where((l) => l['status'] == 'Active' || l['status'] == 'Overdue');
      for (final l in filtered) {
        final t = (l['loan_type'] ?? 'Other').toString();
        breakdown[t] = (breakdown[t] ?? 0) + 1;
      }
    }
    if (breakdown.isNotEmpty) {
      _loanTypeCounts = breakdown;
    } else if (loanType != null) {
      _loanTypeCounts = loanType!.map((k, v) => MapEntry(k, int.tryParse('$v') ?? 0));
    }

    // ── BAGO: "Overdue Alert" — kunin ang mga Overdue loans,
    // i-cross-reference sa members list para makuha ang kasalukuyang
    // Loan Multiplier ng bawat isa. ──────────────────────────────────
    if (activeLoans != null) {
      final overdueLoans = activeLoans!.where((l) => l['status'] == 'Overdue').toList();
      if (overdueLoans.isNotEmpty && members != null) {
        _overdueAlerts = overdueLoans.map((l) {
          final mem = members!.firstWhere((m) => m['id'] == l['member'], orElse: () => null);
          return {
            'loan_id': l['loan_id'],
            'member_id': l['member'],
            'member_name': l['member_name'],
            'member_code': l['member_code'],
            'loan_multiplier': mem != null ? (mem['loan_multiplier'] ?? 1) : 1,
            'total_penalty': double.tryParse('${l['total_penalty'] ?? 0}') ?? 0,
            'months_overdue': l['months_overdue_penalized'] ?? 0,
          };
        }).toList();
      }
    }

    if (activity != null) _activityLog = activity!;

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AdminScreenScaffold(
      activeRouteKey: 'dashboard',
      gcashPendingCount: _gcashPending,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadDashboard(), _loadGcashPending()]);
        },
        color: _DashColors.iconColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: _DashColors.iconColor)),
                    )
                  // ── FIX: dating 2-column grid para sa 4 cards lang —
                  // 6 na ngayon, ginawa kong 3 columns x 2 rows para
                  // hindi lumabas nang basta-basta/hindi pantay. ──────
                  : GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.95,
                      children: [
                        _StatCard(label: 'Total Share Capital', value: '₱${_totalShareCapital.toStringAsFixed(0)}', icon: Icons.trending_up),
                        _StatCard(label: 'Active Members', value: '$_activeMembers', icon: Icons.person_outline),
                        // ── BAGO: hiwalay na "Inactive Members" card. ──
                        _StatCard(label: 'Inactive Members', value: '$_inactiveMembers', icon: Icons.person_off_outlined),
                        // ── BAGO: "New Members This Month" — growth
                        // indicator. ──────────────────────────────────
                        _StatCard(label: 'New This Month', value: '$_newMembersThisMonth', icon: Icons.person_add_alt_1_outlined),
                        _StatCard(label: 'Pending Loan Approvals', value: '$_pendingLoanApprovals', icon: Icons.hourglass_empty),
                        _StatCard(label: 'Online Applicants', value: '$_onlineApplicants', icon: Icons.public),
                      ],
                    ),
              const SizedBox(height: 14),
              // ── BAGO: "Overdue Loan Alert" widget — makikita agad ng
              // admin ang mga miyembrong may bagong-overdue na loan,
              // kasama ang kasalukuyang Loan Multiplier nila. Lumalabas
              // lang kapag may talagang overdue. ─────────────────────
              if (_overdueAlerts.isNotEmpty) _OverdueAlertCard(alerts: _overdueAlerts),
              if (_overdueAlerts.isNotEmpty) const SizedBox(height: 14),
              CollectionLineChartCard(monthlyValues: _monthlyValues, loading: _loading),
              const SizedBox(height: 14),
              // ── BAGO: "Member Growth" chart — kasabay ng Collection
              // dahil parehong monthly trend charts. ──────────────────
              MemberGrowthLineChartCard(monthlyValues: _memberGrowth, loading: _loading),
              const SizedBox(height: 14),
              LoanStatusBarChartCard(statusCounts: _loanStatusCounts, loading: _loading),
              const SizedBox(height: 14),
              const CollectionCalendarCard(),
              const SizedBox(height: 14),
              ActivityLogCard(log: _activityLog, loading: _loading),
              const SizedBox(height: 14),
              LoanTypeDoughnutChartCard(typeCounts: _loanTypeCounts, loading: _loading),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DashColors.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _DashColors.label, letterSpacing: 0.5),
                ),
              ),
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: _DashColors.iconBg, borderRadius: BorderRadius.circular(9), border: Border.all(color: _DashColors.iconBorder)),
                child: Icon(icon, color: _DashColors.iconColor, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _DashColors.value)),
          ),
        ],
      ),
    );
  }
}

// ── BAGO: "Overdue Loan Alert" widget — makikita agad ng admin ang mga
// miyembrong may bagong-overdue na loan, kasama ang kasalukuyang Loan
// Multiplier nila, para agad silang makapag-desisyon (hal. i-downgrade
// papuntang 2x kung mahinang magbayad, o panatilihin sa 3x). ───────────
class _OverdueAlertCard extends StatelessWidget {
  final List<Map<String, dynamic>> alerts;
  const _OverdueAlertCard({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF8BBD0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 17, color: Color(0xFFC62828)),
            const SizedBox(width: 8),
            Text('Overdue Loan Alert (${alerts.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFC62828))),
          ]),
          const SizedBox(height: 6),
          const Text('Ang mga miyembrong ito ay may loan na naliban na sa due date. Suriin kung dapat baguhin ang kanilang Loan Multiplier.', style: TextStyle(fontSize: 10.5, color: Color(0xFF888888))),
          const SizedBox(height: 10),
          ...alerts.map((a) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(
                          text: '${a['member_name']} ',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B)),
                          children: [TextSpan(text: '${a['member_code']}', style: const TextStyle(fontWeight: FontWeight.w400, color: Color(0xFF888888), fontSize: 10.5, fontFamily: 'monospace'))],
                        )),
                        const SizedBox(height: 2),
                        Text(
                          '${a['loan_id']} · ${a['months_overdue']} month${a['months_overdue'] != 1 ? "s" : ""} overdue'
                          '${(a['total_penalty'] as double) > 0 ? " · +₱${(a['total_penalty'] as double).toStringAsFixed(0)} penalty" : ""}'
                          ' · Current multiplier: ${a['loan_multiplier']}×',
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFFC62828)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/admin/members', arguments: {'openMemberId': a['member_id']}),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    icon: const Icon(Icons.arrow_forward, size: 13),
                    label: const Text('Review'),
                  ),
                ]),
              )),
        ],
      ),
    );
  }
}