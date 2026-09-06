import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/member_provider.dart';
import '../admin_drawer.dart';
import '../../screens/admin/admin_settings_screen.dart';

class _ScaffoldColors {
  static const pageBg   = Color(0xFFD8E8CC);
  static const topbarBg = Color(0xFFF2EDE0);
  static const border   = Color(0xFFDDD5C0);
  static const brand    = Color(0xFF1B5E20);
  static const green    = Color(0xFF2E7D32);
}

/// Shared Scaffold para sa lahat ng Admin screens — Drawer + Topbar, parehong
/// itsura sa lahat ng pages, katulad ng AdminLayout.jsx sa web, kung saan
/// laging "ADMIN" lang ang laman ng topbar-brand kahit anong page.
///
/// Bawat screen ang may pananagutan sa sariling page title/header sa loob
/// ng body nito (tulad ng ginagawa ng ManageMember.jsx gamit ang mm-page-header).
class AdminScreenScaffold extends StatelessWidget {
  final String activeRouteKey;
  final Widget body;
  final Widget? floatingActionButton;
  final int gcashPendingCount;
  final String? title; // opsyonal lang, hindi ginagamit sa topbar (laging "ADMIN")
  // ── FIX: dating "Navigator.canPop(context)" ang ginamit para malaman
  // kung kailangan ng extra menu button — pero HINDI ito maaasahan,
  // dahil puwedeng "true" pa rin ito kahit sa mga top-level screens
  // (hal. Dashboard) kung may mga screen pa sa ilalim nito sa navigation
  // stack (login/splash, atbp.) — kaya doble pa ring lumalabas ang
  // hamburger doon. Ngayon, EXPLICIT na flag na lang — ang BAWAT SCREEN
  // MISMO ang nagsasabi kung kailangan niya ng dagdag na button (i.e.
  // mga screen na binubuksan via Navigator.push, tulad ng
  // SavingsDeposit/ShareCapitalDeposit), hindi na basta ambient
  // detection. ─────────────────────────────────────────────────────────
  final bool showMenuButton;

  const AdminScreenScaffold({
    super.key,
    required this.activeRouteKey,
    required this.body,
    this.floatingActionButton,
    this.gcashPendingCount = 0,
    this.title,
    this.showMenuButton = false,
  });

  void _onNavTap(BuildContext context, String routeKey) {
    if (routeKey == activeRouteKey) return; // andito na tayo

    // TODO: palitan ito ng tunay na navigation papuntang bawat screen
    // habang ginagawa na natin sila isa-isa, hal.:
    //   case 'members': Navigator.pushReplacementNamed(context, '/admin/members');
    switch (routeKey) {
      case 'dashboard':
        Navigator.pushReplacementNamed(context, '/admin/dashboard');
        break;
      case 'members':
        Navigator.pushReplacementNamed(context, '/admin/members');
        break;
      case 'staff':
        Navigator.pushReplacementNamed(context, '/admin/staff');
        break;
      case 'applications':
        Navigator.pushReplacementNamed(context, '/admin/applications');
        break;
      case 'loan-payment':
        Navigator.pushReplacementNamed(context, '/admin/loan-payment');
        break;
      case 'loan-approval':
        Navigator.pushReplacementNamed(context, '/admin/loan-approval');
        break;
      case 'gcash-verification':
        Navigator.pushReplacementNamed(context, '/admin/gcash-verification');
        break;
      case 'announcement':
        Navigator.pushReplacementNamed(context, '/admin/announcement');
        break;
      case 'reports':
        Navigator.pushReplacementNamed(context, '/admin/reports');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$routeKey" screen — coming soon.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: _ScaffoldColors.pageBg,
      drawer: AdminDrawer(
        activeRouteKey: activeRouteKey,
        gcashPendingCount: gcashPendingCount,
        onNavTap: (key) => _onNavTap(context, key),
      ),
      floatingActionButton: floatingActionButton,
      appBar: AppBar(
        backgroundColor: _ScaffoldColors.topbarBg,
        foregroundColor: _ScaffoldColors.brand,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        // ── FIX: kapag may "drawer:" na naka-set, AWTOMATIKONG
        // hamburger (hindi back arrow) ang ipinapakita ni Flutter sa
        // "leading" — kahit poppable ang route. Dahil dito, nagiging
        // DALAWANG HAMBURGER (magkatulad na icon) sa mga screen na
        // "showMenuButton: true" (Savings/ShareCapital) sa halip na
        // back+menu — dahil ang auto-leading ay hamburger pa rin,
        // hindi back arrow, kaya doblado. Ngayon, kapag
        // "showMenuButton: true", pinipilit nang explicit ang back
        // arrow sa "leading" — ito ang nagbibigay-daan para magkasama
        // ang back arrow (kaliwa) at hamburger (kanan, actions). ─────
        leading: showMenuButton ? const BackButton() : null,
        title: const Text(
          'ADMIN',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _ScaffoldColors.brand, letterSpacing: -0.5),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _ScaffoldColors.border),
        ),
        actions: [
          // ── Ginagamit na ang explicit na "showMenuButton" flag
          // (tingnan ang paliwanag sa itaas ng klase) sa halip na
          // Navigator.canPop(context). ─────────────────────────────
          if (showMenuButton)
            Builder(
              builder: (innerContext) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menu',
                onPressed: () => Scaffold.of(innerContext).openDrawer(),
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (value) async {
              if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSettingsScreen()));
                return;
              }
              if (value == 'logout') {
                await context.read<AuthProvider>().logout();
                context.read<MemberProvider>().reset();
                // '/login' ay AuthWrapper na ngayon (hindi hiwalay na
                // LoginScreen), kaya ligtas na itong gawing bagong route
                // — gagana ito kahit na-orphan na yung dating AuthWrapper
                // dahil sa pushReplacementNamed navigation sa pagitan ng
                // mga admin screens.
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(auth.name ?? 'Admin', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1A2A1A))),
              ),
              const PopupMenuItem<String>(
                enabled: false,
                child: Text('Admin', style: TextStyle(fontSize: 11, color: Color(0xFF9A9070))),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 16, color: Color(0xFF555555)),
                    SizedBox(width: 8),
                    Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 16, color: Color(0xFFC62828)),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _ScaffoldColors.border),
              ),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: _ScaffoldColors.green,
                child: Text(
                  (auth.name != null && auth.name!.isNotEmpty) ? auth.name![0].toUpperCase() : 'A',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}