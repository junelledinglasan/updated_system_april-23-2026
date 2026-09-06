import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/member_provider.dart';
import 'member_drawer.dart';

// Colors matched sa .ml-topbar CSS — parehong palette ng MemberDrawer,
// hiwalay sa Admin portal's greens.
class _MSColors {
  static const green      = Color(0xFF2D5A1B); // --ml-green (.ml-topbar-title)
  static const greenLt    = Color(0xFF5A9E35); // --ml-green-lt (.ml-topbar-avatar)
  static const topbarBg   = Color(0xFFF0EAD8); // .ml-topbar
  static const border     = Color(0xFFDDD5C0);
}

// Shared Scaffold para sa lahat ng Member screens — Drawer + Topbar,
// katulad ng AdminScreenScaffold pero may locked/gating logic.
//
// StatefulWidget ito (hindi Stateless) para masigurado na na-load na
// ang MemberProvider (profile/isOfficial) BAGO tumakbo ang kahit anong
// screen — dati, Dashboard at Notifications lang ang may ganitong
// safety check, kaya ang ibang screens (tulad ng Loan Application) ay
// laging nakikita ang default na "hindi official" hangga't hindi pa
// na-visit ang Dashboard nang mismo.
class MemberScreenScaffold extends StatefulWidget {
  final String activeRouteKey;
  final Widget body;
  final Widget? floatingActionButton;

  const MemberScreenScaffold({super.key, required this.activeRouteKey, required this.body, this.floatingActionButton});

  @override
  State<MemberScreenScaffold> createState() => _MemberScreenScaffoldState();
}

class _MemberScreenScaffoldState extends State<MemberScreenScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final memberProv = context.read<MemberProvider>();
      if (memberProv.loading) memberProv.load();
    });
  }

  void _onNavTap(BuildContext context, String routeKey) {
    if (routeKey == widget.activeRouteKey) return;
    switch (routeKey) {
      case 'dashboard':
        Navigator.pushReplacementNamed(context, '/member/dashboard');
        break;
      case 'my-loans':
        Navigator.pushReplacementNamed(context, '/member/my-loans');
        break;
      case 'notifications':
        Navigator.pushReplacementNamed(context, '/member/notifications');
        break;
      case 'savings':
        Navigator.pushReplacementNamed(context, '/member/savings');
        break;
      case 'announcements':
        Navigator.pushReplacementNamed(context, '/member/announcements');
        break;
      case 'apply-loan':
        Navigator.pushReplacementNamed(context, '/member/apply-loan');
        break;
      case 'profile':
        Navigator.pushReplacementNamed(context, '/member/profile');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$routeKey" screen — coming soon.')));
    }
  }

  void _onLockedTap(BuildContext context, MemberNavItem item) {
    showOfficialMemberGate(context, onApply: () {
      Navigator.pushNamed(context, '/member/apply-membership');
    });
  }

  @override
  Widget build(BuildContext context) {
    final memberProv = context.watch<MemberProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFD8E8CC), // .ml-content
      drawer: MemberDrawer(
        activeRouteKey: widget.activeRouteKey,
        onNavTap: (key) => _onNavTap(context, key),
        onLockedTap: (item) => _onLockedTap(context, item),
      ),
      floatingActionButton: widget.floatingActionButton,
      appBar: AppBar(
        backgroundColor: _MSColors.topbarBg,
        foregroundColor: _MSColors.green,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: const Text('MEMBER', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _MSColors.green, letterSpacing: 1)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _MSColors.border),
        ),
        actions: [
          // ── FIX: dating PopupMenuButton ito (Name, Member ID, My
          // Profile, Sign Out) — dagdag na feature ito sa mobile na
          // wala naman sa web (walang onClick sa ".ml-topbar-avatar"
          // doon, plain lang na display). Tinanggal na para consistent
          // ang behavior — "My Profile" ay naa-access na rin naman via
          // "Profile" nav item sa drawer, at "Sign Out" ay meron nang
          // dedikadong button sa ilalim ng drawer (kaparehong pattern
          // ng web, kung saan doon lang din nakalagay ang Sign Out). ──
          CircleAvatar(radius: 14, backgroundColor: _MSColors.greenLt, child: Text(memberProv.initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          const SizedBox(width: 12),
        ],
      ),
      body: widget.body,
    );
  }
}