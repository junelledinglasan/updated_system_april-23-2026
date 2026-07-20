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
import '../../widgets/admin/blockchain_ledger_card.dart';
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
  int _pendingLoanApprovals = 0;
  int _onlineApplicants = 0;
  int _gcashPending = 0;

  List<double> _monthlyValues = List.filled(12, 0);
  Map<String, int> _loanStatusCounts = {};
  Map<String, int> _loanTypeCounts = {};

  List<dynamic> _activityLog = [];
  List<dynamic> _ledger = [];

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
    List<dynamic>? auditLog;
    List<dynamic>? activeLoans;
    List<dynamic>? onlineApps;
    List<dynamic>? activity;

    await Future.wait([
      () async { try { overview = await ReportsService.getOverview('$currentYear'); } catch (_) {} }(),
      () async { try { monthly = await ReportsService.getMonthlyCollection('$currentYear'); } catch (_) {} }(),
      () async { try { loanStatus = await ReportsService.getLoanStatus('All'); } catch (_) {} }(),
      () async { try { loanType = await ReportsService.getLoanType('All'); } catch (_) {} }(),
      () async { try { auditLog = await ReportsService.getAuditLog('$currentYear'); } catch (_) {} }(),
      () async { try { activeLoans = await LoansService.getLoans(); } catch (_) {} }(),
      () async { try { onlineApps = await MembersService.getOnlineApplications(); } catch (_) {} }(),
      () async { try { activity = await ActivityService.getActivityLog(limit: 7); } catch (_) {} }(),
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

    if (auditLog != null) _ledger = auditLog!.take(12).toList();
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
                  : GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                      children: [
                        _StatCard(label: 'Total Share Capital', value: '₱${_totalShareCapital.toStringAsFixed(0)}', icon: Icons.trending_up),
                        _StatCard(label: 'Active Members', value: '$_activeMembers', icon: Icons.person_outline),
                        _StatCard(label: 'Pending Loan Approvals', value: '$_pendingLoanApprovals', icon: Icons.hourglass_empty),
                        _StatCard(label: 'Online Applicants', value: '$_onlineApplicants', icon: Icons.public),
                      ],
                    ),
              const SizedBox(height: 14),
              CollectionLineChartCard(monthlyValues: _monthlyValues, loading: _loading),
              const SizedBox(height: 14),
              LoanStatusBarChartCard(statusCounts: _loanStatusCounts, loading: _loading),
              const SizedBox(height: 14),
              const CollectionCalendarCard(),
              const SizedBox(height: 14),
              ActivityLogCard(log: _activityLog, loading: _loading),
              const SizedBox(height: 14),
              LoanTypeDoughnutChartCard(typeCounts: _loanTypeCounts, loading: _loading),
              const SizedBox(height: 14),
              BlockchainLedgerCard(
                data: _ledger,
                loading: _loading,
                onPdfTap: (row) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PDF export — coming soon.')),
                  );
                },
              ),
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