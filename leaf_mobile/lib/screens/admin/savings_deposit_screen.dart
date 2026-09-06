import 'package:flutter/material.dart';
import '../../services/members_service.dart';
import '../../widgets/admin/admin_scaffold_helpers.dart';

class _SVColors {
  static const orange = Color(0xFFF57F17);
  static const dark   = Color(0xFF1B5E20);
  static const sub    = Color(0xFF888888);
  static const green  = Color(0xFF2E7D32);
  static const red    = Color(0xFFC62828);
}

class SavingsDepositScreen extends StatefulWidget {
  const SavingsDepositScreen({super.key});

  @override
  State<SavingsDepositScreen> createState() => _SavingsDepositScreenState();
}

class _SavingsDepositScreenState extends State<SavingsDepositScreen> {
  String _mainTab = 'new'; // new | history
  int _step = 1;

  List<dynamic> _members = [];
  bool _fetching = true;
  String _search = '';
  dynamic _selected;
  double _balance = 0;

  String _type = 'Deposit';
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _error;
  bool _saving = false;
  bool _done = false;

  List<dynamic> _history = [];
  bool _histLoading = false;
  String _histSearch = '';
  // ── BAGO: dating flat na listahan lang ng LAHAT ng transactions —
  // ngayon naka-group per member, makikita muna ang MEMBER, tapos
  // i-expand para makita ang kanilang mga record. ────────────────────
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
      final data = await MembersService.getAllSavingsHistory();
      if (mounted) setState(() => _history = data);
    } catch (_) {
      if (mounted) setState(() => _history = []);
    } finally {
      if (mounted) setState(() => _histLoading = false);
    }
  }

  Future<void> _selectMember(dynamic m) async {
    setState(() => _selected = m);
    try {
      final s = await MembersService.getMemberSavings('${m['id']}');
      if (mounted) setState(() => _balance = double.tryParse('${s['balance'] ?? 0}') ?? 0);
    } catch (_) {
      if (mounted) setState(() => _balance = 0);
    }
  }

  double get _parsed => double.tryParse(_amountCtrl.text) ?? 0;
  double get _newBalance => _type == 'Deposit' ? _balance + _parsed : _balance - _parsed;
  bool get _isValid => _parsed > 0 && _selected != null && (_type == 'Deposit' || _parsed <= _balance);

  Future<void> _handleSave() async {
    if (_parsed <= 0) { setState(() => _error = 'Enter a valid amount.'); return; }
    if (_type == 'Withdraw' && _parsed > _balance) { setState(() => _error = 'Insufficient balance. Current: ₱${_balance.toStringAsFixed(0)}'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await MembersService.recordSavings({
        'member': _selected['id'],
        'transaction_type': _type,
        'amount': _parsed,
        'note': _noteCtrl.text,
      });
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to record transaction.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<dynamic> get _filteredMembers => _members.where((m) {
        final q = _search.toLowerCase();
        final name = (m['fullname'] ?? '').toString().toLowerCase();
        final id = (m['member_id'] ?? '').toString().toLowerCase();
        return name.contains(q) || id.contains(q);
      }).toList();

  List<dynamic> get _filteredHistory => _history.where((tx) {
        final q = _histSearch.toLowerCase();
        final name = (tx['member_name'] ?? '').toString().toLowerCase();
        final code = (tx['member_code'] ?? '').toString().toLowerCase();
        return name.contains(q) || code.contains(q);
      }).toList();

  // ── BAGO: i-group ang mga transaction per member. ────────────────
  List<Map<String, dynamic>> get _memberGroups {
    final Map<String, Map<String, dynamic>> groups = {};
    for (final tx in _filteredHistory) {
      final key = '${tx['member_code'] ?? tx['member_name']}';
      groups.putIfAbsent(key, () => {
            'member_name': tx['member_name'],
            'member_code': tx['member_code'],
            'txs': <dynamic>[],
          });
      (groups[key]!['txs'] as List<dynamic>).add(tx);
    }
    return groups.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    // ── FIX: dating sariling plain Scaffold+AppBar lang ito (walang
    // drawer) — kaya "back" arrow lang ang lumalabas, walang access sa
    // hamburger/drawer menu papunta sa ibang admin sections. Gamit na
    // ngayon ang parehong AdminScreenScaffold na ginagamit ng ibang
    // admin screens (Manage Members, atbp.), para consistent ang
    // navigation access. ─────────────────────────────────────────────
    return AdminScreenScaffold(
      activeRouteKey: 'savings',
      title: 'Savings Transaction',
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _MainTab(label: 'New Transaction', active: _mainTab == 'new', color: _SVColors.orange, onTap: () => setState(() { _mainTab = 'new'; _done = false; _step = 1; _expandedMember = null; })),
                _MainTab(
                  label: 'History${_history.isNotEmpty ? " (${_history.length})" : ""}',
                  active: _mainTab == 'history',
                  color: _SVColors.orange,
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
            Icon(_type == 'Deposit' ? Icons.savings_outlined : Icons.money_off, size: 44, color: _SVColors.dark),
            const SizedBox(height: 10),
            Text('$_type Recorded!', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _SVColors.dark)),
            const SizedBox(height: 8),
            Text(
              '₱${_parsed.toStringAsFixed(0)} ${_type.toLowerCase()} for ${_selected['fullname']}. New balance: ₱${_newBalance.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: _SVColors.sub),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _SVColors.green, foregroundColor: Colors.white),
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
              decoration: InputDecoration(
                hintText: 'Search by name or member ID...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: _fetching
                ? const Center(child: CircularProgressIndicator())
                : _filteredMembers.isEmpty
                    ? const Center(child: Text('No members found.', style: TextStyle(color: _SVColors.sub)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredMembers.length,
                        itemBuilder: (context, i) {
                          final m = _filteredMembers[i];
                          final isSel = _selected != null && _selected['id'] == m['id'];
                          return _MemberPickRow(
                            name: '${m['fullname'] ?? ''}',
                            id: '${m['member_id'] ?? ''}',
                            selected: isSel,
                            color: _SVColors.orange,
                            onTap: () => _selectMember(m),
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
                  style: ElevatedButton.styleFrom(backgroundColor: _SVColors.orange, foregroundColor: Colors.white),
                  onPressed: _selected != null ? () => setState(() => _step = 2) : null,
                  child: const Text('Next →'),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Step 2
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFE082))),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: _SVColors.orange, child: Text('${_selected['fullname'] ?? 'M'}'.isNotEmpty ? '${_selected['fullname']}'[0].toUpperCase() : 'M', style: const TextStyle(color: Colors.white))),
                const SizedBox(width: 10),
                Expanded(child: Text('${_selected['fullname']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [const Text('BALANCE', style: TextStyle(fontSize: 8, color: _SVColors.orange)), Text('₱${_balance.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFFE65100)))]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('Transaction Type', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _SVColors.sub)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _TypeButton(label: 'Deposit', active: _type == 'Deposit', activeColor: _SVColors.green, onTap: () => setState(() { _type = 'Deposit'; _error = null; }))),
            const SizedBox(width: 8),
            Expanded(child: _TypeButton(label: 'Withdraw', active: _type == 'Withdraw', activeColor: _SVColors.red, onTap: () => setState(() { _type = 'Withdraw'; _error = null; }))),
          ]),
          const SizedBox(height: 14),
          const Text('Amount (₱) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _SVColors.sub)),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(prefixText: '₱ ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          ),
          const SizedBox(height: 12),
          const Text('Note (optional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _SVColors.sub)),
          const SizedBox(height: 6),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), hintText: 'e.g. Monthly deposit'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: const TextStyle(color: _SVColors.red, fontSize: 12))),
          ],
          if (_isValid) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE4F0E5))),
              child: Column(children: [
                _PreviewRow('Current Balance', '₱${_balance.toStringAsFixed(0)}'),
                _PreviewRow(_type, '${_type == "Deposit" ? "+" : "−"} ₱${_parsed.toStringAsFixed(0)}', color: _type == 'Deposit' ? _SVColors.green : _SVColors.red),
                const Divider(),
                _PreviewRow('New Balance', '₱${_newBalance.toStringAsFixed(0)}', bold: true, color: const Color(0xFFE65100)),
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
                style: ElevatedButton.styleFrom(backgroundColor: _type == 'Deposit' ? _SVColors.green : _SVColors.red, foregroundColor: Colors.white),
                onPressed: (!_isValid || _saving) ? null : _handleSave,
                child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_type == 'Deposit' ? 'Record Deposit' : 'Record Withdrawal'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final totalDeposit = _history.where((t) => t['transaction_type'] == 'Deposit').fold<double>(0, (s, t) => s + (double.tryParse('${t['amount']}') ?? 0));
    final totalWithdraw = _history.where((t) => t['transaction_type'] == 'Withdraw').fold<double>(0, (s, t) => s + (double.tryParse('${t['amount']}') ?? 0));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _StatBox(label: 'Total Deposits', value: '₱${totalDeposit.toStringAsFixed(0)}', color: _SVColors.green, bg: const Color(0xFFE8F5E9))),
                const SizedBox(width: 8),
                Expanded(child: _StatBox(label: 'Total Withdrawals', value: '₱${totalWithdraw.toStringAsFixed(0)}', color: _SVColors.red, bg: const Color(0xFFFCE4EC))),
                const SizedBox(width: 8),
                Expanded(child: _StatBox(label: 'Transactions', value: '${_history.length}', color: const Color(0xFFE65100), bg: const Color(0xFFFFF8E1))),
              ]),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() => _histSearch = v),
                decoration: InputDecoration(hintText: 'Search by member name or ID...', prefixIcon: const Icon(Icons.search, size: 18), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ],
          ),
        ),
        Expanded(
          child: _histLoading
              ? const Center(child: CircularProgressIndicator())
              : _memberGroups.isEmpty
                  ? const Center(child: Text('No savings transactions found.', style: TextStyle(color: _SVColors.sub)))
                  // ── BAGO: dating flat na ListView lang ng LAHAT ng
                  // transactions — ngayon naka-group per MEMBER, i-tap
                  // para makita ang kanilang mga record. ─────────────
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _memberGroups.length,
                      itemBuilder: (context, i) {
                        final g = _memberGroups[i];
                        final txs = g['txs'] as List<dynamic>;
                        final code = '${g['member_code'] ?? g['member_name']}';
                        final isOpen = _expandedMember == code;
                        final memberTotal = txs.fold<double>(0, (s, t) => s + (t['transaction_type'] == 'Deposit' ? 1 : -1) * (double.tryParse('${t['amount']}') ?? 0));
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: isOpen ? _SVColors.orange : const Color(0xFFF0F0F0))),
                          child: Column(children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(() => _expandedMember = isOpen ? null : code),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  CircleAvatar(radius: 18, backgroundColor: const Color(0xFFFFF3E0), child: Text('${g['member_name'] ?? 'M'}'.isNotEmpty ? '${g['member_name']}'[0].toUpperCase() : 'M', style: const TextStyle(color: _SVColors.orange, fontWeight: FontWeight.w800))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('${g['member_name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                      Text('$code · ${txs.length} transaction${txs.length != 1 ? 's' : ''}', style: const TextStyle(fontSize: 10, color: _SVColors.sub)),
                                    ]),
                                  ),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Text('${memberTotal >= 0 ? "+" : ""}₱${memberTotal.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: memberTotal >= 0 ? _SVColors.green : _SVColors.red)),
                                    const Text('net', style: TextStyle(fontSize: 8, color: Color(0xFFBBBBBB))),
                                  ]),
                                  Icon(isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: const Color(0xFFBBBBBB)),
                                ]),
                              ),
                            ),
                            if (isOpen)
                              Container(
                                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF5E9D0)))),
                                child: Column(
                                  children: txs.map<Widget>((tx) {
                                    final isDeposit = tx['transaction_type'] == 'Deposit';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFFAFAFA)))),
                                      child: Row(children: [
                                        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: (isDeposit ? _SVColors.green : _SVColors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text('${tx['transaction_type']}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isDeposit ? _SVColors.green : _SVColors.red))),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text('${'${tx['created_at'] ?? ''}'.split('T').first}${tx['note'] != null && '${tx['note']}'.isNotEmpty ? " · ${tx['note']}" : ""}', style: const TextStyle(fontSize: 10, color: _SVColors.sub))),
                                        Text('${isDeposit ? "+" : "−"}₱${(double.tryParse('${tx['amount']}') ?? 0).toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w700, color: isDeposit ? _SVColors.green : _SVColors.red, fontSize: 12)),
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

class _MemberPickRow extends StatelessWidget {
  final String name;
  final String id;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _MemberPickRow({required this.name, required this.id, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: selected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? color : const Color(0xFFE8EAE0), width: selected ? 1.5 : 1),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Row(children: [
                CircleAvatar(radius: 20, backgroundColor: selected ? color : color.withOpacity(0.15), child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'M', style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text(id, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600))])),
                if (selected) Icon(Icons.check_circle, color: color, size: 20),
              ]),
            ),
          ),
        ),
      );
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _TypeButton({required this.label, required this.active, required this.activeColor, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: active ? activeColor.withOpacity(0.1) : const Color(0xFFFAFAFA), border: Border.all(color: active ? activeColor : const Color(0xFFE0E0E0), width: 2), borderRadius: BorderRadius.circular(10)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: active ? activeColor : const Color(0xFFAAAAAA))),
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
          FittedBox(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color))),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ]),
      );
}