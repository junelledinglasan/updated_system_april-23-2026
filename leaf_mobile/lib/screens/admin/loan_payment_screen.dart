import 'package:flutter/material.dart';
import '../../services/loans_service.dart';
import '../../services/payments_service.dart';
import '../../widgets/admin/admin_scaffold_helpers.dart';
import 'record_payment_screen.dart';
import 'receipt_screen.dart';
import 'loan_payment_history_screen.dart';
import 'f2f_payment_screen.dart';
import 'new_loan_application_screen.dart';

class _LPColors {
  static const title   = Color(0xFF1B5E20);
  static const sub     = Color(0xFFAAAAAA);
  static const green   = Color(0xFF2E7D32);
  static const border  = Color(0xFFC8DDC8);
  static const red     = Color(0xFFC62828);
  static const blue    = Color(0xFF1565C0);
  static const purple  = Color(0xFF6A1B9A);
}

class LoanPaymentScreen extends StatefulWidget {
  const LoanPaymentScreen({super.key});

  @override
  State<LoanPaymentScreen> createState() => _LoanPaymentScreenState();
}

class _LoanPaymentScreenState extends State<LoanPaymentScreen> {
  List<dynamic> _loans = [];
  List<dynamic> _allLoans = [];
  bool _allLoansLoading = false;
  bool _allLoansFetched = false;
  List<dynamic> _transactions = [];
  Map<String, dynamic> _pStats = {};
  bool _loading = true;

  String _activeTab = 'loans'; // loans | history | loanhistory
  String _search = '';
  String _filterStatus = 'All';
  String _loanHistFilter = 'All';
  String _historyView = 'daily'; // daily | all

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    // Palaging i-invalidate yung Loan History cache dito — kasi kapag
    // may bagong payment, dapat ma-refresh din yung balance doon sa
    // susunod na buksan yung "Loan History" tab, hindi yung lumang data.
    _allLoansFetched = false;
    try {
      final results = await Future.wait([
        LoansService.getLoans(status: 'Active'),
        LoansService.getLoans(status: 'Overdue'),
        PaymentsService.getPayments(),
        PaymentsService.getPaymentStats(),
      ]);
      final active = results[0] as List<dynamic>;
      final overdue = results[1] as List<dynamic>;
      if (mounted) {
        setState(() {
          _loans = [...active, ...overdue];
          _transactions = results[2] as List<dynamic>;
          _pStats = results[3] as Map<String, dynamic>;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchAllLoans() async {
    if (_allLoansFetched) return;
    setState(() => _allLoansLoading = true);
    try {
      final results = await Future.wait([
        LoansService.getLoans(status: 'Active'),
        LoansService.getLoans(status: 'Overdue'),
        LoansService.getLoans(status: 'Completed'),
        LoansService.getLoans(status: 'Declined'),
      ]);
      final all = [...results[0], ...results[1], ...results[2], ...results[3]];
      all.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
      if (mounted) setState(() { _allLoans = all; _allLoansFetched = true; });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _allLoansLoading = false);
    }
  }

  void _switchTab(String tab) {
    setState(() { _activeTab = tab; _search = ''; _filterStatus = 'All'; });
    if (tab == 'loanhistory') _fetchAllLoans();
  }

  double get _totalCollected => double.tryParse('${_pStats['total_collected'] ?? 0}') ?? 0;
  int get _overdueCount => _loans.where((l) => l['status'] == 'Overdue').length;
  double get _totalOutstanding => _loans.fold<double>(0, (s, l) => s + (double.tryParse('${l['balance'] ?? 0}') ?? 0));

  List<dynamic> get _filteredLoans => _loans.where((l) {
        final matchS = _filterStatus == 'All' || l['status'] == _filterStatus;
        final q = _search.toLowerCase();
        return matchS && (
          '${l['loan_id'] ?? ''}'.toLowerCase().contains(q) ||
          '${l['member_name'] ?? ''}'.toLowerCase().contains(q) ||
          '${l['member_code'] ?? ''}'.toLowerCase().contains(q) ||
          '${l['loan_type'] ?? ''}'.toLowerCase().contains(q)
        );
      }).toList();

  List<dynamic> get _filteredTx => _transactions.where((t) {
        final q = _search.toLowerCase();
        return '${t['tx_id'] ?? ''}'.toLowerCase().contains(q) ||
            '${t['member_name'] ?? ''}'.toLowerCase().contains(q) ||
            '${t['loan_code'] ?? ''}'.toLowerCase().contains(q);
      }).toList();

  List<dynamic> get _filteredAllLoans => _allLoans.where((l) {
        final matchS = _loanHistFilter == 'All' || l['status'] == _loanHistFilter;
        final q = _search.toLowerCase();
        return matchS && (
          '${l['loan_id'] ?? ''}'.toLowerCase().contains(q) ||
          '${l['member_name'] ?? ''}'.toLowerCase().contains(q) ||
          '${l['member_code'] ?? ''}'.toLowerCase().contains(q)
        );
      }).toList();

  Map<String, List<dynamic>> get _dailyGroups {
    final groups = <String, List<dynamic>>{};
    for (final tx in _filteredTx) {
      final paidAt = tx['paid_at'];
      String dateStr = 'Unknown';
      if (paidAt != null) {
        try {
          dateStr = DateTime.parse(paidAt).toIso8601String().split('T').first;
        } catch (_) {}
      }
      groups.putIfAbsent(dateStr, () => []).add(tx);
    }
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final maxA = groups[a]!.map((t) => t['id'] ?? 0).fold<int>(0, (p, c) => c > p ? c : p);
        final maxB = groups[b]!.map((t) => t['id'] ?? 0).fold<int>(0, (p, c) => c > p ? c : p);
        return maxB.compareTo(maxA);
      });
    return {for (final k in sortedKeys) k: groups[k]!};
  }

  String _dateLabel(String dateStr) {
    if (dateStr == 'Unknown') return 'Unknown Date';
    final now = DateTime.now();
    final today = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yest = now.subtract(const Duration(days: 1));
    final yestStr = '${yest.year.toString().padLeft(4, '0')}-${yest.month.toString().padLeft(2, '0')}-${yest.day.toString().padLeft(2, '0')}';
    if (dateStr == today) return 'Today';
    if (dateStr == yestStr) return 'Yesterday';
    try {
      final d = DateTime.parse(dateStr);
      const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
      const weekdays = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
      return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  void _openRecordPayment(dynamic loan) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => RecordPaymentScreen(loan: loan)),
    );
    if (result != null) {
      await _fetchData();
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ReceiptScreen(tx: result)));
      }
    }
  }

  void _openLoanHistory(dynamic loan) {
    final payments = _transactions.where((p) => '${p['loan_code']}'.trim() == '${loan['loan_id']}'.trim()).toList();
    Navigator.push(context, MaterialPageRoute(builder: (context) => LoanPaymentHistoryScreen(loan: loan, payments: payments)));
  }

  void _openF2FPayment() async {
    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (context) => const F2fPaymentScreen()));
    if (result != null) {
      await _fetchData();
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => ReceiptScreen(tx: result)));
    }
  }

  void _openNewLoanApplication() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const NewLoanApplicationScreen()));
    if (result == true) _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScreenScaffold(
      activeRouteKey: 'loan-payment',
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'f2f-payment-fab',
            backgroundColor: _LPColors.blue,
            tooltip: 'New F2F Payment',
            onPressed: _openF2FPayment,
            child: const Icon(Icons.payments_outlined, color: Colors.white),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            heroTag: 'new-loan-app-fab',
            backgroundColor: _LPColors.green,
            tooltip: 'New Loan Application',
            onPressed: _openNewLoanApplication,
            child: const Icon(Icons.note_add_outlined, color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: _LPColors.green,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Loan Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _LPColors.title)),
              const SizedBox(height: 2),
              const Text('Record and track F2F loan payments collected at the office.', style: TextStyle(fontSize: 11, color: _LPColors.sub)),
              const SizedBox(height: 14),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.9,
                children: [
                  _SummaryCard(icon: Icons.account_balance_wallet_outlined, label: 'Total Collected', value: '₱${_totalCollected.toStringAsFixed(0)}', color: _LPColors.title, bg: const Color(0xFFE8F5E9)),
                  _SummaryCard(icon: Icons.warning_amber_rounded, label: 'Overdue Loans', value: '$_overdueCount', color: _LPColors.red, bg: const Color(0xFFFCE4EC), onTap: () { _switchTab('loans'); setState(() => _filterStatus = 'Overdue'); }),
                  _SummaryCard(icon: Icons.bar_chart_outlined, label: 'Total Outstanding', value: '₱${_totalOutstanding.toStringAsFixed(0)}', color: _LPColors.blue, bg: const Color(0xFFE3F2FD)),
                  _SummaryCard(icon: Icons.receipt_long_outlined, label: 'Transactions', value: '${_transactions.length}', color: _LPColors.purple, bg: const Color(0xFFF3E5F5), onTap: () => _switchTab('history')),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _LPColors.border), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Expanded(child: _TabBtn(label: 'Active Loans', count: _loans.length, active: _activeTab == 'loans', onTap: () => _switchTab('loans'))),
                    Container(width: 1, height: 40, color: const Color(0xFFE4F0E5)),
                    Expanded(child: _TabBtn(label: 'Payment History', count: _transactions.length, active: _activeTab == 'history', onTap: () => _switchTab('history'))),
                    Container(width: 1, height: 40, color: const Color(0xFFE4F0E5)),
                    Expanded(child: _TabBtn(label: 'Loan History', count: _allLoans.length, active: _activeTab == 'loanhistory', onTap: () => _switchTab('loanhistory'))),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(color: const Color(0xFFF5FAF5), border: Border.all(color: _LPColors.border), borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(hintText: 'Search...', hintStyle: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)), prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFFAAAAAA)), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12)),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 10),

              if (_activeTab == 'loans') ..._buildLoansTab(),
              if (_activeTab == 'history') ..._buildHistoryTab(),
              if (_activeTab == 'loanhistory') ..._buildLoanHistoryTab(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLoansTab() {
    final list = _filteredLoans;
    return [
      Wrap(
        spacing: 6,
        children: ['All', 'Active', 'Overdue'].map((s) {
          final active = _filterStatus == s;
          final color = s == 'Overdue' ? _LPColors.red : _LPColors.green;
          return ChoiceChip(
            label: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF888888))),
            selected: active,
            selectedColor: color,
            backgroundColor: Colors.white,
            side: BorderSide(color: active ? color : const Color(0xFFE0E8E0)),
            onSelected: (_) => setState(() => _filterStatus = s),
          );
        }).toList(),
      ),
      const SizedBox(height: 10),
      if (_loading)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: _LPColors.green)))
      else if (list.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No loans found.', style: TextStyle(color: _LPColors.sub, fontStyle: FontStyle.italic))))
      else
        ...list.map((l) => _LoanCard(
              loan: l,
              onTap: (double.tryParse('${l['balance'] ?? 0}') ?? 0) > 0 ? () => _openRecordPayment(l) : null,
              onViewHistory: () => _openLoanHistory(l),
            )),
    ];
  }

  List<Widget> _buildHistoryTab() {
    return [
      Row(children: [
        Expanded(child: _ViewToggle(label: 'Daily View', icon: Icons.calendar_today_outlined, active: _historyView == 'daily', onTap: () => setState(() => _historyView = 'daily'))),
        const SizedBox(width: 8),
        Expanded(child: _ViewToggle(label: 'All Transactions', icon: Icons.list_alt, active: _historyView == 'all', onTap: () => setState(() => _historyView = 'all'))),
      ]),
      const SizedBox(height: 10),
      if (_loading)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: _LPColors.green)))
      else if (_historyView == 'daily')
        ..._buildDailyView()
      else
        ..._buildAllTxView(),
    ];
  }

  List<Widget> _buildDailyView() {
    final groups = _dailyGroups;
    if (groups.isEmpty) {
      return [const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No transactions found.', style: TextStyle(color: _LPColors.sub))))];
    }
    return groups.entries.map((entry) => _DailyGroupCard(dateLabel: _dateLabel(entry.key), dateStr: entry.key, txList: entry.value, onViewTx: (tx) => Navigator.push(context, MaterialPageRoute(builder: (context) => ReceiptScreen(tx: tx))))).toList();
  }

  List<Widget> _buildAllTxView() {
    final list = _filteredTx;
    if (list.isEmpty) {
      return [const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No transactions found.', style: TextStyle(color: _LPColors.sub))))];
    }
    return list.map<Widget>((tx) => _TxCard(tx: tx, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReceiptScreen(tx: tx))))).toList();
  }

  List<Widget> _buildLoanHistoryTab() {
    return [
      Wrap(
        spacing: 6,
        children: ['All', 'Active', 'Overdue', 'Completed', 'Declined'].map((s) {
          final active = _loanHistFilter == s;
          return ChoiceChip(
            label: Text(s, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF888888))),
            selected: active,
            selectedColor: _LPColors.green,
            backgroundColor: Colors.white,
            side: BorderSide(color: active ? _LPColors.green : const Color(0xFFE0E8E0)),
            onSelected: (_) => setState(() => _loanHistFilter = s),
          );
        }).toList(),
      ),
      const SizedBox(height: 10),
      if (_allLoansLoading)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: _LPColors.green)))
      else if (_filteredAllLoans.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No loans found.', style: TextStyle(color: _LPColors.sub))))
      else
        ..._filteredAllLoans.map((l) => _LoanCard(loan: l, onTap: null, onViewHistory: () => _openLoanHistory(l), showChevron: true)),
    ];
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _LPColors.border), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: color, size: 17)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color))),
                  Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: _LPColors.sub), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.count, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _LPColors.green : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1.1, color: active ? Colors.white : const Color(0xFF888888)),
              ),
              const SizedBox(height: 2),
              Text('$count', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: active ? Colors.white.withOpacity(0.85) : const Color(0xFFAAAAAA))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ViewToggle({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: active ? _LPColors.green : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? _LPColors.green : _LPColors.border)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: active ? Colors.white : const Color(0xFF888888)),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF888888))),
          ],
        ),
      ),
    );
  }
}

class _LoanCard extends StatelessWidget {
  final dynamic loan;
  final VoidCallback? onTap;
  final VoidCallback onViewHistory;
  final bool showChevron;
  const _LoanCard({required this.loan, required this.onTap, required this.onViewHistory, this.showChevron = false});

  @override
  Widget build(BuildContext context) {
    final status = (loan['status'] ?? '').toString();
    final balance = double.tryParse('${loan['balance'] ?? 0}') ?? 0;
    final isPaid = status == 'Completed' || balance == 0;
    final color = isPaid ? _LPColors.blue : (status == 'Overdue' ? _LPColors.red : _LPColors.green);
    final bg = isPaid ? const Color(0xFFE3F2FD) : (status == 'Overdue' ? const Color(0xFFFCE4EC) : const Color(0xFFE8F5E9));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap ?? onViewHistory,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${loan['loan_id'] ?? ''}', style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: _LPColors.title)),
                        Text('${loan['member_name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        Text('${loan['member_code'] ?? ''} · ${loan['loan_type'] ?? ''}', style: const TextStyle(fontSize: 10, color: _LPColors.sub)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
                    child: Text(isPaid ? 'Completed' : status, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _MiniStat('Amount', '₱${(double.tryParse('${loan['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', const Color(0xFF333333))),
                  Expanded(child: _MiniStat('Balance', isPaid ? '₱0 ✓' : '₱${balance.toStringAsFixed(0)}', isPaid ? _LPColors.green : _LPColors.red)),
                  Expanded(child: _MiniStat('Monthly', '₱${(double.tryParse('${loan['monthly_due'] ?? 0}') ?? 0).toStringAsFixed(0)}', _LPColors.green)),
                  IconButton(
                    onPressed: onViewHistory,
                    icon: Icon(showChevron ? Icons.chevron_right : Icons.history, size: 17, color: _LPColors.blue),
                    tooltip: 'Payment history',
                    visualDensity: VisualDensity.compact,
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8.5, color: Color(0xFF999999))),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _TxCard extends StatelessWidget {
  final dynamic tx;
  final VoidCallback onTap;
  const _TxCard({required this.tx, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${tx['tx_id'] ?? ''}', style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: _LPColors.title, fontWeight: FontWeight.w700)),
                    Text('${tx['member_name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Text('${tx['loan_code'] ?? ''} · ${'${tx['paid_at'] ?? ''}'.split('T').first}', style: const TextStyle(fontSize: 10, color: _LPColors.sub)),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₱${(double.tryParse('${tx['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: _LPColors.green, fontSize: 13)),
                Text('Bal: ₱${(double.tryParse('${tx['balance'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: _LPColors.blue)),
              ]),
              const Icon(Icons.chevron_right, size: 16, color: _LPColors.sub),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DailyGroupCard extends StatefulWidget {
  final String dateLabel;
  final String dateStr;
  final List<dynamic> txList;
  final void Function(dynamic tx) onViewTx;
  const _DailyGroupCard({required this.dateLabel, required this.dateStr, required this.txList, required this.onViewTx});

  @override
  State<_DailyGroupCard> createState() => _DailyGroupCardState();
}

class _DailyGroupCardState extends State<_DailyGroupCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final total = widget.txList.fold<double>(0, (s, t) => s + (double.tryParse('${t['amount'] ?? 0}') ?? 0));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.vertical(top: const Radius.circular(10), bottom: _expanded ? Radius.zero : const Radius.circular(10))),
              child: Row(children: [
                Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16, color: _LPColors.green),
                const SizedBox(width: 6),
                Expanded(child: Text(widget.dateLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _LPColors.title))),
                Text('${widget.txList.length} tx', style: const TextStyle(fontSize: 10, color: _LPColors.sub)),
                const SizedBox(width: 8),
                Text('₱${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _LPColors.green)),
              ]),
            ),
          ),
          if (_expanded)
            ...widget.txList.map((tx) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: InkWell(
                    onTap: () => widget.onViewTx(tx),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${tx['tx_id'] ?? ''}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: _LPColors.sub)),
                            Text('${tx['member_name'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Text('₱${(double.tryParse('${tx['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: _LPColors.green, fontSize: 12)),
                    ]),
                  ),
                )),
        ],
      ),
    );
  }
}