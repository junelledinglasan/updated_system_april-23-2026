import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
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
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 20, color: _MSColors.green),
                onPressed: () => Navigator.pushNamed(context, '/member/notifications'),
              ),
              if (memberProv.notifCount > 0)
                Positioned(
                  top: 6, right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: const Color(0xFFE53935), shape: BoxShape.circle, border: Border.all(color: _MSColors.topbarBg, width: 1.5)),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('${memberProv.notifCount}', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (value) async {
              if (value == 'logout') {
                // ignore: use_build_context_synchronously
                await context.read<AuthProvider>().logout();
                context.read<MemberProvider>().reset();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } else if (value == 'profile') {
                Navigator.pushReplacementNamed(context, '/member/profile');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(memberProv.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1A2E1A))),
              ),
              PopupMenuItem<String>(
                enabled: false,
                child: Text(memberProv.isOfficial ? 'Member · ${memberProv.memberId}' : 'Pending Membership', style: const TextStyle(fontSize: 11, color: Color(0xFF7A8A6A))),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Row(children: [
                  Icon(Icons.person_outline, size: 16, color: Color(0xFF555555)),
                  SizedBox(width: 8),
                  Text('My Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, size: 16, color: Color(0xFFC62828)),
                  SizedBox(width: 8),
                  Text('Sign Out', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
            child: CircleAvatar(radius: 14, backgroundColor: _MSColors.greenLt, child: Text(memberProv.initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: widget.body,
    );
  }
}