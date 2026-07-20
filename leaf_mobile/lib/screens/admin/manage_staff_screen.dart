import 'package:flutter/material.dart';
import '../../services/staff_service.dart';
import '../../widgets/admin/admin_scaffold_helpers.dart';

class _MSColors {
  static const title  = Color(0xFF1B5E20);
  static const sub    = Color(0xFF8A9A7A);
  static const green  = Color(0xFF2E7D32);
  static const border = Color(0xFFC8DDC8);
  static const orange = Color(0xFFE65100);
  static const red    = Color(0xFFC62828);
  static const blue   = Color(0xFF1565C0);
}

const Map<String, String> kStaffRoleLabels = {
  'cashier': 'Cashier',
  'collector': 'Collector',
  'admin_clerk': 'Administrative Clerk',
};

const List<Map<String, String>> kStaffRoleOptions = [
  {'value': 'cashier', 'label': 'Cashier'},
  {'value': 'collector', 'label': 'Collector'},
  {'value': 'admin_clerk', 'label': 'Administrative Clerk'},
];

class ManageStaffScreen extends StatefulWidget {
  const ManageStaffScreen({super.key});

  @override
  State<ManageStaffScreen> createState() => _ManageStaffScreenState();
}

class _ManageStaffScreenState extends State<ManageStaffScreen> {
  List<dynamic> _staffList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    setState(() => _loading = true);
    try {
      final data = await StaffService.getStaffList();
      if (mounted) setState(() => _staffList = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? _MSColors.red : _MSColors.green, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openAdd() async {
    final result = await showDialog<bool>(context: context, builder: (context) => const _AddStaffDialog());
    if (result == true) {
      _showToast('Staff account created!');
      _fetchStaff();
    }
  }

  Future<void> _openEdit(dynamic staff) async {
    final result = await showDialog<bool>(context: context, builder: (context) => _EditStaffDialog(staff: staff));
    if (result == true) {
      _showToast('Staff updated!');
      _fetchStaff();
    }
  }

  Future<void> _openResetPassword(dynamic staff) async {
    await showDialog<bool>(context: context, builder: (context) => _ResetPasswordDialog(staff: staff));
  }

  Future<void> _openDelete(dynamic staff) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => _DeleteStaffDialog(staff: staff));
    if (confirmed != true) return;
    try {
      await StaffService.deleteStaff(staff['id']);
      _showToast('Staff account deleted.', isError: true);
      _fetchStaff();
    } catch (_) {
      _showToast('Failed to delete staff.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _staffList.where((s) => s['is_active'] == true).length;

    return AdminScreenScaffold(
      activeRouteKey: 'staff',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: _MSColors.green,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 18),
        label: const Text('Add Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStaff,
        color: _MSColors.green,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Manage Staff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _MSColors.title)),
              const SizedBox(height: 2),
              const Text('View, add, and manage staff accounts for office personnel.', style: TextStyle(fontSize: 11, color: _MSColors.sub)),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(child: _StatCard(label: 'Total Staff', value: '${_staffList.length}', color: _MSColors.title)),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(label: 'Active', value: '$activeCount', color: _MSColors.green)),
                ],
              ),
              const SizedBox(height: 16),

              if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: _MSColors.green)))
              else if (_staffList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.people_outline, size: 36, color: Color(0xFFCCCCCC)),
                        const SizedBox(height: 8),
                        const Text('No staff accounts yet.', style: TextStyle(color: _MSColors.sub)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: _MSColors.green, foregroundColor: Colors.white),
                          onPressed: _openAdd,
                          icon: const Icon(Icons.person_add_alt_1, size: 16),
                          label: const Text('Add First Staff'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._staffList.map((s) => _StaffCard(
                      staff: s,
                      onEdit: () => _openEdit(s),
                      onResetPassword: () => _openResetPassword(s),
                      onDelete: () => _openDelete(s),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _MSColors.border), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: _MSColors.sub, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final dynamic staff;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onDelete;
  const _StaffCard({required this.staff, required this.onEdit, required this.onResetPassword, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = '${staff['name'] ?? ''}';
    final roleLabel = kStaffRoleLabels[staff['staff_role']] ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _MSColors.green,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text('@${staff['username'] ?? ''}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF666666), fontFamily: 'monospace')),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFBBDEFB))),
                child: Text(roleLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _MSColors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _ActionBtn(icon: Icons.edit_outlined, label: 'Edit', bg: const Color(0xFFE8F5E9), fg: _MSColors.title, onTap: onEdit)),
              const SizedBox(width: 6),
              Expanded(child: _ActionBtn(icon: Icons.key_outlined, label: 'Reset', bg: const Color(0xFFFFF3E0), fg: _MSColors.orange, onTap: onResetPassword)),
              const SizedBox(width: 6),
              Expanded(child: _ActionBtn(icon: Icons.delete_outline, label: 'Delete', bg: const Color(0xFFFCE4EC), fg: _MSColors.red, onTap: onDelete)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.bg, required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Add Staff Dialog ──────────────────────────────────────────────────────
class _AddStaffDialog extends StatefulWidget {
  const _AddStaffDialog();

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _role;
  bool _showPw = false;
  bool _loading = false;
  Map<String, dynamic>? _done;
  final Map<String, String> _errors = {};

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    if (_nameCtrl.text.trim().isEmpty) e['name'] = 'Name is required.';
    if (_usernameCtrl.text.trim().isEmpty) e['username'] = 'Username is required.';
    if (_usernameCtrl.text.length < 4) e['username'] = 'Minimum 4 characters.';
    if (_role == null) e['staff_role'] = 'Please select a role.';
    if (_passwordCtrl.text.isEmpty) e['password'] = 'Password is required.';
    if (_passwordCtrl.text.length < 6) e['password'] = 'Minimum 6 characters.';
    if (_passwordCtrl.text != _confirmCtrl.text) e['confirm'] = 'Passwords do not match.';
    return e;
  }

  Future<void> _submit() async {
    final e = _validate();
    if (e.isNotEmpty) { setState(() => _errors..clear()..addAll(e)); return; }
    setState(() => _loading = true);
    try {
      final staff = await StaffService.addStaff({
        'name': _nameCtrl.text,
        'username': _usernameCtrl.text,
        'password': _passwordCtrl.text,
        'staff_role': _role,
      });
      if (mounted) setState(() => _done = staff);
    } catch (_) {
      if (mounted) setState(() => _errors['username'] = 'Username already exists.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done != null) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: _MSColors.green, size: 40),
              const SizedBox(height: 10),
              const Text('Staff Account Created!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _MSColors.title)),
              const SizedBox(height: 8),
              Text('${_done!['name']} can now log in using the credentials below.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF555555))),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAF8), border: Border.all(color: const Color(0xFFC8E6C9)), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  children: [
                    _CredRow('Name', '${_done!['name']}'),
                    _CredRow('Username', '${_done!['username']}'),
                    _CredRow('Role', kStaffRoleLabels[_done!['staff_role']] ?? '${_done!['staff_role']}'),
                    _CredRow('Password', _passwordCtrl.text),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _MSColors.green, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Staff', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _MSColors.title)),
              const Text('Create a staff account for office personnel', style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
              const SizedBox(height: 14),
              _LabeledField('Full Name', required: true, error: _errors['name'], child: TextField(controller: _nameCtrl, decoration: _dec('e.g. Juan Dela Cruz'))),
              const SizedBox(height: 10),
              _LabeledField('Username', required: true, error: _errors['username'], child: TextField(controller: _usernameCtrl, decoration: _dec('e.g. juan123'))),
              const SizedBox(height: 10),
              _LabeledField(
                'Staff Role',
                required: true,
                error: _errors['staff_role'],
                child: DropdownButtonFormField<String>(
                  value: _role,
                  items: kStaffRoleOptions.map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!, style: const TextStyle(fontSize: 12.5)))).toList(),
                  onChanged: (v) => setState(() => _role = v),
                  decoration: _dec('— Select a role —'),
                ),
              ),
              const SizedBox(height: 10),
              _LabeledField(
                'Password',
                required: true,
                error: _errors['password'],
                child: TextField(
                  controller: _passwordCtrl,
                  obscureText: !_showPw,
                  decoration: _dec('At least 6 characters').copyWith(
                    suffixIcon: IconButton(icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility, size: 16), onPressed: () => setState(() => _showPw = !_showPw)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _LabeledField(
                'Confirm Password',
                required: true,
                error: _errors['confirm'],
                child: TextField(controller: _confirmCtrl, obscureText: !_showPw, decoration: _dec('Re-enter password')),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _MSColors.green, foregroundColor: Colors.white),
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Edit Staff Dialog ─────────────────────────────────────────────────────
class _EditStaffDialog extends StatefulWidget {
  final dynamic staff;
  const _EditStaffDialog({required this.staff});

  @override
  State<_EditStaffDialog> createState() => _EditStaffDialogState();
}

class _EditStaffDialogState extends State<_EditStaffDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  String? _role;
  bool _loading = false;
  bool _done = false;
  final Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: '${widget.staff['name'] ?? ''}');
    _usernameCtrl = TextEditingController(text: '${widget.staff['username'] ?? ''}');
    _role = widget.staff['staff_role'];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final e = <String, String>{};
    if (_nameCtrl.text.trim().isEmpty) e['name'] = 'Name is required.';
    if (_usernameCtrl.text.trim().isEmpty) e['username'] = 'Username is required.';
    if (_role == null) e['staff_role'] = 'Please select a role.';
    if (e.isNotEmpty) { setState(() => _errors..clear()..addAll(e)); return; }
    setState(() => _loading = true);
    try {
      await StaffService.editStaff(widget.staff['id'], {'name': _nameCtrl.text, 'username': _usernameCtrl.text, 'staff_role': _role});
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) setState(() => _errors['username'] = 'Username already taken.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: _MSColors.green, size: 40),
              const SizedBox(height: 10),
              const Text('Staff Updated!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _MSColors.title)),
              const SizedBox(height: 6),
              const Text('Staff account has been successfully updated.', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _MSColors.green, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Staff Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _MSColors.title)),
              const Text('Update staff name, username and role', style: TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
              const SizedBox(height: 14),
              _LabeledField('Full Name', required: true, error: _errors['name'], child: TextField(controller: _nameCtrl, decoration: _dec(''))),
              const SizedBox(height: 10),
              _LabeledField('Username', required: true, error: _errors['username'], child: TextField(controller: _usernameCtrl, decoration: _dec(''))),
              const SizedBox(height: 10),
              _LabeledField(
                'Staff Role',
                required: true,
                error: _errors['staff_role'],
                child: DropdownButtonFormField<String>(
                  value: kStaffRoleOptions.any((o) => o['value'] == _role) ? _role : null,
                  items: kStaffRoleOptions.map((o) => DropdownMenuItem(value: o['value'], child: Text(o['label']!, style: const TextStyle(fontSize: 12.5)))).toList(),
                  onChanged: (v) => setState(() => _role = v),
                  decoration: _dec('— Select a role —'),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _MSColors.green, foregroundColor: Colors.white),
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reset Password Dialog ─────────────────────────────────────────────────
class _ResetPasswordDialog extends StatefulWidget {
  final dynamic staff;
  const _ResetPasswordDialog({required this.staff});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPw = false;
  bool _loading = false;
  bool _done = false;
  final Map<String, String> _errors = {};

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final e = <String, String>{};
    if (_passwordCtrl.text.isEmpty) e['password'] = 'New password is required.';
    if (_passwordCtrl.text.length < 6) e['password'] = 'Minimum 6 characters.';
    if (_passwordCtrl.text != _confirmCtrl.text) e['confirm'] = 'Passwords do not match.';
    if (e.isNotEmpty) { setState(() => _errors..clear()..addAll(e)); return; }
    setState(() => _loading = true);
    try {
      await StaffService.resetStaffPassword(widget.staff['id'], _passwordCtrl.text);
      if (mounted) setState(() => _done = true);
    } catch (_) {
      if (mounted) setState(() => _errors['password'] = 'Failed to reset password. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = '${widget.staff['name'] ?? ''}';

    if (_done) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.key, color: _MSColors.orange, size: 36),
              const SizedBox(height: 10),
              const Text('Password Reset!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _MSColors.title)),
              const SizedBox(height: 6),
              Text('New password for $name has been set.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF555555))),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF8FAF8), border: Border.all(color: const Color(0xFFC8E6C9)), borderRadius: BorderRadius.circular(8)),
                child: Column(children: [
                  _CredRow('Username', '${widget.staff['username']}'),
                  _CredRow('New Password', _passwordCtrl.text),
                ]),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _MSColors.green, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reset Password', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _MSColors.title)),
              Text('Set a new password for $name', style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF1F8E9), border: Border.all(color: const Color(0xFFC8E6C9)), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  CircleAvatar(radius: 16, backgroundColor: _MSColors.green, child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _MSColors.title)),
                    Text('@${widget.staff['username']} · ${kStaffRoleLabels[widget.staff['staff_role']] ?? "Staff"}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF888888))),
                  ])),
                ]),
              ),
              const SizedBox(height: 12),
              _LabeledField(
                'New Password',
                required: true,
                error: _errors['password'],
                child: TextField(
                  controller: _passwordCtrl,
                  obscureText: !_showPw,
                  decoration: _dec('At least 6 characters').copyWith(suffixIcon: IconButton(icon: Icon(_showPw ? Icons.visibility_off : Icons.visibility, size: 16), onPressed: () => setState(() => _showPw = !_showPw))),
                ),
              ),
              const SizedBox(height: 10),
              _LabeledField('Confirm New Password', required: true, error: _errors['confirm'], child: TextField(controller: _confirmCtrl, obscureText: !_showPw, decoration: _dec('Re-enter new password'))),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _MSColors.orange, foregroundColor: Colors.white),
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Reset Password'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Delete Staff Dialog ────────────────────────────────────────────────────
class _DeleteStaffDialog extends StatelessWidget {
  final dynamic staff;
  const _DeleteStaffDialog({required this.staff});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Delete Staff Account', style: TextStyle(color: _MSColors.red, fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _MSColors.red, size: 36),
          const SizedBox(height: 10),
          const Text('Are you sure you want to delete this staff account?', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF8FAF8), border: Border.all(color: const Color(0xFFC8E6C9)), borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              _CredRow('Name', '${staff['name']}'),
              _CredRow('Username', '@${staff['username']}'),
              _CredRow('Role', kStaffRoleLabels[staff['staff_role']] ?? '—'),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(8)),
            child: const Text('This action cannot be undone.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: _MSColors.red)),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _MSColors.red, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes, Delete'),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool required;
  final String? error;
  const _LabeledField(this.label, {required this.child, this.required = false, this.error});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(text: label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.4), children: [
          if (required) const TextSpan(text: ' *', style: TextStyle(color: _MSColors.red)),
        ])),
        const SizedBox(height: 4),
        child,
        if (error != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(error!, style: const TextStyle(fontSize: 10, color: _MSColors.red, fontWeight: FontWeight.w600))),
      ],
    );
  }
}

class _CredRow extends StatelessWidget {
  final String label;
  final String value;
  const _CredRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _MSColors.title, fontFamily: 'monospace')),
      ]),
    );
  }
}

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _MSColors.green)),
    );