import 'package:flutter/material.dart';
import '../../services/loans_service.dart';
import '../../services/payments_service.dart';
import '../../widgets/member_scaffold_helpers.dart';
import '../admin/receipt_screen.dart';
import 'gcash_payment_screen.dart';

class _MLColors {
  static const dark   = Color(0xFF1B5E20);
  static const green  = Color(0xFF2E7D32);
  static const sub    = Color(0xFFAAAAAA);
  static const red    = Color(0xFFC62828);
  static const blue   = Color(0xFF1565C0);
  static const orange = Color(0xFFF57C00);
  static const border = Color(0xFFE8F5E9);
}

const Map<String, Color> _statusColor = {'Active': _MLColors.green, 'Overdue': _MLColors.red, 'Completed': _MLColors.blue, 'Declined': Color(0xFF757575)};
const Map<String, Color> _statusBg = {'Active': Color(0xFFE8F5E9), 'Overdue': Color(0xFFFFEBEE), 'Completed': Color(0xFFE3F2FD), 'Declined': Color(0xFFF5F5F5)};

String _peso(double value) {
  final fixed = value.toStringAsFixed(0);
  final isNeg = fixed.startsWith('-');
  final digits = isNeg ? fixed.substring(1) : fixed;
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '₱${isNeg ? '-' : ''}$buf';
}

class MyLoansScreen extends StatefulWidget {
  const MyLoansScreen({super.key});

  @override
  State<MyLoansScreen> createState() => _MyLoansScreenState();
}

class _MyLoansScreenState extends State<MyLoansScreen> {
  bool _loading = true;
  List<dynamic> _activeLoans = [];
  List<dynamic> _allLoans = [];
  List<dynamic> _payments = [];
  List<dynamic> _gcashRequests = [];
  dynamic _selectedLoan;
  String _mainTab = 'active'; // active | history | all
  String _detailTab = 'details'; // details | payments | schedule
  String? _expandedLoanId;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    List<dynamic> active = [];
    List<dynamic> completed = [];
    List<dynamic> payments = [];
    List<dynamic> gcash = [];
    await Future.wait([
      () async { try { active = await LoansService.getLoans(); } catch (_) {} }(),
      () async { try { completed = await LoansService.getLoans(status: 'Completed'); } catch (_) {} }(),
      () async { try { payments = await PaymentsService.getPayments(); } catch (_) {} }(),
      () async { try { gcash = await LoansService.getGCashRequests(); } catch (_) {} }(),
    ]);
    final activeFiltered = active.where((l) => l['status'] == 'Active' || l['status'] == 'Overdue').toList();
    if (mounted) {
      setState(() {
        _activeLoans = activeFiltered;
        _allLoans = [...activeFiltered, ...completed]..sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
        _payments = payments;
        _gcashRequests = gcash;
        _selectedLoan = activeFiltered.isNotEmpty ? activeFiltered.first : null;
        _loading = false;
      });
    }
  }

  bool _hasPendingGCash(String loanId) => _gcashRequests.any((r) => r['loan_id'] == loanId && r['status'] == 'Pending');

  void _openReceipt(dynamic payment) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ReceiptScreen(tx: payment)));
  }

  void _payViaGcash(dynamic loan) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => GcashPaymentScreen(loan: loan)));
    if (result != null) _fetchAll(); // i-refresh para makita yung bagong "Pending" badge
  }

  @override
  Widget build(BuildContext context) {
    return MemberScreenScaffold(
      activeRouteKey: 'my-loans',
      body: RefreshIndicator(
        onRefresh: _fetchAll,
        color: _MLColors.green,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _MLColors.green))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Loans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _MLColors.dark)),
                    const SizedBox(height: 2),
                    const Text('View your loans, payment history, and receipts.', style: TextStyle(fontSize: 11, color: _MLColors.sub)),
                    const SizedBox(height: 14),

                    // ── Main tabs ─────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _MLColors.border), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Expanded(child: _MainTabBtn(icon: Icons.credit_card_outlined, label: 'Active', count: _activeLoans.length, active: _mainTab == 'active', onTap: () => setState(() => _mainTab = 'active'))),
                        Expanded(child: _MainTabBtn(icon: Icons.list_alt, label: 'History', count: _allLoans.length, active: _mainTab == 'history', onTap: () => setState(() => _mainTab = 'history'))),
                        Expanded(child: _MainTabBtn(icon: Icons.receipt_long_outlined, label: 'Payments', count: _payments.length, active: _mainTab == 'all', onTap: () => setState(() => _mainTab = 'all'))),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    if (_mainTab == 'active') ..._buildActiveTab(),
                    if (_mainTab == 'history') ..._buildHistoryTab(),
                    if (_mainTab == 'all') ..._buildAllPaymentsTab(),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _buildActiveTab() {
    if (_activeLoans.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _MLColors.border)),
          child: Column(children: const [
            Icon(Icons.description_outlined, size: 36, color: Color(0xFFC8E6C9)),
            SizedBox(height: 10),
            Text('No active loans', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF555555))),
            SizedBox(height: 4),
            Text('You have no active loan records at the moment.', style: TextStyle(fontSize: 12, color: _MLColors.sub)),
          ]),
        ),
      ];
    }

    final pendingCount = _gcashRequests.where((r) => r['status'] == 'Pending').length;

    return [
      // Loan selector cards
      ..._activeLoans.map((loan) {
        final lp = double.tryParse('${loan['amount'] ?? 0}') ?? 0;
        final lb = double.tryParse('${loan['balance'] ?? 0}') ?? 0;
        final pct = lp > 0 ? (((lp - lb) / lp) * 100).round() : 0;
        final isSelected = _selectedLoan != null && _selectedLoan['loan_id'] == loan['loan_id'];
        final pending = _hasPendingGCash(loan['loan_id']);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFFA5D6A7) : _MLColors.border, width: 1),
          ),
          child: InkWell(
            onTap: () => setState(() { _selectedLoan = loan; _detailTab = 'details'; }),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('${loan['loan_type'] ?? ''}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _MLColors.dark)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: _statusBg[loan['status']] ?? const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)),
                    child: Text('${loan['status'] ?? ''}', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _statusColor[loan['status']] ?? const Color(0xFF555555))),
                  ),
                ]),
                Text('${loan['loan_id'] ?? ''}', style: const TextStyle(fontSize: 10, color: _MLColors.sub, fontFamily: 'monospace')),
                const SizedBox(height: 8),
                Text(_peso(lb), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                const Text('remaining balance', style: TextStyle(fontSize: 10, color: _MLColors.sub)),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1), backgroundColor: const Color(0xFFF5F5F5), color: _MLColors.green, minHeight: 8)),
                const SizedBox(height: 4),
                Text('$pct% paid', style: const TextStyle(fontSize: 10, color: _MLColors.sub)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: pending ? null : () => _payViaGcash(loan),
                    style: ElevatedButton.styleFrom(backgroundColor: pending ? const Color(0xFFF5F5F5) : const Color(0xFF1976D2), foregroundColor: pending ? const Color(0xFFAAAAAA) : Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                    icon: const Icon(Icons.smartphone, size: 14),
                    label: Text(pending ? 'GCash Pending Verification' : 'Pay via GCash', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      }),

      if (pendingCount > 0)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFFF8E1), border: Border.all(color: const Color(0xFFFFE082)), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: _MLColors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text('You have $pendingCount GCash payment request(s) pending admin verification. You will be notified once verified.', style: const TextStyle(fontSize: 11.5, color: _MLColors.orange, fontWeight: FontWeight.w600))),
          ]),
        ),

      // Detail card
      if (_selectedLoan != null) ..._buildDetailCard(),
    ];
  }

  List<Widget> _buildDetailCard() {
    final loan = _selectedLoan;
    final principal = double.tryParse('${loan['amount'] ?? 0}') ?? 0;
    final balance = double.tryParse('${loan['balance'] ?? 0}') ?? 0;
    final totalPaid = principal - balance;
    final monthlyDue = double.tryParse('${loan['monthly_due'] ?? 0}') ?? 0;
    final paidPct = principal > 0 ? ((totalPaid / principal) * 100).round() : 0;

    return [
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _MLColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: _DetailTabBtn(label: 'Loan Details', active: _detailTab == 'details', onTap: () => setState(() => _detailTab = 'details'))),
              Expanded(child: _DetailTabBtn(label: 'Payment History', active: _detailTab == 'payments', onTap: () => setState(() => _detailTab = 'payments'))),
              Expanded(child: _DetailTabBtn(label: 'Amortization', active: _detailTab == 'schedule', onTap: () => setState(() => _detailTab = 'schedule'))),
            ]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _detailTab == 'details'
                  ? _buildDetailsTab(loan, principal, balance, totalPaid, monthlyDue, paidPct)
                  : _detailTab == 'payments'
                      ? _buildPaymentsTab(loan)
                      : _buildScheduleTab(loan, monthlyDue),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildDetailsTab(dynamic loan, double principal, double balance, double totalPaid, double monthlyDue, int paidPct) {
    final rows = [
      ['Loan ID', '${loan['loan_id'] ?? ''}'],
      ['Loan Type', '${loan['loan_type'] ?? ''}'],
      ['Principal', _peso(principal)],
      ['Remaining', _peso(balance)],
      ['Total Paid', _peso(totalPaid)],
      ['Monthly Due', _peso(monthlyDue)],
      ['Term', '${loan['term_months'] ?? ''} months'],
      ['Release Date', '${loan['approved_at'] ?? ''}'.split('T').first],
      ['Next Due', '${loan['next_due_date'] ?? '—'}'],
      ['Status', '${loan['status'] ?? ''}'],
    ];
    // Ginawang pares (2 kada row) gamit ang Row+Expanded imbes na manual
    // pixel-width Container sa loob ng Wrap — dati kasi nag-o-overflow
    // dahil hindi kasama sa width computation yung border thickness
    // (hindi border-box ang default box model sa Flutter).
    final pairs = <List<List<String>>>[];
    for (var i = 0; i < rows.length; i += 2) {
      pairs.add([rows[i], if (i + 1 < rows.length) rows[i + 1]]);
    }

    Widget fieldCell(List<String> r, {required bool isLast}) {
      final label = r[0];
      final val = r[1];
      final color = label == 'Remaining' ? _MLColors.red : label == 'Total Paid' ? _MLColors.green : const Color(0xFF1A1A1A);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border(left: isLast ? BorderSide.none : const BorderSide(color: _MLColors.border))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFAAAAAA), letterSpacing: 0.4)),
              const SizedBox(height: 3),
              Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color), overflow: TextOverflow.ellipsis, maxLines: 1),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(border: Border.all(color: _MLColors.border), borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: List.generate(pairs.length, (i) {
              final pair = pairs[i];
              final isLastRow = i == pairs.length - 1;
              return Container(
                decoration: BoxDecoration(border: Border(bottom: isLastRow ? BorderSide.none : const BorderSide(color: _MLColors.border))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fieldCell(pair[0], isLast: true),
                    if (pair.length > 1) fieldCell(pair[1], isLast: false) else const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: (paidPct / 100).clamp(0, 1), backgroundColor: const Color(0xFFF5F5F5), color: _MLColors.green, minHeight: 10)),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$paidPct% paid', style: const TextStyle(fontSize: 11, color: _MLColors.sub)),
          Text('${_peso(balance)} remaining', style: const TextStyle(fontSize: 11, color: _MLColors.sub)),
        ]),
      ],
    );
  }

  Widget _buildPaymentsTab(dynamic loan) {
    final loanPayments = _payments.where((p) => p['loan'] == loan['id'] || '${p['loan_code']}' == '${loan['loan_id']}').toList();
    if (loanPayments.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('No payments yet.', style: TextStyle(color: _MLColors.sub))));
    }
    return Column(
      children: loanPayments.map<Widget>((p) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p['paid_at'] ?? ''}'.split('T').first, style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
                    Text('${p['tx_id'] ?? ''}', style: const TextStyle(fontSize: 9.5, color: _MLColors.sub, fontFamily: 'monospace')),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_peso(double.tryParse('${p['amount'] ?? 0}') ?? 0), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _MLColors.green)),
                Text(_peso(double.tryParse('${p['balance'] ?? 0}') ?? 0), style: const TextStyle(fontSize: 10, color: _MLColors.blue)),
              ]),
              IconButton(icon: const Icon(Icons.visibility_outlined, size: 16, color: _MLColors.green), onPressed: () => _openReceipt(p), visualDensity: VisualDensity.compact),
            ]),
          )).toList(),
    );
  }

  Widget _buildScheduleTab(dynamic loan, double monthlyDue) {
    final loanPayments = _payments.where((p) => p['loan'] == loan['id']).toList();
    final totalPaidAmt = loanPayments.fold<double>(0, (s, p) => s + (double.tryParse('${p['amount'] ?? 0}') ?? 0));
    final monthsPaid = monthlyDue > 0 ? (totalPaidAmt / monthlyDue).floor() : 0;
    final termMonths = int.tryParse('${loan['term_months'] ?? 0}') ?? 0;
    DateTime baseDate;
    try {
      baseDate = DateTime.parse(loan['approved_at'] ?? loan['applied_at'] ?? DateTime.now().toIso8601String());
    } catch (_) {
      baseDate = DateTime.now();
    }

    return Column(
      children: List.generate(termMonths, (i) {
        final due = DateTime(baseDate.year, baseDate.month + i + 1, baseDate.day);
        final isPaid = i < monthsPaid;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            SizedBox(width: 24, child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: _MLColors.sub))),
            Expanded(child: Text('${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11.5))),
            Text(_peso(monthlyDue), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: isPaid ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isPaid ? Icons.check_circle : Icons.access_time, size: 11, color: isPaid ? _MLColors.green : const Color(0xFF999999)),
                const SizedBox(width: 4),
                Text(isPaid ? 'Paid' : 'Upcoming', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: isPaid ? _MLColors.green : const Color(0xFF999999))),
              ]),
            ),
          ]),
        );
      }),
    );
  }

  List<Widget> _buildHistoryTab() {
    if (_allLoans.isEmpty) {
      return [const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No loan history yet.', style: TextStyle(color: _MLColors.sub))))];
    }
    return _allLoans.map<Widget>((loan) {
      final isExpanded = _expandedLoanId == loan['loan_id'];
      final isPaid = loan['status'] == 'Completed' || (double.tryParse('${loan['balance'] ?? 0}') ?? 0) == 0;
      final sc = isPaid ? _MLColors.blue : (_statusColor[loan['status']] ?? const Color(0xFF555555));
      final sb = isPaid ? const Color(0xFFE3F2FD) : (_statusBg[loan['status']] ?? const Color(0xFFF5F5F5));
      final loanPayments = _payments.where((p) => p['loan'] == loan['id'] || '${p['loan_code']}' == '${loan['loan_id']}').toList();

      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: isExpanded ? const Color(0xFFA5D6A7) : _MLColors.border, width: isExpanded ? 1.5 : 1), color: Colors.white),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expandedLoanId = isExpanded ? null : loan['loan_id']),
              child: Container(
                padding: const EdgeInsets.all(14),
                color: isExpanded ? const Color(0xFFF1F8E9) : Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${loan['loan_id'] ?? ''}', style: const TextStyle(fontFamily: 'monospace', color: _MLColors.dark, fontWeight: FontWeight.w800, fontSize: 13)),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: _MLColors.sub),
                    ]),
                    Text('${loan['loan_type'] ?? ''}', style: const TextStyle(fontSize: 11, color: _MLColors.sub)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _HistMini('Amount', _peso(double.tryParse('${loan['amount'] ?? 0}') ?? 0))),
                      Expanded(child: _HistMini('Balance', isPaid ? '₱0' : _peso(double.tryParse('${loan['balance'] ?? 0}') ?? 0), color: isPaid ? _MLColors.green : _MLColors.red)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: sb, borderRadius: BorderRadius.circular(20), border: Border.all(color: sc.withOpacity(0.3))),
                        child: Text(isPaid ? 'Completed' : '${loan['status'] ?? ''}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(color: Color(0xFFF9FEF9), border: Border(top: BorderSide(color: _MLColors.border))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment History (${loanPayments.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _MLColors.green)),
                    const SizedBox(height: 8),
                    if (loanPayments.isEmpty)
                      const Text('No payments recorded yet.', style: TextStyle(fontSize: 11.5, color: _MLColors.sub))
                    else
                      ...loanPayments.map((p) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Expanded(child: Text('${p['paid_at'] ?? ''}'.split('T').first, style: const TextStyle(fontSize: 10.5, color: Color(0xFF666666)))),
                              Text(_peso(double.tryParse('${p['amount'] ?? 0}') ?? 0), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _MLColors.green)),
                              IconButton(icon: const Icon(Icons.visibility_outlined, size: 14, color: _MLColors.green), onPressed: () => _openReceipt(p), visualDensity: VisualDensity.compact),
                            ]),
                          )),
                  ],
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildAllPaymentsTab() {
    if (_payments.isEmpty) {
      return [const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No payment records yet.', style: TextStyle(color: _MLColors.sub))))];
    }
    final totalPaid = _payments.fold<double>(0, (s, p) => s + (double.tryParse('${p['amount'] ?? 0}') ?? 0));
    final latest = '${_payments.first['paid_at'] ?? ''}'.split('T').first;

    return [
      Row(children: [
        Expanded(child: _SummaryStat(label: 'Total Payments', value: '${_payments.length}', color: _MLColors.dark)),
        const SizedBox(width: 8),
        Expanded(child: _SummaryStat(label: 'Total Paid', value: _peso(totalPaid), color: _MLColors.green)),
        const SizedBox(width: 8),
        Expanded(child: _SummaryStat(label: 'Latest', value: latest.isEmpty ? '—' : latest, color: const Color(0xFF555555))),
      ]),
      const SizedBox(height: 14),
      ..._payments.map((p) {
        final loan = _allLoans.firstWhere((l) => l['loan_id'] == p['loan_code'], orElse: () => null);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _MLColors.border)),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('${p['loan_code'] ?? ''}', style: const TextStyle(fontFamily: 'monospace', color: _MLColors.dark, fontWeight: FontWeight.w700, fontSize: 11)),
                    if (loan != null) ...[
                      const SizedBox(width: 6),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFF3E5F5), borderRadius: BorderRadius.circular(20)), child: Text('${loan['loan_type']}', style: const TextStyle(fontSize: 8.5, color: Color(0xFF6A1B9A), fontWeight: FontWeight.w700))),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text('${p['paid_at'] ?? ''}'.split('T').first, style: const TextStyle(fontSize: 10.5, color: Color(0xFF555555))),
                  if (p['note'] != null && '${p['note']}'.isNotEmpty) Text('${p['note']}', style: const TextStyle(fontSize: 10, color: _MLColors.sub)),
                ],
              ),
            ),
            Text(_peso(double.tryParse('${p['amount'] ?? 0}') ?? 0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _MLColors.green)),
            IconButton(icon: const Icon(Icons.receipt_long_outlined, size: 16, color: _MLColors.green), onPressed: () => _openReceipt(p)),
          ]),
        );
      }),
    ];
  }
}

class _MainTabBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _MainTabBtn({required this.icon, required this.label, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _MLColors.dark : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? Colors.white : const Color(0xFF888888)),
              const SizedBox(width: 6),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF888888)))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: active ? Colors.white.withOpacity(0.2) : const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? Colors.white : const Color(0xFFAAAAAA))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailTabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DetailTabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? _MLColors.green : Colors.transparent, width: 2))),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? _MLColors.green : const Color(0xFF888888))),
      ),
    );
  }
}

class _HistMini extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _HistMini(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 8.5, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color ?? const Color(0xFF1A1A1A))),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _MLColors.border)),
      child: Column(children: [
        FittedBox(child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color))),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w700), textAlign: TextAlign.center),
      ]),
    );
  }
}