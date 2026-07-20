import 'package:flutter/material.dart';

class _LHColors {
  static const title = Color(0xFF1B5E20);
  static const sub   = Color(0xFF888888);
  static const green = Color(0xFF2E7D32);
  static const blue  = Color(0xFF1565C0);
  static const red   = Color(0xFFC62828);
}

class LoanPaymentHistoryScreen extends StatelessWidget {
  final dynamic loan;
  final List<dynamic> payments;
  const LoanPaymentHistoryScreen({super.key, required this.loan, required this.payments});

  @override
  Widget build(BuildContext context) {
    final balance = double.tryParse('${loan['balance'] ?? 0}') ?? 0;
    final totalPaid = payments.fold<double>(0, (s, p) => s + (double.tryParse('${p['amount'] ?? 0}') ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _LHColors.title,
        elevation: 0.5,
        title: Text('${loan['loan_id'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _LHColors.title, fontFamily: 'monospace')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${loan['member_name'] ?? ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(child: _BalBox(label: 'Loan Amount', value: '₱${(double.tryParse('${loan['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', color: const Color(0xFF333333))),
              const SizedBox(width: 6),
              Expanded(child: _BalBox(label: 'Balance', value: '₱${balance.toStringAsFixed(0)}', color: _LHColors.red, highlight: true)),
              const SizedBox(width: 6),
              Expanded(child: _BalBox(label: 'Monthly Due', value: '₱${(double.tryParse('${loan['monthly_due'] ?? 0}') ?? 0).toStringAsFixed(0)}', color: _LHColors.green)),
            ]),
            const SizedBox(height: 16),

            const Text('PAYMENT HISTORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _LHColors.sub, letterSpacing: 0.5)),
            const SizedBox(height: 8),

            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('No payments recorded yet.', style: TextStyle(color: _LHColors.sub))),
              )
            else
              ...payments.map((p) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF0F0F0))),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${p['tx_id'] ?? ''}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: _LHColors.title)),
                            Text('${'${p['paid_at'] ?? ''}'.split('T').first}', style: const TextStyle(fontSize: 10, color: _LHColors.sub)),
                            if (p['note'] != null && '${p['note']}'.isNotEmpty) Text('${p['note']}', style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                          ],
                        ),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('₱${(double.tryParse('${p['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: _LHColors.green, fontSize: 13)),
                        Text('Bal: ₱${(double.tryParse('${p['balance'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: TextStyle(fontSize: 10, color: (double.tryParse('${p['balance'] ?? 0}') ?? 0) == 0 ? _LHColors.blue : _LHColors.red)),
                      ]),
                    ]),
                  )),

            if (payments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${payments.length} payment${payments.length != 1 ? "s" : ""} · Total: ₱${totalPaid.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: _LHColors.sub, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
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