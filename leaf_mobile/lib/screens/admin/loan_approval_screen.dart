import 'package:flutter/material.dart';
import '../../services/loans_service.dart';
import '../../widgets/admin/admin_scaffold_helpers.dart';
import 'process_loan_screen.dart';

class _LAColors {
  static const title  = Color(0xFF1B5E20);
  static const sub    = Color(0xFFAAAAAA);
  static const green  = Color(0xFF2E7D32);
  static const border = Color(0xFFC8DDC8);
  static const orange = Color(0xFFE65100);
  static const red    = Color(0xFFC62828);
  static const blue   = Color(0xFF1565C0);
}

const List<String> kLoanTypes = ['Regular Loan', 'Emergency Loan', 'Salary Loan', 'Housing Loan', 'Business Loan', 'Other Loan'];

Color laStatusColor(String status) {
  switch (status) {
    case 'Active':
    case 'Completed':
      return _LAColors.green;
    case 'Declined':
    case 'Overdue':
      return _LAColors.red;
    default:
      return _LAColors.orange;
  }
}

Color laStatusBg(String status) {
  switch (status) {
    case 'Active':
    case 'Completed':
      return const Color(0xFFE8F5E9);
    case 'Declined':
    case 'Overdue':
      return const Color(0xFFFCE4EC);
    default:
      return const Color(0xFFFFF8E1);
  }
}

class LoanApprovalScreen extends StatefulWidget {
  const LoanApprovalScreen({super.key});

  @override
  State<LoanApprovalScreen> createState() => _LoanApprovalScreenState();
}

class _LoanApprovalScreenState extends State<LoanApprovalScreen> {
  List<dynamic> _loans = [];
  bool _loading = true;
  String _search = '';
  String _filterStatus = 'For Review';
  String _filterType = 'All';
  int _page = 1;
  static const int _rowsPerPage = 8;

  @override
  void initState() {
    super.initState();
    _fetchLoans();
  }

  Future<void> _fetchLoans({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        LoansService.getLoans(status: 'For Review'),
        LoansService.getLoans(status: 'Declined'),
      ]);
      if (mounted) setState(() => _loans = [...results[0], ...results[1]]);
    } catch (_) {
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Map<String, int> get _counts => {
        'forReview': _loans.where((l) => l['status'] == 'For Review').length,
        'declined': _loans.where((l) => l['status'] == 'Declined').length,
      };

  double get _pendingAmount => _loans.where((l) => l['status'] == 'For Review').fold<double>(0, (s, l) => s + (double.tryParse('${l['amount'] ?? 0}') ?? 0));

  List<dynamic> get _filtered {
    return _loans.where((l) {
      final matchStatus = _filterStatus == 'All' || l['status'] == _filterStatus;
      final matchType = _filterType == 'All' || l['loan_type'] == _filterType;
      final q = _search.toLowerCase();
      return matchStatus && matchType && (
        '${l['loan_id'] ?? ''}'.toLowerCase().contains(q) ||
        '${l['member_name'] ?? ''}'.toLowerCase().contains(q) ||
        '${l['member_code'] ?? ''}'.toLowerCase().contains(q) ||
        '${l['loan_type'] ?? ''}'.toLowerCase().contains(q) ||
        '${l['purpose'] ?? ''}'.toLowerCase().contains(q)
      );
    }).toList();
  }

  void _openProcess(dynamic loan) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => ProcessLoanScreen(loan: loan)));
    if (changed == true) _fetchLoans(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalPages = (filtered.length / _rowsPerPage).ceil().clamp(1, 999999);
    final safePage = _page.clamp(1, totalPages);
    final paginated = filtered.skip((safePage - 1) * _rowsPerPage).take(_rowsPerPage).toList();
    final counts = _counts;

    return AdminScreenScaffold(
      activeRouteKey: 'loan-approval',
      body: RefreshIndicator(
        onRefresh: () => _fetchLoans(),
        color: _LAColors.green,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Loan Approval', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _LAColors.title)),
              const SizedBox(height: 2),
              const Text('Evaluate and process member loan applications submitted online.', style: TextStyle(fontSize: 11, color: _LAColors.sub)),
              const SizedBox(height: 14),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  _SummaryCard(icon: Icons.access_time, label: 'For Review', value: '${counts['forReview']}', color: _LAColors.orange, bg: const Color(0xFFFFF8E1), onTap: () => setState(() { _filterStatus = 'For Review'; _page = 1; })),
                  _SummaryCard(icon: Icons.cancel_outlined, label: 'Declined', value: '${counts['declined']}', color: _LAColors.red, bg: const Color(0xFFFCE4EC), onTap: () => setState(() { _filterStatus = 'Declined'; _page = 1; })),
                  _SummaryCard(icon: Icons.check_circle_outline, label: 'Total Applications', value: '${(counts['forReview'] ?? 0) + (counts['declined'] ?? 0)}', color: _LAColors.green, bg: const Color(0xFFE8F5E9)),
                  _SummaryCard(icon: Icons.account_balance_wallet_outlined, label: 'Pending Amount', value: '₱${_pendingAmount.toStringAsFixed(0)}', color: _LAColors.blue, bg: const Color(0xFFE3F2FD)),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                decoration: BoxDecoration(color: const Color(0xFFF5FAF5), border: Border.all(color: _LAColors.border), borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  onChanged: (v) => setState(() { _search = v; _page = 1; }),
                  decoration: const InputDecoration(hintText: 'Search by Loan ID, Name, Member ID...', hintStyle: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)), prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFFAAAAAA)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12)),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE0E0E0)), borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterType,
                    isExpanded: true,
                    icon: const Icon(Icons.filter_list, size: 16),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
                    items: [
                      const DropdownMenuItem(value: 'All', child: Text('All Loan Types')),
                      ...kLoanTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                    ],
                    onChanged: (v) => setState(() { _filterType = v ?? 'All'; _page = 1; }),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: ['For Review', 'Declined'].map((s) {
                  final active = _filterStatus == s;
                  final color = s == 'Declined' ? _LAColors.red : _LAColors.orange;
                  return ChoiceChip(
                    label: Text('$s (${_loans.where((l) => l['status'] == s).length})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF888888))),
                    selected: active,
                    selectedColor: color,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: active ? color : const Color(0xFFE0E8E0)),
                    onSelected: (_) => setState(() { _filterStatus = s; _page = 1; }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: _LAColors.green)))
              else if (paginated.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No loan applications found.', style: TextStyle(color: _LAColors.sub, fontStyle: FontStyle.italic))))
              else
                ...paginated.map((l) => _LoanApplicationCard(loan: l, onTap: () => _openProcess(l))),

              if (!_loading && filtered.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Showing ${filtered.isEmpty ? 0 : (safePage - 1) * _rowsPerPage + 1}–${(safePage * _rowsPerPage).clamp(0, filtered.length)} of ${filtered.length}', style: const TextStyle(fontSize: 11, color: _LAColors.sub)),
                    Row(children: [
                      IconButton(onPressed: safePage > 1 ? () => setState(() => _page = safePage - 1) : null, icon: const Icon(Icons.chevron_left, size: 18), visualDensity: VisualDensity.compact),
                      Text('$safePage / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      IconButton(onPressed: safePage < totalPages ? () => setState(() => _page = safePage + 1) : null, icon: const Icon(Icons.chevron_right, size: 18), visualDensity: VisualDensity.compact),
                    ]),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final VoidCallback? onTap;
  const _SummaryCard({required this.icon, required this.label, required this.value, required this.color, required this.bg, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _LAColors.border), borderRadius: BorderRadius.circular(12)),
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
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _LAColors.sub, letterSpacing: 0.4),
                  ),
                ),
                Container(width: 30, height: 30, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 15)),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoanApplicationCard extends StatelessWidget {
  final dynamic loan;
  final VoidCallback onTap;
  const _LoanApplicationCard({required this.loan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = (loan['status'] ?? '').toString();
    final isForReview = status == 'For Review';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('${loan['loan_id'] ?? ''}', style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: _LAColors.title)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: laStatusBg(status), borderRadius: BorderRadius.circular(20), border: Border.all(color: laStatusColor(status).withOpacity(0.3))),
                          child: Text(status, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: laStatusColor(status))),
                        ),
                      ]),
                      const SizedBox(height: 3),
                      Text('${loan['member_name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      Text('${loan['member_code'] ?? ''} · ${loan['loan_type'] ?? ''}', style: const TextStyle(fontSize: 10, color: _LAColors.sub)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('₱${(double.tryParse('${loan['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: _LAColors.green, fontSize: 12.5)),
                        const SizedBox(width: 8),
                        Text('· ${loan['term_months'] ?? loan['term'] ?? ''}mo', style: const TextStyle(fontSize: 11, color: _LAColors.sub)),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isForReview ? _LAColors.orange : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isForReview ? _LAColors.orange : const Color(0xFFC8E6C9)),
                  ),
                  child: Text(isForReview ? 'Process' : 'View', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isForReview ? Colors.white : _LAColors.green)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}