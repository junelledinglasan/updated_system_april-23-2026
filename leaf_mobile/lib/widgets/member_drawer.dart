import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/settings_service.dart';
import '../providers/member_provider.dart';

// Colors matched 1:1 to MemberLayout.css — HALATANG magkaiba ang green
// palette dito kumpara sa Admin portal (#2d5a1b hindi #2e7d32), kaya
// hiwalay itong palette, hindi ginagamit yung mula sa AdminDrawer.
class _MLColors {
  static const green     = Color(0xFF2D5A1B); // --ml-green
  static const greenMid  = Color(0xFF3D7A25); // --ml-green-mid
  static const greenLt   = Color(0xFF5A9E35); // --ml-green-lt
  static const sidebarBg = Color(0xFFF0EAD8); // .ml-sidebar / .ml-topbar
  static const border    = Color(0xFFDDD5C0); // borders
  static const sub       = Color(0xFF7A8A6A); // .ml-profile-id
  static const navIdle   = Color(0xFF3A5A3A); // .ml-nav-item
  static const navActive = Color(0xFF1B5E20); // .ml-nav-item.active
  static const red       = Color(0xFFC62828); // .ml-logout-btn
  static const redHover  = Color(0xFF8E0000);
  static const profileName = Color(0xFF1A2E1A);
}

class MemberNavItem {
  final IconData icon;
  final String label;
  final String routeKey;
  final bool locked;
  const MemberNavItem({required this.icon, required this.label, required this.routeKey, this.locked = false});
}

const List<MemberNavItem> kMemberNavItems = [
  MemberNavItem(icon: Icons.dashboard_outlined,    label: 'Dashboard',      routeKey: 'dashboard', locked: true),
  MemberNavItem(icon: Icons.credit_card_outlined,  label: 'My Loans',       routeKey: 'my-loans',  locked: true),
  MemberNavItem(icon: Icons.savings_outlined,      label: 'My Savings',    routeKey: 'savings',    locked: true),
  MemberNavItem(icon: Icons.notifications_outlined, label: 'Notifications', routeKey: 'notifications'),
  MemberNavItem(icon: Icons.campaign_outlined,     label: 'Announcements',  routeKey: 'announcements'),
  MemberNavItem(icon: Icons.description_outlined,  label: 'Apply for Loan', routeKey: 'apply-loan', locked: true),
  MemberNavItem(icon: Icons.person_outline,        label: 'My Profile',    routeKey: 'profile'),
];

// ─── Official Member Gate — matched sa .ml-gate-* CSS ──────────────────────
void showOfficialMemberGate(BuildContext context, {required VoidCallback onApply}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔒', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            const Text('Official Members Only', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20))),
            const SizedBox(height: 8),
            const Text(
              'This feature is only available to official LEAF MPC members. Complete your membership to unlock full access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.6),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFC8E6C9))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('UNLOCK THESE FEATURES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32), letterSpacing: 0.4)),
                  const SizedBox(height: 6),
                  _gateFeature('Dashboard & loan overview'),
                  _gateFeature('My Loans & payment history'),
                  _gateFeature('Apply for loans online'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white, padding: const EdgeInsets.all(12)),
                onPressed: () { Navigator.pop(context); onApply(); },
                child: const Text('Apply for Official Membership', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF888888), side: const BorderSide(color: Color(0xFFDDDDDD)), padding: const EdgeInsets.all(10)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe Later'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _gateFeature(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
    );

class MemberDrawer extends StatelessWidget {
  final String activeRouteKey;
  final void Function(String routeKey) onNavTap;
  final void Function(MemberNavItem item) onLockedTap;

  const MemberDrawer({super.key, required this.activeRouteKey, required this.onNavTap, required this.onLockedTap});

  @override
  Widget build(BuildContext context) {
    final memberProv = context.watch<MemberProvider>();
    final isOfficial = memberProv.isOfficial;

    return Drawer(
      backgroundColor: _MLColors.sidebarBg,
      width: 240,
      child: SafeArea(
        child: Column(
          children: [
            // ── Logo ──────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _MLColors.border))),
              child: SizedBox(
                height: 35,
                child: FutureBuilder<String?>(
                  future: SettingsService.getLogoUrl(),
                  builder: (context, snapshot) {
                    final customUrl = snapshot.data;
                    if (customUrl != null && customUrl.isNotEmpty) {
                      return Image.network(
                        customUrl,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                        errorBuilder: (_, __, ___) => Image.asset('assets/images/logo.png', fit: BoxFit.contain, alignment: Alignment.centerLeft),
                      );
                    }
                    return Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (_, __, ___) => Row(children: const [
                        Icon(Icons.eco, color: _MLColors.green, size: 24),
                        SizedBox(width: 8),
                        Text('LEAF MPC', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _MLColors.green)),
                      ]),
                    );
                  },
                ),
              ),
            ),

            // ── Profile strip ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _MLColors.border))),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: const BoxDecoration(color: _MLColors.greenLt, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(memberProv.initials, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(memberProv.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _MLColors.profileName), overflow: TextOverflow.ellipsis),
                      Text(memberProv.isOfficial ? memberProv.memberId : 'No ID yet', style: const TextStyle(fontSize: 9.5, color: _MLColors.sub, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Container(
                  width: 9, height: 9,
                  decoration: BoxDecoration(
                    color: isOfficial ? const Color(0xFF4CAF50) : const Color(0xFFFFC107),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: (isOfficial ? const Color(0xFF4CAF50) : const Color(0xFFFFC107)).withOpacity(0.25), blurRadius: 0, spreadRadius: 2)],
                  ),
                ),
              ]),
            ),

            if (!isOfficial)
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E1), border: Border.all(color: const Color(0xFFFFE082)), borderRadius: BorderRadius.circular(8)),
                child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFF5D4037)),
                  SizedBox(width: 6),
                  Expanded(child: Text('You are not yet an official member. Some features are locked.', style: TextStyle(fontSize: 11, color: Color(0xFF5D4037), height: 1.4))),
                ]),
              ),

            // ── Nav items ─────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: kMemberNavItems.map((item) {
                  final isActive = item.routeKey == activeRouteKey;
                  final isLocked = item.locked && !isOfficial;
                  final activeAndUnlocked = isActive && !isLocked;
                  // ── BAGO: red number badge para sa Notifications —
                  // katumbas ng ginawa na natin sa web sidebar. ──────
                  final notifCount = item.routeKey == 'notifications'
                      ? context.watch<MemberProvider>().notifCount
                      : 0;
                  return Material(
                    color: activeAndUnlocked ? _MLColors.green.withOpacity(0.12) : Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        if (isLocked) {
                          onLockedTap(item);
                        } else {
                          onNavTap(item.routeKey);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(border: Border(left: BorderSide(color: activeAndUnlocked ? _MLColors.greenMid : Colors.transparent, width: 3))),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                        child: Opacity(
                          opacity: isLocked ? 0.45 : 1,
                          child: Row(children: [
                            Icon(item.icon, size: 16, color: activeAndUnlocked ? _MLColors.navActive : _MLColors.navIdle),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item.label, style: TextStyle(fontSize: 12.5, fontWeight: activeAndUnlocked ? FontWeight.w700 : FontWeight.w500, color: activeAndUnlocked ? _MLColors.navActive : _MLColors.navIdle))),
                            if (notifCount > 0)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                constraints: const BoxConstraints(minWidth: 18),
                                decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(20)),
                                child: Text('$notifCount', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
                              ),
                            if (isLocked) const Icon(Icons.lock_outline, size: 12, color: _MLColors.navIdle),
                          ]),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Logout ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _MLColors.border))),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _MLColors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10)),
                  onPressed: () async {
                    Navigator.pop(context);
                    await context.read<AuthProvider>().logout();
                    context.read<MemberProvider>().reset();
                    if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  },
                  child: const Text('SIGN OUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}