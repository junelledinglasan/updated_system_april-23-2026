import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/member_provider.dart';
import '../../services/members_service.dart';
import '../../services/loans_service.dart';
import '../../services/payments_service.dart';
import '../../widgets/member_scaffold_helpers.dart';
import 'package:provider/provider.dart';

class _LAColors {
  static const dark   = Color(0xFF1B5E20);
  static const green  = Color(0xFF2E7D32);
  static const sub    = Color(0xFFAAAAAA);
  static const red    = Color(0xFFC62828);
  static const blue   = Color(0xFF1565C0);
  static const border = Color(0xFFE4F0E5);
}

const List<Map<String, dynamic>> kLoanTypes = [
  {'type': 'Regular Loan', 'icon': Icons.home_outlined, 'color': Color(0xFF2E7D32), 'bg': Color(0xFFE8F5E9), 'border': Color(0xFFA5D6A7), 'desc': 'For personal or household needs', 'maxAmt': 50000, 'maxTerm': 24},
  {'type': 'Emergency Loan', 'icon': Icons.warning_amber_rounded, 'color': Color(0xFFC62828), 'bg': Color(0xFFFCE4EC), 'border': Color(0xFFEF9A9A), 'desc': 'For urgent and unexpected expenses', 'maxAmt': 20000, 'maxTerm': 12},
  {'type': 'Salary Loan', 'icon': Icons.work_outline, 'color': Color(0xFF1565C0), 'bg': Color(0xFFE3F2FD), 'border': Color(0xFF90CAF9), 'desc': 'Based on your monthly salary', 'maxAmt': 30000, 'maxTerm': 12},
  {'type': 'Housing Loan', 'icon': Icons.construction_outlined, 'color': Color(0xFFE65100), 'bg': Color(0xFFFFF8E1), 'border': Color(0xFFFFCC80), 'desc': 'For home repair or construction', 'maxAmt': 100000, 'maxTerm': 48},
  {'type': 'Business Loan', 'icon': Icons.storefront_outlined, 'color': Color(0xFF6A1B9A), 'bg': Color(0xFFF3E5F5), 'border': Color(0xFFCE93D8), 'desc': 'For business capital or expansion', 'maxAmt': 80000, 'maxTerm': 36},
];

const Map<String, Map<String, dynamic>> kStatusMeta = {
  'For Review': {'bg': Color(0xFFFFF8E1), 'color': Color(0xFFE65100), 'label': '⏳ For Review'},
  // ── BAGO: hiwalay na type mula sa "Active" — na-approve na pero
  // hindi pa na-"Confirm Release" (waiting for release sa opisina). ──
  'Approved':   {'bg': Color(0xFFFFF8E1), 'color': Color(0xFFE65100), 'label': '📦 Approved — For Release'},
  'Active':     {'bg': Color(0xFFE8F5E9), 'color': Color(0xFF2E7D32), 'label': '✅ Active'},
  'Declined':   {'bg': Color(0xFFFCE4EC), 'color': Color(0xFFC62828), 'label': '❌ Declined'},
  'Completed':  {'bg': Color(0xFFE3F2FD), 'color': Color(0xFF1565C0), 'label': '✔ Completed'},
  'Overdue':    {'bg': Color(0xFFFFEBEE), 'color': Color(0xFFB71C1C), 'label': '⚠️ Overdue'},
  // ── BAGO: kapag ang MEMBER MISMO ang nag-cancel ng sarili niyang
  // "For Review" application (hiwalay sa "Declined" na galing sa admin). ──
  'Cancelled':  {'bg': Color(0xFFF5F5F5), 'color': Color(0xFF777777), 'label': '🚫 Cancelled'},
};

String _peso(num v) {
  final fixed = v.toStringAsFixed(0);
  final isNeg = fixed.startsWith('-');
  final digits = isNeg ? fixed.substring(1) : fixed;
  final buf = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '₱${isNeg ? '-' : ''}$buf';
}

class LoanApplicationScreen extends StatefulWidget {
  const LoanApplicationScreen({super.key});

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  int _step = 1;
  double _shareCapital = 0;
  double _monthlyIncome = 0;
  String _classification = 'Employed';
  bool _loadingProfile = true;
  List<dynamic> _myLoans = [];
  bool _loadingLoans = true;
  bool _showHistory = false;

  String? _selType;
  final _amountCtrl = TextEditingController();
  int _term = 12;
  final _purposeCtrl = TextEditingController();
  final _collateralCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final Map<String, String> _errors = {};

  bool _submitted = false;
  bool _submitting = false;

  // ── BAGO: edit/cancel ng sariling "For Review" application ──────────
  dynamic _editingId;      // loan['id'] kapag naka-edit mode
  bool _editedNotice = false; // "Updated!" na screen imbes na "Submitted!"
  String _formError = '';  // API-level error (hiwalay sa per-field errors)
  dynamic _checkingId;     // loan['id'] na kasalukuyang chine-check bago Edit/Cancel
  String _staleNotice = '';

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = '';
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    _collateralCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loadingProfile = true; _loadingLoans = true; });
    try {
      final p = await MembersService.getMyProfile();
      final jobIncome = double.tryParse('${p['job_profile']?['monthly_income'] ?? 0}') ?? 0;
      final seniorIncome = double.tryParse('${p['senior_profile']?['pension_income'] ?? 0}') ?? 0;
      final studentIncome = double.tryParse('${p['student_profile']?['allowance'] ?? 0}') ?? 0;
      final inc = jobIncome != 0 ? jobIncome : (seniorIncome != 0 ? seniorIncome : studentIncome);
      if (mounted) {
        setState(() {
          _shareCapital = double.tryParse('${p['share_capital'] ?? 0}') ?? 0;
          _monthlyIncome = inc;
          _classification = '${p['classification'] ?? 'Employed'}';
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
    try {
      final loans = await LoansService.getLoans();
      if (mounted) setState(() { _myLoans = loans; _loadingLoans = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingLoans = false);
    }
  }

  // ── BAGO: hiwalay na refresh function — ginagamit ng freshness
  // check bago mag-Edit/Cancel. ───────────────────────────────────────
  Future<List<dynamic>> _refreshLoans() async {
    try {
      final loans = await LoansService.getLoans();
      if (mounted) setState(() => _myLoans = loans);
      return loans;
    } catch (_) {
      return _myLoans;
    }
  }

  // ── Eligibility Checker — parehong logic sa web ─────────────────────
  Map<String, dynamic> get _eligibility {
    final issues = <String>[];
    final passed = <String>[];
    final maxLoanable = _shareCapital * 2;
    final active = _myLoans.where((l) => l['status'] == 'Active').toList();
    final overdue = _myLoans.where((l) => l['status'] == 'Overdue').toList();
    final pending = _myLoans.where((l) => l['status'] == 'For Review').toList();
    // ── BAGO: "Approved" — na-approve na pero hindi pa na-"Confirm
    // Release" (waiting for the member to claim funds at the office).
    // Kailangan itong isama sa blocking statuses, dahil naka-block na
    // rin ito sa backend (status__in=['Active','For Review','Approved']).
    final approved = _myLoans.where((l) => l['status'] == 'Approved').toList();
    final completed = _myLoans.where((l) => l['status'] == 'Completed').toList();

    if (_shareCapital >= 4000) {
      passed.add('Share Capital: ${_peso(_shareCapital)} — Max Loanable: ${_peso(maxLoanable)}');
    } else {
      issues.add('Insufficient Share Capital. Current: ${_peso(_shareCapital)}. Minimum ₱4,000 required.');
    }
    if (overdue.isEmpty) {
      passed.add('No overdue loans');
    } else {
      issues.add('You have ${overdue.length} overdue loan(s): ${overdue.map((l) => l['loan_id']).join(', ')}. Please settle them first.');
    }
    // ── BAGO: hiwalay ang message para sa "Approved" (for release)
    // laban sa "Active"/"For Review" — iba ang kailangang gawin ng
    // member sa bawat isa. ─────────────────────────────────────────
    if (active.isEmpty && approved.isEmpty && pending.isEmpty) {
      passed.add('No existing active or pending loans');
    } else {
      if (approved.isNotEmpty) {
        issues.add('📦 You have ${approved.length} approved loan(s) ready for release: ${approved.map((l) => l['loan_id']).join(', ')}. Please visit the LEAF MPC office to claim your funds first.');
      }
      final activePending = [...active, ...pending];
      if (activePending.isNotEmpty) {
        issues.add('You have ${activePending.length} active/pending loan(s): ${activePending.map((l) => l['loan_id']).join(', ')}. Complete them before applying for a new one.');
      }
    }
    if (completed.isNotEmpty) passed.add('Good payment history: ${completed.length} completed loan(s)');

    return {'eligible': issues.isEmpty, 'issues': issues, 'passed': passed, 'maxLoanable': maxLoanable, 'approvedLoans': approved};
  }

  // ── Loan Recommendation Engine — parehong logic sa web ──────────────
  Map<String, dynamic> get _recommendation {
    final maxLoanable = _shareCapital * 2;
    final completed = _myLoans.where((l) => l['status'] == 'Completed').length;
    final hasGoodHistory = completed > 0;

    double recAmtPct = hasGoodHistory ? 0.8 : 0.5;
    double recAmount = (maxLoanable * recAmtPct / 1000).floor() * 1000;
    recAmount = recAmount.clamp(3000, maxLoanable == 0 ? 3000 : maxLoanable);

    final rate = recAmount <= 50000 ? 0.0125 : recAmount <= 150000 ? 0.01125 : 0.01;
    final maxMonthly = _monthlyIncome * 0.30;
    int recTerm = 12;
    if (_monthlyIncome > 0) {
      final denominator = maxMonthly - (rate * recAmount);
      if (denominator > 0) {
        final rawTerm = (recAmount / denominator).ceil();
        const availTerms = [3, 6, 9, 12, 18, 24, 36, 48];
        recTerm = availTerms.firstWhere((t) => t >= rawTerm, orElse: () => 48);
      } else {
        recTerm = 48;
      }
    }

    String recType = 'Regular Loan';
    if (_classification == 'Student') recType = 'Emergency Loan';
    if (_classification == 'Senior') recType = 'Regular Loan';
    if (_classification == 'Employed') recType = _monthlyIncome >= 15000 ? 'Salary Loan' : 'Regular Loan';

    final interest = rate * recAmount * recTerm;
    final monthlyDue = (recAmount + interest) / recTerm;
    final debtRatio = _monthlyIncome > 0 ? (monthlyDue / _monthlyIncome) * 100 : 0.0;

    return {
      'amount': recAmount, 'term': recTerm, 'type': recType,
      'monthlyDue': monthlyDue.round(), 'debtRatio': debtRatio.round(),
      'maxLoanable': maxLoanable, 'monthlyIncome': _monthlyIncome,
    };
  }

  double get _amount => double.tryParse(_amountCtrl.text) ?? 0;
  Map<String, dynamic>? get _selectedType => _selType == null ? null : kLoanTypes.firstWhere((t) => t['type'] == _selType);
  double get _monthlyRate => _amount <= 50000 ? 0.0125 : _amount <= 150000 ? 0.01125 : 0.01;
  double get _interest => _monthlyRate * _amount * _term;
  double get _serviceFee => _amount * 0.03;
  double get _filingFee => _amount <= 50000 ? 50 : 100;
  double get _insurance => _amount * 0.0125;
  double get _sd => _amount * 0.01;
  double get _sc => _amount * 0.03;
  double get _totalDed => _interest + _serviceFee + _filingFee + _insurance + _sd + _sc;
  double get _netProceeds => _amount - _totalDed;
  double get _monthlyEst => _amount > 0 ? (_amount + _interest) / _term : 0;

  Map<String, String> _validate() {
    final e = <String, String>{};
    final maxLoanable = (_eligibility['maxLoanable'] as double);
    if (_amount < 3000) {
      e['amount'] = 'Minimum loan amount is ₱3,000.';
    } else if (_amount > maxLoanable) {
      e['amount'] = 'Amount exceeds your max loanable of ${_peso(maxLoanable)}.';
    }
    if (_purposeCtrl.text.trim().isEmpty) e['purpose'] = 'Purpose is required.';
    return e;
  }

  // ── BAGO: buksan ang form sa edit mode, prefilled ng existing data
  // ng loan. Kino-check muna ang pinakabagong status bago buksan —
  // dahil posibleng na-approve na ito ng admin sa likod habang naka-
  // open ang page (stale na yung dating fetched list). ────────────────
  Future<void> _handleEditClick(dynamic loan) async {
    setState(() { _checkingId = loan['id']; _staleNotice = ''; });
    final loans = await _refreshLoans();
    final fresh = loans.firstWhere((l) => l['id'] == loan['id'], orElse: () => null);
    if (mounted) setState(() => _checkingId = null);
    if (fresh == null || fresh['status'] != 'For Review') {
      if (mounted) {
        setState(() => _staleNotice = '${loan['loan_id']} is no longer "For Review" (current status: ${fresh != null ? fresh['status'] : 'unknown'}). Your loan list has been refreshed.');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _editingId = fresh['id'];
      _selType = fresh['loan_type'];
      _amountCtrl.text = '${(double.tryParse('${fresh['amount']}') ?? 0).round()}'; // ── buong numero lang
      _term = int.tryParse('${fresh['term_months']}') ?? 12;
      _purposeCtrl.text = fresh['purpose'] ?? '';
      _collateralCtrl.text = fresh['collateral'] ?? '';
      _noteCtrl.text = '';
      _errors.clear();
      _formError = '';
      _step = 2;
      _showHistory = false;
    });
  }

  void _handleCancelEdit() {
    setState(() {
      _editingId = null;
      _step = 1; _selType = null;
      _amountCtrl.clear(); _term = 12; _purposeCtrl.clear(); _collateralCtrl.clear(); _noteCtrl.clear();
      _errors.clear();
      _formError = '';
    });
  }

  // ── BAGO: parehong freshness check bago buksan ang Cancel confirm,
  // saka lang lalabas ang "Are you sure?" dialog. ─────────────────────
  Future<void> _handleCancelClick(dynamic loan) async {
    setState(() { _checkingId = loan['id']; _staleNotice = ''; });
    final loans = await _refreshLoans();
    final fresh = loans.firstWhere((l) => l['id'] == loan['id'], orElse: () => null);
    if (mounted) setState(() => _checkingId = null);
    if (fresh == null || fresh['status'] != 'For Review') {
      if (mounted) {
        setState(() => _staleNotice = '${loan['loan_id']} is no longer "For Review" (current status: ${fresh != null ? fresh['status'] : 'unknown'}). Your loan list has been refreshed.');
      }
      return;
    }
    if (!mounted) return;
    _showCancelDialog(fresh);
  }

  // ── BAGO: "Are you sure?" confirmation bago talaga i-cancel ────────
  void _showCancelDialog(dynamic loan) {
    bool cancelling = false;
    String cancelError = '';
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(builder: (context, setSt) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('⚠️ Cancel this application?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _LAColors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(style: const TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.5), children: [
                const TextSpan(text: 'Are you sure you want to cancel '),
                TextSpan(text: '${loan['loan_id']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' (${_peso(double.tryParse('${loan['amount'] ?? 0}') ?? 0)})? This cannot be undone.'),
              ])),
              if (cancelError.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)),
                  child: Text(cancelError, style: const TextStyle(fontSize: 12, color: _LAColors.red)),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Expanded(
              child: OutlinedButton(
                onPressed: cancelling ? null : () => Navigator.pop(context),
                child: const Text('No, keep it'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _LAColors.red, foregroundColor: Colors.white),
                onPressed: cancelling ? null : () async {
                  setSt(() => cancelling = true);
                  try {
                    await LoansService.updateLoanStatus(loan['id'], 'Cancelled');
                    final loans = await LoansService.getLoans();
                    if (mounted) setState(() => _myLoans = loans);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    setSt(() { cancelling = false; cancelError = 'Failed to cancel loan application.'; });
                  }
                },
                child: Text(cancelling ? 'Cancelling...' : 'Yes, cancel it'),
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _handleSubmit() async {
    // ── BAGO: kapag naka-edit mode, hindi kailangan ng eligibility
    // check ulit (existing application na 'to, hindi bagong apply). ──
    if (_editingId == null && !(_eligibility['eligible'] as bool)) return;
    final errs = _validate();
    if (errs.isNotEmpty) {
      setState(() => _errors..clear()..addAll(errs));
      return;
    }
    setState(() { _formError = ''; _submitting = true; });
    try {
      final payload = {
        'loan_type': _selType,
        'amount': _amount,
        'term_months': _term,
        'purpose': _purposeCtrl.text.trim(),
        'collateral': _collateralCtrl.text.trim(),
      };
      if (_editingId != null) {
        // ── BAGO: generic update — hindi status change, kundi
        // pag-edit ng loan details habang "For Review" pa. ──────────
        await LoansService.updateLoan(_editingId, payload);
        final loans = await LoansService.getLoans();
        if (mounted) {
          setState(() {
            _myLoans = loans;
            _editedNotice = true;
            _editingId = null;
            _submitting = false;
          });
        }
      } else {
        await LoansService.createLoan(payload);
        final loans = await LoansService.getLoans();
        if (mounted) {
          setState(() {
            _myLoans = loans;
            _submitted = true;
            _submitting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _formError = 'Failed to submit application.';
        });
      }
    }
  }

  Future<void> _openLoanDetail(dynamic loan) async {
    List<dynamic> payments = [];
    bool loading = true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setSt) {
        if (loading) {
          PaymentsService.getPayments().then((all) {
            payments = all.where((p) => p['loan_code'] == loan['loan_id']).toList();
            loading = false;
            setSt(() {});
          }).catchError((_) { loading = false; setSt(() {}); });
        }
        final st = kStatusMeta[loan['status']] ?? {'bg': const Color(0xFFF5F5F5), 'color': const Color(0xFF888888), 'label': loan['status']};
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${loan['loan_id']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _LAColors.dark)),
                          Text('${loan['loan_type']} · Applied ${'${loan['applied_at'] ?? ''}'.split('T').first}', style: const TextStyle(fontSize: 10.5, color: _LAColors.sub)),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => Navigator.pop(context)),
                  ]),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: const Color(0xFFF9FEF9),
                  child: Wrap(spacing: 16, runSpacing: 8, children: [
                    _MiniStat('Amount', _peso(double.tryParse('${loan['amount'] ?? 0}') ?? 0)),
                    _MiniStat('Balance', _peso(double.tryParse('${loan['balance'] ?? 0}') ?? 0)),
                    _MiniStat('Monthly Due', _peso(double.tryParse('${loan['monthly_due'] ?? 0}') ?? 0)),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('STATUS', style: TextStyle(fontSize: 9, color: _LAColors.sub, fontWeight: FontWeight.w700)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: st['bg'] as Color, borderRadius: BorderRadius.circular(20)), child: Text('${st['label']}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: st['color'] as Color))),
                    ]),
                  ]),
                ),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator(color: _LAColors.green))
                      : payments.isEmpty
                          ? const Center(child: Text('No payments recorded yet.', style: TextStyle(color: _LAColors.sub)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: payments.length,
                              itemBuilder: (context, i) {
                                final p = payments[i];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(children: [
                                    Expanded(child: Text('${p['paid_at'] ?? ''}'.split('T').first, style: const TextStyle(fontSize: 11, color: Color(0xFF555555)))),
                                    Text(_peso(double.tryParse('${p['amount'] ?? 0}') ?? 0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _LAColors.green)),
                                  ]),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile || _loadingLoans) {
      return const MemberScreenScaffold(activeRouteKey: 'apply-loan', body: Center(child: CircularProgressIndicator(color: _LAColors.green)));
    }
    if (_submitted) return MemberScreenScaffold(activeRouteKey: 'apply-loan', body: _buildSuccess());
    if (_editedNotice) return MemberScreenScaffold(activeRouteKey: 'apply-loan', body: _buildEditedSuccess());

    return MemberScreenScaffold(activeRouteKey: 'apply-loan', body: _buildForm());
  }

  Widget _buildSuccess() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _LAColors.border)),
        child: Column(children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Application Submitted!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _LAColors.dark)),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(style: const TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.7), children: [
              TextSpan(text: 'Your '), TextSpan(text: '$_selType', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ' application for '), TextSpan(text: _peso(_amount), style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ' has been submitted.\n\nThe admin will review your application and notify you of the result.'),
            ]),
            textAlign: TextAlign.center,
          ),
          if (_myLoans.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF9FEF9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE8F5E9))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('📋 Your Loan Applications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _LAColors.green)),
                  ..._myLoans.map((l) => _LoanHistoryItem(loan: l, onTap: () => _openLoanDetail(l))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _LAColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () {
                setState(() {
                  _step = 1; _selType = null; _submitted = false;
                  _amountCtrl.clear(); _term = 12; _purposeCtrl.clear(); _collateralCtrl.clear(); _noteCtrl.clear();
                });
              },
              child: const Text('Submit Another Application', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── BAGO: Edit Success Screen — hiwalay sa "Submitted" screen ──────
  Widget _buildEditedSuccess() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _LAColors.border)),
        child: Column(children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Application Updated!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _LAColors.dark)),
          const SizedBox(height: 10),
          const Text(
            'Your loan application has been updated and is still For Review.\n\nThe admin will review your updated application.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.7),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _LAColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () {
                setState(() {
                  _editedNotice = false;
                  _step = 1; _selType = null;
                  _amountCtrl.clear(); _term = 12; _purposeCtrl.clear(); _collateralCtrl.clear(); _noteCtrl.clear();
                });
              },
              child: const Text('Back to Apply for Loan', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildForm() {
    final elig = _eligibility;
    final eligible = elig['eligible'] as bool;
    final approvedLoans = elig['approvedLoans'] as List;
    final rec = _recommendation;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Apply for Loan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _LAColors.dark)),
          const Text('Submit a loan application online. Admin will review and notify you.', style: TextStyle(fontSize: 11, color: _LAColors.sub)),
          const SizedBox(height: 14),

          // ── BAGO: lalabas kapag nag-attempt mag-edit/cancel ng loan
          // na hindi na pala "For Review" (na-approve na sa likod). ──
          if (_staleNotice.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), border: Border.all(color: const Color(0xFFFFB74D)), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Expanded(child: Text('⚠️ $_staleNotice', style: const TextStyle(fontSize: 11.5, color: Color(0xFF7A4A00)))),
                InkWell(onTap: () => setState(() => _staleNotice = ''), child: const Icon(Icons.close, size: 16, color: Color(0xFF7A4A00))),
              ]),
            ),
            const SizedBox(height: 14),
          ],

          // ── BAGO: editing-mode indicator bar ──
          if (_editingId != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFE3F2FD), border: Border.all(color: const Color(0xFF90CAF9)), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('✏️ Editing your submitted application', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _LAColors.blue)),
                InkWell(onTap: _handleCancelEdit, child: const Text('Cancel Edit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _LAColors.blue, decoration: TextDecoration.underline))),
              ]),
            ),
            const SizedBox(height: 14),
          ],

          // ── BAGO: prominent na banner — makikita agad kung may loan
          // na approved at ready for release. ─────────────────────────
          if (approvedLoans.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)]), border: Border.all(color: const Color(0xFFFFB74D)), borderRadius: BorderRadius.circular(12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📦', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      approvedLoans.length == 1
                          ? 'Your loan ${approvedLoans.first['loan_id']} is approved and ready for release!'
                          : 'You have ${approvedLoans.length} approved loans ready for release!',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFE65100)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Visit the LEAF MPC office (Mon–Fri, 8:00 AM – 5:00 PM) to claim ${approvedLoans.length == 1 ? 'your ${_peso(double.tryParse('${approvedLoans.first['amount'] ?? 0}') ?? 0)} loan proceeds' : 'your loan proceeds'} and sign the necessary documents.',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF7A4A00), height: 1.4),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
          ],

          // ── Eligibility ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: eligible ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12), border: Border.all(color: eligible ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(eligible ? Icons.check_circle : Icons.cancel, size: 18, color: eligible ? _LAColors.green : _LAColors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(eligible ? 'You are eligible to apply for a loan' : 'You are not eligible to apply at this time', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: eligible ? _LAColors.dark : _LAColors.red))),
                ]),
                const SizedBox(height: 8),
                ...(elig['passed'] as List<String>).map((p) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.check_circle, size: 12, color: _LAColors.green), const SizedBox(width: 6), Expanded(child: Text(p, style: const TextStyle(fontSize: 11.5, color: _LAColors.green)))]))),
                ...(elig['issues'] as List<String>).map((issue) => Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEF9A9A))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.warning_amber_rounded, size: 13, color: _LAColors.red),
                        const SizedBox(width: 6),
                        Expanded(child: Text(issue, style: const TextStyle(fontSize: 11.5, color: _LAColors.red))),
                      ]),
                    )),
                const SizedBox(height: 10),
                // ── BAGO: hiwalay na "Active Loans" (Active/Overdue lang)
                // at "For Release" (Approved lang) — dating pinagsama,
                // na mali/nakakalito dahil "Approved" pa lang, hindi pa
                // talaga "Active". ─────────────────────────────────────
                Wrap(spacing: 10, runSpacing: 8, children: [
                  _StatChip('Share Capital', _peso(_shareCapital), _LAColors.dark),
                  _StatChip('Max Loanable (×2)', _peso(elig['maxLoanable'] as double), _LAColors.blue),
                  _StatChip('Active Loans', '${_myLoans.where((l) => ['Active', 'Overdue'].contains(l['status'])).length}', _myLoans.where((l) => ['Active', 'Overdue'].contains(l['status'])).isNotEmpty ? _LAColors.red : _LAColors.green),
                  _StatChip('For Release', '${approvedLoans.length}', approvedLoans.isNotEmpty ? const Color(0xFFE65100) : _LAColors.green),
                  _StatChip('Completed Loans', '${_myLoans.where((l) => l['status'] == 'Completed').length}', _LAColors.green),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Recommendation ───────────────────────────────────────
          if (eligible) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_LAColors.dark, _LAColors.green]), borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Text('💡', style: TextStyle(fontSize: 16))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Loan Recommendation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                          Text('Based on your share capital${rec['monthlyIncome'] > 0 ? ' and monthly income' : ''}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10.5)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _RecCard(icon: '📋', label: 'Recommended Type', value: '${rec['type']}', sub: 'Best for your profile')),
                    const SizedBox(width: 8),
                    Expanded(child: _RecCard(icon: '💰', label: 'Recommended Amount', value: _peso(rec['amount']), sub: 'Max: ${_peso(rec['maxLoanable'])}')),
                  ]),
                  const SizedBox(height: 8),
                  _RecCard(icon: '📅', label: 'Recommended Term', value: '${rec['term']} months', sub: rec['monthlyIncome'] > 0 ? 'Monthly due: ${_peso(rec['monthlyDue'])}' : 'Based on loan amount'),
                  if (rec['monthlyIncome'] > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Debt-to-Income Ratio', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10.5)),
                              const SizedBox(height: 4),
                              ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: (rec['debtRatio'] / 100).clamp(0, 1), backgroundColor: Colors.white.withOpacity(0.2), color: rec['debtRatio'] <= 30 ? const Color(0xFF69F0AE) : rec['debtRatio'] <= 40 ? const Color(0xFFFFEB3B) : const Color(0xFFFF5252), minHeight: 6)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${rec['debtRatio']}%', style: TextStyle(color: rec['debtRatio'] <= 30 ? const Color(0xFF69F0AE) : rec['debtRatio'] <= 40 ? const Color(0xFFFFEB3B) : const Color(0xFFFF5252), fontSize: 16, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.95), foregroundColor: _LAColors.dark, padding: const EdgeInsets.symmetric(vertical: 11)),
                      onPressed: () {
                        setState(() {
                          _selType = rec['type'];
                          _amountCtrl.text = '${rec['amount']}';
                          _term = rec['term'];
                          _step = 2;
                        });
                      },
                      child: const Text('Apply Recommended Loan →', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Loan History ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _LAColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => setState(() => _showHistory = !_showHistory),
                  child: Row(children: [
                    Expanded(child: Text('📋 My Loan Applications (${_myLoans.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _LAColors.dark))),
                    Text(_showHistory ? '▲ Hide' : '▼ Show', style: const TextStyle(fontSize: 11, color: _LAColors.sub)),
                  ]),
                ),
                if (_showHistory) ...[
                  const SizedBox(height: 10),
                  if (_myLoans.isEmpty)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: Text('No loan applications yet.', style: TextStyle(color: _LAColors.sub))))
                  else
                    // ── BAGO: Edit/Cancel buttons — lalabas lang kapag
                    // "For Review" ang status ng partikular na loan. ──
                    ..._myLoans.map((l) => _LoanHistoryItem(
                          loan: l,
                          onTap: () => _openLoanDetail(l),
                          onEdit: () => _handleEditClick(l),
                          onCancel: () => _handleCancelClick(l),
                          checking: _checkingId == l['id'],
                        )),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Block if not eligible — HUWAG i-block kapag naka-edit
          // mode, dahil ang mismong loan na ino-edit ang siyang
          // nagdudulot ng "may pending ka na" na eligibility issue. ──
          if (!eligible && _editingId == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFCC80))),
              child: Column(children: const [
                Icon(Icons.warning_amber_rounded, size: 36, color: Color(0xFFE65100)),
                SizedBox(height: 8),
                Text('Cannot Apply for a New Loan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFFE65100))),
                SizedBox(height: 8),
                Text('Please resolve the issues listed above before applying for a new loan. Visit the LEAF MPC office for assistance.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.6)),
              ]),
            )
          else ...[
            // ── Step indicator ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _LAColors.border)),
              child: Row(children: [
                Expanded(child: _StepIndicator(label: 'Type', num: 1, current: _step)),
                Expanded(child: _StepIndicator(label: 'Details', num: 2, current: _step)),
                Expanded(child: _StepIndicator(label: 'Review', num: 3, current: _step)),
              ]),
            ),
            const SizedBox(height: 14),

            if (_step == 1) _buildStep1(),
            if (_step == 2 && _selectedType != null) _buildStep2(),
            if (_step == 3) _buildStep3(),
          ],
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _LAColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose Loan Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _LAColors.dark)),
          const SizedBox(height: 14),
          ...kLoanTypes.map((lt) {
            final selected = _selType == lt['type'];
            return InkWell(
              onTap: () => setState(() => _selType = lt['type'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: selected ? lt['bg'] as Color : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? lt['border'] as Color : _LAColors.border, width: selected ? 1.5 : 1)),
                child: Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: lt['bg'] as Color, borderRadius: BorderRadius.circular(12), border: Border.all(color: lt['border'] as Color)), child: Icon(lt['icon'] as IconData, color: lt['color'] as Color, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${lt['type']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _LAColors.dark)),
                        Text('${lt['desc']}', style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                        Text('Up to ${_peso(lt['maxAmt'])} · ${lt['maxTerm']} months max', style: const TextStyle(fontSize: 10, color: _LAColors.sub, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle, color: lt['color'] as Color, size: 20),
                ]),
              ),
            );
          }),
          const SizedBox(height: 6),
          if (_editingId != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: _LAColors.red, side: const BorderSide(color: Color(0xFFEF9A9A)), padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: _handleCancelEdit,
                child: const Text('Cancel Edit', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _LAColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: _selType == null ? null : () => setState(() => _step = 2),
              child: const Text('Next: Loan Details →', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    final type = _selectedType!;
    final maxLoanable = _eligibility['maxLoanable'] as double;
    final availTerms = [3, 6, 9, 12, 18, 24, 36, 48].where((t) => t <= (type['maxTerm'] as int)).toList();
    final showComp = _amount >= 3000 && _selType != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _LAColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: type['bg'] as Color, borderRadius: BorderRadius.circular(10), border: Border.all(color: type['border'] as Color)), child: Icon(type['icon'] as IconData, color: type['color'] as Color, size: 18)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Loan Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _LAColors.dark)),
              Text('${type['type']}', style: const TextStyle(fontSize: 11, color: _LAColors.sub)),
            ]),
          ]),
          const SizedBox(height: 16),

          Text.rich(TextSpan(text: 'LOAN AMOUNT (₱)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.4), children: const [TextSpan(text: ' *', style: TextStyle(color: _LAColors.red))])),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            // ── Hindi na basta-basta makakatype nang lalampas sa max
            // loanable — hinaharang ang bagong digit kapag lalabas ang
            // resulta sa itaas ng limitasyon (walang auto-clamp, basta
            // itatanggi lang ang keystroke, gaya rin ng ginawa sa web).
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _MaxAmountFormatter(() => maxLoanable),
            ],
            onChanged: (_) { setState(() => _errors.remove('amount')); },
            decoration: InputDecoration(prefixText: '₱ ', hintText: 'Min ₱3,000 — Max ${_peso(maxLoanable)}', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _errors['amount'] != null ? _LAColors.red : const Color(0xFFE0E0E0))), errorText: _errors['amount']),
          ),
          Padding(padding: const EdgeInsets.only(top: 4), child: Text.rich(TextSpan(text: 'Max loanable: ', style: const TextStyle(fontSize: 10, color: Color(0xFF888888)), children: [TextSpan(text: _peso(maxLoanable), style: const TextStyle(color: _LAColors.blue, fontWeight: FontWeight.w700)), const TextSpan(text: ' (Share Capital × 2)')]))),
          const SizedBox(height: 14),

          const Text('LOAN TERM', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.4)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            value: availTerms.contains(_term) ? _term : availTerms.first,
            items: availTerms.map((t) => DropdownMenuItem(value: t, child: Text('$t months'))).toList(),
            onChanged: (v) => setState(() => _term = v ?? 12),
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          ),
          const SizedBox(height: 14),

          Text.rich(TextSpan(text: 'PURPOSE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.4), children: const [TextSpan(text: ' *', style: TextStyle(color: _LAColors.red))])),
          const SizedBox(height: 6),
          TextField(
            controller: _purposeCtrl,
            maxLines: 3,
            onChanged: (_) => setState(() => _errors.remove('purpose')),
            decoration: InputDecoration(hintText: 'Describe the purpose of your loan...', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _errors['purpose'] != null ? _LAColors.red : const Color(0xFFE0E0E0))), errorText: _errors['purpose']),
          ),
          const SizedBox(height: 14),

          const Text('COLLATERAL (IF ANY)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.4)),
          const SizedBox(height: 6),
          TextField(controller: _collateralCtrl, decoration: InputDecoration(hintText: 'e.g. Land title, vehicle', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 14),

          const Text('ADDITIONAL NOTES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.4)),
          const SizedBox(height: 6),
          TextField(controller: _noteCtrl, decoration: InputDecoration(hintText: 'Optional', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),

          if (showComp) ...[
            const SizedBox(height: 16),
            _buildComputation(),
          ],

          const SizedBox(height: 16),
          if (_editingId != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: _LAColors.red, side: const BorderSide(color: Color(0xFFEF9A9A))),
                onPressed: _handleCancelEdit,
                child: const Text('Cancel Edit', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), child: const Text('← Back'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _LAColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () {
                  final e = _validate();
                  if (e.isNotEmpty) { setState(() => _errors..clear()..addAll(e)); return; }
                  setState(() => _step = 3);
                },
                child: const Text('Next: Review →', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildComputation() {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFC8E6C9))),
      child: Column(
        children: [
          Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), color: _LAColors.dark, child: const Text('🧮 Loan Computation (LEAF MPC)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFF1F8E9),
            child: Column(children: [
              _CompRow('Interest Rate', '${(_monthlyRate * 100).toStringAsFixed(3)}% / mo × $_term months'),
              _CompRow('Total Interest', '₱${_interest.toStringAsFixed(2)}', color: const Color(0xFFE65100)),
              const Divider(height: 16),
              _CompRow('Monthly Amortization', '₱${_monthlyEst.toStringAsFixed(2)}', color: _LAColors.green, bold: true),
            ]),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💰 Upfront Deductions (from Loan Release)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
                const SizedBox(height: 6),
                _CompRow('Loan Amount', _peso(_amount)),
                const Divider(height: 12),
                _CompRow('Interest (${(_monthlyRate * 100)}% × $_term mos)', '− ₱${_interest.toStringAsFixed(2)}', color: _LAColors.red),
                _CompRow('Service Fee (3%)', '− ₱${_serviceFee.toStringAsFixed(2)}', color: _LAColors.red),
                _CompRow('Filing Fee', '− ₱${_filingFee.toStringAsFixed(2)}', color: _LAColors.red),
                _CompRow('Insurance (1.25%)', '− ₱${_insurance.toStringAsFixed(2)}', color: _LAColors.red),
                _CompRow('Savings Deposit (1%)', '− ₱${_sd.toStringAsFixed(2)}', color: _LAColors.red),
                _CompRow('Share Capital CBU (3%)', '− ₱${_sc.toStringAsFixed(2)}', color: _LAColors.red),
                const Divider(height: 12),
                _CompRow('Total Deductions', '− ₱${_totalDed.toStringAsFixed(2)}', color: _LAColors.red, bold: true),
                _CompRow('Net Proceeds (actual release)', '₱${_netProceeds.toStringAsFixed(2)}', color: _LAColors.green, bold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    final type = _selectedType;
    final rows = [
      ['Loan Type', '$_selType'],
      ['Amount', _peso(_amount)],
      ['Term', '$_term months'],
      ['Interest Rate', '${(_monthlyRate * 100).toStringAsFixed(3)}% / month'],
      ['Total Interest', '₱${_interest.toStringAsFixed(2)}'],
      ['Monthly Amort.', '₱${_monthlyEst.toStringAsFixed(2)}'],
      ['Net Proceeds', '₱${_netProceeds.toStringAsFixed(2)}'],
      ['Purpose', _purposeCtrl.text],
      ['Collateral', _collateralCtrl.text.isEmpty ? 'None' : _collateralCtrl.text],
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _LAColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (type != null) Container(width: 40, height: 40, decoration: BoxDecoration(color: type['bg'] as Color, borderRadius: BorderRadius.circular(10), border: Border.all(color: type['border'] as Color)), child: Icon(type['icon'] as IconData, color: type['color'] as Color, size: 18)),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Review Application', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _LAColors.dark)),
                Text('Please verify all details before submitting', style: TextStyle(fontSize: 11, color: _LAColors.sub)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(border: Border.all(color: _LAColors.border), borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: List.generate(rows.length, (i) {
                final r = rows[i];
                final isGreen = r[0] == 'Amount' || r[0] == 'Net Proceeds';
                final isOrange = r[0] == 'Total Interest';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == rows.length - 1 ? Colors.transparent : const Color(0xFFF5F5F5)))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(r[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA), fontWeight: FontWeight.w600)),
                    Flexible(child: Text(r[1], textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: isGreen ? _LAColors.green : isOrange ? const Color(0xFFE65100) : const Color(0xFF222222)))),
                  ]),
                );
              }),
            ),
          ),
          // ── BAGO: API-level error (hal. "must be For Review" kung
          // na-approve na ito sa likod bago pa na-submit) — hiwalay sa
          // per-field errors. ──────────────────────────────────────
          if (_formError.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFEF9A9A))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: _LAColors.red),
                const SizedBox(width: 6),
                Expanded(child: Text(_formError, style: const TextStyle(fontSize: 12.5, color: _LAColors.red))),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBBDEFB))),
            child: const Text('📋 By submitting, you confirm that all information provided is accurate. The admin will evaluate your application and notify you of the result.', style: TextStyle(fontSize: 11.5, color: _LAColors.blue, height: 1.5)),
          ),
          const SizedBox(height: 16),
          if (_editingId != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: _LAColors.red, side: const BorderSide(color: Color(0xFFEF9A9A))),
                onPressed: _submitting ? null : _handleCancelEdit,
                child: const Text('Cancel Edit', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _submitting ? null : () => setState(() => _step = 2), child: const Text('← Back'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _LAColors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: _submitting ? null : _handleSubmit,
                child: _submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_editingId != null ? 'Update Application' : 'Submit Application', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final String label;
  final int num;
  final int current;
  const _StepIndicator({required this.label, required this.num, required this.current});

  @override
  Widget build(BuildContext context) {
    final active = current >= num;
    final done = current > num;
    return Column(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(shape: BoxShape.circle, color: done ? _LAColors.green : active ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5), border: Border.all(color: done ? _LAColors.green : active ? const Color(0xFFC8E6C9) : const Color(0xFFE0E0E0), width: 1.5)),
        alignment: Alignment.center,
        child: done ? const Icon(Icons.check, size: 14, color: Colors.white) : Text('$num', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? _LAColors.green : const Color(0xFFBBBBBB))),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? _LAColors.dark : const Color(0xFFBBBBBB))),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.75), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: Color(0xFF666666), fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

class _RecCard extends StatelessWidget {
  final String icon, label, value, sub;
  const _RecCard({required this.icon, required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(sub, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.5))),
        ],
      ),
    );
  }
}

class _CompRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  final bool bold;
  const _CompRow(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: color ?? const Color(0xFF555555), fontWeight: bold ? FontWeight.w700 : FontWeight.normal))),
        Text(value, style: TextStyle(fontSize: bold ? 13 : 11, color: color ?? const Color(0xFF555555), fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, color: _LAColors.sub, fontWeight: FontWeight.w700)),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _LAColors.dark)),
    ]);
  }
}

class _LoanHistoryItem extends StatelessWidget {
  final dynamic loan;
  final VoidCallback onTap;
  // ── BAGO: optional na Edit/Cancel callbacks — kapag walang laman
  // (hal. sa Success screen), hindi lalabas ang mga buttons kahit
  // "For Review" ang status. ──────────────────────────────────────
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final bool checking;
  const _LoanHistoryItem({required this.loan, required this.onTap, this.onEdit, this.onCancel, this.checking = false});

  @override
  Widget build(BuildContext context) {
    final st = kStatusMeta[loan['status']] ?? {'bg': const Color(0xFFF5F5F5), 'color': const Color(0xFF888888), 'label': loan['status']};
    final canManage = loan['status'] == 'For Review' && onEdit != null && onCancel != null;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F4F1)))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${loan['loan_id']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _LAColors.green, fontFamily: 'monospace')),
                    Text('${loan['loan_type']}', style: const TextStyle(fontSize: 12, color: Color(0xFF555555))),
                    Text('${'${loan['applied_at'] ?? ''}'.split('T').first}', style: const TextStyle(fontSize: 10.5, color: _LAColors.sub)),
                  ],
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_peso(double.tryParse('${loan['amount'] ?? 0}') ?? 0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _LAColors.dark)),
                const SizedBox(height: 3),
                Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2), decoration: BoxDecoration(color: st['bg'] as Color, borderRadius: BorderRadius.circular(20)), child: Text('${st['label']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: st['color'] as Color))),
              ]),
            ]),
            if (canManage)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  OutlinedButton(
                    onPressed: checking ? null : onEdit,
                    style: OutlinedButton.styleFrom(foregroundColor: _LAColors.blue, side: const BorderSide(color: Color(0xFF90CAF9)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text(checking ? 'Checking...' : 'Edit', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: checking ? null : onCancel,
                    style: OutlinedButton.styleFrom(foregroundColor: _LAColors.red, side: const BorderSide(color: Color(0xFFEF9A9A)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text(checking ? 'Checking...' : 'Cancel', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

// ── totoong implementation ng _MaxAmountFormatter — habang nagta-type,
// kapag ang resultang numero ay lalampas sa max loanable, awtomatikong
// hinaharang ang bagong digit (babalik sa dating value, hindi ito
// papasok). Pareho ito ngayon sa final na behavior ng web version. ──
class _MaxAmountFormatter extends TextInputFormatter {
  final double Function() getMax;
  _MaxAmountFormatter(this.getMax);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final parsed = double.tryParse(newValue.text);
    if (parsed == null) return oldValue;
    final max = getMax();
    if (max > 0 && parsed > max) return oldValue;
    return newValue;
  }
}