import 'package:flutter/material.dart';
import '../../services/members_service.dart';

class _FinColors {
  static const green  = Color(0xFF2E7D32);
  static const blue   = Color(0xFF1565C0);
  static const purple = Color(0xFF6A1B9A);
  static const orange = Color(0xFFE65100);
  static const sub    = Color(0xFF888888);
}

class FinancialSummaryTab extends StatefulWidget {
  final int memberId;
  const FinancialSummaryTab({super.key, required this.memberId});

  @override
  State<FinancialSummaryTab> createState() => _FinancialSummaryTabState();
}

class _FinancialSummaryTabState extends State<FinancialSummaryTab> {
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _savings;
  bool _loading = true;
  String _historyTab = 'savings'; // savings | sharecap | loans
  int? _expandedLoanId;
  List<dynamic> _scHistory = [];
  bool _scLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        MembersService.getMemberFinancialSummary(widget.memberId),
        MembersService.getMemberSavings('${widget.memberId}'),
      ]);
      if (mounted) {
        setState(() {
          _summary = results[0] as Map<String, dynamic>;
          _savings = results[1] as Map<String, dynamic>;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadShareCapHistory() async {
    setState(() => _scLoading = true);
    try {
      final data = await MembersService.getShareCapitalHistory(widget.memberId);
      if (mounted) setState(() => _scHistory = data);
    } catch (_) {
      if (mounted) setState(() => _scHistory = []);
    } finally {
      if (mounted) setState(() => _scLoading = false);
    }
  }

  void _switchTab(String tab) {
    setState(() => _historyTab = tab);
    if (tab == 'sharecap' && _scHistory.isEmpty) _loadShareCapHistory();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: _FinColors.green)),
      );
    }
    if (_summary == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('Unable to load financial data.', style: TextStyle(color: _FinColors.sub))),
      );
    }

    final shareCapital = double.tryParse('${_summary!['share_capital'] ?? 0}') ?? 0;
    final activeLoans = _summary!['active_loans'] ?? 0;
    final totalLoans = _summary!['total_loans'] ?? 0;
    final totalPaid = double.tryParse('${_summary!['total_paid'] ?? 0}') ?? 0;
    final totalBalance = double.tryParse('${_summary!['total_balance'] ?? 0}') ?? 0;
    final savingsBalance = double.tryParse('${_savings?['balance'] ?? 0}') ?? 0;
    final totalDeposit = double.tryParse('${_savings?['total_deposit'] ?? 0}') ?? 0;
    final totalWithdraw = double.tryParse('${_savings?['total_withdraw'] ?? 0}') ?? 0;
    final savingsTx = (_savings?['transactions'] as List?) ?? [];
    final loans = (_summary!['loans'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Financial Overview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.5)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.5,
          children: [
            _FinStatBox(icon: Icons.savings_outlined, label: 'Share Capital', value: '₱${shareCapital.toStringAsFixed(0)}', sub: 'Max Loanable: ₱${shareCapital.toStringAsFixed(0)}', color: _FinColors.green, bg: const Color(0xFFE8F5E9)),
            _FinStatBox(icon: Icons.assignment_outlined, label: 'Active Loans', value: '$activeLoans', sub: 'Total: $totalLoans loan${totalLoans != 1 ? "s" : ""}', color: _FinColors.blue, bg: const Color(0xFFE3F2FD)),
            _FinStatBox(icon: Icons.credit_card, label: 'Total Paid', value: '₱${totalPaid.toStringAsFixed(0)}', sub: 'Remaining: ₱${totalBalance.toStringAsFixed(0)}', color: _FinColors.purple, bg: const Color(0xFFF3E5F5)),
            _FinStatBox(icon: Icons.account_balance_outlined, label: 'Savings Balance', value: '₱${savingsBalance.toStringAsFixed(0)}', sub: '↑₱${totalDeposit.toStringAsFixed(0)} · ↓₱${totalWithdraw.toStringAsFixed(0)}', color: _FinColors.orange, bg: const Color(0xFFFFF8E1)),
          ],
        ),
        const SizedBox(height: 12),

        // ── Sub-tabs ──────────────────────────────────────────────────
        Row(
          children: [
            _SubTabButton(label: 'Savings', count: savingsTx.length, active: _historyTab == 'savings', color: _FinColors.orange, onTap: () => _switchTab('savings')),
            _SubTabButton(label: 'Share Cap.', count: _scHistory.length, active: _historyTab == 'sharecap', color: _FinColors.blue, onTap: () => _switchTab('sharecap')),
            _SubTabButton(label: 'Loans', count: loans.length, active: _historyTab == 'loans', color: _FinColors.green, onTap: () => _switchTab('loans')),
          ],
        ),
        const SizedBox(height: 10),

        if (_historyTab == 'savings') _buildSavingsHistory(savingsTx),
        if (_historyTab == 'sharecap') _buildShareCapHistory(),
        if (_historyTab == 'loans') _buildLoansHistory(loans),
      ],
    );
  }

  Widget _buildSavingsHistory(List savingsTx) {
    if (savingsTx.isEmpty) {
      return _emptyBox('No savings transactions yet.', const Color(0xFFFFFDE7), const Color(0xFFFFE082));
    }
    return Column(
      children: savingsTx.map<Widget>((tx) {
        final isDeposit = tx['transaction_type'] == 'Deposit';
        return _TxRow(
          date: '${tx['created_at'] ?? ''}'.split('T').first,
          typeLabel: tx['transaction_type'] ?? '',
          typeColor: isDeposit ? _FinColors.green : const Color(0xFFC62828),
          amount: double.tryParse('${tx['amount'] ?? 0}') ?? 0,
          isPositive: isDeposit,
          balanceAfter: double.tryParse('${tx['balance_after'] ?? 0}') ?? 0,
          note: tx['note'],
        );
      }).toList(),
    );
  }

  Widget _buildShareCapHistory() {
    if (_scLoading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_scHistory.isEmpty) {
      return _emptyBox('No share capital transactions yet.', const Color(0x11E3F2FD), const Color(0xFF90CAF9));
    }
    return Column(
      children: _scHistory.map<Widget>((t) {
        return _TxRow(
          date: '${t['created_at'] ?? ''}',
          typeLabel: t['txn_type'] ?? 'Deposit',
          typeColor: _FinColors.blue,
          amount: double.tryParse('${t['amount'] ?? 0}') ?? 0,
          isPositive: true,
          balanceAfter: double.tryParse('${t['balance_after'] ?? 0}') ?? 0,
          note: t['note'],
          extra: t['recorded_by'] != null ? 'By: ${t['recorded_by']}' : null,
        );
      }).toList(),
    );
  }

  Widget _buildLoansHistory(List loans) {
    if (loans.isEmpty) {
      return _emptyBox('No loans found for this member.', const Color(0xFFFAFAFA), const Color(0xFFEEEEEE));
    }
    const statusColor = {
      'Active': _FinColors.green, 'Overdue': Color(0xFFC62828), 'Completed': _FinColors.blue,
      'For Review': _FinColors.orange, 'Approved': Color(0xFF558B2F), 'Declined': Color(0xFF757575),
    };
    return Column(
      children: loans.map<Widget>((loan) {
        final loanId = loan['loan_id'];
        final isExpanded = _expandedLoanId == loanId.hashCode;
        final balance = double.tryParse('${loan['balance'] ?? 0}') ?? 0;
        final isPaid = balance == 0 || loan['status'] == 'Completed';
        final sColor = isPaid ? _FinColors.blue : (statusColor[loan['status']] ?? const Color(0xFF757575));
        final payments = (loan['payments'] as List?) ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(color: isExpanded ? const Color(0xFFA5D6A7) : const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _expandedLoanId = isExpanded ? null : loanId.hashCode),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  color: isExpanded ? const Color(0xFFF1F8E9) : Colors.transparent,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$loanId', style: const TextStyle(fontFamily: 'monospace', color: _FinColors.green, fontWeight: FontWeight.w700, fontSize: 11.5)),
                            Text('${loan['loan_type'] ?? ''}', style: const TextStyle(fontSize: 9.5, color: _FinColors.sub)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text('₱${(double.tryParse('${loan['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                      Expanded(
                        child: Text(
                          isPaid ? '₱0 ✓' : '₱${balance.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isPaid ? _FinColors.green : const Color(0xFFC62828)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: sColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: sColor.withOpacity(0.3))),
                        child: Text(isPaid ? 'Paid' : '${loan['status'] ?? ''}', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: sColor)),
                      ),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: const Color(0xFFBBBBBB)),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Color(0xFFF9FEF9), border: Border(top: BorderSide(color: Color(0xFFE8F5E9)))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment History (${payments.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _FinColors.green)),
                      const SizedBox(height: 8),
                      if (payments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No payments recorded yet.', style: TextStyle(fontSize: 11, color: _FinColors.sub)),
                        )
                      else
                        ...payments.map<Widget>((p) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${p['paid_at'] ?? ''}', style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                                        Text('${p['tx_id'] ?? ''}', style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: _FinColors.green)),
                                      ],
                                    ),
                                  ),
                                  Text('₱${(double.tryParse('${p['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _FinColors.green)),
                                ],
                              ),
                            )),
                      const Divider(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text('Monthly Due: ₱${(double.tryParse('${loan['monthly_due'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, color: _FinColors.sub)),
                          Text(isPaid ? 'Remaining: ₱0 — Fully Paid ✓' : 'Remaining: ₱${balance.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 10.5, color: isPaid ? _FinColors.blue : const Color(0xFFC62828), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _emptyBox(String text, Color bg, Color border) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: border)),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
    );
  }
}

class _FinStatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;
  final Color bg;
  const _FinStatBox({required this.icon, required this.label, required this.value, required this.sub, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [Icon(icon, size: 13, color: color), const SizedBox(width: 4), Expanded(child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color), overflow: TextOverflow.ellipsis))]),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color))),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 8.5, color: Color(0xFF999999)), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _SubTabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _SubTabButton({required this.label, required this.count, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? color : Colors.transparent, width: 2))),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: active ? color : const Color(0xFFAAAAAA))),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: active ? color : const Color(0xFFAAAAAA))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final String date;
  final String typeLabel;
  final Color typeColor;
  final double amount;
  final bool isPositive;
  final double balanceAfter;
  final String? note;
  final String? extra;
  const _TxRow({
    required this.date, required this.typeLabel, required this.typeColor,
    required this.amount, required this.isPositive, required this.balanceAfter,
    this.note, this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(typeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: typeColor)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: const TextStyle(fontSize: 9.5, color: Color(0xFF888888))),
                if (note != null && note!.isNotEmpty) Text(note!, style: const TextStyle(fontSize: 9.5, color: Color(0xFFAAAAAA))),
                if (extra != null) Text(extra!, style: const TextStyle(fontSize: 9, color: Color(0xFFAAAAAA))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isPositive ? "+" : "−"}₱${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isPositive ? _FinColors.green : const Color(0xFFC62828))),
              Text('Bal: ₱${balanceAfter.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, color: Color(0xFFAAAAAA))),
            ],
          ),
        ],
      ),
    );
  }
}