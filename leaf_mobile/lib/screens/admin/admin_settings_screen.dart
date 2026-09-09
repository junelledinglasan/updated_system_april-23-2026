import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/settings_service.dart';
import '../../widgets/admin/admin_scaffold_helpers.dart';
import '../../widgets/staff_drawer.dart' show kStaffRoleLabels;

class _STColors {
  static const green  = Color(0xFF2E7D32);
  static const dark   = Color(0xFF1B5E20);
  static const sub    = Color(0xFF888888);
  static const border = Color(0xFFE4F0E5);
  static const red    = Color(0xFFC62828);
}

// ── BAGO: salamin ng "DEFAULT_FEATURES_BY_ROLE" sa backend
// (settings_app/models.py) — ginagamit lang para malaman kung
// "default" pa ang kasalukuyang permissions ng isang staff (hindi pa
// na-customize), para maipakita ito sa admin. ─────────────────────────
const Map<String, List<String>> kDefaultFeaturesByRole = {
  'cashier':     ['loan-payment'],
  'collector':   ['loan-payment'],
  'bookkeeper':  ['reports'],
  'admin_clerk': ['members', 'applications', 'loan-approval', 'announcement', 'reports'],
};

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  String _tab = 'logo'; // 'logo' | 'permissions' | 'gcash'

  // ── Logo state ──
  bool _loadingLogo = true;
  String? _logoUrl;
  dynamic _pickedBytes;
  String? _pickedName;
  bool _uploading = false;
  String? _error;
  String? _success;

  // ── Staff Permissions state ──
  bool _loadingStaff = true;
  List<Map<String, dynamic>> _features = [];
  List<Map<String, dynamic>> _staffList = [];
  int? _expandedStaffId;
  int? _savingStaffId;
  final Map<int, List<String>> _localPerms = {};

  // ── BAGO: maraming GCash account (multiple accounts) — dating
  // iisang number/name lang. ───────────────────────────────────────────
  bool _loadingGcash = true;
  List<Map<String, dynamic>> _gcashAccounts = [];
  String? _gcashError;
  String? _gcashSuccess;
  bool _gcashSaving = false;
  int? _editingId;
  final _editLabelCtrl = TextEditingController();
  final _editNumberCtrl = TextEditingController();
  final _editNameCtrl = TextEditingController();
  bool _showAddForm = false;
  final _addLabelCtrl = TextEditingController();
  final _addNumberCtrl = TextEditingController();
  final _addNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLogo();
  }

  @override
  void dispose() {
    _editLabelCtrl.dispose();
    _editNumberCtrl.dispose();
    _editNameCtrl.dispose();
    _addLabelCtrl.dispose();
    _addNumberCtrl.dispose();
    _addNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogo() async {
    setState(() => _loadingLogo = true);
    final url = await SettingsService.getLogoUrl(forceRefresh: true);
    if (mounted) setState(() { _logoUrl = url; _loadingLogo = false; });
  }

  Future<void> _loadStaffPermissions() async {
    if (_staffList.isNotEmpty) return; // load once lang
    setState(() => _loadingStaff = true);
    try {
      final features = await SettingsService.getAvailableFeatures();
      final staff = await SettingsService.getStaffPermissionsList();
      if (mounted) {
        setState(() {
          _features = features;
          _staffList = staff;
          for (final s in staff) {
            final id = s['staff_id'] as int;
            _localPerms[id] = ((s['features'] as List?) ?? []).cast<String>();
          }
          _loadingStaff = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStaff = false);
    }
  }

  // ── BAGO: kunin ang listahan ng LAHAT ng GCash accounts ──────────────
  Future<void> _loadGcash() async {
    if (_gcashAccounts.isNotEmpty) return; // load once lang
    setState(() => _loadingGcash = true);
    try {
      final data = await SettingsService.getGCashAccounts();
      if (mounted) setState(() { _gcashAccounts = data; _loadingGcash = false; });
    } catch (_) {
      if (mounted) setState(() { _gcashError = 'Failed to load GCash accounts.'; _loadingGcash = false; });
    }
  }

  Future<void> _handleAddAccount() async {
    setState(() { _gcashError = null; _gcashSuccess = null; });
    if (_addNumberCtrl.text.trim().isEmpty) { setState(() => _gcashError = 'GCash number is required.'); return; }
    if (_addNameCtrl.text.trim().isEmpty)   { setState(() => _gcashError = 'Account name is required.'); return; }
    setState(() => _gcashSaving = true);
    try {
      final created = await SettingsService.createGCashAccount(
        number: _addNumberCtrl.text.trim(), accountName: _addNameCtrl.text.trim(), label: _addLabelCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _gcashAccounts = [..._gcashAccounts, created];
          _addLabelCtrl.clear(); _addNumberCtrl.clear(); _addNameCtrl.clear();
          _showAddForm = false;
          _gcashSuccess = 'New GCash account added!';
          _gcashSaving = false;
        });
        Future.delayed(const Duration(milliseconds: 3000), () { if (mounted) setState(() => _gcashSuccess = null); });
      }
    } catch (e) {
      if (mounted) setState(() { _gcashError = 'Failed to add GCash account.'; _gcashSaving = false; });
    }
  }

  void _startEdit(Map<String, dynamic> acc) {
    setState(() {
      _editingId = acc['id'];
      _editLabelCtrl.text = acc['label'] ?? '';
      _editNumberCtrl.text = acc['number'] ?? '';
      _editNameCtrl.text = acc['account_name'] ?? '';
      _gcashError = null;
    });
  }

  Future<void> _handleSaveEdit(int id) async {
    if (_editNumberCtrl.text.trim().isEmpty) { setState(() => _gcashError = 'GCash number is required.'); return; }
    if (_editNameCtrl.text.trim().isEmpty)   { setState(() => _gcashError = 'Account name is required.'); return; }
    setState(() => _gcashSaving = true);
    try {
      final updated = await SettingsService.updateGCashAccount(id, {
        'label': _editLabelCtrl.text.trim(), 'number': _editNumberCtrl.text.trim(), 'account_name': _editNameCtrl.text.trim(),
      });
      if (mounted) {
        setState(() {
          _gcashAccounts = _gcashAccounts.map((a) => a['id'] == id ? updated : a).toList();
          _editingId = null;
          _gcashSaving = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _gcashError = 'Failed to update GCash account.'; _gcashSaving = false; });
    }
  }

  Future<void> _handleToggleActive(Map<String, dynamic> acc) async {
    try {
      final updated = await SettingsService.updateGCashAccount(acc['id'], {'is_active': !(acc['is_active'] as bool)});
      if (mounted) setState(() => _gcashAccounts = _gcashAccounts.map((a) => a['id'] == acc['id'] ? updated : a).toList());
    } catch (_) {
      if (mounted) setState(() => _gcashError = 'Failed to update account status.');
    }
  }

  Future<void> _handleDeleteAccount(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete GCash Account?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SettingsService.deleteGCashAccount(id);
      if (mounted) setState(() => _gcashAccounts = _gcashAccounts.where((a) => a['id'] != id).toList());
    } catch (_) {
      if (mounted) setState(() => _gcashError = 'Failed to delete GCash account.');
    }
  }

  void _toggleFeature(int staffId, String key) {
    setState(() {
      final current = List<String>.from(_localPerms[staffId] ?? []);
      if (current.contains(key)) {
        current.remove(key);
      } else {
        current.add(key);
      }
      _localPerms[staffId] = current;
    });
  }

  Future<void> _handleSavePermissions(int staffId) async {
    setState(() => _savingStaffId = staffId);
    try {
      await SettingsService.updateStaffPermissions(staffId, _localPerms[staffId] ?? []);
      if (mounted) {
        setState(() {
          final idx = _staffList.indexWhere((s) => s['staff_id'] == staffId);
          if (idx != -1) _staffList[idx]['features'] = _localPerms[staffId];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _savingStaffId = null);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 2 * 1024 * 1024) {
      setState(() => _error = 'File too large. Maximum is 2MB.');
      return;
    }
    setState(() { _pickedBytes = bytes; _pickedName = picked.name; _error = null; });
  }

  Future<void> _handleUpload() async {
    if (_pickedBytes == null) { setState(() => _error = 'Please choose an image first.'); return; }
    setState(() { _uploading = true; _error = null; });
    try {
      final res = await SettingsService.uploadLogo(_pickedBytes, _pickedName ?? 'logo.png');
      if (mounted) {
        setState(() {
          _logoUrl = res['logo_url'] as String?;
          _pickedBytes = null;
          _pickedName = null;
          _success = 'Logo updated successfully! It is now applied across the whole system.';
          _uploading = false;
        });
        Future.delayed(const Duration(milliseconds: 3500), () { if (mounted) setState(() => _success = null); });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to upload logo. Please try again.'; _uploading = false; });
    }
  }

  Future<void> _handleReset() async {
    setState(() { _uploading = true; _error = null; });
    try {
      await SettingsService.resetLogo();
      if (mounted) {
        setState(() { _logoUrl = null; _success = 'Logo reset to the default LEAF MPC logo.'; _uploading = false; });
        Future.delayed(const Duration(milliseconds: 3500), () { if (mounted) setState(() => _success = null); });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to reset logo.'; _uploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScreenScaffold(
      activeRouteKey: '',
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Row(children: [
              Expanded(child: _TabBtn(label: '🖼️ Logo', active: _tab == 'logo', onTap: () => setState(() => _tab = 'logo'))),
              Expanded(child: _TabBtn(label: '🔐 Staff Permissions', active: _tab == 'permissions', onTap: () { setState(() => _tab = 'permissions'); _loadStaffPermissions(); })),
              // ── BAGO: GCash Payment tab ──
              Expanded(child: _TabBtn(label: '💳 GCash', active: _tab == 'gcash', onTap: () { setState(() => _tab = 'gcash'); _loadGcash(); })),
            ]),
          ),
          Expanded(
            child: _tab == 'logo'
                ? _buildLogoTab()
                : _tab == 'permissions'
                    ? _buildPermissionsTab()
                    : _buildGcashTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoTab() {
    if (_loadingLogo) return const Center(child: CircularProgressIndicator(color: _STColors.green));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _STColors.dark)),
          const Text('Customize your LEAF MPC system.', style: TextStyle(fontSize: 11, color: _STColors.sub)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _STColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CURRENT LOGO', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 90,
                  decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: _STColors.border)),
                  alignment: Alignment.center,
                  child: _logoUrl != null
                      ? Image.network(_logoUrl!, height: 60, fit: BoxFit.contain)
                      : Column(mainAxisSize: MainAxisSize.min, children: const [
                          Icon(Icons.image_outlined, size: 26, color: Color(0xFFBBBBBB)),
                          SizedBox(height: 6),
                          Text('Using default LEAF MPC logo', style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
                        ]),
                ),
                const SizedBox(height: 18),
                const Text('UPLOAD NEW LOGO', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
                const SizedBox(height: 4),
                const Text('Recommended: transparent PNG or SVG, wide aspect ratio (e.g. 300×60px). Max 2MB.', style: TextStyle(fontSize: 10.5, color: _STColors.sub, height: 1.5)),
                const SizedBox(height: 10),
                if (_pickedBytes != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFF7FAF7), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFC8E6C9))),
                    child: Column(children: [
                      Image.memory(_pickedBytes, height: 70, fit: BoxFit.contain),
                      const SizedBox(height: 8),
                      TextButton(onPressed: () => setState(() { _pickedBytes = null; _pickedName = null; }), child: const Text('✕ Remove', style: TextStyle(color: _STColors.red, fontSize: 12))),
                    ]),
                  )
                else
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(color: const Color(0xFFF9FEF9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFC8E6C9), width: 2)),
                      child: Column(children: const [
                        Icon(Icons.upload_outlined, size: 26, color: _STColors.green),
                        SizedBox(height: 6),
                        Text('Tap to choose an image', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _STColors.green)),
                        SizedBox(height: 2),
                        Text('PNG, JPG, WEBP', style: TextStyle(fontSize: 10.5, color: Color(0xFFAAAAAA))),
                      ]),
                    ),
                  ),
                if (_error != null) Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)), child: Text(_error!, style: const TextStyle(fontSize: 11.5, color: _STColors.red, fontWeight: FontWeight.w600))),
                if (_success != null) Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)), child: Text(_success!, style: const TextStyle(fontSize: 11.5, color: _STColors.green, fontWeight: FontWeight.w600))),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(onPressed: (_uploading || _logoUrl == null) ? null : _handleReset, icon: const Icon(Icons.restore, size: 14), label: const Text('Reset to Default', style: TextStyle(fontSize: 12)))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _STColors.green, foregroundColor: Colors.white),
                      onPressed: (_uploading || _pickedBytes == null) ? null : _handleUpload,
                      child: _uploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Logo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── BAGO: GCash Payment tab — dating iisang number/name lang, ngayon
  // puwede nang magdagdag ng ILAN pang account, para maiwasan ang
  // limit ng isang account lang. ───────────────────────────────────────
  Widget _buildGcashTab() {
    if (_loadingGcash) return const Center(child: CircularProgressIndicator(color: _STColors.green));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.smartphone, size: 15, color: _STColors.green),
            SizedBox(width: 8),
            Expanded(child: Text('Ang mga aktibong account sa ibaba ay ipapakita bilang mga choices sa member sa "Pay via GCash" modal.', style: TextStyle(fontSize: 11, color: _STColors.sub, height: 1.5))),
          ]),
          const SizedBox(height: 14),

          if (_gcashError != null) Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)), child: Text(_gcashError!, style: const TextStyle(fontSize: 11.5, color: _STColors.red, fontWeight: FontWeight.w600))),
          if (_gcashSuccess != null) Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)), child: Text(_gcashSuccess!, style: const TextStyle(fontSize: 11.5, color: _STColors.green, fontWeight: FontWeight.w600))),

          ..._gcashAccounts.map((acc) {
            final isActive = acc['is_active'] as bool? ?? true;
            final isEditing = _editingId == acc['id'];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFF9FEF9) : const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isActive ? const Color(0xFFC8E6C9) : const Color(0xFFEEEEEE)),
              ),
              child: isEditing
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      TextField(controller: _editLabelCtrl, decoration: InputDecoration(hintText: 'Label (e.g. Primary)', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                      const SizedBox(height: 8),
                      TextField(controller: _editNumberCtrl, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700), decoration: InputDecoration(hintText: 'GCash Number', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                      const SizedBox(height: 8),
                      TextField(controller: _editNameCtrl, decoration: InputDecoration(hintText: 'Account Name', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton(onPressed: () => setState(() => _editingId = null), child: const Text('Cancel')),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: _STColors.green, foregroundColor: Colors.white),
                          onPressed: _gcashSaving ? null : () => _handleSaveEdit(acc['id']),
                          child: const Text('Save'),
                        ),
                      ]),
                    ])
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            if ((acc['label'] as String?)?.isNotEmpty == true)
                              Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)), child: Text(acc['label'], style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _STColors.green))),
                            if (!isActive) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1), decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(20)), child: const Text('Inactive', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF888888)))),
                          ]),
                          const SizedBox(height: 4),
                          Text(acc['number'] ?? '', style: const TextStyle(fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                          Text(acc['account_name'] ?? '', style: const TextStyle(fontSize: 11.5, color: Color(0xFF666666))),
                        ]),
                      ),
                      Column(children: [
                        Switch(value: isActive, activeColor: _STColors.green, onChanged: (_) => _handleToggleActive(acc)),
                        Row(children: [
                          IconButton(onPressed: () => _startEdit(acc), icon: const Icon(Icons.edit_outlined, size: 16), color: const Color(0xFF555555), visualDensity: VisualDensity.compact),
                          IconButton(onPressed: () => _handleDeleteAccount(acc['id']), icon: const Icon(Icons.delete_outline, size: 16), color: _STColors.red, visualDensity: VisualDensity.compact),
                        ]),
                      ]),
                    ]),
            );
          }),

          if (_showAddForm)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF9FEF9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFA5D6A7), style: BorderStyle.solid)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('LABEL (OPTIONAL)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
                const SizedBox(height: 6),
                TextField(controller: _addLabelCtrl, decoration: InputDecoration(hintText: 'e.g. Backup', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                const SizedBox(height: 10),
                const Text('GCASH NUMBER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
                const SizedBox(height: 6),
                TextField(controller: _addNumberCtrl, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700), decoration: InputDecoration(hintText: 'e.g. 0967-006-3500', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                const SizedBox(height: 10),
                const Text('ACCOUNT NAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
                const SizedBox(height: 6),
                TextField(controller: _addNameCtrl, decoration: InputDecoration(hintText: 'e.g. LEAF MPC', isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => setState(() { _showAddForm = false; _addLabelCtrl.clear(); _addNumberCtrl.clear(); _addNameCtrl.clear(); }), child: const Text('Cancel')),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _STColors.green, foregroundColor: Colors.white),
                    onPressed: _gcashSaving ? null : _handleAddAccount,
                    child: _gcashSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Add Account'),
                  ),
                ]),
              ]),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showAddForm = true),
                style: OutlinedButton.styleFrom(foregroundColor: _STColors.green, side: const BorderSide(color: Color(0xFFA5D6A7)), padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Another GCash Account', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionsTab() {
    if (_loadingStaff) return const Center(child: CircularProgressIndicator(color: _STColors.green));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF9FEF9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE8F5E9))),
            child: const Text('Piliin kung anong mga module ang makikita ng bawat staff account. Kapag walang check, hindi lalabas sa portal nila ang feature na iyon.', style: TextStyle(fontSize: 11, color: Color(0xFF555555), height: 1.5)),
          ),
          const SizedBox(height: 12),
          if (_staffList.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('No staff accounts found.', style: TextStyle(color: _STColors.sub))))
          else
            ..._staffList.map((s) {
              final id = s['staff_id'] as int;
              final isOpen = _expandedStaffId == id;
              final perms = _localPerms[id] ?? [];
              final savedFeatures = ((s['features'] as List?) ?? []).cast<String>();
              final dirty = (perms.toSet().difference(savedFeatures.toSet()).isNotEmpty) || (savedFeatures.toSet().difference(perms.toSet()).isNotEmpty);
              final roleLabel = kStaffRoleLabels[s['staff_role']] ?? s['staff_role'] ?? 'Staff';
              // ── BAGO: "(default)" indicator — para malinaw sa admin
              // kung ito pa rin ang sensible na panimulang set (base
              // sa role) at hindi pa sila mismo nag-customize. ───────
              final roleDefaults = kDefaultFeaturesByRole[s['staff_role']] ?? [];
              final isDefault = perms.toSet().difference(roleDefaults.toSet()).isEmpty && roleDefaults.toSet().difference(perms.toSet()).isEmpty;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: _STColors.border)),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _expandedStaffId = isOpen ? null : id),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${s['staff_name']}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                Text.rich(TextSpan(
                                  text: '$roleLabel · ${perms.length} feature${perms.length != 1 ? 's' : ''} enabled',
                                  style: const TextStyle(fontSize: 10.5, color: _STColors.sub),
                                  children: [
                                    if (isDefault) const TextSpan(text: '  (default)', style: TextStyle(fontStyle: FontStyle.italic)),
                                  ],
                                )),
                              ],
                            ),
                          ),
                          Icon(isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: _STColors.sub),
                        ]),
                      ),
                    ),
                    if (isOpen)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F0F0)))),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _features.map((f) {
                                final key = f['key'] as String;
                                final checked = perms.contains(key);
                                return SizedBox(
                                  width: (MediaQuery.of(context).size.width - 80) / 2,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: CheckboxListTile(
                                      value: checked,
                                      onChanged: (_) => _toggleFeature(id, key),
                                      title: Text('${f['label']}', style: const TextStyle(fontSize: 11.5)),
                                      controlAffinity: ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      activeColor: _STColors.green,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _STColors.green, foregroundColor: Colors.white),
                                onPressed: (!dirty || _savingStaffId == id) ? null : () => _handleSavePermissions(id),
                                child: _savingStaffId == id
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(dirty ? 'Save Changes' : 'Saved', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? _STColors.green : Colors.transparent, width: 2.5))),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: active ? FontWeight.w700 : FontWeight.w600, color: active ? _STColors.green : const Color(0xFFAAAAAA))),
      ),
    );
  }
}