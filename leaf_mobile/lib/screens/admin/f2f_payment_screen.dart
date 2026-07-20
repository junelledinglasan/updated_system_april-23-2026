import 'package:flutter/material.dart';
import '../../services/loans_service.dart';
import '../../services/payments_service.dart';

class _FPColors {
  static const title = Color(0xFF1B5E20);
  static const sub   = Color(0xFF888888);
  static const green = Color(0xFF2E7D32);
  static const blue  = Color(0xFF1565C0);
  static const red   = Color(0xFFC62828);
}

class F2fPaymentScreen extends StatefulWidget {
  const F2fPaymentScreen({super.key});

  @override
  State<F2fPaymentScreen> createState() => _F2fPaymentScreenState();
}

class _F2fPaymentScreenState extends State<F2fPaymentScreen> {
  int _step = 1;
  List<dynamic> _loans = [];
  bool _fetching = true;
  String _search = '';
  dynamic _selected;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _error;
  bool _saving = false;
  bool _done = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLoans() async {
    try {
      final data = await LoansService.getLoans(status: 'Active');
      if (mounted) setState(() => _loans = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  List<dynamic> get _filtered => _loans.where((l) {
        final q = _search.toLowerCase();
        return '${l['member_name'] ?? ''}'.toLowerCase().contains(q) ||
            '${l['member_code'] ?? ''}'.toLowerCase().contains(q) ||
            '${l['loan_id'] ?? ''}'.toLowerCase().contains(q);
      }).toList();

  double get _balance => double.tryParse('${_selected?['balance'] ?? 0}') ?? 0;
  double get _parsed => double.tryParse(_amountCtrl.text) ?? 0;
  bool get _isValid => _parsed > 0 && _selected != null && _parsed <= _balance;

  void _selectLoan(dynamic l) {
    setState(() {
      _selected = l;
      _amountCtrl.text = '${l['monthly_due'] ?? ''}';
      _error = null;
    });
  }

  Future<void> _handlePay() async {
    if (_parsed <= 0) { setState(() => _error = 'Enter a valid amount.'); return; }
    if (_parsed > _balance) { setState(() => _error = 'Exceeds remaining balance ₱${_balance.toStringAsFixed(0)}.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final payment = await PaymentsService.recordPayment({
        'loan': _selected['id'],
        'member': _selected['member'],
        'amount': _parsed,
        'note': _noteCtrl.text,
      });
      if (mounted) setState(() { _done = true; _result = payment; });
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to record payment. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD8E8CC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _FPColors.title,
        elevation: 0.5,
        title: const Text('New F2F Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _FPColors.title)),
      ),
      body: _done ? _buildDone() : (_step == 1 ? _buildStep1() : _buildStep2()),
    );
  }

  Widget _buildDone() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 44, color: _FPColors.green),
          const SizedBox(height: 10),
          const Text('Payment Recorded!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _FPColors.title)),
          const SizedBox(height: 8),
          Text('₱${_parsed.toStringAsFixed(0)} payment for ${_selected['member_name']} has been saved.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: _FPColors.sub)),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _FPColors.blue, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, _result),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Align(alignment: Alignment.centerLeft, child: Text('Select the member\'s active loan to record payment for.', style: TextStyle(fontSize: 11.5, color: _FPColors.sub))),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(hintText: 'Search by name, member ID, loan ID...', prefixIcon: const Icon(Icons.search, size: 18), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ],
          ),
        ),
        Expanded(
          child: _fetching
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? const Center(child: Text('No active loans found.', style: TextStyle(color: _FPColors.sub)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        final l = _filtered[i];
                        final isSel = _selected != null && _selected['id'] == l['id'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: isSel ? _FPColors.blue.withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => _selectLoan(l),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isSel ? _FPColors.blue : const Color(0xFFE8EAE0), width: isSel ? 1.5 : 1),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
                                ),
                                child: Row(children: [
                                  CircleAvatar(radius: 20, backgroundColor: isSel ? _FPColors.blue : _FPColors.blue.withOpacity(0.15), child: Text('${l['member_name'] ?? 'M'}'.isNotEmpty ? '${l['member_name']}'[0].toUpperCase() : 'M', style: TextStyle(color: isSel ? Colors.white : _FPColors.blue, fontWeight: FontWeight.w800))),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${l['member_name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text('${l['member_code']} · ${l['loan_id']}', style: TextStyle(fontSize: 10.5, color: _FPColors.blue, fontWeight: FontWeight.w600))])),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('₱${(double.tryParse('${l['balance'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), const Text('balance', style: TextStyle(fontSize: 8.5, color: Color(0xFFAAAAAA)))]),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _FPColors.blue, foregroundColor: Colors.white), onPressed: _selected != null ? () => setState(() => _step = 2) : null, child: const Text('Next →'))),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4F0E5))),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: _FPColors.blue, child: Text('${_selected['member_name'] ?? 'M'}'.isNotEmpty ? '${_selected['member_name']}'[0].toUpperCase() : 'M', style: const TextStyle(color: Colors.white))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${_selected['member_name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text('${_selected['member_code']} · ${_selected['loan_id']} · Balance: ₱${_balance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: _FPColors.sub))])),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text('Payment Amount (₱) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _FPColors.sub)),
                const SizedBox(height: 6),
                TextField(controller: _amountCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() => _error = null), decoration: InputDecoration(prefixText: '₱ ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                const SizedBox(height: 8),
                Wrap(spacing: 6, children: [
                  ActionChip(label: Text('Monthly ₱${(double.tryParse('${_selected['monthly_due'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, color: _FPColors.green)), backgroundColor: const Color(0xFFF0F8F0), onPressed: () => setState(() { _amountCtrl.text = '${_selected['monthly_due'] ?? 0}'; _error = null; })),
                  ActionChip(label: Text('Full ₱${_balance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, color: _FPColors.green)), backgroundColor: const Color(0xFFF0F8F0), onPressed: () => setState(() { _amountCtrl.text = _balance.toStringAsFixed(0); _error = null; })),
                ]),
                const SizedBox(height: 14),
                const Text('Note (optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _FPColors.sub)),
                const SizedBox(height: 6),
                TextField(controller: _noteCtrl, maxLength: 80, decoration: InputDecoration(hintText: 'e.g. Partial payment, advance...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                if (_error != null) Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: const TextStyle(color: _FPColors.red, fontSize: 12))),
                if (_isValid) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4F0E5))),
                    child: Column(children: [
                      _PrevRow('Current balance', '₱${_balance.toStringAsFixed(0)}'),
                      _PrevRow('Payment', '− ₱${_parsed.toStringAsFixed(0)}', color: _FPColors.red),
                      const Divider(),
                      _PrevRow('New balance', (_balance - _parsed) == 0 ? '₱0 — FULLY PAID 🎉' : '₱${(_balance - _parsed).toStringAsFixed(0)}', bold: true),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), child: const Text('← Back'))),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _FPColors.green, foregroundColor: Colors.white),
                  onPressed: (!_isValid || _saving) ? null : _handlePay,
                  child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Payment Record'),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _PrevRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _PrevRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: bold ? 13 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? _FPColors.title : const Color(0xFF555555))),
        Text(value, style: TextStyle(fontSize: bold ? 13 : 12, fontWeight: FontWeight.w700, color: color ?? const Color(0xFF333333))),
      ]),
    );
  }
}