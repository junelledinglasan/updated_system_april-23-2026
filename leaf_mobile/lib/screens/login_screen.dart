import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'create_account_screen.dart';

// ─── Colors matched 1:1 to Login.css ─────────────────────────────────────────
class _LoginColors {
  static const rightBg     = Color(0xFFD8E8CC); // .login-right background
  static const cardBg      = Colors.white;       // .login-card
  static const title       = Color(0xFF1A1A1A); // .login-card-title
  static const subtitle    = Color(0xFF999999); // .login-card-sub
  static const label       = Color(0xFF333333); // .login-label
  static const inputBorder = Color(0xFFE0E0E0); // .login-input
  static const focusGreen  = Color(0xFF4CAF50); // .login-input:focus
  static const leafGreen   = Color(0xFF4CAF50); // Leaf icon color
  static const linkGreen   = Color(0xFF2E7D32); // .login-link
  static const btnGreen    = Color(0xFF2E7D32); // .login-btn
  static const btnGreenDk  = Color(0xFF1B5E20); // .login-btn:hover
  static const errorBg     = Color(0xFFFFF5F5); // .login-error
  static const errorBorder = Color(0xFFFFCDD2);
  static const errorText   = Color(0xFFC62828);
  static const hint        = Color(0xFFC0C0C0); // .login-input::placeholder
  static const eyeIdle     = Color(0xFFBBBBBB); // .login-pw-eye
  static const notice      = Color(0xFFBBBBBB); // .login-notice
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading      = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ─── Login (same logic as before — AuthWrapper handles navigation) ─────────
  Future<void> _login() async {
    if (_usernameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your username.');
      return;
    }
    if (_passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthProvider>();
    final result = await auth.login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (!result['success']) {
      setState(() {
        _loading = false;
        _error = result['message'];
      });
    }
    // Navigation handled by AuthWrapper on success
  }

  // ─── Forgot Password modal (matches .login-msg-box on web) ─────────────────
  void _showForgotPasswordModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 32, color: _LoginColors.linkGreen),
              const SizedBox(height: 10),
              const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20)),
              ),
              const SizedBox(height: 10),
              const Text(
                'Para sa password reset, mangyaring bumisita sa opisina o makipag-ugnayan sa LEAF MPC administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.6),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _LoginColors.btnGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Create Account ──────────────────────────────────────────────────
  void _handleCreateAccount() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateAccountScreen()));
  }

  InputDecoration _fieldDecoration({required String hint, Widget? suffixIcon}) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _LoginColors.hint, fontSize: 13.5),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
      border: border(_LoginColors.inputBorder, 1.5),
      enabledBorder: border(
        _error != null ? const Color(0xFFE53935) : _LoginColors.inputBorder,
        1.5,
      ),
      focusedBorder: border(_LoginColors.focusGreen, 1.5),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LoginColors.rightBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48, // minus vertical padding
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  // ── Branding above the card (no white box, mas malaki) ──
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.eco, size: 90, color: _LoginColors.leafGreen),
                    ),
                  ),

                  // ── Tagline (matches .login-left-title / .login-left-sub on web) ──
                  const Text(
                    'Cooperative Management System',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E4A2E),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Admin, Staff and Member Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF2E4A2E).withOpacity(0.65),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Card (matches .login-card) ──────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                    decoration: BoxDecoration(
                      color: _LoginColors.cardBg,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.16),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.eco, size: 24, color: _LoginColors.leafGreen),
                        const SizedBox(height: 6),
                        const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _LoginColors.title,
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter your credentials to continue',
                          style: TextStyle(fontSize: 13, color: _LoginColors.subtitle),
                        ),
                        const SizedBox(height: 18),

                        // Username
                        const Text('Username',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600, color: _LoginColors.label)),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _usernameCtrl,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF222222)),
                          decoration: _fieldDecoration(hint: 'Enter your username'),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                        ),
                        const SizedBox(height: 13),

                        // Password
                        const Text('Password',
                            style: TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600, color: _LoginColors.label)),
                        const SizedBox(height: 5),
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: !_showPassword,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF222222)),
                          onSubmitted: (_) => _login(),
                          onChanged: (_) {
                            if (_error != null) setState(() => _error = null);
                          },
                          decoration: _fieldDecoration(
                            hint: 'Enter your password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword ? Icons.visibility_off : Icons.visibility,
                                size: 18,
                                color: _LoginColors.eyeIdle,
                              ),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Links row: Forgot Password / Create Account
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _showForgotPasswordModal,
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: _LoginColors.linkGreen,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _handleCreateAccount,
                              child: const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: _LoginColors.linkGreen,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Error
                        if (_error != null) ...[
                          const SizedBox(height: 13),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _LoginColors.errorBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _LoginColors.errorBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 15, color: _LoginColors.errorText),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(fontSize: 12.5, color: _LoginColors.errorText),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 15),

                        // Login button
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _LoginColors.btnGreen,
                              disabledBackgroundColor: _LoginColors.btnGreen.withOpacity(0.65),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ).copyWith(
                              // Visible ripple on tap (dati same-color yung overlay kaya invisible)
                              overlayColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.pressed)) {
                                  return Colors.white.withOpacity(0.18);
                                }
                                return null;
                              }),
                            ),
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Notice
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.lock_outline, size: 12, color: _LoginColors.notice),
                            SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Your account will automatically be directed to the correct portal',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11.5, color: _LoginColors.notice, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}