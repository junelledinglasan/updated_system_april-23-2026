import 'package:flutter/material.dart';
import '../../services/loans_service.dart';

class _GDColors {
  static const title = Color(0xFF1B5E20);
  static const sub   = Color(0xFF888888);
  static const green = Color(0xFF2E7D32);
  static const blue  = Color(0xFF1565C0);
  static const red   = Color(0xFFC62828);
}

Color _statusColor(String s) => s == 'Verified' ? _GDColors.green : s == 'Rejected' ? _GDColors.red : const Color(0xFFF57C00);
Color _statusBg(String s) => s == 'Verified' ? const Color(0xFFE8F5E9) : s == 'Rejected' ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1);
Color _statusBorder(String s) => s == 'Verified' ? const Color(0xFFA5D6A7) : s == 'Rejected' ? const Color(0xFFEF9A9A) : const Color(0xFFFFE082);

class GcashRequestDetailScreen extends StatefulWidget {
  final dynamic req;
  const GcashRequestDetailScreen({super.key, required this.req});

  @override
  State<GcashRequestDetailScreen> createState() => _GcashRequestDetailScreenState();
}

class _GcashRequestDetailScreenState extends State<GcashRequestDetailScreen> {
  bool _rejectMode = false;
  final _reasonCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    setState(() => _loading = true);
    try {
      await LoansService.verifyGCashRequest(widget.req['id'], {'action': 'verify'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment verified and recorded!'), backgroundColor: _GDColors.green));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to verify.'), backgroundColor: _GDColors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleReject() async {
    if (_reasonCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await LoansService.verifyGCashRequest(widget.req['id'], {'action': 'reject', 'reject_reason': _reasonCtrl.text});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment request rejected.'), backgroundColor: _GDColors.red));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reject.'), backgroundColor: _GDColors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.req;
    final status = (req['status'] ?? 'Pending').toString();
    final hasProof = req['screenshot_url'] != null;
    final amount = double.tryParse('${req['amount'] ?? 0}') ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _GDColors.title,
        elevation: 0.5,
        title: const Row(children: [
          Icon(Icons.smartphone, size: 16, color: _GDColors.blue),
          SizedBox(width: 6),
          Text('GCash Payment Request', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _GDColors.title)),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${req['created_at'] ?? ''}', style: const TextStyle(fontSize: 10.5, color: _GDColors.sub)),
            const SizedBox(height: 12),

            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(color: _statusBg(status), borderRadius: BorderRadius.circular(20), border: Border.all(color: _statusBorder(status))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(status == 'Verified' ? Icons.check_circle : status == 'Rejected' ? Icons.cancel : Icons.access_time, size: 14, color: _statusColor(status)),
                  const SizedBox(width: 6),
                  Text(status == 'Pending' ? 'Pending Verification' : status, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _statusColor(status))),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(10)),
              child: Wrap(spacing: 16, runSpacing: 10, children: [
                _InfoField('Member', req['member_name']),
                _InfoField('Member ID', req['member_id'], mono: true),
                _InfoField('Loan ID', req['loan_id'], mono: true),
                _InfoField('Amount', '₱${amount.toStringAsFixed(0)}'),
              ]),
            ),
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF90CAF9), width: 2)),
              child: Column(children: [
                const Text('GCASH REFERENCE NUMBER', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _GDColors.blue, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                FittedBox(
                  child: Text('${req['reference_number'] ?? ''}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1), letterSpacing: 2, fontFamily: 'monospace')),
                ),
                const SizedBox(height: 6),
                const Text('Verify this in your GCash app → Transaction History', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: _GDColors.sub)),
              ]),
            ),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFA5D6A7))),
              child: Column(children: [
                const Text('Payment Amount', style: TextStyle(fontSize: 11, color: _GDColors.green, fontWeight: FontWeight.w600)),
                Text('₱${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _GDColors.title)),
              ]),
            ),
            const SizedBox(height: 16),

            Row(children: [
              const Text('Payment Proof Screenshot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
              if (!hasProof) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEF9A9A))),
                  child: const Text('No screenshot', style: TextStyle(fontSize: 9, color: _GDColors.red, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            hasProof
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFF90CAF9), width: 2)),
                      child: Image.network(
                        req['screenshot_url'],
                        fit: BoxFit.contain,
                        height: 260,
                        width: double.infinity,
                        loadingBuilder: (context, child, progress) => progress == null ? child : const SizedBox(height: 260, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                        errorBuilder: (context, error, stack) => Container(height: 260, color: const Color(0xFFF0F7FF), alignment: Alignment.center, child: const Text('Unable to load image', style: TextStyle(color: _GDColors.sub))),
                      ),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE0E0E0))),
                    child: const Text('No payment screenshot was submitted.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 12)),
                  ),

            if (req['note'] != null && '${req['note']}'.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFE082))),
                child: Text.rich(TextSpan(text: 'Note: ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF555555)), children: [
                  TextSpan(text: '${req['note']}', style: const TextStyle(fontWeight: FontWeight.w400)),
                ])),
              ),
            ],

            if (status == 'Verified') ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFA5D6A7))),
                child: Text('Verified by ${req['verified_by'] ?? ''} on ${req['verified_at'] ?? ''}', style: const TextStyle(fontSize: 12, color: _GDColors.green, fontWeight: FontWeight.w600)),
              ),
            ],
            if (status == 'Rejected' && req['reject_reason'] != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEF9A9A))),
                child: Text('Rejected: ${req['reject_reason']}', style: const TextStyle(fontSize: 12, color: _GDColors.red)),
              ),
            ],

            if (_rejectMode) ...[
              const SizedBox(height: 16),
              const Text('REASON FOR REJECTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _GDColors.red, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: 'e.g. Reference number not found in GCash, amount does not match...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEF9A9A)))),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: status == 'Pending' && !_rejectMode
              ? Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: _GDColors.red, side: const BorderSide(color: Color(0xFFEF9A9A))),
                      onPressed: () => setState(() => _rejectMode = true),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _GDColors.green, foregroundColor: Colors.white),
                      onPressed: _loading ? null : _handleVerify,
                      child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Verify & Record'),
                    ),
                  ),
                ])
              : _rejectMode
                  ? Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => setState(() { _rejectMode = false; _reasonCtrl.clear(); }), child: const Text('← Back'))),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: _GDColors.red, foregroundColor: Colors.white),
                          onPressed: (_reasonCtrl.text.trim().isEmpty || _loading) ? null : _handleReject,
                          child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirm Rejection'),
                        ),
                      ),
                    ])
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _GDColors.green, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
        ),
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  final String label;
  final dynamic value;
  final bool mono;
  const _InfoField(this.label, this.value, {this.mono = false});

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 62) / 2;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(value == null || '$value'.isEmpty ? '—' : '$value', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF222222), fontFamily: mono ? 'monospace' : null)),
        ],
      ),
    );
  }
}