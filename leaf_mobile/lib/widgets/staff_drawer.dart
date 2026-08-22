import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/member_provider.dart';
import '../services/settings_service.dart';

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
  final String? featureKey; // null = "Home", laging kasama
  const StaffNavItem({required this.icon, required this.label, required this.routeKey, this.featureKey});
}

// ── Master list ng LAHAT ng possible staff nav items — ang "featureKey"
// ay tinutugma sa AVAILABLE_FEATURES sa backend (settings_app). "Home"
// ay laging kasama, hindi na kailangan i-toggle. Dating naka-hardcode
// ito bilang NAV_BY_ROLE (per staff_role), ngayon dynamic na base sa
// Staff Feature Permissions na na-set ng Admin sa Settings. ──────────
const List<StaffNavItem> kAllStaffNav = [
  StaffNavItem(icon: Icons.home_outlined, label: 'Home', routeKey: 'home', featureKey: null),
  StaffNavItem(icon: Icons.people_outline, label: 'Manage Members', routeKey: 'members', featureKey: 'members'),
  StaffNavItem(icon: Icons.description_outlined, label: 'Online Application', routeKey: 'applications', featureKey: 'applications'),
  StaffNavItem(icon: Icons.credit_card_outlined, label: 'Loan Payment', routeKey: 'loan-payment', featureKey: 'loan-payment'),
  StaffNavItem(icon: Icons.checklist_outlined, label: 'Loan Approval', routeKey: 'loan-approval', featureKey: 'loan-approval'),
  StaffNavItem(icon: Icons.campaign_outlined, label: 'Announcement', routeKey: 'announcement', featureKey: 'announcement'),
  StaffNavItem(icon: Icons.bar_chart_outlined, label: 'Reports', routeKey: 'reports', featureKey: 'reports'),
];

const Map<String, String> kStaffRoleLabels = {
  'cashier': 'Cashier',
  'collector': 'Collector',
  'bookkeeper': 'Bookkeeper',
  'admin_clerk': 'Administrative Clerk',
};

class StaffDrawer extends StatefulWidget {
  final String activeRouteKey;
  final void Function(String routeKey) onNavTap;

  const StaffDrawer({super.key, required this.activeRouteKey, required this.onNavTap});

  @override
  State<StaffDrawer> createState() => _StaffDrawerState();
}

class _StaffDrawerState extends State<StaffDrawer> {
  List<String>? _allowedFeatures; // null = loading pa

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPermissions());
  }

  Future<void> _loadPermissions() async {
    final auth = context.read<AuthProvider>();
    if (auth.id == null) return;
    try {
      final features = await SettingsService.getStaffPermissions(auth.id!);
      if (mounted) setState(() => _allowedFeatures = features);
    } catch (_) {
      if (mounted) setState(() => _allowedFeatures = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Habang naglo-load, "Home" muna ang ipapakita; pagkatapos, i-filter
    // ang master list base sa AllowedFeatures mula sa Settings.
    final navItems = _allowedFeatures == null
        ? [kAllStaffNav.first]
        : kAllStaffNav.where((item) => item.featureKey == null || _allowedFeatures!.contains(item.featureKey)).toList();

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
                    errorBuilder: (_, __, ___) => const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.eco, color: _SLColors.green, size: 28),
                      SizedBox(width: 8),
                      Text('LEAF MPC', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _SLColors.dark)),
                    ]),
                  );
                },
              ),
            ),
            if (_allowedFeatures == null)
              const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                children: navItems.map((item) {
                  final isActive = item.routeKey == widget.activeRouteKey;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: isActive ? const Color(0xFFD8ECDA) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () { Navigator.pop(context); widget.onNavTap(item.routeKey); },
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