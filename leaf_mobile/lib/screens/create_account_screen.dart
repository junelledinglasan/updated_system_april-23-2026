import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class _CAColors {
  static const dark   = Color(0xFF1B5E20);
  static const green  = Color(0xFF2E7D32);
  static const sub    = Color(0xFF888888);
  static const red    = Color(0xFFE53935);
  static const orange = Color(0xFFFF9800);
}

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;
  bool _done = false;
  final Map<String, String> _errors = {};

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _validate() {
    final e = <String, String>{};
    if (_firstNameCtrl.text.trim().isEmpty) e['first_name'] = 'Required';
    if (_lastNameCtrl.text.trim().isEmpty) e['last_name'] = 'Required';
    if (_usernameCtrl.text.trim().isEmpty) {
      e['username'] = 'Required';
    } else if (_usernameCtrl.text.trim().length < 4) {
      e['username'] = 'Min 4 characters';
    } else if (_usernameCtrl.text.contains(' ')) {
      e['username'] = 'No spaces allowed';
    }
    if (_passwordCtrl.text.isEmpty) {
      e['password'] = 'Required';
    } else if (_passwordCtrl.text.length < 6) {
      e['password'] = 'Min 6 characters';
    }
    if (_passwordCtrl.text != _confirmCtrl.text) e['confirmPassword'] = 'Passwords do not match';
    return e;
  }

  Future<void> _handleSubmit() async {
    final errs = _validate();
    if (errs.isNotEmpty) {
      setState(() => _errors
        ..clear()
        ..addAll(errs));
      return;
    }
    setState(() {
      _loading = true;
      _errors.clear();
    });
    final result = await AuthService.register(
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      middleName: _middleNameCtrl.text.trim(),
    );
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _loading = false;
        _done = true;
      });
    } else {
      setState(() {
        _loading = false;
        _errors['username'] = result['message'] ?? 'Registration failed.';
      });
    }
  }

  int get _strengthLevel {
    final len = _passwordCtrl.text.length;
    if (len == 0) return 0;
    if (len < 5) return 1; // weak
    if (len < 8) return 2; // fair
    return 3; // strong
  }

  String get _strengthLabel => ['', 'Weak', 'Fair', 'Strong'][_strengthLevel];
  Color get _strengthColor => [
        Colors.transparent,
        _CAColors.red,
        _CAColors.orange,
        _CAColors.green,
      ][_strengthLevel];

  InputDecoration _dec({String? error, Widget? suffixIcon}) => InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        errorText: error,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: error != null ? _CAColors.red : const Color(0xFFE0E0E0), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _CAColors.green, width: 1.5)),
      );

  Widget _field(String label, TextEditingController ctrl, {bool required = false, String? errorKey, TextInputType? type, bool obscure = false, Widget? suffixIcon, void Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(text: label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF555555)), children: [
          if (required) const TextSpan(text: ' *', style: TextStyle(color: _CAColors.red)),
        ])),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: type,
          style: const TextStyle(fontSize: 13),
          onChanged: onChanged ?? (_) => setState(() => _errors.remove(errorKey)),
          decoration: _dec(error: errorKey != null ? _errors[errorKey] : null, suffixIcon: suffixIcon),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 8))],
                ),
                child: _done ? _buildSuccess() : _buildForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: _CAColors.green, size: 52),
          const SizedBox(height: 12),
          const Text('Account Created!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _CAColors.dark)),
          const SizedBox(height: 10),
          const Text(
            'Your account has been created successfully.\n\nYou can now log in using your username and password. Once logged in, you can apply for official membership to unlock full access.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.7),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(10), border: const Border(left: BorderSide(color: _CAColors.green, width: 3))),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 12, color: Color(0xFF555555), height: 1.5),
                children: [
                  TextSpan(text: 'After logging in, go to '),
                  TextSpan(text: 'Apply for Membership', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' to submit your membership application for admin approval.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _CAColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Go to Login', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_CAColors.dark, _CAColors.green], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const Text('LEAF MPC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1)),
              const SizedBox(height: 6),
              const Text('Create Account', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Create your LEAF MPC account to get started.', style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.8))),
            ],
          ),
        ),

        // ── Body ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(10), border: const Border(left: BorderSide(color: _CAColors.green, width: 3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.info_outline, size: 14, color: _CAColors.green),
                      SizedBox(width: 5),
                      Text('Note', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _CAColors.green)),
                    ]),
                    const SizedBox(height: 4),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF555555), height: 1.6),
                        children: [
                          TextSpan(text: 'Creating an account does '),
                          TextSpan(text: 'not', style: TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: ' make you an official member yet. After logging in, you can submit a membership application for admin review.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              _field('First Name', _firstNameCtrl, required: true, errorKey: 'first_name'),
              const SizedBox(height: 12),
              _field('Last Name', _lastNameCtrl, required: true, errorKey: 'last_name'),
              const SizedBox(height: 12),
              _field('Middle Name', _middleNameCtrl),
              const SizedBox(height: 12),

              _field('Username', _usernameCtrl, required: true, errorKey: 'username'),
              const SizedBox(height: 4),
              const Text('Min 4 characters, no spaces allowed.', style: TextStyle(fontSize: 10.5, color: _CAColors.sub)),
              const SizedBox(height: 12),

              _field(
                'Password', _passwordCtrl, required: true, errorKey: 'password', obscure: !_showPassword,
                onChanged: (_) => setState(() => _errors.remove('password')),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 17, color: const Color(0xFFAAAAAA)),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
              const SizedBox(height: 12),
              _field('Confirm Password', _confirmCtrl, required: true, errorKey: 'confirmPassword', obscure: !_showPassword),

              if (_passwordCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Row(
                      children: List.generate(3, (i) {
                        final filled = _strengthLevel > i;
                        return Container(
                          width: 40, height: 4,
                          margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                          decoration: BoxDecoration(color: filled ? _strengthColor : const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Text(_strengthLabel, style: const TextStyle(fontSize: 11, color: _CAColors.sub)),
                  ],
                ),
              ],
            ],
          ),
        ),

        // ── Footer ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _CAColors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
                  onPressed: _loading ? null : _handleSubmit,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ', style: TextStyle(fontSize: 12, color: _CAColors.sub)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('Login here', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _CAColors.green, decoration: TextDecoration.underline)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}