import 'package:flutter/material.dart';
import '../../services/members_service.dart';
import '../../widgets/admin/admin_scaffold_helpers.dart';
import 'view_application_screen.dart';

class _OAColors {
  static const title    = Color(0xFF1B5E20);
  static const sub      = Color(0xFFAAAAAA);
  static const green    = Color(0xFF2E7D32);
  static const border   = Color(0xFFC8DDC8);
  static const pending  = Color(0xFFE65100);
  static const approved = Color(0xFF2E7D32);
  static const rejected = Color(0xFFC62828);
}

Color statusColor(String status) {
  switch (status) {
    case 'Approved': return _OAColors.approved;
    case 'Rejected': return _OAColors.rejected;
    default: return _OAColors.pending;
  }
}

Color statusBg(String status) {
  switch (status) {
    case 'Approved': return const Color(0xFFE8F5E9);
    case 'Rejected': return const Color(0xFFFCE4EC);
    default: return const Color(0xFFFFF8E1);
  }
}

class OnlineApplicationsScreen extends StatefulWidget {
  const OnlineApplicationsScreen({super.key});

  @override
  State<OnlineApplicationsScreen> createState() => _OnlineApplicationsScreenState();
}

class _OnlineApplicationsScreenState extends State<OnlineApplicationsScreen> {
  List<dynamic> _apps = [];
  bool _loading = true;
  String _search = '';
  String _filterStatus = 'All';
  int _page = 1;
  static const int _rowsPerPage = 8;

  @override
  void initState() {
    super.initState();
    _fetchApps();
  }

  Future<void> _fetchApps({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await MembersService.getOnlineApplications();
      final appList = (res is Map && res['applications'] != null) ? res['applications'] as List<dynamic> : (res is List ? res : <dynamic>[]);
      if (mounted) setState(() => _apps = appList);
    } catch (_) {
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Map<String, int> get _counts => {
        'total': _apps.length,
        'pending': _apps.where((a) => a['application_status'] == 'Pending').length,
        'approved': _apps.where((a) => a['application_status'] == 'Approved').length,
        'rejected': _apps.where((a) => a['application_status'] == 'Rejected').length,
      };

  List<dynamic> get _filtered {
    return _apps.where((a) {
      final matchStatus = _filterStatus == 'All' || a['application_status'] == _filterStatus;
      final q = _search.toLowerCase();
      final fullname = (a['fullname'] ?? '${a['first_name']} ${a['last_name']}').toString().toLowerCase();
      return matchStatus && (
        (a['app_id'] ?? '').toString().toLowerCase().contains(q) ||
        fullname.contains(q) ||
        (a['contact_number'] ?? '').toString().contains(q) ||
        (a['email'] ?? '').toString().toLowerCase().contains(q)
      );
    }).toList();
  }

  void _onViewApp(dynamic app) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => ViewApplicationScreen(app: app)),
    );
    if (changed == true) _fetchApps(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalPages = (filtered.length / _rowsPerPage).ceil().clamp(1, 999999);
    final safePage = _page.clamp(1, totalPages);
    final paginated = filtered.skip((safePage - 1) * _rowsPerPage).take(_rowsPerPage).toList();
    final counts = _counts;

    return AdminScreenScaffold(
      activeRouteKey: 'applications',
      body: RefreshIndicator(
        onRefresh: () => _fetchApps(),
        color: _OAColors.green,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Online Applications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _OAColors.title)),
              const SizedBox(height: 2),
              const Text('Review membership registration forms submitted online by applicants.', style: TextStyle(fontSize: 11, color: _OAColors.sub)),
              const SizedBox(height: 14),

              // ── Summary cards (2x2, clickable) ─────────────────────
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: [
                  _SummaryCard(label: 'Total Received', value: '${counts['total']}', color: _OAColors.title, onTap: () => setState(() { _filterStatus = 'All'; _page = 1; })),
                  _SummaryCard(label: 'For Review', value: '${counts['pending']}', color: _OAColors.pending, onTap: () => setState(() { _filterStatus = 'Pending'; _page = 1; })),
                  _SummaryCard(label: 'Approved', value: '${counts['approved']}', color: _OAColors.approved, onTap: () => setState(() { _filterStatus = 'Approved'; _page = 1; })),
                  _SummaryCard(label: 'Rejected', value: '${counts['rejected']}', color: _OAColors.rejected, onTap: () => setState(() { _filterStatus = 'Rejected'; _page = 1; })),
                ],
              ),
              const SizedBox(height: 14),

              // ── Search ──────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF8FAF8), border: Border.all(color: _OAColors.border), borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  onChanged: (v) => setState(() { _search = v; _page = 1; }),
                  decoration: const InputDecoration(
                    hintText: 'Search by App ID, Name, Contact, or Email...',
                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)),
                    prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFFAAAAAA)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 10),

              // ── Status tabs — horizontal scroll imbes na Wrap, para
              // hindi na-aawkward na madiskaril sa sariling linya ─────
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final s = ['All', 'Pending', 'Approved', 'Rejected'][i];
                    final active = _filterStatus == s;
                    final color = s == 'All' ? _OAColors.green : statusColor(s);
                    final count = s == 'All' ? counts['total'] : counts[s.toLowerCase()];
                    return ChoiceChip(
                      label: Text('$s${s != 'All' ? " ($count)" : ""}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF888888))),
                      selected: active,
                      selectedColor: color,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: active ? color : const Color(0xFFE0E8E0)),
                      onSelected: (_) => setState(() { _filterStatus = s; _page = 1; }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // ── List ────────────────────────────────────────────────
              if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: _OAColors.green)))
              else if (paginated.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No applications found.', style: TextStyle(color: _OAColors.sub, fontStyle: FontStyle.italic))))
              else
                ...paginated.map((a) => _AppCard(app: a, onTap: () => _onViewApp(a))),

              if (!_loading && filtered.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Showing ${filtered.isEmpty ? 0 : (safePage - 1) * _rowsPerPage + 1}–${(safePage * _rowsPerPage).clamp(0, filtered.length)} of ${filtered.length}',
                        style: const TextStyle(fontSize: 11, color: _OAColors.sub)),
                    Row(children: [
                      IconButton(onPressed: safePage > 1 ? () => setState(() => _page = safePage - 1) : null, icon: const Icon(Icons.chevron_left, size: 18), visualDensity: VisualDensity.compact),
                      Text('$safePage / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      IconButton(onPressed: safePage < totalPages ? () => setState(() => _page = safePage + 1) : null, icon: const Icon(Icons.chevron_right, size: 18), visualDensity: VisualDensity.compact),
                    ]),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  const _SummaryCard({required this.label, required this.value, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _OAColors.border), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF8A9A7A), letterSpacing: 0.4)),
          ],
        ),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final dynamic app;
  final VoidCallback onTap;
  const _AppCard({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = (app['application_status'] ?? 'Pending').toString();
    final fullname = app['fullname'] ?? '${app['first_name'] ?? ''} ${app['last_name'] ?? ''}';
    // ── BAGO: dating "Valid ID" (id_front_url/id_back_url) — ngayon
    // "Birth Certificate" na lang (id_front_url lang). ─────────────────
    final hasBirthCert = app['id_front_url'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: statusBg(status).withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: statusColor(status), width: 3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(radius: 18, backgroundColor: statusColor(status).withOpacity(0.15), child: Text(fullname.toString().isNotEmpty ? fullname.toString()[0].toUpperCase() : 'A', style: TextStyle(color: statusColor(status), fontWeight: FontWeight.w700))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('${app['app_id'] ?? ''}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: _OAColors.title)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(color: statusBg(status), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor(status).withOpacity(0.3))),
                          child: Text(status, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: statusColor(status))),
                        ),
                      ]),
                      const SizedBox(height: 2),
                      Text(fullname.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                      Text('${app['contact_number'] ?? ''} · ${app['occupation'] ?? ''}', style: const TextStyle(fontSize: 10.5, color: _OAColors.sub), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(hasBirthCert ? Icons.verified_user_outlined : Icons.no_accounts_outlined, size: 15, color: hasBirthCert ? _OAColors.green : const Color(0xFFCCCCCC)),
                    const SizedBox(height: 4),
                    Text('${app['created_at'] ?? ''}'.split('T').first, style: const TextStyle(fontSize: 9, color: _OAColors.sub)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}