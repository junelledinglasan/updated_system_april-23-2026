import 'package:flutter/material.dart';
import '../../services/members_service.dart';
import '../../widgets/admin/financial_summary_tab.dart';

class _VEColors {
  static const green  = Color(0xFF2E7D32);
  static const dark   = Color(0xFF1B5E20);
  static const sub    = Color(0xFF888888);
  static const border = Color(0xFFE0E0E0);
  static const label  = Color(0xFFAAAAAA);
}

class _FieldSpec {
  final String label;
  final String name;
  final String type; // text, number, date, email, tel, select, checkbox
  final List<String>? options;
  final bool full;
  const _FieldSpec(this.label, this.name, {this.type = 'text', this.options, this.full = false});
}

const List<_FieldSpec> _kPersonalFields = [
  _FieldSpec('Last Name', 'last_name'),
  _FieldSpec('First Name', 'first_name'),
  _FieldSpec('Middle Name', 'middle_name'),
  _FieldSpec('Birthdate', 'birth_date', type: 'date'),
  _FieldSpec('Place of Birth', 'place_of_birth'),
  _FieldSpec('Sex', 'sex', type: 'select', options: ['Male', 'Female']),
  _FieldSpec('Civil Status', 'civil_status', type: 'select', options: ['Single', 'Married', 'Widowed', 'Separated']),
  _FieldSpec('TIN No.', 'tin_no'),
  _FieldSpec('SSS/GSIS No.', 'sss_gsis_no'),
  _FieldSpec('Contact No.', 'contact_number', type: 'tel'),
  _FieldSpec('Email', 'email', type: 'email'),
  _FieldSpec('Occupation', 'occupation'),
  _FieldSpec('Monthly Income (₱)', 'income', type: 'number'),
  _FieldSpec('Religious/Social Affiliation', 'religious_social_affiliation'),
  _FieldSpec('Address', 'address', full: true),
];

const List<_FieldSpec> _kSpouseFields = [
  _FieldSpec('Spouse Name', 'spouse_name'),
  _FieldSpec('Spouse Occupation', 'spouse_occupation'),
  _FieldSpec('Spouse Income (₱)', 'spouse_income', type: 'number'),
  _FieldSpec('No. of Dependants', 'no_of_dependants', type: 'number'),
  _FieldSpec('Beneficiary Name', 'beneficiary_name'),
  _FieldSpec('Relationship', 'beneficiary_relationship'),
  _FieldSpec('Credit References', 'credit_references', full: true),
];

class ViewEditMemberScreen extends StatefulWidget {
  final dynamic member;
  const ViewEditMemberScreen({super.key, required this.member});

  @override
  State<ViewEditMemberScreen> createState() => _ViewEditMemberScreenState();
}

class _ViewEditMemberScreenState extends State<ViewEditMemberScreen> {
  bool _editMode = false;
  bool _loading = true;
  bool _saving = false;
  String _profileTab = 'info'; // info | finance
  bool _showPassword = false;
  Map<String, dynamic>? _detail;
  final Map<String, dynamic> _form = {};
  final Map<String, TextEditingController> _controllers = {};
  // ── BAGO: 1x/2x/3x na Loan Multiplier — hiwalay itong maliit na
  // control (auto-save agad pagpalit, hindi kasama sa buong Edit/Save
  // flow), dahil desisyon ito ng admin base sa payment history ng
  // member, hindi bahagi ng profile info. ──────────────────────────
  int _loanMultiplier = 1;
  bool _savingMultiplier = false;
  bool _multiplierSaved = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await MembersService.getMember(widget.member['id']);
      final pm = (data['pre_member_info'] as Map?) ?? {};
      final sp = (data['student_profile'] as Map?) ?? {};
      final sr = (data['senior_profile'] as Map?) ?? {};
      final jp = (data['job_profile'] as Map?) ?? {};

      _form.addAll({
        'first_name': data['first_name'] ?? pm['first_name'] ?? '',
        'last_name': data['last_name'] ?? pm['last_name'] ?? '',
        'middle_name': pm['middle_name'] ?? '',
        'status': data['status'] ?? 'Active',
        'birth_date': pm['birth_date'] ?? '',
        'place_of_birth': pm['place_of_birth'] ?? '',
        'sex': pm['sex'] ?? 'Male',
        'civil_status': pm['civil_status'] ?? 'Single',
        'tin_no': pm['tin_no'] ?? '',
        'sss_gsis_no': pm['sss_gsis_no'] ?? '',
        'contact_number': pm['contact_number'] ?? data['contact'] ?? '',
        'email': pm['email'] ?? data['email'] ?? '',
        'address': pm['address'] ?? '',
        'occupation': pm['occupation'] ?? '',
        'share_capital': data['share_capital'] ?? 0,
        'classification': pm['classification'] ?? data['classification'] ?? 'Employed',
        'educational_attainment': pm['educational_attainment'] ?? 'College',
        'income': pm['income']?.toString() ?? '',
        'religious_social_affiliation': pm['religious_social_affiliation'] ?? '',
        'birth_certificate': pm['birth_certificate'] ?? false,
        'marriage_certificate': pm['marriage_certificate'] ?? false,
        'spouse_name': pm['spouse_name'] ?? '',
        'spouse_occupation': pm['spouse_occupation'] ?? '',
        'spouse_income': pm['spouse_income']?.toString() ?? '',
        'no_of_dependants': pm['no_of_dependants']?.toString() ?? '',
        'beneficiary_name': pm['beneficiary_name'] ?? '',
        'beneficiary_relationship': pm['beneficiary_relationship'] ?? '',
        'credit_references': pm['credit_references'] ?? '',
        'school_name': sp['school_name'] ?? '',
        'year_level': sp['year_level'] ?? '',
        'allowance': sp['allowance']?.toString() ?? '',
        'pension_income': sr['pension_income']?.toString() ?? '',
        'job_type': jp['job_type'] ?? 'Employed',
        'monthly_income': jp['monthly_income']?.toString() ?? '',
        'plain_password': data['plain_password'] ?? '',
      });
      _loanMultiplier = int.tryParse('${data['loan_multiplier'] ?? 1}') ?? 1;

      for (final entry in _form.entries) {
        if (entry.value is! bool) {
          _controllers[entry.key] = TextEditingController(text: '${entry.value}');
        }
      }

      if (mounted) setState(() => _detail = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    // I-sync yung controllers pabalik sa _form
    for (final entry in _controllers.entries) {
      _form[entry.key] = entry.value.text;
    }
    try {
      await MembersService.updateMember(widget.member['id'], Map<String, dynamic>.from(_form));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member updated successfully.'), backgroundColor: _VEColors.green),
        );
        Navigator.pop(context, true); // true = may binago, i-refresh yung list
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update member.'), backgroundColor: Color(0xFFC62828)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── BAGO: auto-save agad pagpalit ng multiplier — hindi na
  // kailangang pindutin pa ang "Save" ng buong Edit screen. ───────────
  Future<void> _handleMultiplierChange(int newVal) async {
    final prevVal = _loanMultiplier;
    setState(() { _loanMultiplier = newVal; _savingMultiplier = true; });
    try {
      await MembersService.updateMember(widget.member['id'], {'loan_multiplier': newVal});
      if (mounted) {
        setState(() => _multiplierSaved = true);
        Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _multiplierSaved = false); });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loanMultiplier = prevVal); // ── ibalik kung na-fail
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update loan multiplier.'), backgroundColor: Color(0xFFC62828)),
        );
      }
    } finally {
      if (mounted) setState(() => _savingMultiplier = false);
    }
  }

  Widget _buildField(_FieldSpec spec) {
    final value = _form[spec.name];

    if (!_editMode) {
      String display;
      if (spec.type == 'checkbox') {
        display = (value == true) ? 'Submitted' : 'Not submitted';
      } else {
        display = (value == null || '$value'.isEmpty) ? '—' : '$value';
      }
      return _ViewFieldTile(label: spec.label, value: display, full: spec.full);
    }

    if (spec.type == 'checkbox') {
      return SizedBox(
        width: spec.full ? double.infinity : null,
        child: CheckboxListTile(
          value: _form[spec.name] == true,
          onChanged: (v) => setState(() => _form[spec.name] = v ?? false),
          title: Text(spec.label, style: const TextStyle(fontSize: 12)),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      );
    }

    if (spec.type == 'select' && spec.options != null) {
      return _EditFieldWrap(
        label: spec.label,
        full: spec.full,
        child: DropdownButtonFormField<String>(
          value: spec.options!.contains(_form[spec.name]) ? _form[spec.name] : spec.options!.first,
          items: spec.options!.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12.5)))).toList(),
          onChanged: (v) => setState(() => _form[spec.name] = v),
          decoration: _inputDecoration(),
        ),
      );
    }

    final controller = _controllers[spec.name] ?? TextEditingController(text: '$value');
    return _EditFieldWrap(
      label: spec.label,
      full: spec.full,
      child: TextField(
        controller: controller,
        keyboardType: spec.type == 'number'
            ? TextInputType.number
            : spec.type == 'email'
                ? TextInputType.emailAddress
                : spec.type == 'tel'
                    ? TextInputType.phone
                    : TextInputType.text,
        style: const TextStyle(fontSize: 12.5),
        decoration: _inputDecoration(),
      ),
    );
  }

  InputDecoration _inputDecoration() => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _VEColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _VEColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _VEColors.green)),
      );

  @override
  Widget build(BuildContext context) {
    final fullname = '${_form['first_name'] ?? widget.member['first_name'] ?? ''} ${_form['last_name'] ?? widget.member['last_name'] ?? ''}'.trim();
    final memberId = _detail?['member_id'] ?? widget.member['member_id'] ?? '—';
    final username = _detail?['user_username'] ?? '—';
    final status = (_form['status'] ?? widget.member['status'] ?? '').toString();
    final shareCapital = double.tryParse('${_form['share_capital'] ?? 0}') ?? 0;
    final classification = _form['classification'] ?? 'Employed';

    return Scaffold(
      // ── BAGO: dating plain gray ang background — ginawa nang light
      // green tint (tugma sa admin theme, hal. Manage Member list). ──
      backgroundColor: const Color(0xFFD8E8CC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3EEE0),
        foregroundColor: _VEColors.dark,
        elevation: 0,
        title: Text(_editMode ? 'Edit Member' : 'Member Profile', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _VEColors.dark)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: const Color(0xFFE4D9BE))),
        actions: [
          if (!_loading && !_editMode)
            TextButton.icon(
              onPressed: () => setState(() => _editMode = true),
              icon: const Icon(Icons.edit, size: 15, color: _VEColors.green),
              label: const Text('Edit', style: TextStyle(color: _VEColors.green, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _VEColors.green))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── BAGO: gradient na header — kaparehong theme ng
                  // Dashboard/ibang member-facing screens (dating plain
                  // light-gray box lang, walang kulay). ──────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)], stops: [0.0, 0.6, 1.0], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: _VEColors.green.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white.withOpacity(0.22),
                          child: Text(fullname.isNotEmpty ? fullname[0].toUpperCase() : 'M', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fullname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                              Text('$memberId', style: const TextStyle(fontSize: 10, color: Colors.white70, fontFamily: 'monospace')),
                              Text('@$username', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'Active' ? Colors.white.withOpacity(0.9) : const Color(0xFFFFCDD2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: status == 'Active' ? _VEColors.green : const Color(0xFFC62828))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Tabs (info / finance) — view mode lang ─────────────
                  if (!_editMode) ...[
                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE4F0E5))),
                      child: Row(
                        children: [
                          _ProfileTabButton(label: 'Profile Info', icon: Icons.person_outline, active: _profileTab == 'info', onTap: () => setState(() => _profileTab = 'info')),
                          _ProfileTabButton(label: 'Financial Summary', icon: Icons.account_balance_wallet_outlined, active: _profileTab == 'finance', onTap: () => setState(() => _profileTab = 'finance')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── BAGO: naka-wrap na ngayon sa isang puting card ang
                  // buong "info" tab (dating direktang nakalatag sa
                  // background, walang separation/contrast). ──────────
                  (_editMode || _profileTab == 'info')
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4F0E5))),
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    // ── Share capital bar ──────────────────────────────
                    Container(
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF1F8E9), Color(0xFFE8F5E9)]), border: Border.all(color: const Color(0xFFC8E6C9)), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          Expanded(child: _CapitalBox(label: 'Share Capital', value: '₱${shareCapital.toStringAsFixed(0)}', color: const Color(0xFF222222))),
                          Container(width: 1, height: 44, color: const Color(0xFFC8E6C9)),
                          Expanded(child: _CapitalBox(label: 'Max Loanable', value: '₱${(shareCapital * _loanMultiplier).toStringAsFixed(0)}', color: _VEColors.green)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // ── BAGO: editable na Loan Multiplier — 1x (unang
                    // loan), 2x (masamang payment history), 3x (magandang
                    // payment history). Direkta ang admin na nagpapasya
                    // dito, hindi ito awtomatiko. Auto-save agad.
                    // BAGO: dinagdagan ng espasyo/prominence (icon,
                    // mas makapal na padding, colored left accent) para
                    // mas kumapit ito at hindi na-eeng masyadong maiksi. ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FEF9),
                        border: Border.all(color: const Color(0xFFC8E6C9)),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: _VEColors.green.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(9)),
                            child: const Icon(Icons.trending_up, size: 18, color: _VEColors.green),
                          ),
                          const SizedBox(width: 10),
                          const Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Loan Multiplier', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _VEColors.dark)),
                                Text('Base sa payment history', style: TextStyle(fontSize: 10, color: _VEColors.sub)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (_savingMultiplier) const Padding(padding: EdgeInsets.only(right: 8), child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))),
                          if (_multiplierSaved && !_savingMultiplier) const Padding(padding: EdgeInsets.only(right: 8), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, size: 13, color: _VEColors.green), SizedBox(width: 3), Text('Saved', style: TextStyle(fontSize: 11, color: _VEColors.green, fontWeight: FontWeight.w600))])),
                          // ── FIX: dating masyadong mahaba ang naka-
                          // display kapag sarado ang dropdown (hal. "2×
                          // — Bad payment history"), kaya nag-o-overflow
                          // sa makipot na screen. Gamit na ngayon ng
                          // "selectedItemBuilder" — "1×"/"2×"/"3×" lang
                          // ang lumalabas kapag sarado, buo pa rin ang
                          // teksto kapag binuksan ang dropdown menu. ────
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFA5D6A7))),
                            child: DropdownButton<int>(
                            value: _loanMultiplier,
                            underline: const SizedBox.shrink(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _VEColors.dark),
                            selectedItemBuilder: (context) => const [
                              Text('1×', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _VEColors.dark)),
                              Text('2×', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _VEColors.dark)),
                              Text('3×', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _VEColors.dark)),
                            ],
                            // ── FIX: masikip/nagki-crumple ang text sa
                            // loob ng dropdown menu popup dahil sumasalig
                            // ang lapad nito sa maliit na "1×"/"2×"/"3×"
                            // na naka-display kapag sarado. Binibigyan na
                            // ngayon ng fixed/generous na width ang bawat
                            // item para hindi na mag-wrap ang text. ──────
                            items: const [
                              DropdownMenuItem(value: 1, child: SizedBox(width: 190, child: Text('1× — First loan', style: TextStyle(fontSize: 12.5)))),
                              DropdownMenuItem(value: 2, child: SizedBox(width: 190, child: Text('2× — Bad payment history', style: TextStyle(fontSize: 12.5)))),
                              DropdownMenuItem(value: 3, child: SizedBox(width: 190, child: Text('3× — Good payment history', style: TextStyle(fontSize: 12.5)))),
                            ],
                            onChanged: _savingMultiplier ? null : (v) { if (v != null) _handleMultiplierChange(v); },
                          ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    _SectionTitle('Personal Information'),
                    _FieldGrid(fields: _kPersonalFields.map(_buildField).toList()),
                    const SizedBox(height: 14),

                    _SectionTitle('Spouse & Family'),
                    _FieldGrid(fields: _kSpouseFields.map(_buildField).toList()),
                    const SizedBox(height: 14),

                    _SectionTitle('Classification & Profile'),
                    _FieldGrid(fields: [
                      _buildField(const _FieldSpec('Classification', 'classification', type: 'select', options: ['Student', 'Senior', 'Employed'])),
                      _buildField(const _FieldSpec('Educational Attainment', 'educational_attainment', type: 'select', options: ['Elementary', 'High School', 'Vocational', 'College', 'Post Graduate'])),
                      _buildField(const _FieldSpec('Birth Certificate', 'birth_certificate', type: 'checkbox')),
                      _buildField(const _FieldSpec('Marriage Certificate', 'marriage_certificate', type: 'checkbox')),
                    ]),
                    if (classification == 'Student') ...[
                      const SizedBox(height: 8),
                      _FieldGrid(fields: [
                        _buildField(const _FieldSpec('School Name', 'school_name')),
                        _buildField(const _FieldSpec('Year Level', 'year_level', type: 'select', options: ['Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12', '1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year', 'Graduate'])),
                        _buildField(const _FieldSpec('Monthly Allowance (₱)', 'allowance', type: 'number')),
                      ]),
                    ],
                    if (classification == 'Senior') ...[
                      const SizedBox(height: 8),
                      _FieldGrid(fields: [_buildField(const _FieldSpec('Monthly Pension Income (₱)', 'pension_income', type: 'number'))]),
                    ],
                    if (classification == 'Employed') ...[
                      const SizedBox(height: 8),
                      _FieldGrid(fields: [
                        _buildField(const _FieldSpec('Employment Type', 'job_type', type: 'select', options: ['Employed', 'Self-Employed', 'Business', 'Freelance', 'Other'])),
                        _buildField(const _FieldSpec('Monthly Income (₱)', 'monthly_income', type: 'number')),
                      ]),
                    ],
                    const SizedBox(height: 14),

                    _SectionTitle('Account'),
                    _ViewFieldTile(label: 'Member ID', value: '$memberId', full: true, mono: true),
                    _ViewFieldTile(label: 'Username', value: '$username', full: true, mono: true),
                    if (!_editMode)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ViewFieldTile(
                                label: 'Password',
                                value: _showPassword ? (_form['plain_password']?.toString().isNotEmpty == true ? _form['plain_password'] : 'No password saved') : '••••••••',
                                full: true,
                                mono: true,
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                              child: Text(_showPassword ? 'Hide' : 'Show', style: const TextStyle(fontSize: 11, color: _VEColors.green, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      )
                    else
                      _EditFieldWrap(
                        label: 'New Password (leave blank to keep current)',
                        full: true,
                        child: TextField(
                          controller: _controllers['plain_password'],
                          obscureText: !_showPassword,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: _inputDecoration().copyWith(
                            hintText: 'Enter new password',
                            suffixIcon: IconButton(
                              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 16),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                          ),
                        ),
                      ),
                    _ViewFieldTile(
                      label: 'Date Registered',
                      value: _detail?['date_registered'] != null ? '${_detail!['date_registered']}'.split('T').first : '—',
                      full: true,
                    ),
                        ],
                        ),
                      )
                    : FinancialSummaryTab(memberId: widget.member['id']),
                ],
              ),
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _editMode
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _editMode = false),
                              child: const Text('← Back'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: _VEColors.green, foregroundColor: Colors.white),
                              onPressed: _saving ? null : _handleSave,
                              child: _saving
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Save Changes'),
                            ),
                          ),
                        ],
                      )
                    : null,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: _VEColors.green, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _VEColors.dark, letterSpacing: 0.6)),
        ],
      ),
    );
  }
}

class _FieldGrid extends StatelessWidget {
  final List<Widget> fields;
  const _FieldGrid({required this.fields});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: fields,
    );
  }
}

class _ViewFieldTile extends StatelessWidget {
  final String label;
  final String value;
  final bool full;
  final bool mono;
  const _ViewFieldTile({required this.label, required this.value, this.full = false, this.mono = false});

  @override
  Widget build(BuildContext context) {
    // ── FIX: dating "MediaQuery.of(context).size.width" (buong laki
    // ng SCREEN) ang basehan ng "half width" — hindi nito naiisip ang
    // lahat ng padding sa paligid nito (Scaffold, Container, Card),
    // kaya mas malaki pa rin ang na-compute kumpara sa aktwal na
    // available space, at isang column lang ang kumakasya kahit
    // dapat 2. Gamit na ngayon ng "LayoutBuilder" — TAMANG available
    // width ang nakukuha nito sa eksaktong posisyon sa tree (galing
    // mismo sa constraints na ipinapasa ng Wrap parent). ────────────
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = full ? double.infinity : (constraints.maxWidth - 10) / 2;
        return SizedBox(
          width: width,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF9FEF9), border: Border.all(color: const Color(0xFFEEF5EA)), borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF7A8A6A), letterSpacing: 0.4)),
                const SizedBox(height: 3),
                Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A), fontFamily: mono ? 'monospace' : null)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EditFieldWrap extends StatelessWidget {
  final String label;
  final Widget child;
  final bool full;
  const _EditFieldWrap({required this.label, required this.child, this.full = false});

  @override
  Widget build(BuildContext context) {
    // ── FIX: parehong dahilan/ayos ng _ViewFieldTile sa itaas. ───────
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = full ? double.infinity : (constraints.maxWidth - 10) / 2;
        return SizedBox(
          width: width,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF9FEF9), border: Border.all(color: const Color(0xFFEEF5EA)), borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF7A8A6A), letterSpacing: 0.4)),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CapitalBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CapitalBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _VEColors.label, letterSpacing: 0.4)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ProfileTabButton({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF9FEF9) : Colors.transparent,
            border: Border(bottom: BorderSide(color: active ? _VEColors.green : const Color(0xFFE8F5E9), width: 2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? _VEColors.green : _VEColors.sub),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: active ? _VEColors.green : _VEColors.sub)),
            ],
          ),
        ),
      ),
    );
  }
}