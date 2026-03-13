import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/local_security_service.dart';

// ══════════════════════════════════════════════════════════════
// LOGIN SCREEN — Email/password + biometric + PIN login
// ══════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _securityService = LocalSecurityService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorText;
  bool _emailError = false;
  bool _passwordError = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final emailEmpty = _emailController.text.trim().isEmpty;
    final passEmpty = _passwordController.text.isEmpty;

    setState(() {
      _emailError = emailEmpty;
      _passwordError = passEmpty;
    });

    if (emailEmpty || passEmpty) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await _authService.signIn(
        _emailController.text,
        _passwordController.text,
      );
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', true);
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      String destination = AppRoutes.home;
      if (uid != null) {
        final setupComplete = await _securityService.isSecuritySetupComplete(uid);
        if (!setupComplete) destination = AppRoutes.securitySetup;
      }
      if (mounted) {
        context.go(destination);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = _firebaseErrorMessage(e.code);
        _isLoading = false;
      });
    }
  }

  String _firebaseErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Aucun compte trouvé pour cet email';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mot de passe incorrect';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet email';
      case 'weak-password':
        return 'Le mot de passe doit contenir au moins 6 caractères';
      case 'invalid-email':
        return 'Adresse email invalide';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard';
      default:
        return 'Erreur d\'authentification ($code)';
    }
  }

  Future<void> _handleBiometric() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorText = 'Veuillez d\'abord vous connecter avec email';
          _isLoading = false;
        });
        return;
      }

      final biometricEnabled = await _securityService.isBiometricEnabled(user.uid);
      if (!biometricEnabled) {
        setState(() {
          _errorText = 'Biométrie non activée pour ce compte';
          _isLoading = false;
        });
        return;
      }

      final didAuth = await _securityService.authenticateWithBiometric();
      if (didAuth && mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', true);
        if (mounted) context.go(AppRoutes.home);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _errorText = 'Erreur d\'authentification biométrique';
        _isLoading = false;
      });
    }
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = size.height;
    final iconAreaHeight = min(200.0, h * 0.22);
    final smallGap = h * 0.008;
    final bottomSpacing = h * 0.025;
    final headerHeight = min(160.0, h * 0.19);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? const Color(0xFFE0E0E0) : Colors.black87;
    final subtextColor = isDark ? const Color(0xFF9E9E9E) : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── 1. BLUE WAVE HEADER ──
            _buildWaveHeader(headerHeight),

            // ── 2. TITLES ──
            SizedBox(height: smallGap),
            Text(
              'ModuVib',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Connexion',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),

            // ── 3. VIBRATION ICON ──
            const SizedBox(height: 8),
            SizedBox(
              height: iconAreaHeight,
              child: Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.15),
                        AppColors.primary.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                      stops: const [0.3, 0.7, 1.0],
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                        ),
                      ),
                      Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                        ),
                      ),
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                        child: const Icon(LucideIcons.vibrate, size: 30, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 4. FORM ──
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildEmailField(isDark),
                    SizedBox(height: h * 0.012),
                    _buildPasswordField(isDark),

                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          width: 24, height: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v ?? false),
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => setState(() => _rememberMe = !_rememberMe),
                          child: Text(
                            'Se souvenir de moi',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'Mot de passe oublié ?',
                            style: GoogleFonts.poppins(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: h * 0.012),

                    if (_errorText != null) ...[
                      Text(_errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      const SizedBox(height: 8),
                    ],

                    _buildLoginButton(),
                    SizedBox(height: h * 0.012),
                    _buildDivider(isDark),
                    SizedBox(height: h * 0.012),
                    _buildBiometricButton(isDark),
                    SizedBox(height: h * 0.008),
                    _buildPinLoginButton(),
                    SizedBox(height: h * 0.01),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Pas de compte ? ", style: GoogleFonts.poppins(fontSize: 14, color: subtextColor)),
                        TextButton(
                          onPressed: _isLoading ? null : () => context.go(AppRoutes.createAccount),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            "S'inscrire",
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: bottomSpacing),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  UI Components
  // ══════════════════════════════════════════════════════════

  Widget _buildWaveHeader(double height) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          ClipPath(
            clipper: _WaveClipperBack(),
            child: Container(
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
                ),
              ),
            ),
          ),
          ClipPath(
            clipper: _WaveClipperFront(),
            child: Container(
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF42A5F5), Color(0xFF64B5F6)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField(bool isDark) {
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final textCol = isDark ? const Color(0xFFE0E0E0) : Colors.black87;
    return SizedBox(
      height: 52,
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: GoogleFonts.poppins(fontSize: 15, color: textCol),
        onChanged: (_) { if (_emailError) setState(() => _emailError = false); },
        decoration: InputDecoration(
          isDense: true,
          hintText: _emailError ? 'Veuillez entrer votre email' : 'Email',
          hintStyle: GoogleFonts.poppins(
            color: _emailError ? Colors.redAccent.withValues(alpha: 0.7) : Colors.grey.shade500, fontSize: 15,
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _emailError ? Colors.redAccent : borderColor, width: _emailError ? 1.5 : 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _emailError ? Colors.redAccent : AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(bool isDark) {
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final textCol = isDark ? const Color(0xFFE0E0E0) : Colors.black87;
    return SizedBox(
      height: 52,
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: GoogleFonts.poppins(fontSize: 15, color: textCol),
        onChanged: (_) { if (_passwordError) setState(() => _passwordError = false); },
        decoration: InputDecoration(
          isDense: true,
          hintText: _passwordError ? 'Veuillez entrer un mot de passe' : 'Mot de passe',
          hintStyle: GoogleFonts.poppins(
            color: _passwordError ? Colors.redAccent.withValues(alpha: 0.7) : Colors.grey.shade500, fontSize: 15,
          ),
          filled: false,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.grey.shade500, size: 22,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _passwordError ? Colors.redAccent : borderColor, width: _passwordError ? 1.5 : 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _passwordError ? Colors.redAccent : AppColors.primary, width: 1.5),
          ),
        ),
        onFieldSubmitted: (_) => _handleLogin(),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
          elevation: 4, shadowColor: AppColors.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: _isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text('Se connecter', style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    final dividerCol = isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    return Row(
      children: [
        Expanded(child: Divider(color: dividerCol)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('ou', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade500)),
        ),
        Expanded(child: Divider(color: dividerCol)),
      ],
    );
  }

  Widget _buildBiometricButton(bool isDark) {
    return SizedBox(
      width: double.infinity, height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleBiometric,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.scan, size: 20),
            const SizedBox(width: 6),
            Text('Face ID', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Container(width: 1, height: 20, color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
            const SizedBox(width: 12),
            const Icon(LucideIcons.fingerprint, size: 20),
            const SizedBox(width: 6),
            Text('Empreinte', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildPinLoginButton() {
    return SizedBox(
      width: double.infinity, height: 44,
      child: TextButton(
        onPressed: _isLoading ? null : () => context.go(AppRoutes.lock),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.keyRound, size: 18),
            const SizedBox(width: 8),
            Text('Connexion par code PIN', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Custom Wave Clippers
// ══════════════════════════════════════════════════════════════

class _WaveClipperBack extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * 0.75)
      ..cubicTo(size.width * 0.20, size.height * 1.05, size.width * 0.45, size.height * 0.60, size.width * 0.70, size.height * 0.75)
      ..cubicTo(size.width * 0.85, size.height * 0.85, size.width * 0.95, size.height * 0.70, size.width, size.height * 0.55)
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _WaveClipperFront extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height * 0.55)
      ..cubicTo(size.width * 0.25, size.height * 0.85, size.width * 0.50, size.height * 0.45, size.width * 0.75, size.height * 0.60)
      ..cubicTo(size.width * 0.90, size.height * 0.68, size.width * 0.95, size.height * 0.50, size.width, size.height * 0.40)
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
