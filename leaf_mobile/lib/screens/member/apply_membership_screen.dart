import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/member_provider.dart';
import '../../services/members_service.dart';
import '../../services/supabase_storage_service.dart';
import '../../widgets/member_scaffold_helpers.dart';
import '../../widgets/ph_address_picker.dart';

class _AMColors {
  static const green  = Color(0xFF2E7D32);
  static const dark   = Color(0xFF1B5E20);
  static const sub    = Color(0xFF888888);
  static const border = Color(0xFFE0E0E0);
  static const label  = Color(0xFFAAAAAA);
  static const red    = Color(0xFFE53935);
}

class ApplyMembershipScreen extends StatefulWidget {
  const ApplyMembershipScreen({super.key});

  @override
  State<ApplyMembershipScreen> createState() => _ApplyMembershipScreenState();
}

class _ApplyMembershipScreenState extends State<ApplyMembershipScreen> {
  bool _checkingApp = true;
  Map<String, dynamic>? _existingApp;
  bool _resubmit = false;
  bool _done = false;
  bool _loading = false;
  String _uploadProgress = '';
  int _tabIndex = 0; // 0=personal,1=spouse,2=classification,3=verification
  final Map<String, String> _errors = {};

  final Map<String, dynamic> _form = {
    'first_name': '', 'last_name': '', 'middle_name': '',
    'birth_date': '', 'place_of_birth': '', 'sex': '', 'sex_other': '',
    'civil_status': 'Single', 'educational_attainment': '',
    'contact_number': '', 'email': '', 'address': '',
    'occupation': '', 'income': '', 'tin_no': '', 'sss_gsis_no': '',
    'religious_social_affiliation': '',
    'birth_certificate': false, 'marriage_certificate': false,
    'spouse_name': '', 'spouse_occupation': '', 'spouse_income': '',
    'no_of_dependants': '', 'beneficiary_name': '', 'beneficiary_relationship': '',
    'credit_references': '',
    'classification': 'Employed', 'school_name': '', 'year_level': '', 'allowance': '',
    'pension_income': '', 'job_type': 'Employed', 'monthly_income': '',
  };
  final Map<String, TextEditingController> _c = {};
  TextEditingController _ctrl(String key) => _c.putIfAbsent(key, () => TextEditingController(text: '${_form[key]}'));

  // ── BAGO: dating "Valid ID" (front + back, 2 uploads) — ngayon
  // "Birth Certificate" na lang (1 upload). ───────────────────────────
  dynamic _birthCertBytes;
  String? _birthCertName;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _form['first_name'] = (auth.name ?? '').split(' ').first;
    _checkExisting();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _checkExisting() async {
    try {
      final app = await MembersService.getMyOnlineApp();
      if (mounted) setState(() => _existingApp = app);
    } catch (_) {
      if (mounted) setState(() => _existingApp = null);
    } finally {
      if (mounted) setState(() => _checkingApp = false);
    }
  }

  Future<void> _pickBirthCert() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      setState(() => _errors['birth_cert'] = 'File too large. Maximum is 5MB.');
      return;
    }
    setState(() {
      _birthCertBytes = bytes;
      _birthCertName = picked.name;
      _errors.remove('birth_cert');
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime(2000, 1, 1), firstDate: DateTime(1930), lastDate: DateTime.now());
    if (picked != null) {
      final formatted = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        _form['birth_date'] = formatted;
        _ctrl('birth_date').text = formatted;
        _errors.remove('birth_date');
      });
    }
  }

  void _syncControllers() {
    for (final entry in _c.entries) {
      _form[entry.key] = entry.value.text;
    }
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    if ('${_form['first_name']}'.trim().isEmpty) e['first_name'] = 'Required';
    if ('${_form['last_name']}'.trim().isEmpty) e['last_name'] = 'Required';
    if ('${_form['birth_date']}'.trim().isEmpty) e['birth_date'] = 'Required';
    if ('${_form['place_of_birth']}'.trim().isEmpty) e['place_of_birth'] = 'Required';
    if ('${_form['sex']}'.trim().isEmpty) e['sex'] = 'Required';
    if ('${_form['contact_number']}'.trim().isEmpty) e['contact_number'] = 'Required';
    if ('${_form['email']}'.trim().isEmpty) {
      e['email'] = 'Required';
    } else if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch('${_form['email']}'.trim())) {
      e['email'] = 'Please enter a valid email address.';
    }
    if ('${_form['address']}'.trim().isEmpty) e['address'] = 'Please complete the address dropdowns above.';
    if (_form['sex'] == 'Other' && '${_form['sex_other']}'.trim().isEmpty) e['sex_other'] = 'Please specify';
    if ('${_form['occupation']}'.trim().isEmpty) e['occupation'] = 'Required';
    if (_form['classification'] == 'Student') {
      if ('${_form['school_name']}'.trim().isEmpty) e['school_name'] = 'Required';
      if ('${_form['year_level']}'.trim().isEmpty) e['year_level'] = 'Required';
    }
    if (_birthCertBytes == null) e['birth_cert'] = 'Please upload your Birth Certificate.';
    return e;
  }

  Future<void> _handleSubmit() async {
    _syncControllers();
    final errs = _validate();
    if (errs.isNotEmpty) {
      setState(() => _errors..clear()..addAll(errs));
      const personalFields = ['first_name', 'last_name', 'birth_date', 'place_of_birth', 'sex', 'sex_other', 'contact_number', 'email', 'address', 'occupation'];
      const classFields = ['school_name', 'year_level'];
      const idFields = ['birth_cert'];
      if (personalFields.any(errs.containsKey)) {
        setState(() => _tabIndex = 0);
      } else if (classFields.any(errs.containsKey)) {
        setState(() => _tabIndex = 2);
      } else if (idFields.any(errs.containsKey)) {
        setState(() => _tabIndex = 3);
      }
      return;
    }
    setState(() { _loading = true; _uploadProgress = 'Uploading Birth Certificate...'; });
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ext = (_birthCertName ?? 'birth_cert.jpg').split('.').last;
      final birthCertUrl = await SupabaseStorageService.uploadFile(_birthCertBytes, 'birth-certificates/$ts.$ext', folder: 'birth-certificates');
      setState(() => _uploadProgress = 'Submitting application...');

      await MembersService.submitApplication({
        'first_name': _form['first_name'], 'last_name': _form['last_name'], 'middle_name': _form['middle_name'],
        'birth_date': _form['birth_date'], 'place_of_birth': _form['place_of_birth'], 'sex': _form['sex'] == 'Other' ? _form['sex_other'] : _form['sex'],
        'civil_status': _form['civil_status'], 'educational_attainment': _form['educational_attainment'],
        'contact_number': _form['contact_number'], 'email': _form['email'], 'address': _form['address'],
        'occupation': _form['occupation'], 'income': _form['income'].toString().isEmpty ? 0 : _form['income'],
        'tin_no': _form['tin_no'], 'sss_gsis_no': _form['sss_gsis_no'],
        'religious_social_affiliation': _form['religious_social_affiliation'],
        'birth_certificate': _form['birth_certificate'], 'marriage_certificate': _form['marriage_certificate'],
        'spouse_name': _form['spouse_name'], 'spouse_occupation': _form['spouse_occupation'],
        'spouse_income': _form['spouse_income'].toString().isEmpty ? 0 : _form['spouse_income'],
        'no_of_dependants': _form['no_of_dependants'].toString().isEmpty ? 0 : _form['no_of_dependants'],
        'beneficiary_name': _form['beneficiary_name'], 'beneficiary_relationship': _form['beneficiary_relationship'],
        'credit_references': _form['credit_references'], 'classification': _form['classification'],
        'school_name': _form['school_name'], 'year_level': _form['year_level'],
        'allowance': _form['allowance'].toString().isEmpty ? 0 : _form['allowance'],
        'pension_income': _form['pension_income'].toString().isEmpty ? 0 : _form['pension_income'],
        'job_type': _form['job_type'],
        'monthly_income': _form['monthly_income'].toString().isEmpty ? 0 : _form['monthly_income'],
        // ── PAALALA: dating "id_front_url"/"id_back_url" ang dalawang
        // field na 'to (Valid ID front+back). Ngayon isa na lang na
        // Birth Certificate ang ipinapasa — inilagay ko pa rin sa
        // "id_front_url" key (backend compatibility, wala akong
        // access sa backend serializer para malaman kung meron bang
        // dedikadong field name para dito). ───────────────────────────
        'id_front_url': birthCertUrl, 'id_back_url': null,
      });
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errors['first_name'] = 'Failed to submit. Please try again.';
          _tabIndex = 0;
        });
      }
    } finally {
      if (mounted) setState(() { _loading = false; _uploadProgress = ''; });
    }
  }

  InputDecoration _dec({String? error}) => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFFAFCF8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        errorText: error,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _AMColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: error != null ? _AMColors.red : _AMColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _AMColors.green, width: 1.5)),
      );

  Widget _textField(String key, String label, {bool required = false, TextInputType? type, bool full = false}) {
    return _FieldBox(
      label: label, required: required, full: full,
      child: TextField(controller: _ctrl(key), keyboardType: type, style: const TextStyle(fontSize: 12.5), onChanged: (_) => _errors.remove(key), decoration: _dec(error: _errors[key])),
    );
  }

  Widget _selectField(String key, String label, List<String> options, {bool full = false, bool required = false}) {
    return _FieldBox(
      label: label, full: full, required: required,
      child: DropdownButtonFormField<String>(
        value: options.contains(_form[key]) ? _form[key] : null,
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 12.5)))).toList(),
        onChanged: (v) => setState(() { _form[key] = v; _errors.remove(key); }),
        decoration: _dec(error: _errors[key]),
        hint: const Text('Select...', style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MemberScreenScaffold(activeRouteKey: 'profile', body: _buildBody());
  }

  Widget _buildBody() {
    if (_checkingApp) return const Center(child: CircularProgressIndicator(color: _AMColors.green));
    if (_done) return _buildSuccess();
    if (_existingApp != null && !_resubmit) return _buildExistingStatus();
    return _buildForm();
  }

  Widget _buildSuccess() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE0EAD8))),
        child: Column(children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Application Submitted!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _AMColors.dark)),
          const SizedBox(height: 10),
          const Text('Your membership application has been submitted successfully. The admin or staff will review it and notify you once processed.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.7)),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(10)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('📋', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Expanded(child: Text('You can check the status in your notifications. You will be contacted once your application is reviewed.', style: TextStyle(fontSize: 12, color: Color(0xFF555555), height: 1.5))),
            ]),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _AMColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: () => Navigator.pushReplacementNamed(context, '/member/notifications'),
              child: const Text('Go to Notifications', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/member/profile'),
              child: const Text('View My Profile'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildExistingStatus() {
    final status = _existingApp?['application_status'];
    final isPending = status == 'Pending';
    final isApproved = status == 'Approved';
    final isRejected = status == 'Rejected';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0EAD8))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Membership Application', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _AMColors.dark)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPending ? const Color(0xFFFFF8E1) : isApproved ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isPending ? const Color(0xFFFFE082) : isApproved ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A), width: 1.5),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isPending ? '⏳' : isApproved ? '✅' : '❌', style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isPending ? 'Application Under Review' : isApproved ? 'Application Approved!' : 'Application Rejected', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isPending ? const Color(0xFFF57C00) : isApproved ? _AMColors.dark : _AMColors.red)),
                      const SizedBox(height: 4),
                      Text('Application ID: ${_existingApp?['app_id'] ?? ''} · Submitted ${'${_existingApp?['created_at'] ?? ''}'.split('T').first}', style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                      if (isRejected && _existingApp?['reject_reason'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Reason: ${_existingApp?['reject_reason']}', style: const TextStyle(fontSize: 12, color: _AMColors.red, fontStyle: FontStyle.italic))),
                      if (isPending) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Please wait for the admin to review your application.', style: TextStyle(fontSize: 12, color: Color(0xFF555555)))),
                      if (isApproved) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Please visit the LEAF MPC office to complete the process.\nBring: 2x2 ID picture, Birth Certificate, Marriage Certificate (if married), Valid ID, and ₱4,000 minimum share capital.', style: TextStyle(fontSize: 12, color: Color(0xFF555555), height: 1.5))),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pushReplacementNamed(context, '/member/profile'), child: const Text('View My Profile'))),
              if (isRejected) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _AMColors.green, foregroundColor: Colors.white),
                    onPressed: () => setState(() => _resubmit = true),
                    child: const Text('Re-apply'),
                  ),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    const tabLabels = ['Personal Info', 'Spouse & Family', 'Classification', 'Verification'];
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_resubmit ? 'Re-apply for Membership' : 'Apply for Official Membership', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _AMColors.dark)),
              const Text('Fill out the LEAF MPC Member Application & Information Sheet below.', style: TextStyle(fontSize: 11, color: _AMColors.sub)),
            ],
          ),
        ),
        if (_resubmit)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFFFF8E1),
            child: const Text('You are re-applying after a previous rejection. Make sure to correct the issues before submitting.', style: TextStyle(fontSize: 11.5, color: Color(0xFFF57C00), fontWeight: FontWeight.w600)),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFFF9FBE7),
          child: const Text('ℹ️ Make sure all information is accurate. A valid ID is required for verification.', style: TextStyle(fontSize: 11, color: Color(0xFF555555))),
        ),
        Container(
          color: Colors.white,
          child: Row(children: List.generate(tabLabels.length, (i) => _TabButton(label: tabLabels[i], index: i, active: _tabIndex == i, onTap: () => setState(() => _tabIndex = i)))),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE0EAD8))),
              child: LayoutBuilder(builder: (context, constraints) => _FieldWidth(maxWidth: constraints.maxWidth, child: _buildTabContent())),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              if (_uploadProgress.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                  child: Text(_uploadProgress, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _AMColors.green, fontWeight: FontWeight.w600)),
                ),
              Row(children: [
                if (_tabIndex > 0) Expanded(child: OutlinedButton(onPressed: () => setState(() => _tabIndex--), child: const Text('← Previous'))),
                if (_tabIndex > 0) const SizedBox(width: 10),
                if (_tabIndex < 3)
                  Expanded(
                    flex: _tabIndex == 0 ? 1 : 1,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _AMColors.green, foregroundColor: Colors.white),
                      onPressed: () { _syncControllers(); setState(() => _tabIndex++); },
                      child: const Text('Next →'),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _AMColors.green, foregroundColor: Colors.white),
                      onPressed: _loading ? null : _handleSubmit,
                      child: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_resubmit ? 'Re-submit Application' : 'Submit Application'),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    if (_tabIndex == 0) {
      return Wrap(spacing: 10, runSpacing: 10, children: [
        _textField('last_name', 'Surname', required: true),
        _textField('first_name', 'First Name', required: true),
        _textField('middle_name', 'Middle Name'),
        PhAddressPicker(
          errorRegion: _errors['address'],
          onAddressChanged: (addr) => setState(() {
            _form['address'] = addr;
            _errors.remove('address');
          }),
        ),
        _FieldBox(
          label: 'Date of Birth', required: true,
          child: InkWell(onTap: _pickDate, child: InputDecorator(decoration: _dec(error: _errors['birth_date']), child: Text('${_form['birth_date']}'.isEmpty ? 'Select date' : '${_form['birth_date']}', style: const TextStyle(fontSize: 12.5)))),
        ),
        _textField('place_of_birth', 'Place of Birth', required: true),
        _selectField('sex', 'Sex', const ['Male', 'Female', 'Non-binary', 'Prefer not to say', 'Other'], required: true),
        if (_form['sex'] == 'Other')
          _textField('sex_other', 'Please specify', required: true),
        _selectField('civil_status', 'Civil Status', const ['Single', 'Married', 'Widowed', 'Separated']),
        _textField('tin_no', 'TIN No.'),
        _textField('sss_gsis_no', 'SSS/GSIS No.'),
        _textField('occupation', 'Occupation', required: true),
        _textField('income', 'Monthly Income (₱)', type: TextInputType.number),
        _textField('contact_number', 'Tel. No. / CP No.', required: true, type: TextInputType.phone),
        _textField('email', 'Email Address', required: true, type: TextInputType.emailAddress),
        _selectField('educational_attainment', 'Educational Attainment', const ['Elementary', 'High School', 'Vocational', 'College', 'Post Graduate']),
        _textField('religious_social_affiliation', 'Religious/Social Affiliation'),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: CheckboxListTile(value: _form['birth_certificate'] == true, onChanged: (v) => setState(() => _form['birth_certificate'] = v ?? false), title: const Text('Birth Certificate Submitted', style: TextStyle(fontSize: 12)), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, dense: true, activeColor: _AMColors.green),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: CheckboxListTile(value: _form['marriage_certificate'] == true, onChanged: (v) => setState(() => _form['marriage_certificate'] = v ?? false), title: const Text('Marriage Certificate Submitted (if married)', style: TextStyle(fontSize: 12)), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, dense: true, activeColor: _AMColors.green),
          ),
        ),
      ]);
    }

    if (_tabIndex == 1) {
      return Wrap(spacing: 10, runSpacing: 10, children: [
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), decoration: BoxDecoration(color: const Color(0xFFF9FEF9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE8F5E9))), child: const Text('Fill in spouse information if married. Leave blank if not applicable.', style: TextStyle(fontSize: 11.5, color: Color(0xFF555555)))),
        _textField('spouse_name', 'Spouse Name'),
        _textField('spouse_occupation', 'Spouse Occupation'),
        _textField('spouse_income', 'Spouse Monthly Income (₱)', type: TextInputType.number),
        _textField('no_of_dependants', 'No. of Dependants', type: TextInputType.number),
        const _SectionHeader(label: 'BENEFICIARY INFORMATION'),
        _textField('beneficiary_name', 'Beneficiary Name'),
        _textField('beneficiary_relationship', 'Relationship to Applicant'),
        const _SectionHeader(label: 'CREDIT REFERENCES'),
        _FieldBox(label: 'Credit References', full: true, child: TextField(controller: _ctrl('credit_references'), maxLines: 3, style: const TextStyle(fontSize: 12.5), decoration: _dec())),
      ]);
    }

    if (_tabIndex == 2) {
      final classification = _form['classification'];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Member Classification', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _AMColors.sub)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _ClassCard(label: 'Student', icon: Icons.school_outlined, active: classification == 'Student', onTap: () => setState(() => _form['classification'] = 'Student'))),
            const SizedBox(width: 8),
            Expanded(child: _ClassCard(label: 'Senior', icon: Icons.elderly_outlined, active: classification == 'Senior', onTap: () => setState(() => _form['classification'] = 'Senior'))),
            const SizedBox(width: 8),
            Expanded(child: _ClassCard(label: 'Employed', icon: Icons.work_outline, active: classification == 'Employed', onTap: () => setState(() => _form['classification'] = 'Employed'))),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) => _FieldWidth(
                maxWidth: constraints.maxWidth,
                child: Wrap(spacing: 10, runSpacing: 10, children: [
                  if (classification == 'Student') ...[
                    _textField('school_name', 'School Name', required: true),
                    _selectField('year_level', 'Year Level', const ['Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12', '1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year', 'Graduate']),
                    _textField('allowance', 'Monthly Allowance (₱)', type: TextInputType.number),
                  ],
                  if (classification == 'Senior') ...[
                    _selectField('educational_attainment', 'Educational Attainment', const ['Elementary', 'High School', 'Vocational', 'College', 'Post Graduate']),
                    _textField('pension_income', 'Monthly Pension Income (₱)', type: TextInputType.number),
                  ],
                  if (classification == 'Employed') ...[
                    _textField('occupation', 'Occupation/Job Title'),
                    _selectField('job_type', 'Employment Type', const ['Employed', 'Self-Employed', 'Business', 'Freelance', 'Other']),
                    _textField('monthly_income', 'Monthly Income (₱)', type: TextInputType.number),
                  ],
                ]),
              )),
        ],
      );
    }

    // Tab 3: Verification
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFC8E6C9))),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Birth Certificate Verification (Required)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _AMColors.dark)),
              SizedBox(height: 6),
              Text('Upload a clear photo or scan of your PSA/NSO-issued Birth Certificate.', style: TextStyle(fontSize: 11.5, color: Color(0xFF555555), height: 1.6)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _idUpload('Birth Certificate', _birthCertBytes, _birthCertName),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFE082))),
          child: const Text('Make sure the document photo is clear and fully readable. Blurry or incomplete images may cause rejection.', style: TextStyle(fontSize: 11, color: Color(0xFFF57C00))),
        ),
      ],
    );
  }

  Widget _idUpload(String label, dynamic bytes, String? name) {
    final error = _errors['birth_cert'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(text: label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF333333)), children: const [TextSpan(text: ' *', style: TextStyle(color: _AMColors.red))])),
        const SizedBox(height: 6),
        if (bytes != null)
          Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(bytes, width: double.infinity, height: 160, fit: BoxFit.cover)),
            Positioned(top: 6, right: 6, child: GestureDetector(onTap: () => setState(() { _birthCertBytes = null; _birthCertName = null; }), child: Container(width: 26, height: 26, decoration: const BoxDecoration(color: _AMColors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)))),
            Positioned(bottom: 6, left: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)), child: Text(name ?? '', style: const TextStyle(fontSize: 10, color: Colors.white)))),
          ])
        else
          InkWell(
            onTap: _pickBirthCert,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(color: error != null ? const Color(0xFFFFF5F5) : const Color(0xFFF9FEF9), borderRadius: BorderRadius.circular(10), border: Border.all(color: error != null ? _AMColors.red : const Color(0xFFC8E6C9), width: 2)),
              child: Column(children: [
                Icon(Icons.upload_outlined, size: 28, color: error != null ? _AMColors.red : _AMColors.green),
                const SizedBox(height: 6),
                Text('Click to upload', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: error != null ? _AMColors.red : _AMColors.green)),
                const SizedBox(height: 2),
                const Text('JPG, PNG, WEBP · Max 5MB', style: TextStyle(fontSize: 10.5, color: Color(0xFFAAAAAA))),
              ]),
            ),
          ),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(error, style: const TextStyle(fontSize: 11, color: _AMColors.red))),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.only(bottom: 8, top: 4), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE8F5E9), width: 2))), child: Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _AMColors.green, letterSpacing: 0.6)));
}

class _FieldWidth extends InheritedWidget {
  final double maxWidth;
  const _FieldWidth({required this.maxWidth, required super.child});
  static double of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<_FieldWidth>();
    return widget?.maxWidth ?? MediaQuery.of(context).size.width - 32;
  }
  @override
  bool updateShouldNotify(_FieldWidth oldWidget) => oldWidget.maxWidth != maxWidth;
}

class _FieldBox extends StatelessWidget {
  final String label;
  final Widget child;
  final bool required;
  final bool full;
  const _FieldBox({required this.label, required this.child, this.required = false, this.full = false});
  @override
  Widget build(BuildContext context) {
    final available = _FieldWidth.of(context);
    final width = full ? double.infinity : (available - 10) / 2;
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(TextSpan(text: label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _AMColors.label), children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: _AMColors.red))])),
        const SizedBox(height: 4),
        child,
      ]),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int index;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.index, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? _AMColors.green : Colors.transparent, width: 2))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 9, backgroundColor: active ? _AMColors.green : const Color(0xFFE0E0E0), child: Text('${index + 1}', style: const TextStyle(fontSize: 10, color: Colors.white))),
              const SizedBox(height: 3),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: active ? _AMColors.green : _AMColors.sub), overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      );
}

class _ClassCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ClassCard({required this.label, required this.icon, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: active ? const Color(0xFFE8F5E9) : const Color(0xFFFAFAFA), border: Border.all(color: active ? _AMColors.green : const Color(0xFFE0E0E0), width: 2), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [Icon(icon, color: _AMColors.green, size: 26), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _AMColors.green))]),
        ),
      );
}