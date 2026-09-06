import 'package:flutter/material.dart';
import '../../services/members_service.dart';
import '../../widgets/admin/admin_scaffold_helpers.dart';

class _SCColors {
  static const blue = Color(0xFF1565C0);
  static const dark = Color(0xFF1B5E20);
  static const sub  = Color(0xFF888888);
  static const green = Color(0xFF2E7D32);
}

class ShareCapitalDepositScreen extends StatefulWidget {
  const ShareCapitalDepositScreen({super.key});

  @override
  State<ShareCapitalDepositScreen> createState() => _ShareCapitalDepositScreenState();
}

class _ShareCapitalDepositScreenState extends State<ShareCapitalDepositScreen> {
  String _mainTab = 'new';
  int _step = 1;

  List<dynamic> _members = [];
  bool _fetching = true;
  String _search = '';
  dynamic _selected;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _error;
  bool _saving = false;
  bool _done = false;

  List<dynamic> _history = [];
  bool _histLoading = false;
  String _histSearch = '';
  // ── BAGO: dating flat na listahan lang — ngayon naka-group per
  // member, i-tap para makita ang kanilang mga record. ────────────────
  String? _expandedMember;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final data = await MembersService.getMembers();
      if (mounted) setState(() => _members = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _histLoading = true);
    try {
      final data = await MembersService.getAllShareCapitalHistory();
      if (mounted) setState(() => _history = data);
    } catch (_) {
      if (mounted) setState(() => _history = []);
    } finally {
      if (mounted) setState(() => _histLoading = false);
    }
  }

  double get _currentSC => double.tryParse('${_selected?['share_capital'] ?? 0}') ?? 0;
  double get _parsed => double.tryParse(_amountCtrl.text) ?? 0;
  double get _newSC => _currentSC + _parsed;
  // ── FIX: dating naka-hardcode na "_newSC * 2" — hindi ginagamit
  // ang totoong Loan Multiplier (1x/2x/3x) ng partikular na member. ──
  double get _newMaxLoan => _newSC * (double.tryParse('${_selected?['loan_multiplier'] ?? 1}') ?? 1);
  bool get _isValid => _parsed > 0 && _selected != null;

  Future<void> _handleSave() async {
    if (_parsed <= 0) { setState(() => _error = 'Enter a valid amount.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await MembersService.recordShareCapitalDeposit(_selected['id'], {
        'amount': _parsed,
        'note': _noteCtrl.text.isEmpty ? 'Share capital deposit' : _noteCtrl.text,
        'txn_type': 'Deposit',
      });
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to record deposit.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<dynamic> get _filteredMembers => _members.where((m) {
        final q = _search.toLowerCase();
        return (m['fullname'] ?? '').toString().toLowerCase().contains(q) || (m['member_id'] ?? '').toString().toLowerCase().contains(q);
      }).toList();

  List<dynamic> get _filteredHistory => _history.where((t) {
        final q = _histSearch.toLowerCase();
        return (t['member_name'] ?? '').toString().toLowerCase().contains(q) || (t['member_id'] ?? '').toString().toLowerCase().contains(q);
      }).toList();

  // ── BAGO: i-group ang mga transaction per member. ────────────────
  List<Map<String, dynamic>> get _memberGroups {
    final Map<String, Map<String, dynamic>> groups = {};
    for (final t in _filteredHistory) {
      final key = '${t['member_id'] ?? t['member_name']}';
      groups.putIfAbsent(key, () => {
            'member_name': t['member_name'],
            'member_id': t['member_id'],
            'txs': <dynamic>[],
          });
      (groups[key]!['txs'] as List<dynamic>).add(t);
    }
    return groups.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    // ── FIX: dating sariling plain Scaffold+AppBar lang ito (walang
    // drawer) — kaya "back" arrow lang ang lumalabas, walang access sa
    // hamburger/drawer menu papunta sa ibang admin sections. Gamit na
    // ngayon ang parehong AdminScreenScaffold na ginagamit ng ibang
    // admin screens, para consistent ang navigation access. ──────────
    return AdminScreenScaffold(
      activeRouteKey: 'sharecap',
      title: 'Share Capital',
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _MainTab(label: 'New Deposit', active: _mainTab == 'new', color: _SCColors.blue, onTap: () => setState(() { _mainTab = 'new'; _done = false; _step = 1; _expandedMember = null; })),
                _MainTab(
                  label: 'History${_history.isNotEmpty ? " (${_history.length})" : ""}',
                  active: _mainTab == 'history',
                  color: _SCColors.blue,
                  onTap: () { setState(() { _mainTab = 'history'; _expandedMember = null; }); if (_history.isEmpty) _loadHistory(); },
                ),
              ],
            ),
          ),
          Expanded(child: _mainTab == 'new' ? _buildNewTab() : _buildHistoryTab()),
        ],
      ),
    );
  }

  Widget _buildNewTab() {
    if (_done) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_outlined, size: 44, color: _SCColors.blue),
            const SizedBox(height: 10),
            const Text('Share Capital Deposit Recorded!', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _SCColors.blue)),
            const SizedBox(height: 8),
            Text(
              '₱${_parsed.toStringAsFixed(0)} deposited for ${_selected['fullname']}.\nNew Share Capital: ₱${_newSC.toStringAsFixed(0)}\nNew Max Loanable: ₱${_newMaxLoan.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: _SCColors.sub, height: 1.6),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _SCColors.blue, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }

    if (_step == 1) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(hintText: 'Search by name or member ID...', prefixIcon: const Icon(Icons.search, size: 18), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
          Expanded(
            child: _fetching
                ? const Center(child: CircularProgressIndicator())
                : _filteredMembers.isEmpty
                    ? const Center(child: Text('No members found.', style: TextStyle(color: _SCColors.sub)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, i) {
                          final m = _filteredMembers[i];
                          final isSel = _selected != null && _selected['id'] == m['id'];
                          final sc = double.tryParse('${m['share_capital'] ?? 0}') ?? 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: isSel ? _SCColors.blue.withOpacity(0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => setState(() { _selected = m; _error = null; }),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isSel ? _SCColors.blue : const Color(0xFFE8EAE0), width: isSel ? 1.5 : 1),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
                                  ),
                                  child: Row(children: [
                                    CircleAvatar(radius: 20, backgroundColor: isSel ? _SCColors.blue : _SCColors.blue.withOpacity(0.15), child: Text('${m['fullname'] ?? 'M'}'.isNotEmpty ? '${m['fullname']}'[0].toUpperCase() : 'M', style: TextStyle(color: isSel ? Colors.white : _SCColors.blue, fontWeight: FontWeight.w800))),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${m['fullname']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text('${m['member_id']}', style: const TextStyle(fontSize: 10.5, color: _SCColors.blue, fontWeight: FontWeight.w600))])),
                                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('₱${sc.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _SCColors.blue)), const Text('share capital', style: TextStyle(fontSize: 8.5, color: Color(0xFFAAAAAA)))]),
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
              // ── FIX: tinanggal ang "Cancel" button — hindi na
              // kailangan, wala nang back arrow, at meron nang hamburger
              // menu papunta sa ibang sections. ────────────────────────
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _SCColors.blue, foregroundColor: Colors.white),
                  onPressed: _selected != null ? () => setState(() => _step = 2) : null,
                  child: const Text('Next →'),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF90CAF9))),
            child: Row(children: [
              CircleAvatar(backgroundColor: _SCColors.blue, child: Text('${_selected['fullname'] ?? 'M'}'.isNotEmpty ? '${_selected['fullname']}'[0].toUpperCase() : 'M', style: const TextStyle(color: Colors.white))),
              const SizedBox(width: 10),
              Expanded(child: Text('${_selected['fullname']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)), child: Column(children: [const Text('CURRENT SC', style: TextStyle(fontSize: 8, color: _SCColors.blue)), Text('₱${_currentSC.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0D47A1)))])),
            ]),
          ),
          const SizedBox(height: 14),
          const Text('Deposit Amount (₱) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _SCColors.sub)),
          const SizedBox(height: 6),
          TextField(controller: _amountCtrl, keyboardType: TextInputType.number, onChanged: (_) => setState(() => _error = null), decoration: InputDecoration(prefixText: '₱ ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
          const SizedBox(height: 12),
          const Text('Note (optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _SCColors.sub)),
          const SizedBox(height: 6),
          TextField(controller: _noteCtrl, decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), hintText: 'e.g. Additional share capital')),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 12))),
          ],
          if (_isValid) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4F0E5))),
              child: Column(children: [
                _PreviewRow('Current Share Capital', '₱${_currentSC.toStringAsFixed(0)}'),
                _PreviewRow('Deposit', '+ ₱${_parsed.toStringAsFixed(0)}', color: _SCColors.blue),
                const Divider(),
                _PreviewRow('New Share Capital', '₱${_newSC.toStringAsFixed(0)}', bold: true, color: _SCColors.blue),
                _PreviewRow('New Max Loanable', '₱${_newMaxLoan.toStringAsFixed(0)}', color: _SCColors.green),
              ]),
            ),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), child: const Text('← Back'))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _SCColors.blue, foregroundColor: Colors.white),
                onPressed: (!_isValid || _saving) ? null : _handleSave,
                child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Record Deposit'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final total = _history.fold<double>(0, (s, t) => s + (double.tryParse('${t['amount']}') ?? 0));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(child: _StatBox(label: 'Total Deposited', value: '₱${total.toStringAsFixed(0)}', color: _SCColors.blue, bg: const Color(0xFFE3F2FD))),
              const SizedBox(width: 8),
              Expanded(child: _StatBox(label: 'Transactions', value: '${_history.length}', color: _SCColors.green, bg: const Color(0xFFE8F5E9))),
            ]),
            const SizedBox(height: 10),
            TextField(onChanged: (v) => setState(() => _histSearch = v), decoration: InputDecoration(hintText: 'Search by member name or ID...', prefixIcon: const Icon(Icons.search, size: 18), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
          ]),
        ),
        Expanded(
          child: _histLoading
              ? const Center(child: CircularProgressIndicator())
              : _memberGroups.isEmpty
                  ? const Center(child: Text('No share capital transactions found.', style: TextStyle(color: _SCColors.sub)))
                  // ── BAGO: dating flat na ListView lang — ngayon
                  // naka-group per MEMBER, i-tap para makita ang
                  // kanilang mga record. ────────────────────────────
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _memberGroups.length,
                      itemBuilder: (context, i) {
                        final g = _memberGroups[i];
                        final txs = g['txs'] as List<dynamic>;
                        final code = '${g['member_id'] ?? g['member_name']}';
                        final isOpen = _expandedMember == code;
                        final memberTotal = txs.fold<double>(0, (s, t) => s + (double.tryParse('${t['amount']}') ?? 0));
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: isOpen ? _SCColors.blue : const Color(0xFFF0F0F0))),
                          child: Column(children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(() => _expandedMember = isOpen ? null : code),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  CircleAvatar(radius: 18, backgroundColor: const Color(0xFFE3F2FD), child: Text('${g['member_name'] ?? 'M'}'.isNotEmpty ? '${g['member_name']}'[0].toUpperCase() : 'M', style: const TextStyle(color: _SCColors.blue, fontWeight: FontWeight.w800))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('${g['member_name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      Text('$code · ${txs.length} transaction${txs.length != 1 ? 's' : ''}', style: const TextStyle(fontSize: 10, color: _SCColors.sub)),
                                    ]),
                                  ),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('+₱${memberTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _SCColors.blue)),
                                    const Text('total', style: TextStyle(fontSize: 8, color: Color(0xFFBBBBBB))),
                                  ]),
                                  Icon(isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: const Color(0xFFBBBBBB)),
                                ]),
                              ),
                            ),
                            if (isOpen)
                              Container(
                                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE3F2FD)))),
                                child: Column(
                                  children: txs.map<Widget>((t) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFFAFAFA)))),
                                      child: Row(children: [
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: _SCColors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text('${t['txn_type'] ?? 'Deposit'}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _SCColors.blue))),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text('${t['created_at'] ?? ''}${t['note'] != null && '${t['note']}'.isNotEmpty ? " · ${t['note']}" : ""}', style: const TextStyle(fontSize: 10, color: _SCColors.sub))),
                                        Text('+₱${(double.tryParse('${t['amount']}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: _SCColors.blue, fontSize: 12)),
                                      ]),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ]),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _MainTab extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _MainTab({required this.label, required this.active, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? color : Colors.transparent, width: 2))),
            child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? color : const Color(0xFFAAAAAA))),
          ),
        ),
      );
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _PreviewRow(this.label, this.value, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: bold ? 13 : 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? (color ?? const Color(0xFF1B5E20)) : const Color(0xFF555555))),
          Text(value, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: FontWeight.w700, color: color ?? const Color(0xFF333333))),
        ]),
      );
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _StatBox({required this.label, required this.value, required this.color, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          FittedBox(child: Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color))),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
        ]),
      );
}