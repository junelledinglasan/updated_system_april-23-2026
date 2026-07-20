import 'package:flutter/material.dart';
import '../../services/members_service.dart';
import '../../widgets/member_scaffold_helpers.dart';

class _SCColors {
  static const dark   = Color(0xFF1B5E20);
  static const green  = Color(0xFF2E7D32);
  static const sub    = Color(0xFFAAAAAA);
  static const border = Color(0xFFE4F0E5);
}

String _peso(num v) {
  final fixed = v.toStringAsFixed(0);
  final digits = fixed.replaceAll('-', '');
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '₱$buf';
}

class ShareCapitalHistoryScreen extends StatefulWidget {
  final int memberId;
  final double currentShareCapital;
  const ShareCapitalHistoryScreen({super.key, required this.memberId, required this.currentShareCapital});

  @override
  State<ShareCapitalHistoryScreen> createState() => _ShareCapitalHistoryScreenState();
}

class _ShareCapitalHistoryScreenState extends State<ShareCapitalHistoryScreen> {
  bool _loading = true;
  bool _error = false;
  List<dynamic> _txns = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final data = await MembersService.getShareCapitalHistory(widget.memberId);
      if (mounted) setState(() { _txns = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDeposits = _txns.where((t) => t['txn_type'] == 'Deposit').fold<double>(0, (s, t) => s + (double.tryParse('${t['amount'] ?? 0}') ?? 0));

    return MemberScreenScaffold(
      activeRouteKey: 'profile',
      body: RefreshIndicator(
        onRefresh: _load,
        color: _SCColors.green,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _SCColors.green))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: _SCColors.dark), onPressed: () => Navigator.pop(context)),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Share Capital History', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _SCColors.dark)),
                            Text('Track your share capital deposits over time.', style: TextStyle(fontSize: 10.5, color: _SCColors.sub)),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),

                    if (_error)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFE082))),
                        child: const Text('Hindi makuha ang share capital history. Subukan ulit mamaya, o tanungin ang admin.', style: TextStyle(fontSize: 12, color: Color(0xFFF57F17))),
                      )
                    else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_SCColors.dark, _SCColors.green, Color(0xFF388E3C)], stops: [0.0, 0.6, 1.0], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(children: [
                          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.savings_outlined, color: Colors.white70, size: 16),
                            SizedBox(width: 6),
                            Text('CURRENT SHARE CAPITAL', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          ]),
                          const SizedBox(height: 8),
                          Text(_peso(widget.currentShareCapital), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Max loanable: ${_peso(widget.currentShareCapital * 2)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ]),
                      ),
                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(child: _StatBox(label: 'Total Deposits', value: _peso(totalDeposits), color: _SCColors.green, icon: Icons.arrow_downward)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatBox(label: 'Transactions', value: '${_txns.length}', color: const Color(0xFF1565C0), icon: Icons.receipt_long_outlined)),
                      ]),
                      const SizedBox(height: 14),

                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _SCColors.border)),
                        child: _txns.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(child: Text('No share capital transactions yet.', style: TextStyle(color: _SCColors.sub, fontStyle: FontStyle.italic))),
                              )
                            : Column(
                                children: _txns.map((t) {
                                  final amt = double.tryParse('${t['amount'] ?? 0}') ?? 0;
                                  final isLast = t == _txns.last;
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : const Color(0xFFF5F5F5)))),
                                    child: Row(children: [
                                      Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_downward, size: 16, color: _SCColors.green)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${t['txn_type'] ?? 'Deposit'}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                            Text('${t['created_at'] ?? ''}', style: const TextStyle(fontSize: 10, color: _SCColors.sub)),
                                            if (t['note'] != null && '${t['note']}'.isNotEmpty) Text('${t['note']}', style: const TextStyle(fontSize: 10, color: _SCColors.sub)),
                                            if (t['recorded_by'] != null) Text('Recorded by: ${t['recorded_by']}', style: const TextStyle(fontSize: 9.5, color: Color(0xFFCCCCCC))),
                                          ],
                                        ),
                                      ),
                                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                        Text('+${_peso(amt)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _SCColors.green)),
                                        Text('Bal: ${_peso(double.tryParse('${t['balance_after'] ?? 0}') ?? 0)}', style: const TextStyle(fontSize: 9.5, color: _SCColors.sub)),
                                      ]),
                                    ]),
                                  );
                                }).toList(),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _StatBox({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _SCColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(height: 6),
        FittedBox(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color))),
        Text(label, style: const TextStyle(fontSize: 9, color: _SCColors.sub, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}