import 'package:flutter/material.dart';
import '../../services/members_service.dart';
import '../../widgets/admin/admin_scaffold_helpers.dart';
import '../../widgets/admin/age_group_chart.dart';
import 'view_edit_member_screen.dart';
import 'register_member_screen.dart';
import 'pending_application_screen.dart';
import 'savings_deposit_screen.dart';
import 'share_capital_deposit_screen.dart';

class _MMColors {
  static const pageBg      = Color(0xFFD8E8CC);
  static const cardBorder  = Color(0xFFC8DDC8);
  static const title       = Color(0xFF1B5E20);
  static const sub         = Color(0xFFAAAAAA);
  static const green       = Color(0xFF2E7D32);
  static const greenDark   = Color(0xFF1B5E20);
  static const blue        = Color(0xFF1565C0);
  static const orange      = Color(0xFFE65100);
  static const red         = Color(0xFFC62828);
}

int? computeAge(String? birthDate) {
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

class ManageMemberScreen extends StatefulWidget {
  const ManageMemberScreen({super.key});

  @override
  State<ManageMemberScreen> createState() => _ManageMemberScreenState();
}

class _ManageMemberScreenState extends State<ManageMemberScreen> {
  List<dynamic> _members = [];
  List<dynamic> _pending = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  String _mainTab = 'official'; // official | pending
  String _search = '';
  String _filterStatus = 'All';
  String _sortBy = 'newest';
  int _page = 1;
  bool _showAgeChart = false;
  static const int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        MembersService.getMembers(),
        MembersService.getMemberStats(),
        MembersService.getOnlineApplications(params: {'status': 'Approved'}),
      ]);
      final members = results[0] as List<dynamic>;
      final stats = results[1] as Map<String, dynamic>;
      final appsRaw = results[2];
      final appList = (appsRaw is Map && appsRaw['applications'] != null)
          ? appsRaw['applications'] as List<dynamic>
          : (appsRaw is List ? appsRaw : <dynamic>[]);
      final pending = appList.where((a) => a['application_status'] == 'Approved').toList();

      if (mounted) {
        setState(() {
          _members = members;
          _stats = stats;
          _pending = pending;
        });
      }
    } catch (_) {
      // silent fail — mananatiling nasa dating state
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  List<dynamic> get _filtered {
    var list = _members.where((m) {
      final matchStatus = _filterStatus == 'All' || m['status'] == _filterStatus;
      final q = _search.toLowerCase();
      final fullname = (m['fullname'] ?? '${m['first_name']} ${m['last_name']}').toString().toLowerCase();
      final memberId = (m['member_id'] ?? '').toString().toLowerCase();
      return matchStatus && (fullname.contains(q) || memberId.contains(q));
    }).toList();

    if (_sortBy == 'az') {
      list.sort((a, b) => (a['fullname'] ?? '').toString().compareTo((b['fullname'] ?? '').toString()));
    } else if (_sortBy == 'za') {
      list.sort((a, b) => (b['fullname'] ?? '').toString().compareTo((a['fullname'] ?? '').toString()));
    } else if (_sortBy == 'oldest') {
      list.sort((a, b) => (a['id'] ?? 0).compareTo(b['id'] ?? 0));
    } else {
      list.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
    }
    return list;
  }

  Future<void> _handleDeactivate(dynamic member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeactivateDialog(member: member),
    );
    if (confirmed != true) return;
    try {
      await MembersService.deactivateMember(member['id']);
      _showToast('Member deactivated. All active loans have been completed.', isError: true);
      _fetchData(silent: true);
    } catch (_) {
      _showToast('Failed to deactivate member.', isError: true);
    }
  }

  Future<void> _handleDelete(dynamic member) async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => _DeleteDialog(member: member),
    );
    if (password == null || password.isEmpty) return;
    try {
      await MembersService.deleteMember(member['id'], password);
      _showToast('Member deleted.', isError: true);
      _fetchData(silent: true);
    } on WrongPasswordException {
      _showToast('Incorrect password. Member was not deleted.', isError: true);
    } catch (_) {
      _showToast('Failed to delete member.', isError: true);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _MMColors.red : _MMColors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onViewMember(dynamic member) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => ViewEditMemberScreen(member: member)),
    );
    if (changed == true) _fetchData(silent: true);
  }

  void _onRegisterMember() async {
    final registered = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const RegisterMemberScreen()),
    );
    if (registered == true) {
      _showToast('Member registered successfully!');
      _fetchData(silent: true);
    }
  }

  void _onViewPending(dynamic app) async {
    final converted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => PendingApplicationScreen(app: app)),
    );
    if (converted == true) _fetchData(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalPages = (filtered.length / _rowsPerPage).ceil().clamp(1, 999999);
    final safePage = _page.clamp(1, totalPages);
    final paginated = filtered.skip((safePage - 1) * _rowsPerPage).take(_rowsPerPage).toList();

    return AdminScreenScaffold(
      activeRouteKey: 'members',
      title: 'Manage Members',
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'add-savings-fab',
            backgroundColor: const Color(0xFFF57F17),
            tooltip: 'Add Savings',
            onPressed: () async {
              final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const SavingsDepositScreen()));
              if (changed == true) _fetchData(silent: true);
            },
            child: const Icon(Icons.savings_outlined, color: Colors.white),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            heroTag: 'add-share-capital-fab',
            backgroundColor: const Color(0xFF1565C0),
            tooltip: 'Add Share Capital',
            onPressed: () async {
              final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => const ShareCapitalDepositScreen()));
              if (changed == true) _fetchData(silent: true);
            },
            child: const Icon(Icons.account_balance_outlined, color: Colors.white),
          ),
          const SizedBox(width: 10),
          FloatingActionButton(
            heroTag: 'register-fab',
            onPressed: _onRegisterMember,
            backgroundColor: _MMColors.green,
            tooltip: 'Register Member',
            child: const Icon(Icons.person_add_alt_1, color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchData(),
        color: _MMColors.green,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Member Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _MMColors.title)),
              const SizedBox(height: 2),
              const Text('View, edit, and manage all registered LEAF MPC members.',
                  style: TextStyle(fontSize: 11, color: _MMColors.sub)),
              const SizedBox(height: 12),

              // ── Mini stats ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(child: _MiniStat(label: 'Active', value: '${_stats['active'] ?? 0}', color: _MMColors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniStat(label: 'Deactivated', value: '${_stats['deactivated'] ?? 0}', color: _MMColors.red)),
                  const SizedBox(width: 8),
                  Expanded(child: _MiniStat(label: 'Total', value: '${_stats['total'] ?? 0}', color: _MMColors.blue)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mainTab = 'pending'),
                      child: _MiniStat(label: 'Pending', value: '${_pending.length}', color: _MMColors.orange),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Main tabs ─────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _MMColors.cardBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _MainTabButton(
                        icon: Icons.people_outline,
                        label: 'Official',
                        count: _members.length,
                        active: _mainTab == 'official',
                        onTap: () => setState(() => _mainTab = 'official'),
                      ),
                    ),
                    Container(width: 1, height: 40, color: const Color(0xFFE4F0E5)),
                    Expanded(
                      child: _MainTabButton(
                        icon: Icons.hourglass_empty,
                        label: 'Pending',
                        count: _pending.length,
                        active: _mainTab == 'pending',
                        badgeColor: _MMColors.orange,
                        onTap: () => setState(() => _mainTab = 'pending'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_mainTab == 'official') ..._buildOfficialTab(paginated, filtered, safePage, totalPages)
              else ..._buildPendingTab(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOfficialTab(List<dynamic> paginated, List<dynamic> filtered, int safePage, int totalPages) {
    return [
      if (_showAgeChart) AgeGroupChart(members: _members),

      // ── Search ──────────────────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5FAF5),
          border: Border.all(color: _MMColors.cardBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          onChanged: (v) => setState(() { _search = v; _page = 1; }),
          decoration: const InputDecoration(
            hintText: 'Search by Name or Member ID...',
            hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFFBBBBBB)),
            prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFFAAAAAA)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
          style: const TextStyle(fontSize: 12.5),
        ),
      ),
      const SizedBox(height: 10),

      // ── Sort + Filter ───────────────────────────────────────────────
      Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortBy,
                  isExpanded: true,
                  icon: const Icon(Icons.swap_vert, size: 16),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                    DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                    DropdownMenuItem(value: 'az', child: Text('Name A → Z')),
                    DropdownMenuItem(value: 'za', child: Text('Name Z → A')),
                  ],
                  onChanged: (v) => setState(() { _sortBy = v ?? 'newest'; _page = 1; }),
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        children: [
          ...['All', 'Active', 'Deactivated'].map((s) {
            final active = _filterStatus == s;
            return ChoiceChip(
              label: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF888888))),
              selected: active,
              selectedColor: _MMColors.green,
              backgroundColor: Colors.white,
              side: BorderSide(color: active ? _MMColors.green : const Color(0xFFE0E8E0)),
              onSelected: (_) => setState(() { _filterStatus = s; _page = 1; }),
            );
          }),
          ChoiceChip(
            avatar: Icon(Icons.bar_chart_outlined, size: 14, color: _showAgeChart ? Colors.white : const Color(0xFF888888)),
            label: Text('Age Chart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _showAgeChart ? Colors.white : const Color(0xFF888888))),
            selected: _showAgeChart,
            selectedColor: _MMColors.green,
            backgroundColor: Colors.white,
            side: BorderSide(color: _showAgeChart ? _MMColors.green : const Color(0xFFE0E8E0)),
            onSelected: (_) => setState(() => _showAgeChart = !_showAgeChart),
          ),
        ],
      ),
      const SizedBox(height: 14),

      // ── Member list ─────────────────────────────────────────────────
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator(color: _MMColors.green)),
        )
      else if (paginated.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('No members found.', style: TextStyle(color: _MMColors.sub, fontStyle: FontStyle.italic))),
        )
      else
        ...paginated.map((m) => _MemberCard(
              member: m,
              onTap: () => _onViewMember(m),
              onDeactivate: () => _handleDeactivate(m),
              onDelete: () => _handleDelete(m),
            )),

      // ── Pagination ──────────────────────────────────────────────────
      if (!_loading && filtered.isNotEmpty) ...[
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Showing ${filtered.isEmpty ? 0 : (safePage - 1) * _rowsPerPage + 1}–${(safePage * _rowsPerPage).clamp(0, filtered.length)} of ${filtered.length}',
              style: const TextStyle(fontSize: 11, color: _MMColors.sub),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: safePage > 1 ? () => setState(() => _page = safePage - 1) : null,
                  icon: const Icon(Icons.chevron_left, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                Text('$safePage / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                IconButton(
                  onPressed: safePage < totalPages ? () => setState(() => _page = safePage + 1) : null,
                  icon: const Icon(Icons.chevron_right, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _buildPendingTab() {
    if (_pending.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 36, color: _MMColors.green),
                SizedBox(height: 8),
                Text('No pending applications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _MMColors.title)),
                SizedBox(height: 4),
                Text('All approved applicants have been processed.', style: TextStyle(fontSize: 12, color: _MMColors.sub)),
              ],
            ),
          ),
        ),
      ];
    }
    return _pending.map<Widget>((p) => _PendingCard(app: p, onTap: () => _onViewPending(p))).toList();
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0EAD8)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: _MMColors.sub, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

class _MainTabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final Color? badgeColor;
  final VoidCallback onTap;
  const _MainTabButton({
    required this.icon, required this.label, required this.count,
    required this.active, required this.onTap, this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _MMColors.green : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: active ? Colors.white : const Color(0xFF888888)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF888888))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? Colors.white.withOpacity(0.2) : (badgeColor?.withOpacity(0.12) ?? const Color(0xFFE8F5E9)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? Colors.white : (badgeColor ?? _MMColors.green))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final dynamic member;
  final VoidCallback onTap;
  final VoidCallback onDeactivate;
  final VoidCallback onDelete;
  const _MemberCard({required this.member, required this.onTap, required this.onDeactivate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final status = (member['status'] ?? '').toString();
    final isActive = status == 'Active';
    final age = computeAge(member['birth_date']);
    final fullname = member['fullname'] ?? '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFF0F0F0))),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _MMColors.green.withOpacity(0.12),
                child: Text(
                  fullname.toString().isNotEmpty ? fullname.toString()[0].toUpperCase() : 'M',
                  style: const TextStyle(color: _MMColors.green, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullname.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF222222)), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      '${member['member_id'] ?? ''}${age != null ? " · $age yrs" : ""}',
                      style: const TextStyle(fontSize: 10.5, color: _MMColors.sub, fontFamily: 'monospace'),
                    ),
                    if (member['contact'] != null && '${member['contact']}'.isNotEmpty)
                      Text('${member['contact']}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF888888))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFCE4EC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? const Color(0xFFC8E6C9) : const Color(0xFFF8BBD0)),
                    ),
                    child: Text(status, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: isActive ? _MMColors.green : _MMColors.red)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (isActive)
                        _RowIconButton(icon: Icons.power_settings_new, color: _MMColors.orange, onTap: onDeactivate),
                      const SizedBox(width: 4),
                      _RowIconButton(icon: Icons.delete_outline, color: _MMColors.red, onTap: onDelete),
                    ],
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

class _RowIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _RowIconButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final dynamic app;
  final VoidCallback onTap;
  const _PendingCard({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fullname = app['fullname'] ?? '${app['first_name'] ?? ''} ${app['last_name'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFF0F0F0))),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _MMColors.orange.withOpacity(0.12),
                child: Text(
                  fullname.toString().isNotEmpty ? fullname.toString()[0].toUpperCase() : 'A',
                  style: const TextStyle(color: _MMColors.orange, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullname.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${app['app_id'] ?? ''} · ${app['occupation'] ?? ''}', style: const TextStyle(fontSize: 10.5, color: _MMColors.sub)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: _MMColors.sub),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeactivateDialog extends StatefulWidget {
  final dynamic member;
  const _DeactivateDialog({required this.member});

  @override
  State<_DeactivateDialog> createState() => _DeactivateDialogState();
}

class _DeactivateDialogState extends State<_DeactivateDialog> {
  @override
  Widget build(BuildContext context) {
    final fullname = widget.member['fullname'] ?? '${widget.member['first_name'] ?? ''} ${widget.member['last_name'] ?? ''}';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(
        children: [
          Icon(Icons.power_settings_new, color: _MMColors.orange),
          SizedBox(width: 8),
          Text('Deactivate Member', style: TextStyle(color: _MMColors.orange, fontSize: 15)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                text: 'Deactivate ',
                style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
                children: [
                  TextSpan(text: fullname.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  const TextSpan(text: '?'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text('Member ID: ${widget.member['member_id'] ?? ''}', style: const TextStyle(fontSize: 11, color: _MMColors.sub, fontFamily: 'monospace')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                border: Border.all(color: const Color(0xFFFFCC80)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('The following will happen upon deactivation:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _MMColors.orange)),
                  SizedBox(height: 6),
                  _BulletLine('Member status → Deactivated (permanent)'),
                  _BulletLine('All Active/Overdue loans → Completed (balance ₱0)'),
                  _BulletLine('Loans are covered by member insurance'),
                  _BulletLine('Member cannot login after deactivation'),
                  _BulletLine('This action cannot be undone'),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _MMColors.orange, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Yes, Deactivate'),
        ),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  const _BulletLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(fontSize: 11.5, color: _MMColors.orange)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5, color: _MMColors.orange, height: 1.4))),
        ],
      ),
    );
  }
}

class _DeleteDialog extends StatefulWidget {
  final dynamic member;
  const _DeleteDialog({required this.member});

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final fullname = member['fullname'] ?? '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}';
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Delete Member', style: TextStyle(color: _MMColors.red, fontSize: 15)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: _MMColors.red, size: 36),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              text: 'Are you sure you want to delete ',
              style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
              children: [
                TextSpan(text: fullname.toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                const TextSpan(text: '?'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text('Member ID: ${member['member_id'] ?? ''}', style: const TextStyle(fontSize: 11, color: _MMColors.sub, fontFamily: 'monospace')),
          const SizedBox(height: 4),
          const Text('This action cannot be undone.', style: TextStyle(fontSize: 11, color: _MMColors.red, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          // ── BAGO: kailangan ng sariling password bago matuloy — para
          // hindi basta-basta sinuman ang makakapag-delete ────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
            child: const Text('Para sa seguridad, i-type ang sarili mong password para kumpirmahin.', style: TextStyle(fontSize: 10.5, color: Color(0xFFE65100))),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            autofocus: true,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Your password',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 18),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _MMColors.red, foregroundColor: Colors.white),
          onPressed: () {
            if (_passwordCtrl.text.trim().isEmpty) {
              setState(() => _error = 'Required');
              return;
            }
            Navigator.pop(context, _passwordCtrl.text);
          },
          child: const Text('Yes, Delete'),
        ),
      ],
    );
  }
}