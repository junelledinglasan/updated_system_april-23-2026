import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/member_provider.dart';
import '../../services/announcements_service.dart';
import '../../services/loans_service.dart';
import '../../services/payments_service.dart';
import '../../services/members_service.dart';
import '../../widgets/member_scaffold_helpers.dart';

class _NFColors {
  static const dark = Color(0xFF1B5E20);
  static const sub  = Color(0xFF888888);
}

class _NotifMeta {
  final IconData icon;
  final String label;
  final Color bg;
  final Color border;
  final Color text;
  const _NotifMeta(this.icon, this.label, this.bg, this.border, this.text);
}

const Map<String, _NotifMeta> _typeMeta = {
  'due':        _NotifMeta(Icons.calendar_today_outlined, 'Payment Due', Color(0xFFFFF8E1), Color(0xFFFFE082), Color(0xFFE65100)),
  'notice':     _NotifMeta(Icons.campaign_outlined, 'Announcement', Color(0xFFE3F2FD), Color(0xFF90CAF9), Color(0xFF1565C0)),
  'approved':   _NotifMeta(Icons.check_circle_outline, 'Approved', Color(0xFFE8F5E9), Color(0xFFA5D6A7), Color(0xFF1B5E20)),
  'rejected':   _NotifMeta(Icons.cancel_outlined, 'Rejected', Color(0xFFFFEBEE), Color(0xFFEF9A9A), Color(0xFFC62828)),
  'membership': _NotifMeta(Icons.emoji_events_outlined, 'Membership', Color(0xFFE8F5E9), Color(0xFFA5D6A7), Color(0xFF1B5E20)),
  'system':     _NotifMeta(Icons.settings_outlined, 'System', Color(0xFFF5F5F5), Color(0xFFE0E0E0), Color(0xFF555555)),
  'overdue':    _NotifMeta(Icons.warning_amber_rounded, 'Overdue', Color(0xFFFFEBEE), Color(0xFFEF9A9A), Color(0xFFC62828)),
  'gcash':      _NotifMeta(Icons.smartphone, 'GCash Payment', Color(0xFFE3F2FD), Color(0xFF90CAF9), Color(0xFF007BFF)),
  'payment':    _NotifMeta(Icons.credit_card, 'Payment Recorded', Color(0xFFE8F5E9), Color(0xFFA5D6A7), Color(0xFF2E7D32)),
  'savings':    _NotifMeta(Icons.savings_outlined, 'Savings', Color(0xFFFFF8E1), Color(0xFFFFE082), Color(0xFFE65100)),
  'sharecap':   _NotifMeta(Icons.account_balance_wallet_outlined, 'Share Capital', Color(0xFFF3E5F5), Color(0xFFCE93D8), Color(0xFF6A1B9A)),
  'loan':       _NotifMeta(Icons.description_outlined, 'Loan', Color(0xFFE3F2FD), Color(0xFF90CAF9), Color(0xFF1565C0)),
  'completed':  _NotifMeta(Icons.done_all, 'Loan Completed', Color(0xFFE3F2FD), Color(0xFF90CAF9), Color(0xFF1565C0)),
};

const List<String> _filters = ['All', 'Unread', 'Loans', 'Payments', 'GCash', 'Savings', 'Share Capital', 'Announcements', 'Membership', 'System'];
const String _storageKey = 'leaf_read_notifs';

class NotifItem {
  final String id;
  final String type;
  final String title;
  final String msg;
  final DateTime? date;
  bool read;
  final String? route;
  final String? actionLabel;
  // ── BAGO: structured content para sa mas maayos na detail view ──────────
  final List<String>? requirements;
  final String? highlight;
  final List<List<String>>? details; // [[key, value], ...]
  NotifItem({required this.id, required this.type, required this.title, required this.msg, this.date, required this.read, this.route, this.actionLabel, this.requirements, this.highlight, this.details});

  String get timeAgo {
    if (date == null) return '';
    final diff = DateTime.now().difference(date!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minute${diff.inMinutes != 1 ? 's' : ''} ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours != 1 ? 's' : ''} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays != 1 ? 's' : ''} ago';
    return '${date!.month}/${date!.day}/${date!.year}';
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<NotifItem> _notifs = [];
  String _filter = 'All';
  Set<String> _readIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _build());
  }

  Future<Set<String>> _loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_storageKey) ?? []).toSet();
  }

  Future<void> _saveReadIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, ids.toList());
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse('$v');
    } catch (_) {
      return null;
    }
  }

  Future<void> _build() async {
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final memberProv = context.read<MemberProvider>();
    // Hindi tulad ng Dashboard, hindi natin sigurado kung na-load na
    // yung member profile bago pumunta rito ang user (hal. pag-tap sa
    // bell icon bago pa man mag-open ang Dashboard) — kaya siguraduhin
    // natin munang na-load na ito, kung hindi ay laging magiging
    // "hindi official" ang default value kahit official na talaga siya.
    if (memberProv.loading) {
      await memberProv.load();
    }
    final isOfficial = memberProv.isOfficial;
    final name = auth.name ?? auth.username ?? 'Member';
    final List<NotifItem> built = [];

    // ── 1. WELCOME ──────────────────────────────────────────────────
    built.add(NotifItem(id: 'welcome-system', type: 'system', title: 'Welcome to LEAF MPC', msg: 'Hello, $name! Welcome to the LEAF MPC Management System. Stay updated on your loans, payments, and cooperative news here.', date: DateTime.now(), read: true));

    if (!isOfficial) {
      built.add(NotifItem(id: 'system-info-portal', type: 'system', title: 'About the LEAF MPC Portal', msg: 'Apply for membership, track your application, and view announcements. Full features unlock once you become an official member.', date: DateTime.now(), read: true));
    }

    // ── 2. MEMBERSHIP STATUS (non-official lang) ──────────────────────
    bool hasApplication = false;
    if (!isOfficial) {
      try {
        final app = await MembersService.getMyOnlineApp();
        final status = app['application_status'];
        if (status == 'Approved') {
          hasApplication = true;
          built.add(NotifItem(
            id: 'membership-approved', type: 'membership', title: 'Membership Application Approved',
            msg: "Congratulations! Your application (${app['app_id']}) has been approved! Please visit the LEAF MPC office to complete your membership.",
            requirements: const [
              '2 pieces 2x2 ID picture, white background',
              'Photocopy of Birth Certificate (PSA copy preferred)',
              'Photocopy of Marriage Certificate — if married, optional',
              'Valid Government-issued ID',
              'Initial Share Capital Payment, minimum ₱4,000',
            ],
            highlight: 'Office Hours: Mon–Fri, 8:00 AM – 5:00 PM · LEAF MPC Office, Lucban, Quezon',
            date: _parseDate(app['reviewed_at'] ?? app['created_at']), read: false, route: 'apply-membership', actionLabel: 'View Requirements',
          ));
        } else if (status == 'Rejected') {
          hasApplication = true;
          built.add(NotifItem(
            id: 'membership-rejected', type: 'rejected', title: 'Membership Application Not Approved',
            msg: "Your application (${app['app_id']}) was not approved.${app['reject_reason'] != null ? ' Reason: ${app['reject_reason']}' : ''} You may re-apply or visit the office.",
            date: _parseDate(app['reviewed_at'] ?? app['created_at']), read: false, route: 'apply-membership', actionLabel: 'Re-apply',
          ));
        } else if (status == 'Pending') {
          hasApplication = true;
          built.add(NotifItem(id: 'membership-pending', type: 'system', title: 'Membership Application Under Review', msg: "Your application (${app['app_id']}) is currently under review. Thank you for your patience.", date: _parseDate(app['created_at']), read: true));
        }
      } catch (_) {}

      if (!hasApplication) {
        built.add(NotifItem(id: 'no-application', type: 'membership', title: 'Complete Your Membership Application', msg: 'Hi $name! You haven\'t submitted a membership application yet. Apply now to become an official LEAF MPC member.', date: DateTime.now(), read: false, route: 'apply-membership', actionLabel: 'Apply for Membership'));
      }
    }

    // ── 3. ANNOUNCEMENTS ────────────────────────────────────────────
    try {
      final anns = await AnnouncementsService.getAnnouncements();
      for (final a in anns.take(10)) {
        built.add(NotifItem(id: 'ann-${a['id']}', type: 'notice', title: '${a['title'] ?? ''}', msg: '${a['body'] ?? a['caption'] ?? 'No content available.'}', date: _parseDate(a['created_at'] ?? a['posted_at']), read: false, route: 'announcements', actionLabel: 'View Announcement'));
      }
    } catch (_) {}

    if (isOfficial) {
      // ── 4. LOANS ───────────────────────────────────────────────────
      try {
        final allLoans = await LoansService.getLoans();
        for (final l in allLoans.where((l) => l['status'] == 'Overdue')) {
          built.add(NotifItem(id: 'overdue-${l['id']}', type: 'overdue', title: '⚠ Overdue Payment — ${l['loan_id']}', msg: "Your ${l['loan_type']} (${l['loan_id']}) is OVERDUE with balance ₱${(double.tryParse('${l['balance'] ?? 0}') ?? 0).toStringAsFixed(0)}. Please settle immediately to avoid additional penalties.", date: _parseDate(l['next_due_date']), read: false, route: 'my-loans', actionLabel: 'Pay Now'));
        }
        for (final l in allLoans.where((l) => l['status'] == 'Active')) {
          built.add(NotifItem(id: 'due-${l['id']}', type: 'due', title: 'Payment Reminder — ${l['loan_id']}', msg: "Your monthly payment of ₱${(double.tryParse('${l['monthly_due'] ?? 0}') ?? 0).toStringAsFixed(0)} for ${l['loan_type']} (${l['loan_id']}) is due on ${l['next_due_date'] ?? '—'}. Pay on time to avoid penalties.", date: _parseDate(l['next_due_date']), read: false, route: 'my-loans', actionLabel: 'View My Loans'));
          built.add(NotifItem(id: 'approved-${l['id']}', type: 'approved', title: 'Loan Approved — ${l['loan_id']}', msg: "Your ${l['loan_type']} for ₱${(double.tryParse('${l['amount'] ?? 0}') ?? 0).toStringAsFixed(0)} has been approved and activated. Monthly due: ₱${(double.tryParse('${l['monthly_due'] ?? 0}') ?? 0).toStringAsFixed(0)}. Visit the office to sign documents.", date: _parseDate(l['approved_at']), read: true, route: 'my-loans', actionLabel: 'View Loan Details'));
        }
        for (final l in allLoans.where((l) => l['status'] == 'For Review')) {
          built.add(NotifItem(id: 'forreview-${l['id']}', type: 'loan', title: 'Loan Application Submitted — ${l['loan_id']}', msg: "Your ${l['loan_type']} application for ₱${(double.tryParse('${l['amount'] ?? 0}') ?? 0).toStringAsFixed(0)} (${l['loan_id']}) has been submitted and is waiting for admin review.", date: _parseDate(l['applied_at']), read: true, route: 'my-loans', actionLabel: 'View Status'));
        }
        for (final l in allLoans.where((l) => l['status'] == 'Declined')) {
          built.add(NotifItem(id: 'declined-${l['id']}', type: 'rejected', title: 'Loan Application Declined — ${l['loan_id']}', msg: "Your ${l['loan_type']} application for ₱${(double.tryParse('${l['amount'] ?? 0}') ?? 0).toStringAsFixed(0)} was declined.${l['decline_reason'] != null ? ' Reason: ${l['decline_reason']}' : ''} You may re-apply or visit the office.", date: _parseDate(l['applied_at']), read: false, route: 'my-loans', actionLabel: 'View My Loans'));
        }
        for (final l in allLoans.where((l) => l['status'] == 'Completed')) {
          built.add(NotifItem(id: 'completed-${l['id']}', type: 'completed', title: 'Loan Fully Paid — ${l['loan_id']}', msg: "Congratulations! Your ${l['loan_type']} (${l['loan_id']}) for ₱${(double.tryParse('${l['amount'] ?? 0}') ?? 0).toStringAsFixed(0)} has been fully paid. Thank you for being a responsible member!", date: _parseDate(l['approved_at']), read: true, route: 'my-loans', actionLabel: 'View History'));
        }
      } catch (_) {}

      // ── 5. RECENT PAYMENTS ────────────────────────────────────────
      try {
        final payments = await PaymentsService.getPayments();
        for (final p in payments.take(5)) {
          built.add(NotifItem(id: 'payment-${p['id'] ?? p['tx_id']}', type: 'payment', title: 'Payment Recorded — ₱${(double.tryParse('${p['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}', msg: "Your payment of ₱${(double.tryParse('${p['amount'] ?? 0}') ?? 0).toStringAsFixed(0)} for loan ${p['loan_code']} has been recorded (TX: ${p['tx_id']}). Remaining balance: ₱${(double.tryParse('${p['balance'] ?? 0}') ?? 0).toStringAsFixed(0)}.", date: _parseDate(p['paid_at']), read: true, route: 'my-loans', actionLabel: 'View Payment History'));
        }
      } catch (_) {}

      // ── 6. GCASH REQUESTS ─────────────────────────────────────────
      try {
        final gcashReqs = await LoansService.getGCashRequests();
        for (final r in gcashReqs) {
          if (r['status'] == 'Verified') {
            built.add(NotifItem(id: 'gcash-verified-${r['id']}', type: 'gcash', title: 'GCash Payment Verified', msg: "Your GCash payment of ₱${(double.tryParse('${r['amount'] ?? 0}') ?? 0).toStringAsFixed(0)} for loan ${r['loan_id']} (Ref: ${r['reference_number']}) has been verified and recorded by admin on ${r['verified_at']}.", date: _parseDate(r['verified_at']), read: false, route: 'my-loans', actionLabel: 'View Payment'));
          } else if (r['status'] == 'Rejected') {
            built.add(NotifItem(id: 'gcash-rejected-${r['id']}', type: 'gcash', title: 'GCash Payment Not Verified', msg: "Your GCash payment (Ref: ${r['reference_number']}, ₱${(double.tryParse('${r['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}) for loan ${r['loan_id']} was not verified. Reason: ${r['reject_reason']}. Please resubmit with the correct reference number.", date: _parseDate(r['verified_at']), read: false, route: 'my-loans', actionLabel: 'Resubmit Payment'));
          } else if (r['status'] == 'Pending') {
            built.add(NotifItem(id: 'gcash-pending-${r['id']}', type: 'gcash', title: 'GCash Payment Pending Verification', msg: "Your GCash payment (Ref: ${r['reference_number']}, ₱${(double.tryParse('${r['amount'] ?? 0}') ?? 0).toStringAsFixed(0)}) for loan ${r['loan_id']} is waiting for admin verification.", date: _parseDate(r['created_at']), read: true, route: 'my-loans', actionLabel: 'View My Loans'));
          }
        }
      } catch (_) {}

      // ── 7. SAVINGS ─────────────────────────────────────────────────
      try {
        // Walang dedikadong "my savings" endpoint (hindi tulad ng
        // getMyProfile/getMyOnlineApp) — kailangan natin ng totoong
        // member ID mula sa profile, hindi yung literal na 'me'.
        final myId = memberProv.profile?['id'];
        if (myId != null) {
          final savings = await MembersService.getMemberSavings('$myId');
          final txs = (savings['transactions'] as List?) ?? [];
          for (final tx in txs.take(3)) {
            final amt = double.tryParse('${tx['amount'] ?? 0}') ?? 0;
            final bal = double.tryParse('${tx['balance_after'] ?? 0}') ?? 0;
            built.add(NotifItem(
              id: 'savings-${tx['id']}', type: 'savings',
              title: 'Savings ${tx['transaction_type']} — ₱${amt.toStringAsFixed(0)}',
              msg: "A ${'${tx['transaction_type']}'.toLowerCase()} was recorded to your savings account.",
              details: [
                ['Amount', '₱${amt.toStringAsFixed(0)}'],
                ['New Balance', '₱${bal.toStringAsFixed(0)}'],
                if (tx['note'] != null && '${tx['note']}'.isNotEmpty) ['Note', '${tx['note']}'],
              ],
              date: _parseDate(tx['created_at']), read: true, route: 'dashboard', actionLabel: 'View Dashboard',
            ));
          }

          // ── 8. SHARE CAPITAL — BAGO ──────────────────────────────────
          try {
            final scHistory = await MembersService.getShareCapitalHistory(myId is int ? myId : int.tryParse('$myId') ?? 0);
            for (final t in (scHistory as List).take(3)) {
              final amt = double.tryParse('${t['amount'] ?? 0}') ?? 0;
              final bal = double.tryParse('${t['balance_after'] ?? 0}') ?? 0;
              final txnType = '${t['txn_type'] ?? 'Deposit'}';
              built.add(NotifItem(
                id: 'sharecap-${t['id']}', type: 'sharecap',
                title: 'Share Capital $txnType — ₱${amt.toStringAsFixed(0)}',
                msg: "A ${txnType.toLowerCase()} was recorded to your share capital.",
                details: [
                  ['Amount', '₱${amt.toStringAsFixed(0)}'],
                  ['New Balance', '₱${bal.toStringAsFixed(0)}'],
                  ['Max Loanable', '₱${(bal * 2).toStringAsFixed(0)}'],
                  if (t['note'] != null && '${t['note']}'.isNotEmpty) ['Note', '${t['note']}'],
                ],
                date: _parseDate(t['created_at']), read: true, route: 'dashboard', actionLabel: 'View Dashboard',
              ));
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    // ── Sort: unread muna, tapos by date ────────────────────────────
    built.sort((a, b) {
      if (!a.read && b.read) return -1;
      if (a.read && !b.read) return 1;
      return (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0));
    });

    final readIds = await _loadReadIds();
    for (final n in built) {
      if (readIds.contains(n.id)) n.read = true;
    }

    if (mounted) {
      setState(() {
        _notifs = built;
        _readIds = readIds;
        _loading = false;
      });
      memberProv.setNotifCount(built.where((n) => !n.read).length);
    }
  }

  Future<void> _markAllRead() async {
    final allIds = _notifs.map((n) => n.id).toSet();
    await _saveReadIds(allIds);
    setState(() {
      _readIds = allIds;
      for (final n in _notifs) {
        n.read = true;
      }
    });
    context.read<MemberProvider>().setNotifCount(0);
  }

  Future<void> _handleTap(NotifItem n) async {
    final newIds = {..._readIds, n.id};
    await _saveReadIds(newIds);
    setState(() {
      _readIds = newIds;
      n.read = true;
    });
    context.read<MemberProvider>().setNotifCount(_notifs.where((x) => !x.read).length);
    if (mounted) _showDetail(n);
  }

  void _showDetail(NotifItem n) {
    final meta = _typeMeta[n.type] ?? _typeMeta['system']!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Drag handle ──
                  Center(
                    child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 18), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(10))),
                  ),

                  // ── Icon + badge + close ──
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(color: meta.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: meta.border)),
                      child: Icon(meta.icon, color: meta.text, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: meta.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: meta.border)),
                            child: Text(meta.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: meta.text)),
                          ),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: _NFColors.sub),
                            const SizedBox(width: 4),
                            Text(n.timeAgo, style: const TextStyle(fontSize: 11.5, color: _NFColors.sub, fontWeight: FontWeight.w500)),
                          ]),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFF5F5F5), shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Color(0xFF888888))),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // ── Title ──
                  Text(n.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A), height: 1.3)),

                  const SizedBox(height: 14),

                  // ── Message card ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF0F0F0))),
                    child: Text(n.msg, style: const TextStyle(fontSize: 13.5, color: Color(0xFF4A4A4A), height: 1.7)),
                  ),

                  // ── BAGO: Requirements checklist ──
                  if (n.requirements != null && n.requirements!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFF9FEF9), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0EEE0))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('REQUIREMENTS TO BRING', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _NFColors.dark, letterSpacing: 0.4)),
                          const SizedBox(height: 8),
                          ...n.requirements!.map((r) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Container(width: 17, height: 17, margin: const EdgeInsets.only(top: 1), decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle), child: const Icon(Icons.check, size: 11, color: Colors.white)),
                                  const SizedBox(width: 9),
                                  Expanded(child: Text(r, style: const TextStyle(fontSize: 12.5, color: Color(0xFF444444), height: 1.4))),
                                ]),
                              )),
                        ],
                      ),
                    ),
                  ],

                  // ── BAGO: Highlight box (office hours, location, atbp.) ──
                  if (n.highlight != null && n.highlight!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFBBDEFB))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF1565C0)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(n.highlight!, style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w600, height: 1.5))),
                      ]),
                    ),
                  ],

                  // ── BAGO: Key-value details table ──
                  if (n.details != null && n.details!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFF0F0F0))),
                      child: Column(
                        children: n.details!.map((kv) {
                          final isLast = kv == n.details!.last;
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(kv[0], style: const TextStyle(fontSize: 11.5, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                              Text(kv[1], style: const TextStyle(fontSize: 12.5, color: Color(0xFF222222), fontWeight: FontWeight.w700)),
                            ]),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Actions ──
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: Color(0xFFE0E0E0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close', style: TextStyle(color: Color(0xFF555555), fontWeight: FontWeight.w600)),
                      ),
                    ),
                    if (n.route != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            if (n.route == 'my-loans') {
                              Navigator.pushReplacementNamed(context, '/member/my-loans');
                            } else if (n.route == 'dashboard') {
                              Navigator.pushReplacementNamed(context, '/member/dashboard');
                            } else if (n.route == 'apply-membership') {
                              Navigator.pushReplacementNamed(context, '/member/apply-membership');
                            } else if (n.route == 'announcements') {
                              Navigator.pushReplacementNamed(context, '/member/announcements');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${n.route}" screen — coming soon.')));
                            }
                          },
                          child: Text('${n.actionLabel ?? "View Details"}  →', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<NotifItem> get _filtered {
    return _notifs.where((n) {
      switch (_filter) {
        case 'All': return true;
        case 'Unread': return !n.read;
        case 'Loans': return ['loan', 'approved', 'rejected', 'overdue', 'due', 'completed'].contains(n.type);
        case 'Payments': return n.type == 'payment';
        case 'GCash': return n.type == 'gcash';
        case 'Savings': return n.type == 'savings';
        case 'Share Capital': return n.type == 'sharecap';
        case 'Announcements': return n.type == 'notice';
        case 'Membership': return ['membership', 'rejected'].contains(n.type);
        case 'System': return n.type == 'system';
        default: return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifs.where((n) => !n.read).length;
    final filtered = _filtered;

    return MemberScreenScaffold(
      activeRouteKey: 'notifications',
      body: RefreshIndicator(
        onRefresh: _build,
        color: const Color(0xFF2E7D32),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Notifications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _NFColors.dark)),
                            SizedBox(height: 2),
                            Text('Stay updated on payments, loans, announcements, and more.', style: TextStyle(fontSize: 10.5, color: _NFColors.sub)),
                          ],
                        ),
                      ),
                    ]),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _markAllRead,
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF2E7D32), side: const BorderSide(color: Color(0xFFC8E6C9))),
                          icon: const Icon(Icons.check_circle_outline, size: 13),
                          label: const Text('Mark all as read', style: TextStyle(fontSize: 11)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    Row(children: [
                      Expanded(child: _SummaryChip(value: '${_notifs.length}', label: 'Total', bg: Colors.white, valColor: _NFColors.dark, border: const Color(0xFFDDEEDD))),
                      const SizedBox(width: 6),
                      Expanded(child: _SummaryChip(value: '$unreadCount', label: 'Unread', bg: const Color(0xFFE8F5E9), valColor: const Color(0xFF2E7D32), border: const Color(0xFFC8E6C9))),
                      const SizedBox(width: 6),
                      Expanded(child: _SummaryChip(value: '${_notifs.where((n) => n.type == 'due' || n.type == 'overdue').length}', label: 'Due', bg: const Color(0xFFFFF8E1), valColor: const Color(0xFFE65100), border: const Color(0xFFFFE0B2))),
                      const SizedBox(width: 6),
                      Expanded(child: _SummaryChip(value: '${_notifs.where((n) => n.type == 'notice').length}', label: 'News', bg: const Color(0xFFE3F2FD), valColor: const Color(0xFF1565C0), border: const Color(0xFFBBDEFB))),
                    ]),
                    const SizedBox(height: 12),

                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, i) {
                          final f = _filters[i];
                          final active = _filter == f;
                          return ChoiceChip(
                            label: Text(f == 'Unread' && unreadCount > 0 ? '$f ($unreadCount)' : f, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: active ? Colors.white : const Color(0xFF888888))),
                            selected: active,
                            selectedColor: const Color(0xFF2E7D32),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: active ? const Color(0xFF2E7D32) : const Color(0xFFDDDDDD)),
                            onSelected: (_) => setState(() => _filter = f),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDDEEDD))),
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Column(children: const [
                                Icon(Icons.notifications_none, size: 36, color: Color(0xFFCCCCCC)),
                                SizedBox(height: 8),
                                Text('No notifications', style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB), fontStyle: FontStyle.italic)),
                              ]),
                            )
                          : Column(
                              children: filtered.map((n) {
                                final meta = _typeMeta[n.type] ?? _typeMeta['system']!;
                                final isLast = n == filtered.last;
                                return InkWell(
                                  onTap: () => _handleTap(n),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: n.read ? Colors.white : const Color(0xFFF0F8F0),
                                      border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : const Color(0xFFF5F5F5))),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(width: 38, height: 38, decoration: BoxDecoration(color: meta.bg, borderRadius: BorderRadius.circular(10)), child: Icon(meta.icon, color: meta.text, size: 17)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Expanded(child: Text(n.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF222222)))),
                                                const SizedBox(width: 6),
                                                Text(n.timeAgo, style: const TextStyle(fontSize: 9.5, color: Color(0xFFBBBBBB))),
                                              ]),
                                              const SizedBox(height: 3),
                                              Text(n.msg.length > 90 ? '${n.msg.substring(0, 90)}...' : n.msg, style: const TextStyle(fontSize: 11, color: Color(0xFF777777), height: 1.4)),
                                              if (n.route != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text('${n.actionLabel} →', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: meta.text))),
                                            ],
                                          ),
                                        ),
                                        if (!n.read) Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle))),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String value;
  final String label;
  final Color bg;
  final Color valColor;
  final Color border;
  const _SummaryChip({required this.value, required this.label, required this.bg, required this.valColor, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
      child: Column(children: [
        FittedBox(child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: valColor))),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
      ]),
    );
  }
}