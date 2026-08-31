import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../../services/loans_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../services/settings_service.dart';

// ── BAGO: hindi na naka-hardcode — kinukuha na ngayon mula sa Settings
// (backend, na-e-edit ng admin sa Settings → "💳 GCash" tab). Ang mga
// ito sa ibaba ay FALLBACK LANG habang kinukuha pa/kung mag-fail ang
// fetch — hindi na dapat umasa dito. ─────────────────────────────────
const String _kFallbackGcashNumber = '0967-006-3500';
const String _kFallbackGcashName = 'LEAF MPC';

class _GPColors {
  static const blue    = Color(0xFF007BFF);
  static const blueDk  = Color(0xFF0056B3);
  static const green   = Color(0xFF2E7D32);
  static const dark    = Color(0xFF1B5E20);
  static const sub     = Color(0xFF888888);
  static const red     = Color(0xFFE53935);
}

class GcashPaymentScreen extends StatefulWidget {
  final dynamic loan;
  const GcashPaymentScreen({super.key, required this.loan});

  @override
  State<GcashPaymentScreen> createState() => _GcashPaymentScreenState();
}

class _GcashPaymentScreenState extends State<GcashPaymentScreen> {
  int _step = 1; // 1=instructions, 2=form, 3=success
  bool _copied = false;
  bool _loading = false;
  bool _uploading = false;
  Map<String, dynamic>? _result;

  // ── BAGO: GCash number/name mula sa Settings API ────────────────────
  String _gcashNumber = _kFallbackGcashNumber;
  String _gcashName = _kFallbackGcashName;

  late final TextEditingController _amountCtrl;
  final _refCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final Map<String, String> _errors = {};

  Uint8List? _screenshotBytes;
  String? _screenshotName;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: '${widget.loan['monthly_due'] ?? ''}');
    _loadGcashSettings();
  }

  Future<void> _loadGcashSettings() async {
    final data = await SettingsService.getGCashSettings();
    if (mounted) {
      setState(() {
        if ((data['gcash_number'] ?? '').isNotEmpty) _gcashNumber = data['gcash_number']!;
        if ((data['gcash_name'] ?? '').isNotEmpty) _gcashName = data['gcash_name']!;
      });
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _copyNumber() {
    Clipboard.setData(ClipboardData(text: _gcashNumber.replaceAll('-', '')));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      setState(() => _errors['screenshot'] = 'File too large. Max 5MB.');
      return;
    }
    setState(() {
      _screenshotBytes = bytes;
      _screenshotName = picked.name;
      _errors.remove('screenshot');
    });
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final balance = double.tryParse('${widget.loan['balance'] ?? 0}') ?? 0;
    if (amount <= 0) {
      e['amount'] = 'Enter the amount you paid.';
    } else if (amount > balance) {
      e['amount'] = 'Amount exceeds remaining balance of ₱${balance.toStringAsFixed(0)}.';
    }
    if (_refCtrl.text.trim().isEmpty) {
      e['reference_number'] = 'GCash reference number is required.';
    } else if (_refCtrl.text.trim().length < 10) {
      e['reference_number'] = 'Invalid reference number. Must be at least 10 characters.';
    }
    if (_screenshotBytes == null) {
      e['screenshot'] = 'Please upload a screenshot of your GCash payment as proof.';
    }
    return e;
  }

  Future<void> _handleSubmit() async {
    final errs = _validate();
    if (errs.isNotEmpty) {
      setState(() => _errors..clear()..addAll(errs));
      return;
    }
    setState(() => _loading = true);

    String screenshotUrl = '';
    if (_screenshotBytes != null) {
      setState(() => _uploading = true);
      final ext = (_screenshotName ?? 'proof.jpg').split('.').last;
      final filename = '${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}.$ext';
      screenshotUrl = await SupabaseStorageService.uploadScreenshot(_screenshotBytes!, filename);
      if (mounted) setState(() => _uploading = false);
    }

    try {
      final res = await LoansService.submitGCashRequest({
        'loan_id': widget.loan['id'],
        'amount': double.tryParse(_amountCtrl.text) ?? 0,
        'reference_number': _refCtrl.text.trim(),
        'note': _noteCtrl.text.trim(),
        'screenshot_url': screenshotUrl,
      });
      if (mounted) {
        setState(() {
          _result = res;
          _step = 3;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _errors['reference_number'] = 'Failed to submit. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: _GPColors.dark,
        title: Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_GPColors.blue, _GPColors.blueDk]), borderRadius: BorderRadius.circular(9)), child: const Icon(Icons.smartphone, color: Colors.white, size: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Pay via GCash', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _GPColors.dark)),
                Text('Loan: ${widget.loan['loan_id'] ?? ''}', style: const TextStyle(fontSize: 10, color: _GPColors.sub)),
              ],
            ),
          ),
        ]),
      ),
      body: Column(
        children: [
          // ── Step indicator ─────────────────────────────────────────
          Row(children: [
            Expanded(child: _StepChip(label: 'Payment Info', index: 1, currentStep: _step)),
            Expanded(child: _StepChip(label: 'Submit Reference', index: 2, currentStep: _step)),
            Expanded(child: _StepChip(label: 'Done', index: 3, currentStep: _step)),
          ]),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _step == 1
                  ? _buildStep1()
                  : _step == 2
                      ? _buildStep2()
                      : _buildStep3(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _step == 1
              ? Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _GPColors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () => setState(() => _step = 2),
                      child: const Text("I've Sent Payment →", style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ])
              : _step == 2
                  ? Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), child: const Text('← Back'))),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: _GPColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: (_loading || _uploading) ? null : _handleSubmit,
                          child: _loading || _uploading
                              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                  const SizedBox(width: 8),
                                  Text(_uploading ? 'Uploading...' : 'Submitting...'),
                                ])
                              : const Text('Submit Reference Number', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ])
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _GPColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
                        onPressed: () => Navigator.pop(context, _result),
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    final balance = double.tryParse('${widget.loan['balance'] ?? 0}') ?? 0;
    final monthlyDue = double.tryParse('${widget.loan['monthly_due'] ?? 0}') ?? 0;
    // ── BAGO: hindi na "const" — dahil ang _gcashNumber/_gcashName ay
    // instance fields na ngayon (dynamic mula sa API), hindi na
    // compile-time constants. ───────────────────────────────────────
    final steps = [
      'Open your GCash app',
      'Send payment to $_gcashNumber ($_gcashName)',
      'Enter the amount you want to pay',
      'Complete the transaction',
      'Note your 13-digit reference number',
      'Come back here and click Next to submit your reference number',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Loan info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFCCE5FF))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Loan Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
              const SizedBox(height: 8),
              Wrap(spacing: 20, runSpacing: 10, children: [
                _InfoPair('Loan ID', '${widget.loan['loan_id'] ?? ''}'),
                _InfoPair('Loan Type', '${widget.loan['loan_type'] ?? ''}'),
                _InfoPair('Balance', '₱${balance.toStringAsFixed(0)}'),
                _InfoPair('Monthly Due', '₱${monthlyDue.toStringAsFixed(0)}'),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // GCash number
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFA5D6A7))),
          child: Column(
            children: [
              const Text('SEND GCASH PAYMENT TO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _GPColors.green, letterSpacing: 0.5)),
              const SizedBox(height: 6),
              Text(_gcashNumber, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _GPColors.dark, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(_gcashName, style: const TextStyle(fontSize: 13, color: Color(0xFF555555))),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _copyNumber,
                style: OutlinedButton.styleFrom(
                  backgroundColor: _copied ? _GPColors.green : Colors.white,
                  foregroundColor: _copied ? Colors.white : _GPColors.green,
                  side: const BorderSide(color: _GPColors.green, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: Icon(_copied ? Icons.check_circle : Icons.copy, size: 14),
                label: Text(_copied ? 'Copied!' : 'Copy Number', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Instructions
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFFDE7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFE082))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How to Pay:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF57F17))),
              const SizedBox(height: 8),
              ...List.generate(steps.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 20, height: 20, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFFF57F17), shape: BoxShape.circle), child: Text('${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(steps[i], style: const TextStyle(fontSize: 12, color: Color(0xFF555555)))),
                    ]),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFA5D6A7))),
          child: const Text('After sending payment via GCash, enter your reference number below.', style: TextStyle(fontSize: 12, color: _GPColors.green, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 14),

        Text.rich(TextSpan(text: 'AMOUNT PAID (₱)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF555555), letterSpacing: 0.5), children: const [TextSpan(text: ' *', style: TextStyle(color: _GPColors.red))])),
        const SizedBox(height: 6),
        TextField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _errors.remove('amount')),
          decoration: InputDecoration(prefixText: '₱ ', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _errors['amount'] != null ? _GPColors.red : const Color(0xFFE0E0E0), width: 1.5)), errorText: _errors['amount']),
        ),
        const SizedBox(height: 14),

        Text.rich(TextSpan(text: 'GCASH REFERENCE NUMBER', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF555555), letterSpacing: 0.5), children: const [TextSpan(text: ' *', style: TextStyle(color: _GPColors.red))])),
        const SizedBox(height: 6),
        TextField(
          controller: _refCtrl,
          maxLength: 20,
          onChanged: (_) => setState(() => _errors.remove('reference_number')),
          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 2),
          decoration: InputDecoration(hintText: 'e.g. 1234567890123', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _errors['reference_number'] != null ? _GPColors.red : const Color(0xFFE0E0E0), width: 1.5)), errorText: _errors['reference_number'], counterText: ''),
        ),
        const Text('Found in GCash app → Transaction History → Reference Number', style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
        const SizedBox(height: 14),

        const Text('NOTE (OPTIONAL)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF555555), letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(controller: _noteCtrl, decoration: InputDecoration(hintText: 'e.g. Monthly payment for June', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        const SizedBox(height: 14),

        Text.rich(TextSpan(text: 'PROOF OF PAYMENT', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF555555), letterSpacing: 0.5), children: const [TextSpan(text: ' *', style: TextStyle(color: _GPColors.red))])),
        const SizedBox(height: 6),
        _screenshotBytes != null
            ? Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(_screenshotBytes!, width: double.infinity, height: 220, fit: BoxFit.contain, color: Colors.grey.shade50, colorBlendMode: BlendMode.dst),
                ),
                Positioned(
                  top: 6, right: 6,
                  child: GestureDetector(
                    onTap: () => setState(() { _screenshotBytes = null; _screenshotName = null; }),
                    child: Container(width: 26, height: 26, decoration: const BoxDecoration(color: _GPColors.red, shape: BoxShape.circle), child: const Icon(Icons.delete_outline, size: 14, color: Colors.white)),
                  ),
                ),
              ])
            : InkWell(
                onTap: _pickScreenshot,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(color: const Color(0xFFF0F7FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF90CAF9), width: 2)),
                  child: Column(children: const [
                    Icon(Icons.image_outlined, size: 30, color: Color(0xFF1565C0)),
                    SizedBox(height: 8),
                    Text('Click to upload GCash screenshot', style: TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('JPG, PNG — max 5MB', style: TextStyle(fontSize: 10, color: Color(0xFFAAAAAA))),
                  ]),
                ),
              ),
        if (_errors['screenshot'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_errors['screenshot']!, style: const TextStyle(fontSize: 11, color: _GPColors.red))),
        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFE082))),
          child: const Text('⚠ Make sure your reference number is correct. Admin will verify it against the actual GCash transaction before recording your payment.', style: TextStyle(fontSize: 11, color: Color(0xFFF57F17))),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final result = _result ?? {};
    return Column(
      children: [
        Container(width: 64, height: 64, decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle), child: const Icon(Icons.check_circle, size: 32, color: _GPColors.green)),
        const SizedBox(height: 16),
        const Text('Request Submitted!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _GPColors.dark)),
        const SizedBox(height: 6),
        const Text('Your GCash payment request has been sent to the admin for verification.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.6)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFC8E6C9))),
          child: Column(children: [
            _ResultRow('Reference No.', '${result['reference_number'] ?? _refCtrl.text}', mono: true),
            _ResultRow('Amount', '₱${(double.tryParse('${result['amount'] ?? _amountCtrl.text}') ?? 0).toStringAsFixed(0)}'),
            _ResultRow('Status', 'Pending Verification'),
          ]),
        ),
        const SizedBox(height: 14),
        const Text('Admin will verify your payment and record it once confirmed. You will see it in your payment history.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF888888), height: 1.6)),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final int index;
  final int currentStep;
  const _StepChip({required this.label, required this.index, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final isActive = currentStep == index;
    final isDone = currentStep > index;
    final color = isActive ? _GPColors.blue : isDone ? _GPColors.green : const Color(0xFFBBBBBB);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: (isActive || isDone) ? color : Colors.transparent, width: 2))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isDone) ...[const Icon(Icons.check_circle, size: 12, color: _GPColors.green), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _InfoPair extends StatelessWidget {
  final String label;
  final String value;
  const _InfoPair(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  const _ResultRow(this.label, this.value, {this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _GPColors.dark, fontFamily: mono ? 'monospace' : null)),
      ]),
    );
  }
}