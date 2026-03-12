import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';

// ══════════════════════════════════════════════════════════════
// LOGIN SCREEN — Écran de connexion ModuVub
// ══════════════════════════════════════════════════════════════
// Design : En-tête vague bleue, illustration, formulaire épuré
// Logique : StatefulWidget, GoRouter, validation de formulaire
// Identifiants temporaires : "1234"
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

  // ── Auth Logic (mock) ──
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

    await Future.delayed(const Duration(milliseconds: 600));

    if (_passwordController.text == '1234') {
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', true);
      }
      if (mounted) context.go(AppRoutes.home);
    } else {
      setState(() {
        _errorText = 'Mot de passe incorrect';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleFaceId() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) context.go(AppRoutes.home);
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final h = size.height;
    final imageHeight = min(320.0, h * 0.30);
    final smallGap = h * 0.008;
    //final sectionGap = h * 0.012;
    final bottomSpacing = h * 0.025;
    final headerHeight = min(160.0, h * 0.19);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── 1. GREEN WAVE HEADER ──
            _buildWaveHeader(headerHeight),

            // ── 2. TITLES ──
            SizedBox(height: smallGap),
            Text(
              'Bienvenue !',
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
                color: Colors.black87,
              ),
            ),

            // ── 3. ILLUSTRATION ──
            SizedBox(height: 0),
            SizedBox(
              height: imageHeight,
              child: Image.network(
                'https://img.freepik.com/free-vector/mobile-login-concept-illustration_114360-83.jpg?w=740',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  LucideIcons.imageOff,
                  size: 80,
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
            ),

            // ── 4. FORM ──
            SizedBox(height: 0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Email
                    _buildEmailField(),
                    SizedBox(height: h * 0.012),

                    // Password
                    _buildPasswordField(),

                    // Error message
                    if (_errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorText!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],

                    // Remember me + Forgot password
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
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
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Mot de passe oublié ?',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: h * 0.012),

                    // Login button
                    _buildLoginButton(),

                    SizedBox(height: h * 0.012),

                    // Divider
                    _buildDivider(),

                    SizedBox(height: h * 0.012),

                    // FaceID button
                    _buildBiometricButton(),

                    SizedBox(height: h * 0.01),

                    // Don't Have Account? Signup
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Pas de compte ? ",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            "S'inscrire",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
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

  /// Green wave header — two layered waves like the reference design
  Widget _buildWaveHeader(double height) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // Back wave — darker blue (fills more area)
          ClipPath(
            clipper: _WaveClipperBack(),
            child: Container(
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1976D2), // darker blue top
                    Color(0xFF2196F3), // primary blue
                  ],
                ),
              ),
            ),
          ),
          // Front wave — lighter blue (shorter, in front)
          ClipPath(
            clipper: _WaveClipperFront(),
            child: Container(
              height: height,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF42A5F5), // lighter blue
                    Color(0xFF64B5F6), // even lighter at the wave edge
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return SizedBox(
      height: 52,
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
        onChanged: (_) {
          if (_emailError) setState(() => _emailError = false);
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: _emailError ? 'Veuillez entrer votre email' : 'Email',
          hintStyle: GoogleFonts.poppins(
            color: _emailError ? Colors.redAccent.withValues(alpha: 0.7) : Colors.grey.shade400,
            fontSize: 15,
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: _emailError ? Colors.redAccent : Colors.grey.shade300,
              width: _emailError ? 1.5 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: _emailError ? Colors.redAccent : AppColors.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return SizedBox(
      height: 52,
      child: TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
        onChanged: (_) {
          if (_passwordError) setState(() => _passwordError = false);
        },
        decoration: InputDecoration(
          isDense: true,
          hintText: _passwordError ? 'Veuillez entrer un mot de passe' : 'Mot de passe',
          hintStyle: GoogleFonts.poppins(
            color: _passwordError ? Colors.redAccent.withValues(alpha: 0.7) : Colors.grey.shade400,
            fontSize: 15,
          ),
          filled: false,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.grey.shade500,
              size: 22,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: _passwordError ? Colors.redAccent : Colors.grey.shade300,
              width: _passwordError ? 1.5 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: _passwordError ? Colors.redAccent : AppColors.primary,
              width: 1.5,
            ),
          ),
        ),
        onFieldSubmitted: (_) => _handleLogin(),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                'Se connecter',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ou',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildBiometricButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _handleFaceId,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.scan, size: 20),
            const SizedBox(width: 6),
            Text(
              'Face ID',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 20,
              color: Colors.grey.shade300,
            ),
            const SizedBox(width: 12),
            const Icon(LucideIcons.fingerprint, size: 20),
            const SizedBox(width: 6),
            Text(
              'Empreinte',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Custom Wave Clippers
// ══════════════════════════════════════════════════════════════

/// Back wave — darker, covers more area, dips lower on the right
class _WaveClipperBack extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Top-left corner
    path.lineTo(0, size.height * 0.75);

    // Curve down then up — S shape flowing right
    path.cubicTo(
      size.width * 0.20, size.height * 1.05,
      size.width * 0.45, size.height * 0.60,
      size.width * 0.70, size.height * 0.75,
    );
    path.cubicTo(
      size.width * 0.85, size.height * 0.85,
      size.width * 0.95, size.height * 0.70,
      size.width, size.height * 0.55,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Front wave — lighter, shorter, creates the layered look
class _WaveClipperFront extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.55);

    path.cubicTo(
      size.width * 0.25, size.height * 0.85,
      size.width * 0.50, size.height * 0.45,
      size.width * 0.75, size.height * 0.60,
    );
    path.cubicTo(
      size.width * 0.90, size.height * 0.68,
      size.width * 0.95, size.height * 0.50,
      size.width, size.height * 0.40,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
