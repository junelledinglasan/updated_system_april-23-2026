import 'package:flutter/material.dart';
import '../../services/loans_service.dart';
import 'loan_approval_screen.dart';

class _PLColors {
  static const title  = Color(0xFF1B5E20);
  static const sub    = Color(0xFF888888);
  static const green  = Color(0xFF2E7D32);
  static const red    = Color(0xFFC62828);
  static const orange = Color(0xFFE65100);
}

class ProcessLoanScreen extends StatefulWidget {
  final dynamic loan;
  const ProcessLoanScreen({super.key, required this.loan});

  @override
  State<ProcessLoanScreen> createState() => _ProcessLoanScreenState();
}

class _ProcessLoanScreenState extends State<ProcessLoanScreen> {
  bool _declineMode = false;
  late final TextEditingController _remarksCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _remarksCtrl = TextEditingController(text: '${widget.loan['remarks'] ?? ''}');
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse('${widget.loan['amount'] ?? 0}') ?? 0;
  int get _term => int.tryParse('${widget.loan['term_months'] ?? widget.loan['term'] ?? 6}') ?? 6;
  double get _monthlyRate => _amount <= 50000 ? 0.0125 : _amount <= 150000 ? 0.01125 : 0.01;
  double get _interest => _monthlyRate * _amount * _term;
  double get _serviceFee => _amount * 0.03;
  double get _filingFee => _amount <= 50000 ? 50 : 100;
  double get _insurance => _amount * 0.0125;
  double get _sd => _amount * 0.01;
  double get _sc => _amount * 0.03;
  double get _totalDeductions => _interest + _serviceFee + _filingFee + _insurance + _sd + _sc;
  double get _netProceeds => _amount - _totalDeductions;
  double get _totalPayable => _amount + _interest;
  double get _monthlyAmort => _term > 0 ? _totalPayable / _term : 0;

  Future<void> _handleApprove() async {
    setState(() => _loading = true);
    try {
      await LoansService.updateLoanStatus(widget.loan['id'], 'Approved');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loan approved for ${widget.loan['member_name']}. Monthly: ₱${_monthlyAmort.toStringAsFixed(0)}'), backgroundColor: _PLColors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve loan.'), backgroundColor: _PLColors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleDecline() async {
    if (_remarksCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await LoansService.updateLoanStatus(widget.loan['id'], 'Declined', declineReason: _remarksCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loan declined for ${widget.loan['member_name']}.'), backgroundColor: _PLColors.red),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to decline loan.'), backgroundColor: _PLColors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final status = (loan['status'] ?? '').toString();
    final fullname = loan['member_name'] ?? 'M';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _PLColors.title,
        elevation: 0.5,
        title: Text('${loan['loan_id'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _PLColors.title, fontFamily: 'monospace')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: laStatusBg(status), borderRadius: BorderRadius.circular(20), border: Border.all(color: laStatusColor(status).withOpacity(0.3))),
                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: laStatusColor(status))),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4F0E5))),
              child: Row(children: [
                CircleAvatar(radius: 20, backgroundColor: const Color(0xFFE8F5E9), child: Text('$fullname'.isNotEmpty ? '$fullname'[0].toUpperCase() : 'M', style: const TextStyle(color: _PLColors.green, fontWeight: FontWeight.w700))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$fullname', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('${loan['member_code'] ?? ''} · Submitted ${loan['applied_at'] ?? ''}', style: const TextStyle(fontSize: 10, color: _PLColors.sub)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            _SectionTitle('Loan Request'),
            Wrap(spacing: 14, runSpacing: 10, children: [
              _DetailItem('Loan Type', '${loan['loan_type'] ?? ''}'),
              _DetailItem('Amount', '₱${_amount.toStringAsFixed(0)}', color: _PLColors.green, bold: true),
              _DetailItem('Term', '$_term months'),
              _DetailItem('Purpose', '${loan['purpose'] ?? ''}'),
            ]),
            const SizedBox(height: 16),

            _SectionTitle('Loan Computation'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4F0E5))),
              child: Column(children: [
                _ResultRow('Interest Rate', '${(_monthlyRate * 100).toStringAsFixed(3)}%/mo (${(_monthlyRate * 100 * 12).toStringAsFixed(2)}%/yr)'),
                _ResultRow('Total Interest ($_term months)', '₱${_interest.toStringAsFixed(2)}', color: _PLColors.orange),
                _ResultRow('Total Payable (Principal + Interest)', '₱${_totalPayable.toStringAsFixed(2)}'),
                const Divider(),
                _ResultRow('Monthly Amortization', '₱${_monthlyAmort.toStringAsFixed(2)}', color: _PLColors.green, bold: true),
              ]),
            ),
            const SizedBox(height: 16),

            _SectionTitle('Upfront Deductions (from Loan Release)'),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFFFF8F8), border: Border.all(color: const Color(0xFFFFCDD2)), borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                _DeductRow('Loan Amount', '₱${_amount.toStringAsFixed(0)}'),
                const Divider(),
                _DeductRow('Interest (${(_monthlyRate * 100)}% × $_term mo)', '− ₱${_interest.toStringAsFixed(2)}', red: true),
                _DeductRow('Service Fee (3%)', '− ₱${_serviceFee.toStringAsFixed(2)}', red: true),
                _DeductRow('Filing Fee (fixed)', '− ₱${_filingFee.toStringAsFixed(2)}', red: true),
                _DeductRow('Insurance (1.25%)', '− ₱${_insurance.toStringAsFixed(2)}', red: true),
                _DeductRow('Savings Deposit (1%)', '− ₱${_sd.toStringAsFixed(2)}', red: true),
                _DeductRow('Share Capital CBU Retention (3%)', '− ₱${_sc.toStringAsFixed(2)}', red: true),
                const Divider(),
                _DeductRow('Total Deductions', '− ₱${_totalDeductions.toStringAsFixed(2)}', red: true, bold: true),
                const SizedBox(height: 6),
                _DeductRow('Net Proceeds (actual release)', '₱${_netProceeds.toStringAsFixed(2)}', bold: true, big: true),
              ]),
            ),
            const SizedBox(height: 16),

            _SectionTitle(_declineMode ? 'Reason for Decline' : 'Remarks / Notes'),
            TextField(
              controller: _remarksCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _declineMode ? 'State the reason for declining...' : 'Optional: Add remarks...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _declineMode ? const Color(0xFFF8BBD0) : const Color(0xFFE0E0E0))),
              ),
              onChanged: (_) => setState(() {}),
            ),

            if (status == 'Active')
              Container(margin: const EdgeInsets.only(top: 14), width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFC8E6C9))), child: const Text('This loan has been approved and activated.', style: TextStyle(fontSize: 11.5, color: _PLColors.title))),
            if (status == 'Declined')
              Container(margin: const EdgeInsets.only(top: 14), width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF8BBD0))), child: const Text('This loan has been declined.', style: TextStyle(fontSize: 11.5, color: Color(0xFFB71C1C)))),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: !_declineMode
              ? Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
                  if (status == 'For Review') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: _PLColors.red, side: const BorderSide(color: Color(0xFFFFCDD2))),
                        onPressed: () => setState(() => _declineMode = true),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _PLColors.green, foregroundColor: Colors.white),
                        onPressed: _loading ? null : _handleApprove,
                        child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Approve Loan'),
                      ),
                    ),
                  ],
                ])
              : Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => setState(() => _declineMode = false), child: const Text('← Back'))),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _PLColors.red, foregroundColor: Colors.white),
                      onPressed: (_remarksCtrl.text.trim().isEmpty || _loading) ? null : _handleDecline,
                      child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirm Decline'),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.only(bottom: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE8F5E9), width: 1.5))),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _PLColors.title, letterSpacing: 0.6)),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  const _DetailItem(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 46) / 2;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFBBBBBB), letterSpacing: 0.4)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 12.5, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: color ?? const Color(0xFF222222))),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  const _ResultRow(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: bold ? 12.5 : 11.5, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? _PLColors.title : const Color(0xFF555555)))),
        Text(value, style: TextStyle(fontSize: bold ? 13 : 12, fontWeight: FontWeight.w700, color: color ?? const Color(0xFF333333))),
      ]),
    );
  }
}

class _DeductRow extends StatelessWidget {
  final String label;
  final String value;
  final bool red;
  final bool bold;
  final bool big;
  const _DeductRow(this.label, this.value, {this.red = false, this.bold = false, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: bold ? 12.5 : 11.5, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? _PLColors.title : const Color(0xFF555555)))),
        Text(value, style: TextStyle(fontSize: big ? 16 : (bold ? 13 : 12), fontWeight: FontWeight.w700, color: red ? _PLColors.red : (big ? _PLColors.title : const Color(0xFF333333)))),
      ]),
    );
  }
}