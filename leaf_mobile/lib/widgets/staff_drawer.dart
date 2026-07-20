import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/member_provider.dart';

// Colors matched sa StaffLayout.css
class _SLColors {
  static const green    = Color(0xFF2E7D32);
  static const dark     = Color(0xFF1B5E20);
  static const sidebarBg = Color(0xFFF2EDE0);
  static const border   = Color(0xFFDDD5C0);
  static const navIdle  = Color(0xFF3A4A3A);
  static const red      = Color(0xFFC62828);
}

class StaffNavItem {
  final IconData icon;
  final String label;
  final String routeKey;
  const StaffNavItem({required this.icon, required this.label, required this.routeKey});
}

// ── Nav items per staff role — parehong logic sa NAV_BY_ROLE sa web ────────
const Map<String, List<StaffNavItem>> kStaffNavByRole = {
  'cashier': [
    StaffNavItem(icon: Icons.home_outlined, label: 'Home', routeKey: 'home'),
    StaffNavItem(icon: Icons.credit_card_outlined, label: 'Loan Payment', routeKey: 'loan-payment'),
  ],
  'collector': [
    StaffNavItem(icon: Icons.home_outlined, label: 'Home', routeKey: 'home'),
    StaffNavItem(icon: Icons.credit_card_outlined, label: 'Loan Payment', routeKey: 'loan-payment'),
  ],
  'bookkeeper': [
    StaffNavItem(icon: Icons.home_outlined, label: 'Home', routeKey: 'home'),
    StaffNavItem(icon: Icons.bar_chart_outlined, label: 'Reports', routeKey: 'reports'),
  ],
  'admin_clerk': [
    StaffNavItem(icon: Icons.home_outlined, label: 'Home', routeKey: 'home'),
    StaffNavItem(icon: Icons.people_outline, label: 'Manage Members', routeKey: 'members'),
    StaffNavItem(icon: Icons.checklist_outlined, label: 'Loan Approval', routeKey: 'loan-approval'),
    StaffNavItem(icon: Icons.description_outlined, label: 'Online Application', routeKey: 'applications'),
    StaffNavItem(icon: Icons.bar_chart_outlined, label: 'Reports', routeKey: 'reports'),
    StaffNavItem(icon: Icons.campaign_outlined, label: 'Announcement', routeKey: 'announcement'),
  ],
};

const Map<String, String> kStaffRoleLabels = {
  'cashier': 'Cashier',
  'collector': 'Collector',
  'bookkeeper': 'Bookkeeper',
  'admin_clerk': 'Administrative Clerk',
};

class StaffDrawer extends StatelessWidget {
  final String activeRouteKey;
  final void Function(String routeKey) onNavTap;

  const StaffDrawer({super.key, required this.activeRouteKey, required this.onNavTap});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final staffRole = auth.staffRole ?? '';
    final navItems = kStaffNavByRole[staffRole] ?? [];
    final now = DateTime.now();
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    const mons = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final clockStr = '${days[now.weekday % 7]} ${mons[now.month - 1]} ${now.day}, ${now.year} — ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return Drawer(
      backgroundColor: _SLColors.sidebarBg,
      width: 250,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _SLColors.border))),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/logo.png',
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.eco, color: _SLColors.green, size: 28),
                  SizedBox(width: 8),
                  Text('LEAF MPC', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _SLColors.dark)),
                ]),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                children: navItems.map((item) {
                  final isActive = item.routeKey == activeRouteKey;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: isActive ? const Color(0xFFD8ECDA) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () { Navigator.pop(context); onNavTap(item.routeKey); },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(children: [
                            Icon(item.icon, size: 16, color: isActive ? _SLColors.green : _SLColors.navIdle),
                            const SizedBox(width: 10),
                            Text(item.label, style: TextStyle(fontSize: 12.5, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? _SLColors.dark : _SLColors.navIdle)),
                          ]),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _SLColors.border))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(clockStr, style: const TextStyle(fontSize: 9, color: Color(0xFF7A8A6A)))),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _SLColors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                      onPressed: () async {
                        Navigator.pop(context);
                        await context.read<AuthProvider>().logout();
                        context.read<MemberProvider>().reset();
                        if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                      },
                      icon: const Icon(Icons.logout, size: 14),
                      label: const Text('LOGOUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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