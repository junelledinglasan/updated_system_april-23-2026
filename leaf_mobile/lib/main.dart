import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/member/member_dashboard.dart';
import 'screens/member/my_loans_screen.dart';
import 'screens/member/notifications_screen.dart';
import 'screens/member/my_savings_screen.dart';
import 'screens/member/member_announcements_screen.dart';
import 'screens/member/loan_application_screen.dart';
import 'screens/member/member_profile_screen.dart';
import 'screens/member/apply_membership_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/manage_member_screen.dart';
import 'screens/admin/manage_staff_screen.dart';
import 'screens/admin/online_applications_screen.dart';
import 'screens/admin/loan_payment_screen.dart';
import 'screens/admin/loan_approval_screen.dart';
import 'screens/admin/gcash_verification_screen.dart';
import 'screens/admin/announcement_screen.dart';
import 'screens/admin/reports_screen.dart';
import 'screens/staff/staff_dashboard.dart';
import 'providers/auth_provider.dart';
import 'providers/member_provider.dart';
// ── FIX: dating hindi naka-register ang "LanguageProvider" dito, kahit
// matagal na itong ginagamit ng maraming screens (hal.
// my_loans_screen.dart, na gumagamit ng "context.watch<LanguageProvider>()"
// sa maraming lugar) — kaya lumalabas ang "Could not find the correct
// Provider<LanguageProvider>" error. Idinagdag na ito sa MultiProvider. ──
import 'providers/language_provider.dart';
import 'utils/constants.dart';
import 'utils/nav_key.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MemberProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const LeafMPCApp(),
    ),
  );
}

class LeafMPCApp extends StatelessWidget {
  const LeafMPCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'LEAF MPC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        // NOTE: '/login' ay dapat laging AuthWrapper, hindi diretsong
        // LoginScreen — kasi kung may natirang "#/login" sa browser URL
        // (galing sa lumang navigation), babasahin 'yun ni Flutter Web
        // bilang starting route pag nag-reload/restart. Kung AuthWrapper
        // ang nakatakda dito, laging tama ang idedesisyon nito (Login o
        // Dashboard) base sa totoong session state — hindi na "stuck."
        '/login':            (_) => const AuthWrapper(),
        '/member/dashboard': (_) => const MemberDashboard(),
        '/member/my-loans':  (_) => const MyLoansScreen(),
        '/member/notifications': (_) => const NotificationsScreen(),
        '/member/savings': (_) => const MySavingsScreen(),
        '/member/announcements': (_) => const MemberAnnouncementsScreen(),
        '/member/apply-loan': (_) => const LoanApplicationScreen(),
        '/member/profile': (_) => const MemberProfileScreen(),
        '/member/apply-membership': (_) => const ApplyMembershipScreen(),
        '/admin/dashboard':  (_) => const AdminDashboard(),
        '/admin/members':    (_) => const ManageMemberScreen(),
        '/admin/staff':      (_) => const ManageStaffScreen(),
        '/admin/applications': (_) => const OnlineApplicationsScreen(),
        '/admin/loan-payment': (_) => const LoanPaymentScreen(),
        '/admin/loan-approval': (_) => const LoanApprovalScreen(),
        '/admin/gcash-verification': (_) => const GcashVerificationScreen(),
        '/admin/announcement': (_) => const AnnouncementScreen(),
        '/admin/reports': (_) => const ReportsScreen(),
        '/staff/dashboard':  (_) => const StaffDashboardScreen(),
        '/staff/home': (_) => const StaffDashboardScreen(),
        '/staff/members': (_) => const ManageMemberScreen(),
        '/staff/loan-approval': (_) => const LoanApprovalScreen(),
        '/staff/applications': (_) => const OnlineApplicationsScreen(),
        '/staff/loan-payment': (_) => const LoanPaymentScreen(),
        '/staff/announcement': (_) => const AnnouncementScreen(),
        '/staff/reports': (_) => const ReportsScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().loadFromStorage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.primary,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.eco, size: 80, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'LEAF MPC',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Multi-Purpose Cooperative',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  SizedBox(height: 40),
                  CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),
          );
        }
        if (!auth.isLoggedIn) return const LoginScreen();
        switch (auth.role) {
          case 'admin':  return const AdminDashboard();
          case 'staff':  return const StaffDashboardScreen();
          default:       return const MemberDashboard();
        }
      },
    );
  }
}