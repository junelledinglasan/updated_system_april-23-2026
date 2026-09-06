import 'package:flutter/material.dart';
import '../../services/members_service.dart';

class _VAColors {
  static const title    = Color(0xFF1B5E20);
  static const sub      = Color(0xFF888888);
  static const green    = Color(0xFF2E7D32);
  static const pending  = Color(0xFFE65100);
  static const approved = Color(0xFF2E7D32);
  static const rejected = Color(0xFFC62828);
}

Color _statusColor(String s) => s == 'Approved' ? _VAColors.approved : s == 'Rejected' ? _VAColors.rejected : _VAColors.pending;
Color _statusBg(String s) => s == 'Approved' ? const Color(0xFFE8F5E9) : s == 'Rejected' ? const Color(0xFFFCE4EC) : const Color(0xFFFFF8E1);

class ViewApplicationScreen extends StatefulWidget {
  final dynamic app;
  const ViewApplicationScreen({super.key, required this.app});

  @override
  State<ViewApplicationScreen> createState() => _ViewApplicationScreenState();
}

class _ViewApplicationScreenState extends State<ViewApplicationScreen> {
  dynamic _fullApp;
  bool _loadingDetails = true;
  bool _rejectMode = false;
  final _reasonCtrl = TextEditingController();
  // ── BAGO: tinanggal ang "_idTab" state — hindi na kailangan, wala
  // nang front/back tab switcher, isang Birth Certificate image na lang. ─
  bool _processing = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _loadFull();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFull() async {
    try {
      final data = await MembersService.getOnlineApplication(widget.app['id']);
      if (mounted) setState(() => _fullApp = data);
    } catch (_) {
      if (mounted) setState(() => _fullApp = widget.app);
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  dynamic get _current => _fullApp ?? widget.app;

  Future<void> _handleApprove() async {
    setState(() => _processing = true);
    try {
      await MembersService.updateOnlineAppStatus(_current['id'], {'application_status': 'Approved'});
      if (mounted) {
        setState(() {
          _fullApp = {..._current, 'application_status': 'Approved'};
          _changed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application approved successfully!'), backgroundColor: _VAColors.green));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve application.'), backgroundColor: _VAColors.rejected));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _handleReject() async {
    if (_reasonCtrl.text.trim().isEmpty) return;
    setState(() => _processing = true);
    try {
      await MembersService.updateOnlineAppStatus(_current['id'], {'application_status': 'Rejected', 'reject_reason': _reasonCtrl.text});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application rejected.'), backgroundColor: _VAColors.rejected));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to reject application.'), backgroundColor: _VAColors.rejected));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _current;
    final status = (app['application_status'] ?? app['status'] ?? 'Pending').toString();
    // ── BAGO: dating "Valid ID" (front + back) — ngayon "Birth
    // Certificate" na lang (isang imahe, sa id_front_url pa rin
    // naka-store — walang dedikadong field para dito sa backend). ────
    final hasBirthCert = app['id_front_url'] != null;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _changed);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _VAColors.title,
          elevation: 0.5,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context, _changed)),
          title: const Text('Membership Application', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _VAColors.title)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _statusBg(status), borderRadius: BorderRadius.circular(20), border: Border.all(color: _statusColor(status).withOpacity(0.3))),
                  child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(status))),
                ),
              ),
            ),
          ],
        ),
        body: _loadingDetails
            ? const Center(child: CircularProgressIndicator(color: _VAColors.green))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${app['app_id'] ?? ''} · Submitted ${'${app['created_at'] ?? ''}'.split('T').first}', style: const TextStyle(fontSize: 10.5, color: _VAColors.sub, fontFamily: 'monospace')),
                    const SizedBox(height: 16),

                    _SectionCard(
                      title: 'Personal Information',
                      // ── BAGO: "LayoutBuilder" dito (sa ANTAS NG
                      // COLUMN, hindi sa loob ng Wrap) — dito talaga
                      // TAMA at BOUNDED ang constraints.maxWidth, dahil
                      // ito mismo ang direktang parent constraint na
                      // ipinasa ng Card papunta sa Column na 'to. ──────
                      child: LayoutBuilder(builder: (context, constraints) {
                        final aw = constraints.maxWidth;
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Wrap(
                            spacing: 14,
                            runSpacing: 10,
                            children: [
                              _InfoField('Last Name', app['last_name'], availableWidth: aw),
                              _InfoField('First Name', app['first_name'], availableWidth: aw),
                              _InfoField('Middle Name', app['middle_name'], availableWidth: aw),
                              _InfoField('Birthdate', app['birth_date'], availableWidth: aw),
                              _InfoField('Civil Status', app['civil_status'], availableWidth: aw),
                              _InfoField('Classification', app['classification'], availableWidth: aw),
                              _InfoField('Educational Attainment', app['educational_attainment'], availableWidth: aw),
                              _InfoField('Occupation', app['occupation'], availableWidth: aw),
                              _InfoField('Monthly Income', (app['income'] != null && '${app['income']}' != '0.00') ? '₱${double.tryParse('${app['income']}')?.toStringAsFixed(0) ?? app['income']}' : null, availableWidth: aw),
                              _InfoField('Contact No.', app['contact_number'], mono: true, availableWidth: aw),
                              _InfoField('Email', app['email'], mono: true, availableWidth: aw),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _InfoField('Address', app['address'], full: true, availableWidth: aw),
                          const SizedBox(height: 8),
                          Wrap(spacing: 14, runSpacing: 10, children: [
                            _InfoField('Birth Certificate', app['birth_certificate'] == true ? 'Submitted' : 'Not submitted', availableWidth: aw),
                            _InfoField('Marriage Certificate', app['marriage_certificate'] == true ? 'Submitted' : 'Not submitted', availableWidth: aw),
                          ]),
                        ]);
                      }),
                    ),
                    const SizedBox(height: 14),

                    _SectionCard(
                      title: 'Birth Certificate Verification',
                      icon: Icons.attach_file,
                      child: !hasBirthCert
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFFE082))),
                              child: const Text('No Birth Certificate uploaded by the applicant.', style: TextStyle(fontSize: 12, color: _VAColors.pending)),
                            )
                          : Column(children: [
                              _IdImage(url: app['id_front_url']),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                                child: const Text(
                                  'Please verify that the name and other details on the Birth Certificate match the information provided in the form above before approving.',
                                  style: TextStyle(fontSize: 10.5, color: _VAColors.green, fontWeight: FontWeight.w600, height: 1.4),
                                ),
                              ),
                            ]),
                    ),

                    if (app['username'] != null || app['plain_password'] != null) ...[
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Account Credentials',
                        icon: Icons.lock_outline,
                        child: LayoutBuilder(builder: (context, constraints) {
                          final aw = constraints.maxWidth;
                          return Wrap(spacing: 14, runSpacing: 10, children: [
                            _InfoField('Username', app['username'], mono: true, availableWidth: aw),
                            _InfoField('Password', app['plain_password'], mono: true, availableWidth: aw),
                          ]);
                        }),
                      ),
                    ],

                    if (status == 'Rejected' && app['reject_reason'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF8BBD0))),
                        child: Text.rich(TextSpan(text: 'Rejected: ', style: const TextStyle(fontSize: 11.5, color: Color(0xFFB71C1C)), children: [
                          TextSpan(text: '${app['reject_reason']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ])),
                      ),
                    ],
                    if (status == 'Approved') ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFC8E6C9))),
                        child: const Text.rich(TextSpan(text: 'This application has been ', style: TextStyle(fontSize: 11.5, color: _VAColors.title), children: [
                          TextSpan(text: 'approved', style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: '.'),
                        ])),
                      ),
                    ],

                    if (_rejectMode) ...[
                      const SizedBox(height: 18),
                      const Text('REASON FOR REJECTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _VAColors.rejected, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _reasonCtrl,
                        maxLines: 3,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'e.g. Incomplete requirements, ID does not match provided info...',
                          hintStyle: const TextStyle(fontSize: 11.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
        bottomNavigationBar: _loadingDetails
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: !_rejectMode
                      ? Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, _changed), child: const Text('Close'))),
                            if (status == 'Pending') ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(foregroundColor: _VAColors.rejected, side: const BorderSide(color: Color(0xFFFFCDD2))),
                                  onPressed: () => setState(() => _rejectMode = true),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: _VAColors.green, foregroundColor: Colors.white),
                                  onPressed: _processing ? null : _handleApprove,
                                  child: _processing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Approve'),
                                ),
                              ),
                            ],
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: () => setState(() { _rejectMode = false; _reasonCtrl.clear(); }), child: const Text('← Back'))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _VAColors.rejected, foregroundColor: Colors.white),
                                onPressed: (_reasonCtrl.text.trim().isEmpty || _processing) ? null : _handleReject,
                                child: _processing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirm Rejection'),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
      ),
    );
  }

  // ── BAGO: tinanggal ang "_noIdBox" — hindi na kailangan, wala nang
  // hiwalay na front/back na "not uploaded" states. ───────────────────
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  const _SectionCard({required this.title, this.icon, required this.child});

  // ── BAGO: dating "_SectionTitle" lang (underline lang sa ibaba ng
  // text) — ngayon may white card, subtle border, at green accent bar
  // sa tabi ng title, para mas malinaw ang paghihiwalay ng bawat
  // seksyon, tugma sa ginawa nating redesign sa web. ──────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8F5E9))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: _VAColors.green, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            if (icon != null) ...[Icon(icon, size: 14, color: _VAColors.title), const SizedBox(width: 6)],
            Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _VAColors.title, letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── BAGO: tinanggal ang "_SectionTitle" class — hindi na kailangan,
// ginagamit na ang "_SectionCard" sa lahat ng seksyon. ───────────────

class _InfoField extends StatelessWidget {
  final String label;
  final dynamic value;
  final bool mono;
  final bool full;
  // ── FIX: dating gumagamit ng "MediaQuery.of(context).size.width"
  // mismo sa loob ng field (nire-recompute base sa BUONG SCREEN,
  // hindi sa aktwal na natitirang espasyo pagkatapos ng lahat ng
  // padding sa itaas nito) — laging mali/fragile ito tuwing may
  // pagbabago sa antas ng padding sa itaas (tulad ng nangyari nang
  // idinagdag ang "_SectionCard"). Ngayon, EXPLICIT na ipinapasa ang
  // "availableWidth" mula sa taas — kinukuha ito nang tama gamit ang
  // "LayoutBuilder" sa ANTAS NA HINDI PA LOOB NG "Wrap" (dahil
  // unbounded ang constraints sa loob mismo ng Wrap). ─────────────────
  final double availableWidth;
  const _InfoField(this.label, this.value, {this.mono = false, this.full = false, required this.availableWidth});

  @override
  Widget build(BuildContext context) {
    final width = full ? double.infinity : (availableWidth - 14) / 2;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF9FEF9), border: Border.all(color: const Color(0xFFE8F5E9)), borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF8A9A7A), letterSpacing: 0.4)),
            const SizedBox(height: 2),
            Text(
              value == null || '$value'.isEmpty ? '—' : '$value',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF222222), fontFamily: mono ? 'monospace' : null),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── BAGO: tinanggal ang "_IdTabButton" class — hindi na kailangan,
// wala nang front/back tab switcher (isang Birth Certificate image
// na lang). ─────────────────────────────────────────────────────────

class _IdImage extends StatelessWidget {
  final String url;
  const _IdImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFA5D6A7), width: 2), borderRadius: BorderRadius.circular(10)),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              height: 220,
              width: double.infinity,
              loadingBuilder: (context, child, progress) => progress == null ? child : const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              errorBuilder: (context, error, stack) => Container(
                height: 220,
                alignment: Alignment.center,
                color: const Color(0xFFFAFAFA),
                child: const Text('Unable to load image', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 11)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}