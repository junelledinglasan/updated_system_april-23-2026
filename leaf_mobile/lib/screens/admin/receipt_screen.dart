import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class _RColors {
  static const title = Color(0xFF1B5E20);
  static const sub   = Color(0xFF888888);
  static const green = Color(0xFF2E7D32);
  static const blue  = Color(0xFF1565C0);
  static const red   = Color(0xFFC62828);
}

class ReceiptScreen extends StatelessWidget {
  final dynamic tx;
  const ReceiptScreen({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final isOnBlockchain = tx['polygon_tx'] != null && tx['network'] == 'polygon';
    final explorerUrl = tx['polygon_tx'] != null ? 'https://polygonscan.com/tx/${tx['polygon_tx']}' : null;
    final isFullyPaid = (double.tryParse('${tx['balance'] ?? 0}') ?? 0) == 0;
    final amount = double.tryParse('${tx['amount'] ?? 0}') ?? 0;
    final balance = double.tryParse('${tx['balance'] ?? 0}') ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _RColors.title,
        elevation: 0.5,
        title: Text('${tx['tx_id'] ?? tx['txId'] ?? 'Receipt'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _RColors.title, fontFamily: 'monospace')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFullyPaid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), border: Border.all(color: _RColors.title, width: 2), borderRadius: BorderRadius.circular(10)),
                child: const Text('LOAN FULLY PAID', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _RColors.title)),
              ),

            _SectionTitle('Member Information'),
            _Row('Member Name', tx['member_name'] ?? tx['fullname'] ?? '—'),
            _Row('Member ID', tx['member_code'] ?? tx['memberId'] ?? '—', mono: true),
            _Row('Loan ID', tx['loan_code'] ?? tx['loanId'] ?? '—', mono: true),
            const SizedBox(height: 16),

            _SectionTitle('Payment Details'),
            _Row('Amount Paid', '₱${amount.toStringAsFixed(2)}', color: _RColors.green, bold: true),
            _Row('Balance After', isFullyPaid ? '₱0.00 — FULLY PAID ✓' : '₱${balance.toStringAsFixed(2)}', color: isFullyPaid ? _RColors.blue : _RColors.red, bold: true),
            _Row('Date & Time', _formatDate(tx['paid_at'])),
            _Row('Note', tx['note'] ?? '—'),
            _Row('Recorded By', tx['recorded_by'] ?? '—'),
            const SizedBox(height: 16),

            _SectionTitle('Verification'),
            _Row('SHA-256 Hash', tx['hash'] ?? '—', mono: true, small: true),
            _Row('Blockchain', isOnBlockchain ? 'Polygon Mainnet' : '⚠ Local only'),
            if (tx['polygon_tx'] != null) _Row('Polygon TX', '${tx['polygon_tx']}', mono: true, small: true),
            if (tx['block_number'] != null) _Row('Block Number', '${tx['block_number']}', mono: true),

            if (explorerUrl != null) ...[
              const SizedBox(height: 14),
              Center(
                child: TextButton.icon(
                  onPressed: () => launchUrl(Uri.parse(explorerUrl), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.link, size: 16, color: Color(0xFF7C3AED)),
                  label: const Text('View on Polygonscan', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ),
      ),
    );
  }

  String _formatDate(String? paidAt) {
    if (paidAt == null) return '—';
    try {
      final d = DateTime.parse(paidAt).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final ampm = d.hour >= 12 ? 'PM' : 'AM';
      return '${months[d.month - 1]} ${d.day}, ${d.year} ${h}:${d.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return paidAt;
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.only(bottom: 4),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE8F5E9)))),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _RColors.title, letterSpacing: 0.5)),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final bool bold;
  final bool small;
  final Color? color;
  const _Row(this.label, this.value, {this.mono = false, this.bold = false, this.small = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _RColors.sub, letterSpacing: 0.3))),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: small ? 10 : (bold ? 14 : 12),
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: color ?? const Color(0xFF222222),
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}