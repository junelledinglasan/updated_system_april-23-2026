import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/member_provider.dart';
import '../../services/members_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/member_scaffold_helpers.dart';
import 'share_capital_history_screen.dart';

class _MPColors {
  static const dark   = Color(0xFF1B5E20);
  static const green  = Color(0xFF2E7D32);
  static const sub    = Color(0xFFAAAAAA);
  static const red    = Color(0xFFC62828);
  static const border = Color(0xFFE4F0E5);
}

String _peso(num v) {
  final fixed = v.toStringAsFixed(0);
  final buf = StringBuffer();
  final digits = fixed.replaceAll('-', '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '₱$buf';
}

int? _computeAge(String? birthDate) {
  if (birthDate == null || birthDate.isEmpty) return null;
  try {
    final bd = DateTime.parse(birthDate);
    final today = DateTime.now();
    int age = today.year - bd.year;
    if (today.month < bd.month || (today.month == bd.month && today.day < bd.day)) age--;
    return age;
  } catch (_) {
    return null;
  }
}

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({super.key});

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _application;
  bool _isOfficial = false;
  String _tab = 'info';
  bool _editing = false;

  final _contactCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  bool _saved = false;

  String _username = '';
  final _newUsernameCtrl = TextEditingController();
  String? _unError;
  bool _unSaved = false;

  final _currPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  String? _passError;
  bool _passSaved = false;
  bool _showCurr = false, _showNew = false, _showConf = false;
  bool _savingProfile = false, _savingUsername = false, _savingPassword = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _occupationCtrl.dispose();
    _newUsernameCtrl.dispose();
    _currPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    _username = auth.username ?? '';
    try {
      final p = await MembersService.getMyProfile();
      final pm = (p['pre_member_info'] as Map?) ?? {};
      _contactCtrl.text = '${pm['contact_number'] ?? p['contact'] ?? ''}';
      _emailCtrl.text = '${pm['email'] ?? p['email'] ?? ''}';
      _addressCtrl.text = '${pm['address'] ?? ''}';
      _occupationCtrl.text = '${pm['occupation'] ?? ''}';
      if (mounted) setState(() { _profile = p; _isOfficial = true; _loading = false; });
    } catch (_) {
      try {
        final app = await MembersService.getMyOnlineApp();
        if (mounted) setState(() { _application = app; _loading = false; });
      } catch (_) {
        try {
          final app = await MembersService.getMyApplication();
          if (mounted) setState(() { _application = app; _loading = false; });
        } catch (_) {
          if (mounted) setState(() => _loading = false);
        }
      }
    }
  }

  Map<String, dynamic> get _pm => (_profile?['pre_member_info'] as Map?)?.cast<String, dynamic>() ?? {};

  Future<void> _handleSaveProfile() async {
    setState(() => _savingProfile = true);
    try {
      await MembersService.updateMember(_profile!['id'], {
        'contact_number': _contactCtrl.text,
        'email': _emailCtrl.text,
        'address': _addressCtrl.text,
        'occupation': _occupationCtrl.text,
      });
      if (mounted) {
        setState(() {
          _editing = false;
          _saved = true;
          _savingProfile = false;
        });
        Future.delayed(const Duration(milliseconds: 2500), () { if (mounted) setState(() => _saved = false); });
      }
    } catch (_) {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _handleUsernameChange() async {
    final v = _newUsernameCtrl.text.trim();
    if (v.isEmpty) { setState(() => _unError = 'Username cannot be empty.'); return; }
    if (v.length < 4) { setState(() => _unError = 'Username must be at least 4 characters.'); return; }
    if (v.contains(' ')) { setState(() => _unError = 'Username cannot have spaces.'); return; }
    setState(() { _savingUsername = true; _unError = null; });
    final result = await AuthService.updateUsername(v);
    if (mounted) {
      if (result['success'] == true) {
        setState(() {
          _username = v;
          _newUsernameCtrl.clear();
          _unSaved = true;
          _savingUsername = false;
        });
        Future.delayed(const Duration(milliseconds: 2500), () { if (mounted) setState(() => _unSaved = false); });
      } else {
        setState(() {
          _unError = result['message'] ?? 'Failed to update username.';
          _savingUsername = false;
        });
      }
    }
  }

  Future<void> _handlePasswordChange() async {
    if (_newPassCtrl.text.length < 6) { setState(() => _passError = 'New password must be at least 6 characters.'); return; }
    if (_newPassCtrl.text != _confirmPassCtrl.text) { setState(() => _passError = 'Passwords do not match.'); return; }
    setState(() { _savingPassword = true; _passError = null; });
    final result = await AuthService.changePassword(currentPassword: _currPassCtrl.text, newPassword: _newPassCtrl.text);
    if (mounted) {
      if (result['success'] == true) {
        setState(() {
          _currPassCtrl.clear();
          _newPassCtrl.clear();
          _confirmPassCtrl.clear();
          _passSaved = true;
          _savingPassword = false;
        });
        Future.delayed(const Duration(milliseconds: 2500), () { if (mounted) setState(() => _passSaved = false); });
      } else {
        setState(() {
          _passError = result['message'] ?? 'Current password is incorrect.';
          _savingPassword = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MemberScreenScaffold(activeRouteKey: 'profile', body: Center(child: CircularProgressIndicator(color: _MPColors.green)));
    }
    return MemberScreenScaffold(activeRouteKey: 'profile', body: _isOfficial ? _buildOfficial() : _buildNonOfficial());
  }

  // ── Non-official member view ───────────────────────────────────────
  Widget _buildNonOfficial() {
    final auth = context.watch<AuthProvider>();
    final appStatus = _application?['application_status'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_MPColors.dark, _MPColors.green, Color(0xFF388E3C)], stops: [0.0, 0.6, 1.0]), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              CircleAvatar(radius: 28, backgroundColor: const Color(0xFF4CAF50), child: Text((auth.name?.isNotEmpty == true ? auth.name![0] : 'M').toUpperCase(), style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.name ?? 'Member', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text('@${auth.username ?? '—'}', style: const TextStyle(fontSize: 11, color: Color(0xFFA5D6A7), fontFamily: 'monospace')),
                    const Text('Pending Membership', style: TextStyle(fontSize: 12, color: Color(0xFFFFCC80), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _MPColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Membership Application Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _MPColors.dark)),
                const SizedBox(height: 12),
                if (appStatus == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(children: [
                      Container(width: 64, height: 64, decoration: BoxDecoration(color: const Color(0xFFE8F5E9), shape: BoxShape.circle), alignment: Alignment.center, child: const Text('📋', style: TextStyle(fontSize: 28))),
                      const SizedBox(height: 10),
                      const Text('No application submitted yet', style: TextStyle(fontWeight: FontWeight.w700, color: _MPColors.dark, fontSize: 14)),
                      const SizedBox(height: 6),
                      const Text('Submit a membership application to become an official LEAF MPC member.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Color(0xFF888888), height: 1.6)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _MPColors.dark, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11)),
                        onPressed: () => Navigator.pushNamed(context, '/member/apply-membership'),
                        child: const Text('Apply for Membership', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: appStatus == 'Pending' ? const Color(0xFFFFF8E1) : appStatus == 'Approved' ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: appStatus == 'Pending' ? const Color(0xFFFFE082) : appStatus == 'Approved' ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A), width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(appStatus == 'Pending' ? '⏳' : appStatus == 'Approved' ? '✅' : '❌', style: const TextStyle(fontSize: 30)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appStatus == 'Pending' ? 'Application Under Review' : appStatus == 'Approved' ? 'Application Approved!' : 'Application Rejected',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: appStatus == 'Approved' ? _MPColors.dark : appStatus == 'Rejected' ? _MPColors.red : const Color(0xFFF57C00)),
                              ),
                              const SizedBox(height: 4),
                              Text('App ID: ${_application?['app_id'] ?? ''} · Submitted ${'${_application?['created_at'] ?? ''}'.split('T').first}', style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                              const SizedBox(height: 6),
                              if (appStatus == 'Pending') const Text('Please wait for the admin to review your application.', style: TextStyle(fontSize: 12.5, color: Color(0xFF5D4037))),
                              if (appStatus == 'Approved') const Text('Please visit the LEAF MPC office to complete the process. Bring your 2x2 ID picture, Birth Certificate, Valid ID, and ₱4,000 minimum share capital.', style: TextStyle(fontSize: 12.5, color: _MPColors.dark)),
                              if (appStatus == 'Rejected' && _application?['reject_reason'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Reason: ${_application?['reject_reason']}', style: const TextStyle(fontSize: 12.5, color: _MPColors.red, fontStyle: FontStyle.italic))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (appStatus == 'Rejected') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _MPColors.dark, foregroundColor: Colors.white),
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Re-apply for Membership — coming soon.'))),
                        child: const Text('Re-apply for Membership', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),

          if (_application != null && '${_application?['last_name'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _MPColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personal Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _MPColors.dark)),
                  const SizedBox(height: 10),
                  _InfoGrid(rows: [
                    ['Last Name', '${_application?['last_name'] ?? '—'}'],
                    ['First Name', '${_application?['first_name'] ?? '—'}'],
                    ['Middle Name', '${_application?['middle_name'] ?? '—'}'],
                    ['Birthdate', '${_application?['birth_date'] ?? '—'}'],
                    ['Place of Birth', '${_application?['place_of_birth'] ?? '—'}'],
                    ['Sex', '${_application?['sex'] ?? '—'}'],
                    ['Civil Status', '${_application?['civil_status'] ?? '—'}'],
                    ['Classification', '${_application?['classification'] ?? '—'}'],
                    ['Occupation', '${_application?['occupation'] ?? '—'}'],
                    ['TIN No.', '${_application?['tin_no'] ?? '—'}'],
                    ['SSS/GSIS No.', '${_application?['sss_gsis_no'] ?? '—'}'],
                    ['Contact No.', '${_application?['contact_number'] ?? '—'}'],
                    ['Email', '${_application?['email'] ?? '—'}'],
                    ['Address', '${_application?['address'] ?? '—'}'],
                    ['Religious/Social', '${_application?['religious_social_affiliation'] ?? '—'}'],
                    ['Username', '@$_username'],
                  ]),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Official member view ─────────────────────────────────────────────
  Widget _buildOfficial() {
    final pm = _pm;
    final age = _computeAge('${pm['birth_date'] ?? ''}');
    final shareCapital = double.tryParse('${_profile?['share_capital'] ?? 0}') ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_saved)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _MPColors.green, borderRadius: BorderRadius.circular(8)),
              child: const Text('Profile updated successfully!', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),

          // ── Header ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_MPColors.dark, _MPColors.green, Color(0xFF388E3C)], stops: [0.0, 0.6, 1.0]), borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(radius: 28, backgroundColor: const Color(0xFF4CAF50), child: Text(('${_profile?['first_name'] ?? pm['first_name'] ?? 'M'}').isNotEmpty ? '${_profile?['first_name'] ?? pm['first_name'] ?? 'M'}'[0].toUpperCase() : 'M', style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_profile?['fullname'] ?? '${pm['first_name'] ?? ''} ${pm['last_name'] ?? ''}'.trim()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('${_profile?['member_id'] ?? '—'}', style: const TextStyle(fontSize: 11, color: Color(0xFFA5D6A7), fontFamily: 'monospace')),
                        Text('Member since ${'${_profile?['date_registered'] ?? '—'}'.split('T').first}', style: const TextStyle(fontSize: 10, color: Color(0xFFA5D6A7))),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white.withOpacity(0.15)), borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ShareCapitalHistoryScreen(memberId: _profile!['id'], currentShareCapital: shareCapital))),
                        child: Column(children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Flexible(child: FittedBox(child: Text(_peso(shareCapital), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
                            const SizedBox(width: 3),
                            const Icon(Icons.history, size: 12, color: Color(0xFFA5D6A7)),
                          ]),
                          const Text('SHARE CAPITAL', style: TextStyle(fontSize: 8.5, color: Color(0xFFA5D6A7), letterSpacing: 0.4)),
                        ]),
                      ),
                    ),
                    Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
                    Expanded(child: _HeaderStat(_peso(shareCapital * 2), 'Max Loanable')),
                    Container(width: 1, height: 30, color: Colors.white.withOpacity(0.2)),
                    Expanded(
                      child: Column(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: const Color(0xFF69F0AE), borderRadius: BorderRadius.circular(20)), child: Text('${_profile?['status'] ?? 'Active'}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _MPColors.dark))),
                        const SizedBox(height: 4),
                        const Text('STATUS', style: TextStyle(fontSize: 9, color: Color(0xFFA5D6A7), letterSpacing: 0.5)),
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Tabs ────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _MPColors.border)),
            child: Row(children: [
              Expanded(child: _ProfileTabBtn(label: 'Personal Info', active: _tab == 'info', onTap: () => setState(() => _tab = 'info'))),
              Expanded(child: _ProfileTabBtn(label: 'Account & Security', active: _tab == 'security', onTap: () => setState(() => _tab = 'security'))),
            ]),
          ),
          const SizedBox(height: 14),

          if (_tab == 'info') _buildInfoTab(pm, age) else _buildSecurityTab(),
        ],
      ),
    );
  }

  Widget _buildInfoTab(Map<String, dynamic> pm, int? age) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _MPColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Personal Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _MPColors.dark)),
                Text('Contact details, address, and occupation are editable.', style: TextStyle(fontSize: 10.5, color: Color(0xFFAAAAAA))),
              ]),
            ),
            if (!_editing)
              OutlinedButton(onPressed: () => setState(() => _editing = true), style: OutlinedButton.styleFrom(foregroundColor: _MPColors.green, side: const BorderSide(color: Color(0xFFC8E6C9))), child: const Text('Edit', style: TextStyle(fontSize: 11)))
            else
              Row(children: [
                TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel', style: TextStyle(fontSize: 11))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _MPColors.green, foregroundColor: Colors.white),
                  onPressed: _savingProfile ? null : _handleSaveProfile,
                  child: _savingProfile ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save', style: TextStyle(fontSize: 11)),
                ),
              ]),
          ]),
          const SizedBox(height: 14),

          _SectionLabel('Basic Information'),
          _InfoGrid(rows: [
            ['Last Name', '${_profile?['last_name'] ?? pm['last_name'] ?? '—'}'],
            ['First Name', '${_profile?['first_name'] ?? pm['first_name'] ?? '—'}'],
            ['Middle Name', '${pm['middle_name'] ?? '—'}'],
            ['Date of Birth', '${pm['birth_date'] ?? '—'}'],
            ['Age', age != null ? '$age years old' : '—'],
            ['Sex', '${pm['sex'] ?? '—'}'],
            ['Civil Status', '${pm['civil_status'] ?? '—'}'],
            ['Place of Birth', '${pm['place_of_birth'] ?? '—'}'],
          ]),

          const SizedBox(height: 18),
          _SectionLabel('Classification & Education'),
          _InfoGrid(rows: [
            ['Classification', '${pm['classification'] ?? _profile?['classification'] ?? '—'}'],
            ['Educ. Attainment', '${pm['educational_attainment'] ?? '—'}'],
            ['TIN No.', '${pm['tin_no'] ?? '—'}'],
            ['SSS/GSIS No.', '${pm['sss_gsis_no'] ?? '—'}'],
            ['Religious/Social', '${pm['religious_social_affiliation'] ?? '—'}'],
          ]),

          if (pm['spouse_name'] != null || pm['beneficiary_name'] != null) ...[
            const SizedBox(height: 18),
            _SectionLabel('Spouse & Family'),
            _InfoGrid(rows: [
              ['Spouse Name', '${pm['spouse_name'] ?? '—'}'],
              ['Spouse Occupation', '${pm['spouse_occupation'] ?? '—'}'],
              ['Spouse Income', pm['spouse_income'] != null ? _peso(double.tryParse('${pm['spouse_income']}') ?? 0) : '—'],
              ['No. of Dependants', '${pm['no_of_dependants'] ?? '—'}'],
              ['Beneficiary', '${pm['beneficiary_name'] ?? '—'}'],
              ['Relationship', '${pm['beneficiary_relationship'] ?? '—'}'],
            ]),
          ],

          if ('${pm['credit_references'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionLabel('Credit References'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(8), border: Border.all(color: _MPColors.border)),
              child: Text('${pm['credit_references']}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF333333), height: 1.5)),
            ),
          ],

          const SizedBox(height: 18),
          _SectionLabel('Contact & Address'),
          _editableRow('Contact No.', _contactCtrl, TextInputType.phone),
          _editableRow('Email', _emailCtrl, TextInputType.emailAddress),
          _editableRow('Occupation', _occupationCtrl, TextInputType.text),
          _editableRow('Address', _addressCtrl, TextInputType.text),

          const SizedBox(height: 18),
          _SectionLabel('Documents Submitted'),
          _InfoGrid(rows: [
            ['Birth Certificate', pm['birth_certificate'] == true ? 'Submitted' : 'Not submitted'],
            ['Marriage Certificate', pm['marriage_certificate'] == true ? 'Submitted' : 'Not submitted / N/A'],
          ], colors: {
            'Birth Certificate': pm['birth_certificate'] == true ? _MPColors.green : const Color(0xFFAAAAAA),
            'Marriage Certificate': pm['marriage_certificate'] == true ? _MPColors.green : const Color(0xFFAAAAAA),
          }),
        ],
      ),
    );
  }

  Widget _editableRow(String label, TextEditingController ctrl, TextInputType type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFBBBBBB), letterSpacing: 0.4)),
          const SizedBox(height: 3),
          _editing
              ? TextField(controller: ctrl, keyboardType: type, style: const TextStyle(fontSize: 13), decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(7))))
              : Text(ctrl.text.isEmpty ? '—' : ctrl.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF222222))),
        ],
      ),
    );
  }

  Widget _buildSecurityTab() {
    return Column(
      children: [
        // Hidden autofill-prevention fields not needed in Flutter (no browser autofill issue)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _MPColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Account Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _MPColors.dark)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFF0F1923), borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  _CredRow('MEMBER ID', '${_profile?['member_id'] ?? '—'}'),
                  const SizedBox(height: 8),
                  _CredRow('USERNAME', _username),
                  const SizedBox(height: 8),
                  const _CredRow('STATUS', 'Active', valColor: Color(0xFF69F0AE)),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _MPColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Change Username', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _MPColors.dark)),
              Padding(padding: const EdgeInsets.only(top: 2, bottom: 12), child: Text.rich(TextSpan(text: 'Current username: ', style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)), children: [TextSpan(text: _username, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF555555)))]))),
              if (_unSaved)
                Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)), child: const Text('Username changed successfully!', style: TextStyle(color: _MPColors.green, fontSize: 12, fontWeight: FontWeight.w600))),
              const Text('NEW USERNAME', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFBBBBBB), letterSpacing: 0.4)),
              const SizedBox(height: 5),
              TextField(
                controller: _newUsernameCtrl,
                onChanged: (_) => setState(() => _unError = null),
                decoration: InputDecoration(hintText: 'Enter new username (min. 4 characters)', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _unError != null ? _MPColors.red : const Color(0xFFE0E0E0))), errorText: _unError),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _MPColors.green, foregroundColor: Colors.white),
                  onPressed: _savingUsername ? null : _handleUsernameChange,
                  child: _savingUsername ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update Username', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(8), border: Border.all(color: _MPColors.border)), child: const Text('Your username is used to log in to the LEAF MPC member portal.', style: TextStyle(fontSize: 10.5, color: Color(0xFF888888), height: 1.5))),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _MPColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _MPColors.dark)),
              const Padding(padding: EdgeInsets.only(top: 2, bottom: 12), child: Text('Keep your account secure with a strong password.', style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)))),
              if (_passSaved)
                Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)), child: const Text('Password changed successfully!', style: TextStyle(color: _MPColors.green, fontSize: 12, fontWeight: FontWeight.w600))),
              if (_passError != null)
                Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)), child: Text(_passError!, style: const TextStyle(color: _MPColors.red, fontSize: 12, fontWeight: FontWeight.w600))),

              _passField('CURRENT PASSWORD', _currPassCtrl, _showCurr, () => setState(() => _showCurr = !_showCurr)),
              const SizedBox(height: 12),
              _passField('NEW PASSWORD', _newPassCtrl, _showNew, () => setState(() => _showNew = !_showNew)),
              if (_newPassCtrl.text.isNotEmpty) _buildStrengthBar(),
              const SizedBox(height: 12),
              _passField('CONFIRM NEW PASSWORD', _confirmPassCtrl, _showConf, () => setState(() => _showConf = !_showConf)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _MPColors.green, foregroundColor: Colors.white),
                  onPressed: _savingPassword ? null : _handlePasswordChange,
                  child: _savingPassword ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(8), border: Border.all(color: _MPColors.border)), child: const Text('Forgot your current password? Visit the LEAF MPC office for a password reset.', style: TextStyle(fontSize: 10.5, color: Color(0xFF888888), height: 1.5))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _passField(String label, TextEditingController ctrl, bool show, VoidCallback toggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFBBBBBB), letterSpacing: 0.4)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          obscureText: !show,
          onChanged: (_) => setState(() => _passError = null),
          decoration: InputDecoration(
            isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: IconButton(icon: Icon(show ? Icons.visibility_off : Icons.visibility, size: 17, color: const Color(0xFFAAAAAA)), onPressed: toggle),
          ),
        ),
      ],
    );
  }

  Widget _buildStrengthBar() {
    final len = _newPassCtrl.text.length;
    final level = len < 5 ? 1 : len < 8 ? 2 : 3;
    final colors = [Colors.transparent, _MPColors.red, const Color(0xFFF57C00), _MPColors.green];
    final labels = ['', 'Weak', 'Fair', 'Strong'];
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(children: [
        ...List.generate(3, (i) => Expanded(child: Container(height: 4, margin: EdgeInsets.only(right: i < 2 ? 4 : 8), decoration: BoxDecoration(color: level > i ? colors[level] : const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(4))))),
        Text(labels[level], style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String val, label;
  const _HeaderStat(this.val, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      FittedBox(child: Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
      Text(label.toUpperCase(), style: const TextStyle(fontSize: 8.5, color: Color(0xFFA5D6A7), letterSpacing: 0.4)),
    ]);
  }
}

class _ProfileTabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ProfileTabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _MPColors.green : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF888888)))),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE8F5E9)))),
      child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _MPColors.green, letterSpacing: 1)),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final List<List<String>> rows;
  final Map<String, Color>? colors;
  const _InfoGrid({required this.rows, this.colors});

  @override
  Widget build(BuildContext context) {
    final pairs = <List<List<String>>>[];
    for (var i = 0; i < rows.length; i += 2) {
      pairs.add([rows[i], if (i + 1 < rows.length) rows[i + 1]]);
    }
    return Column(
      children: pairs.map((pair) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _infoCell(pair[0])),
              const SizedBox(width: 12),
              Expanded(child: pair.length > 1 ? _infoCell(pair[1]) : const SizedBox.shrink()),
            ]),
          )).toList(),
    );
  }

  Widget _infoCell(List<String> r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(r[0].toUpperCase(), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFBBBBBB), letterSpacing: 0.4)),
        const SizedBox(height: 2),
        Text(r[1], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors?[r[0]] ?? const Color(0xFF222222))),
      ],
    );
  }
}

class _CredRow extends StatelessWidget {
  final String label, value;
  final Color valColor;
  const _CredRow(this.label, this.value, {this.valColor = const Color(0xFFA5D6A7)});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF445566), letterSpacing: 0.5)),
      Text(value, style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700, color: valColor)),
    ]);
  }
}