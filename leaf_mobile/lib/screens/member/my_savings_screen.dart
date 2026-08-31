import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/members_service.dart';
import '../../widgets/member_scaffold_helpers.dart';
import '../../utils/page_cache.dart';

class _SVColors {
  static const dark   = Color(0xFF1B5E20);
  static const green  = Color(0xFF2E7D32);
  static const sub    = Color(0xFF888888);
  static const red    = Color(0xFFC62828);
  static const border = Color(0xFFE8F5E9);
}

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

class MySavingsScreen extends StatefulWidget {
  const MySavingsScreen({super.key});

  @override
  State<MySavingsScreen> createState() => _MySavingsScreenState();
}

class _MySavingsScreenState extends State<MySavingsScreen> {
  bool _loading = true;
  bool _error = false;
  double _balance = 0;
  List<dynamic> _transactions = [];
  String _filter = 'All'; // All | Deposit | Withdrawal
  // ── BAGO: scope key para sa CACHE lang — gamit ang username mula
  // sa AuthProvider (available na agad, hindi async). Si member.id
  // (mula sa MemberProvider) ay ginagamit pa rin para sa aktwal na
  // API call, dahil kailangan talaga 'yon ng backend endpoint. ─────
  String? _scopeKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      _scopeKey = auth.username ?? auth.name;
      // ── BAGO: cache-first — instant na ipinapakita ang huling
      // nakitang balance/transactions habang tahimik na nagre-
      // refresh sa likod. ─────────────────────────────────────────
      final cached = PageCache.get<Map<String, dynamic>>('savings', _scopeKey);
      if (cached != null && mounted) {
        setState(() {
          _balance = cached['balance'] as double? ?? 0;
          _transactions = cached['transactions'] as List<dynamic>? ?? [];
          _loading = false;
        });
      }
      _load();
    });
  }

  Future<void> _load() async {
    final memberProv = context.read<MemberProvider>();
    // ── FIX: kung hindi pa tapos mag-load ang MemberProvider,
    // hintayin muna 'to — para siguradong may myId na tayo bago
    // mag-early-return (dating puwedeng ma-stuck sa loading spinner
    // magpakailanman kung na-null pa ang myId sa unang tawag). ─────
    if (memberProv.loading) await memberProv.load();
    if (!mounted) return;
    final myId = context.read<MemberProvider>().profile?['id'];
    if (myId == null) {
      if (mounted) setState(() { _loading = false; _error = true; });
      return;
    }
    // ── Huwag pilitin ang loading spinner kung may cache na tayong
    // ipinapakita — tahimik na lang mag-refresh sa likod. ───────────
    if (PageCache.get('savings', _scopeKey) == null && mounted) {
      setState(() { _loading = true; _error = false; });
    } else if (mounted) {
      setState(() => _error = false);
    }
    try {
      final data = await MembersService.getMemberSavings('$myId');
      if (mounted) {
        final newBalance = double.tryParse('${data['balance'] ?? data['savings_balance'] ?? 0}') ?? 0;
        final newTx = (data['transactions'] as List?) ?? [];
        setState(() {
          _balance = newBalance;
          _transactions = newTx;
          _loading = false;
        });
        PageCache.set('savings', _scopeKey, {'balance': newBalance, 'transactions': newTx});
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  List<dynamic> get _filtered {
    if (_filter == 'All') return _transactions;
    return _transactions.where((t) => '${t['transaction_type'] ?? ''}' == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalDeposits = _transactions.where((t) => t['transaction_type'] == 'Deposit').fold<double>(0, (s, t) => s + (double.tryParse('${t['amount'] ?? 0}') ?? 0));
    final totalWithdrawals = _transactions.where((t) => t['transaction_type'] == 'Withdrawal').fold<double>(0, (s, t) => s + (double.tryParse('${t['amount'] ?? 0}') ?? 0));
    final filtered = _filtered;

    return MemberScreenScaffold(
      activeRouteKey: 'savings',
      body: RefreshIndicator(
        onRefresh: _load,
        color: _SVColors.green,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _SVColors.green))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('My Savings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _SVColors.dark)),
                    const SizedBox(height: 2),
                    const Text('Track your savings deposits and withdrawals.', style: TextStyle(fontSize: 11, color: _SVColors.sub)),
                    const SizedBox(height: 14),

                    if (_error)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFE082))),
                        child: const Text('Hindi makuha ang savings data. Maaaring hindi pinapayagan ang member accounts na tumingin dito, o wala pang savings record. Subukan mo ulit mamaya, o tanungin yung admin.', style: TextStyle(fontSize: 12, color: Color(0xFFF57F17))),
                      )
                    else ...[
                      // Balance card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_SVColors.dark, _SVColors.green, Color(0xFF388E3C)], stops: [0.0, 0.6, 1.0], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.savings_outlined, color: Colors.white70, size: 16),
                              SizedBox(width: 6),
                              Text('CURRENT SAVINGS BALANCE', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            ]),
                            const SizedBox(height: 8),
                            Text(_peso(_balance), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(children: [
                        Expanded(child: _StatBox(label: 'Total Deposits', value: _peso(totalDeposits), color: _SVColors.green, icon: Icons.arrow_downward)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatBox(label: 'Total Withdrawals', value: _peso(totalWithdrawals), color: _SVColors.red, icon: Icons.arrow_upward)),
                        const SizedBox(width: 8),
                        Expanded(child: _StatBox(label: 'Transactions', value: '${_transactions.length}', color: const Color(0xFF1565C0), icon: Icons.receipt_long_outlined)),
                      ]),
                      const SizedBox(height: 14),

                      Wrap(spacing: 6, children: ['All', 'Deposit', 'Withdrawal'].map((f) {
                        final active = _filter == f;
                        return ChoiceChip(
                          label: Text(f, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF888888))),
                          selected: active,
                          selectedColor: _SVColors.green,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: active ? _SVColors.green : const Color(0xFFDDDDDD)),
                          onSelected: (_) => setState(() => _filter = f),
                        );
                      }).toList()),
                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _SVColors.border)),
                        child: filtered.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(child: Text('No savings transactions yet.', style: TextStyle(color: _SVColors.sub, fontStyle: FontStyle.italic))),
                              )
                            : Column(
                                children: filtered.map((tx) {
                                  final isDeposit = tx['transaction_type'] == 'Deposit';
                                  final amt = double.tryParse('${tx['amount'] ?? 0}') ?? 0;
                                  final isLast = tx == filtered.last;
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : const Color(0xFFF5F5F5)))),
                                    child: Row(children: [
                                      Container(
                                        width: 36, height: 36,
                                        decoration: BoxDecoration(color: isDeposit ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10)),
                                        child: Icon(isDeposit ? Icons.arrow_downward : Icons.arrow_upward, size: 16, color: isDeposit ? _SVColors.green : _SVColors.red),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${tx['transaction_type'] ?? ''}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                            Text('${tx['created_at'] ?? ''}'.split('T').first, style: const TextStyle(fontSize: 10, color: _SVColors.sub)),
                                            if (tx['note'] != null && '${tx['note']}'.isNotEmpty) Text('${tx['note']}', style: const TextStyle(fontSize: 10, color: _SVColors.sub)),
                                          ],
                                        ),
                                      ),
                                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                        Text('${isDeposit ? '+' : '−'}${_peso(amt)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDeposit ? _SVColors.green : _SVColors.red)),
                                        Text('Bal: ${_peso(double.tryParse('${tx['balance_after'] ?? 0}') ?? 0)}', style: const TextStyle(fontSize: 9.5, color: _SVColors.sub)),
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
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatBox({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _SVColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(height: 6),
        FittedBox(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color))),
        Text(label, style: const TextStyle(fontSize: 8.5, color: _SVColors.sub, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}