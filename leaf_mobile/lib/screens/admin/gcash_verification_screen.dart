import 'package:flutter/material.dart';
import '../../services/loans_service.dart';
import '../../widgets/admin/admin_scaffold_helpers.dart';
import 'gcash_request_detail_screen.dart';

class _GVColors {
  static const title   = Color(0xFF1B5E20);
  static const sub     = Color(0xFFAAAAAA);
  static const blue    = Color(0xFF1565C0);
  static const pending = Color(0xFFF57C00);
  static const verified= Color(0xFF2E7D32);
  static const rejected= Color(0xFFC62828);
}

Color gvStatusColor(String s) => s == 'Verified' ? _GVColors.verified : s == 'Rejected' ? _GVColors.rejected : _GVColors.pending;
Color gvStatusBg(String s) => s == 'Verified' ? const Color(0xFFE8F5E9) : s == 'Rejected' ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1);
Color gvStatusBorder(String s) => s == 'Verified' ? const Color(0xFFA5D6A7) : s == 'Rejected' ? const Color(0xFFEF9A9A) : const Color(0xFFFFE082);

class GcashVerificationScreen extends StatefulWidget {
  const GcashVerificationScreen({super.key});

  @override
  State<GcashVerificationScreen> createState() => _GcashVerificationScreenState();
}

class _GcashVerificationScreenState extends State<GcashVerificationScreen> {
  List<dynamic> _requests = [];
  bool _loading = true;
  String _filter = 'Pending';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await LoansService.getGCashRequests(status: _filter != 'All' ? _filter : null);
      if (mounted) setState(() => _requests = data);
    } catch (_) {
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _onFilterChange(String f) {
    setState(() => _filter = f);
    _fetchRequests();
  }

  Map<String, int> get _counts => {
        'Pending': _requests.where((r) => r['status'] == 'Pending').length,
        'Verified': _requests.where((r) => r['status'] == 'Verified').length,
        'Rejected': _requests.where((r) => r['status'] == 'Rejected').length,
      };

  List<dynamic> get _filtered => _requests.where((r) {
        final q = _search.toLowerCase();
        return '${r['member_name'] ?? ''}'.toLowerCase().contains(q) ||
            '${r['member_id'] ?? ''}'.toLowerCase().contains(q) ||
            '${r['loan_id'] ?? ''}'.toLowerCase().contains(q) ||
            '${r['reference_number'] ?? ''}'.toLowerCase().contains(q);
      }).toList();

  void _openDetail(dynamic req) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => GcashRequestDetailScreen(req: req)));
    if (changed == true) _fetchRequests(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    final filtered = _filtered;

    return AdminScreenScaffold(
      activeRouteKey: 'gcash-verification',
      body: RefreshIndicator(
        onRefresh: () => _fetchRequests(),
        color: _GVColors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.smartphone, color: _GVColors.blue, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GCash Payment Requests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _GVColors.title)),
                      Text('Verify member GCash payments before recording', style: TextStyle(fontSize: 10.5, color: _GVColors.sub)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              Row(children: [
                Expanded(child: _SummaryCard(label: 'Pending', value: '${counts['Pending']}', icon: Icons.access_time, color: _GVColors.pending, onTap: () => _onFilterChange('Pending'))),
                const SizedBox(width: 8),
                Expanded(child: _SummaryCard(label: 'Verified', value: '${counts['Verified']}', icon: Icons.check_circle_outline, color: _GVColors.verified, onTap: () => _onFilterChange('Verified'))),
                const SizedBox(width: 8),
                Expanded(child: _SummaryCard(label: 'Rejected', value: '${counts['Rejected']}', icon: Icons.cancel_outlined, color: _GVColors.rejected, onTap: () => _onFilterChange('Rejected'))),
              ]),
              const SizedBox(height: 14),

              Wrap(
                spacing: 6,
                children: ['All', 'Pending', 'Verified', 'Rejected'].map((s) {
                  final active = _filter == s;
                  final color = s == 'All' ? _GVColors.blue : gvStatusColor(s);
                  final count = s == 'All' ? _requests.length : counts[s];
                  return ChoiceChip(
                    label: Text('$s${s != 'All' && (count ?? 0) > 0 ? " ($count)" : ""}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: active ? Colors.white : const Color(0xFF888888))),
                    selected: active,
                    selectedColor: color,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: active ? color : const Color(0xFFE0E0E0)),
                    onSelected: (_) => _onFilterChange(s),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(8)),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Search by name, member ID, loan ID, reference...',
                    hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFFBBBBBB)),
                    prefixIcon: Icon(Icons.search, size: 16, color: Color(0xFFAAAAAA)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 14),

              if (_loading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator(color: _GVColors.blue)))
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No ${_filter != 'All' ? _filter.toLowerCase() : ''} GCash requests.', style: const TextStyle(color: _GVColors.sub))),
                )
              else
                ...filtered.map((r) => _RequestCard(req: r, onTap: () => _openDetail(r))),
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
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: gvStatusBg(label), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final dynamic req;
  final VoidCallback onTap;
  const _RequestCard({required this.req, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = (req['status'] ?? 'Pending').toString();
    final hasProof = req['screenshot_url'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF0F0F0))),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${req['member_name'] ?? ''}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        Text('${req['member_id'] ?? ''} · ${req['loan_id'] ?? ''}', style: const TextStyle(fontSize: 10, color: _GVColors.sub, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: gvStatusBg(status), borderRadius: BorderRadius.circular(20), border: Border.all(color: gvStatusBorder(status))),
                    child: Text(status, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: gvStatusColor(status))),
                  ),
                ]),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Text('REF:', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _GVColors.blue)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${req['reference_number'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1), fontFamily: 'monospace', letterSpacing: 1))),
                    Text('₱${(double.tryParse('${req['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _GVColors.verified)),
                  ]),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(hasProof ? Icons.image_outlined : Icons.image_not_supported_outlined, size: 13, color: hasProof ? _GVColors.blue : const Color(0xFFCCCCCC)),
                  const SizedBox(width: 4),
                  Text(hasProof ? 'Has proof screenshot' : 'No screenshot', style: TextStyle(fontSize: 9.5, color: hasProof ? _GVColors.blue : const Color(0xFFCCCCCC))),
                  const Spacer(),
                  Text('${req['created_at'] ?? ''}'.split('T').first, style: const TextStyle(fontSize: 9.5, color: _GVColors.sub)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}