import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/member_provider.dart';
import '../services/settings_service.dart';

// ─── Colors matched to AdminLayout.css ───────────────────────────────────────
class _AdminColors {
  static const sidebarBg     = Color(0xFFF2EDE0); // --sidebar-bg
  static const sidebarBorder = Color(0xFFDDD5C0); // --sidebar-border
  static const navActiveBg   = Color(0xFFD8ECDA); // .nav-item.active
  static const navActiveText = Color(0xFF1B5E20); // .nav-item.active
  static const navIdleText   = Color(0xFF3A4A3A); // .nav-item
  static const navIconActive = Color(0xFF2E7D32); // .nav-item.active .nav-icon
  static const pageBg        = Color(0xFFD8E8CC); // .page-content
  static const logoutBg      = Color(0xFFC62828); // .logout-btn
  static const logoutBgHover = Color(0xFF9A0007);
  static const clockText     = Color(0xFF7A8A6A); // .clock-display
  static const badgeBg       = Color(0xFFC62828);
}

class AdminNavItem {
  final IconData icon;
  final String label;
  final String routeKey; // used to mark active state
  const AdminNavItem({required this.icon, required this.label, required this.routeKey});
}

// ── Same order/labels as web's NAV_ITEMS ────────────────────────────────────
const List<AdminNavItem> kAdminNavItems = [
  AdminNavItem(icon: Icons.dashboard_outlined,       label: 'Dashboard',          routeKey: 'dashboard'),
  AdminNavItem(icon: Icons.people_outline,           label: 'Manage Member',      routeKey: 'members'),
  AdminNavItem(icon: Icons.manage_accounts_outlined, label: 'Manage Staff',       routeKey: 'staff'),
  AdminNavItem(icon: Icons.description_outlined,     label: 'Online Application', routeKey: 'applications'),
  AdminNavItem(icon: Icons.credit_card_outlined,     label: 'Loan Payment',       routeKey: 'loan-payment'),
  AdminNavItem(icon: Icons.fact_check_outlined,      label: 'Loan Approval',      routeKey: 'loan-approval'),
  AdminNavItem(icon: Icons.smartphone_outlined,      label: 'Online Payments',    routeKey: 'gcash-verification'),
  AdminNavItem(icon: Icons.campaign_outlined,        label: 'Announcement',       routeKey: 'announcement'),
  AdminNavItem(icon: Icons.bar_chart_outlined,       label: 'Reports',            routeKey: 'reports'),
];

class AdminDrawer extends StatefulWidget {
  final String activeRouteKey;
  final int gcashPendingCount;
  final void Function(String routeKey) onNavTap;

  const AdminDrawer({
    super.key,
    required this.activeRouteKey,
    required this.onNavTap,
    this.gcashPendingCount = 0,
  });

  @override
  State<AdminDrawer> createState() => _AdminDrawerState();
}

class _AdminDrawerState extends State<AdminDrawer> {
  String _clock = '';

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    final now = DateTime.now();
    const days = ['SUN','MON','TUE','WED','THU','FRI','SAT'];
    const mons = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    String pad(int n) => n.toString().padLeft(2, '0');
    setState(() {
      _clock =
          '${days[now.weekday % 7]} ${mons[now.month - 1]} ${now.day}, ${now.year} — '
          '${pad(now.hour)}:${pad(now.minute)}:${pad(now.second)}';
    });
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _tick();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _AdminColors.sidebarBg,
      width: 250,
      child: SafeArea(
        child: Column(
          children: [
            // ── Logo ──────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _AdminColors.sidebarBorder)),
              ),
              child: FutureBuilder<String?>(
                future: SettingsService.getLogoUrl(),
                builder: (context, snapshot) {
                  final customUrl = snapshot.data;
                  if (customUrl != null && customUrl.isNotEmpty) {
                    return Image.network(
                      customUrl,
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset('assets/images/logo.png', height: 40, fit: BoxFit.contain),
                    );
                  }
                  return Image.asset(
                    'assets/images/logo.png',
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Row(
                      children: [
                        Icon(Icons.eco, color: Color(0xFF2E7D32), size: 28),
                        SizedBox(width: 8),
                        Text('LEAF MPC', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Nav items ─────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: kAdminNavItems.map((item) {
                  final isActive = item.routeKey == widget.activeRouteKey;
                  final isGcash = item.routeKey == 'gcash-verification';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 1),
                    child: Material(
                      color: isActive ? _AdminColors.navActiveBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Navigator.pop(context); // close drawer
                          widget.onNavTap(item.routeKey);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: isActive ? _AdminColors.navIconActive : _AdminColors.navIdleText,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                    color: isActive ? _AdminColors.navActiveText : _AdminColors.navIdleText,
                                  ),
                                ),
                              ),
                              if (isGcash && widget.gcashPendingCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _AdminColors.badgeBg,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${widget.gcashPendingCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Bottom: clock + logout ───────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _AdminColors.sidebarBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                    child: Text(
                      _clock,
                      style: const TextStyle(fontSize: 10, color: _AdminColors.clockText, height: 1.5),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _AdminColors.logoutBg,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ).copyWith(
                          overlayColor: WidgetStateProperty.all(_AdminColors.logoutBgHover.withOpacity(0.2)),
                        ),
                        onPressed: () async {
                          Navigator.pop(context); // isara muna yung drawer
                          await context.read<AuthProvider>().logout();
                          context.read<MemberProvider>().reset();
                          // '/login' ay AuthWrapper na ngayon, kaya ligtas
                          // na itong gawing bagong route — gagana ito
                          // kahit na-orphan na yung dating AuthWrapper.
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          }
                        },
                        child: const Text(
                          'LOGOUT',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}