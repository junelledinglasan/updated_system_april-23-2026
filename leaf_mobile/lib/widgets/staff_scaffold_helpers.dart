import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/member_provider.dart';
import 'staff_drawer.dart';

class _SSColors {
  static const green    = Color(0xFF2E7D32);
  static const dark     = Color(0xFF1B5E20);
  static const topbarBg = Color(0xFFF2EDE0);
  static const border   = Color(0xFFDDD5C0);
}

// Shared Scaffold para sa lahat ng Staff screens.
class StaffScreenScaffold extends StatelessWidget {
  final String activeRouteKey;
  final Widget body;
  final Widget? floatingActionButton;

  const StaffScreenScaffold({super.key, required this.activeRouteKey, required this.body, this.floatingActionButton});

  void _onNavTap(BuildContext context, String routeKey) {
    if (routeKey == activeRouteKey) return;
    switch (routeKey) {
      case 'home':
        Navigator.pushReplacementNamed(context, '/staff/home');
        break;
      case 'members':
        Navigator.pushReplacementNamed(context, '/staff/members');
        break;
      case 'loan-approval':
        Navigator.pushReplacementNamed(context, '/staff/loan-approval');
        break;
      case 'applications':
        Navigator.pushReplacementNamed(context, '/staff/applications');
        break;
      case 'loan-payment':
        Navigator.pushReplacementNamed(context, '/staff/loan-payment');
        break;
      case 'announcement':
        Navigator.pushReplacementNamed(context, '/staff/announcement');
        break;
      case 'reports':
        Navigator.pushReplacementNamed(context, '/staff/reports');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$routeKey" screen — coming soon.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final roleLabel = kStaffRoleLabels[auth.staffRole] ?? 'Staff';

    return Scaffold(
      backgroundColor: const Color(0xFFD8E8CC),
      drawer: StaffDrawer(activeRouteKey: activeRouteKey, onNavTap: (key) => _onNavTap(context, key)),
      floatingActionButton: floatingActionButton,
      appBar: AppBar(
        backgroundColor: _SSColors.topbarBg,
        foregroundColor: _SSColors.dark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 4,
        title: const Text('STAFF', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _SSColors.dark, letterSpacing: -0.3)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: _SSColors.border)),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (value) async {
              if (value == 'logout') {
                await context.read<AuthProvider>().logout();
                context.read<MemberProvider>().reset();
                if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(enabled: false, child: Text(auth.name ?? 'Staff', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1A2A1A)))),
              PopupMenuItem<String>(enabled: false, child: Text(roleLabel, style: const TextStyle(fontSize: 11, color: Color(0xFF9A9070)))),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 16, color: Color(0xFFC62828)), SizedBox(width: 8), Text('Sign Out', style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.w600))])),
            ],
            child: CircleAvatar(radius: 14, backgroundColor: _SSColors.green, child: Text((auth.name?.isNotEmpty == true ? auth.name![0] : 'S').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: body,
    );
  }
}