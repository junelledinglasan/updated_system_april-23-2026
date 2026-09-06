import 'package:flutter/material.dart';
import '../../services/payments_service.dart';

class _RPColors {
  static const title = Color(0xFF1B5E20);
  static const sub   = Color(0xFF888888);
  static const green = Color(0xFF2E7D32);
  static const red   = Color(0xFFC62828);
}

class RecordPaymentScreen extends StatefulWidget {
  final dynamic loan;
  const RecordPaymentScreen({super.key, required this.loan});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  late final TextEditingController _amountCtrl;
  final _noteCtrl = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: '${widget.loan['monthly_due'] ?? ''}');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _balance => double.tryParse('${widget.loan['balance'] ?? 0}') ?? 0;
  double get _parsed => double.tryParse(_amountCtrl.text) ?? 0;
  double get _newBalance => _balance - _parsed;
  bool get _isValid => _parsed > 0 && _parsed <= _balance;

  Future<void> _submit() async {
    if (_parsed <= 0) { setState(() => _error = 'Please enter a valid amount.'); return; }
    if (_parsed > _balance) { setState(() => _error = 'Exceeds remaining balance of ₱${_balance.toStringAsFixed(0)}.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final payment = await PaymentsService.recordPayment({
        'loan': widget.loan['id'],
        'member': widget.loan['member'],
        'amount': _parsed,
        'note': _noteCtrl.text,
      });
      final normalized = {
        ...payment,
        'member_name': payment['member_name'] ?? widget.loan['member_name'] ?? '',
        'member_code': payment['member_code'] ?? widget.loan['member_code'] ?? '',
        'loan_code': payment['loan_code'] ?? widget.loan['loan_id'] ?? '',
        'paid_at': payment['paid_at'] ?? DateTime.now().toIso8601String(),
        'balance': payment['balance'] ?? _newBalance,
        'amount': payment['amount'] ?? _parsed,
      };
      if (mounted) Navigator.pop(context, normalized);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to record payment. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final fullname = loan['member_name'] ?? loan['fullname'] ?? 'M';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _RPColors.title,
        elevation: 0.5,
        title: const Text('Record Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _RPColors.title)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('F2F — Office Collection', style: TextStyle(fontSize: 11, color: _RPColors.sub)),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4F0E5))),
              child: Row(children: [
                CircleAvatar(radius: 20, backgroundColor: const Color(0xFFE8F5E9), child: Text('$fullname'.isNotEmpty ? '$fullname'[0].toUpperCase() : 'M', style: const TextStyle(color: _RPColors.green, fontWeight: FontWeight.w700))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$fullname', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      Text('${loan['member_code'] ?? ''} · ${loan['loan_id'] ?? ''} · ${loan['loan_type'] ?? ''}', style: const TextStyle(fontSize: 10, color: _RPColors.sub, fontFamily: 'monospace')),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(child: _BalBox(label: 'Principal', value: '₱${(double.tryParse('${loan['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', color: const Color(0xFF333333))),
              const SizedBox(width: 6),
              Expanded(child: _BalBox(label: 'Balance', value: '₱${_balance.toStringAsFixed(0)}', color: _RPColors.red, highlight: true)),
              const SizedBox(width: 6),
              Expanded(child: _BalBox(label: 'Monthly Due', value: '₱${(double.tryParse('${loan['monthly_due'] ?? 0}') ?? 0).toStringAsFixed(0)}', color: _RPColors.green)),
              const SizedBox(width: 6),
              // ── BAGO: Term — kulang dati dito, tulad ng nakita sa
              // web (LoanPayment.jsx RecordModal) na kailangang idagdag. ──
              Expanded(child: _BalBox(label: 'Term', value: '${loan['term_months'] ?? '—'} months', color: const Color(0xFF333333))),
            ]),
            // ── BAGO: penalty breakdown — 2% ng Monthly Due kada
            // buwang naliban, naka-dagdag na sa Balance sa itaas.
            // Ipinapakita lang ito kapag may naipong penalty. ──────────
            if ((double.tryParse('${loan['total_penalty'] ?? 0}') ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFFCE4EC), border: Border.all(color: const Color(0xFFF8BBD0)), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFC62828)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Includes ₱${(double.tryParse('${loan['total_penalty']}') ?? 0).toStringAsFixed(0)} penalty (${loan['months_overdue_penalized'] ?? 0} month${(loan['months_overdue_penalized'] ?? 0) != 1 ? "s" : ""} overdue × 2% of Monthly Due)',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFC62828), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 16),

            const Text('Payment Amount (₱) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _RPColors.sub)),
            const SizedBox(height: 6),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(prefixText: '₱ ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _RPColors.title),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              ActionChip(
                label: Text('Monthly Due ₱${(double.tryParse('${loan['monthly_due'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, color: _RPColors.green, fontWeight: FontWeight.w600)),
                backgroundColor: const Color(0xFFF0F8F0),
                side: const BorderSide(color: Color(0xFFC8E6C9)),
                onPressed: () => setState(() { _amountCtrl.text = '${loan['monthly_due'] ?? 0}'; _error = null; }),
              ),
              ActionChip(
                label: Text('Full Balance ₱${_balance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, color: _RPColors.green, fontWeight: FontWeight.w600)),
                backgroundColor: const Color(0xFFF0F8F0),
                side: const BorderSide(color: Color(0xFFC8E6C9)),
                onPressed: () => setState(() { _amountCtrl.text = _balance.toStringAsFixed(0); _error = null; }),
              ),
            ]),
            const SizedBox(height: 14),

            const Text('Note (optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _RPColors.sub)),
            const SizedBox(height: 6),
            TextField(controller: _noteCtrl, maxLength: 80, decoration: InputDecoration(hintText: 'e.g. Partial payment, advance payment...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),

            if (_error != null) ...[
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: const TextStyle(color: _RPColors.red, fontSize: 12))),
            ],

            if (_isValid) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4F0E5))),
                child: Column(children: [
                  _PrevRow('Current balance', '₱${_balance.toStringAsFixed(0)}'),
                  _PrevRow('Payment', '− ₱${_parsed.toStringAsFixed(0)}', color: _RPColors.red),
                  const Divider(),
                  _PrevRow('New balance', _newBalance == 0 ? '₱0 — FULLY PAID' : '₱${_newBalance.toStringAsFixed(0)}', bold: true, color: _newBalance == 0 ? _RPColors.green : _RPColors.title, icon: _newBalance == 0 ? Icons.celebration : null),
                ]),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _RPColors.green, foregroundColor: Colors.white),
                onPressed: (!_isValid || _loading) ? null : _submit,
                child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Payment Record'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BalBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;
  const _BalBox({required this.label, required this.value, required this.color, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(color: highlight ? const Color(0xFFFFF5F5) : const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(8), border: Border.all(color: highlight ? const Color(0xFFFFCDD2) : const Color(0xFFF0F0F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFFBBBBBB))),
          const SizedBox(height: 3),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color))),
        ],
      ),
    );
  }
}

class _PrevRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  final IconData? icon;
  const _PrevRow(this.label, this.value, {this.bold = false, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: bold ? 13 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? (color ?? _RPColors.title) : const Color(0xFF555555))),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: TextStyle(fontSize: bold ? 13 : 12, fontWeight: FontWeight.w700, color: color ?? const Color(0xFF333333))),
          if (icon != null) ...[const SizedBox(width: 5), Icon(icon, size: 15, color: color)],
        ]),
      ]),
    );
  }
}