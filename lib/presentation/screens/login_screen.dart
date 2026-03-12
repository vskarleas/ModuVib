import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';

// ══════════════════════════════════════════════════════════════
// LOGIN SCREEN — Écran de connexion ModuVib
// ══════════════════════════════════════════════════════════════
// Design : En-tête vague bleue, illustration, formulaire épuré
// Logique : Firebase Auth, biométrie (FaceID / Empreinte)
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
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorText;
  bool _emailError = false;
  bool _passwordError = false;
  bool _rememberMe = false;
  
  // Phone auth state
  bool _isEmailMode = true; // true = email login, false = phone login
  bool _isPhoneSignupMode = false; // true = show SMS code verification
  String? _phoneVerificationId;
  bool _phoneError = false;
  bool _smsCodeError = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
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
      if (mounted) context.go(AppRoutes.home);
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

  Future<void> _handleFaceId() async {
    setState(() => _isLoading = true);
    try {
      final auth = LocalAuthentication();
      final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canCheck) {
        setState(() {
          _errorText = 'Biométrie non disponible sur cet appareil';
          _isLoading = false;
        });
        return;
      }
      final didAuth = await auth.authenticate(
        localizedReason: 'Connectez-vous avec la biométrie',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
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

  // ── Phone Auth Logic ──
  Future<void> _handlePhoneLogin() async {
    final phoneEmpty = _phoneController.text.trim().isEmpty;

    setState(() {
      _phoneError = phoneEmpty;
    });

    if (phoneEmpty) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final phoneNumber = _phoneController.text.trim();
      // Add country code if not present
      final formattedPhone = phoneNumber.startsWith('+') ? phoneNumber : '+1$phoneNumber';
      
      final verificationId = await _authService.startPhoneSignIn(formattedPhone);
      
      if (mounted) {
        setState(() {
          _phoneVerificationId = verificationId;
          _isPhoneSignupMode = true; // Show SMS code field
          _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = _firebaseErrorMessage(e.code);
        _isLoading = false;
      });
    }
  }

  Future<void> _handleVerifyPhoneCodeLogin() async {
    final codeEmpty = _smsCodeController.text.trim().isEmpty;

    setState(() {
      _smsCodeError = codeEmpty;
    });

    if (codeEmpty || _phoneVerificationId == null) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await _authService.verifyPhoneCode(
        _phoneVerificationId!,
        _smsCodeController.text.trim(),
      );
      
      if (_rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', true);
      }
      
      if (mounted) context.go(AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = _firebaseErrorMessage(e.code);
        _isLoading = false;
      });
    }
  }

  // Phone signup is now handled by _sendSignupPhoneCode and _verifyPhoneAndCreateAccount
  // within the _showSignUpDialog method

  void _resetPhoneFlow() {
    setState(() {
      _phoneController.clear();
      _smsCodeController.clear();
      _phoneError = false;
      _smsCodeError = false;
      _isPhoneSignupMode = false;
      _phoneVerificationId = null;
      _errorText = null;
    });
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
                    // Email / Phone Toggle
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isEmailMode = true;
                                _resetPhoneFlow();
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _isEmailMode ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Email',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _isEmailMode ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _isEmailMode = false;
                                _resetPhoneFlow();
                              }),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: !_isEmailMode ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Téléphone',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: !_isEmailMode ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: h * 0.015),

                    // ── EMAIL MODE FIELDS ──
                    if (_isEmailMode) ...[
                      // Email
                      _buildEmailField(),
                      SizedBox(height: h * 0.012),

                      // Password
                      _buildPasswordField(),

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

                      // Error message
                      if (_errorText != null) ...[
                        Text(
                          _errorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Login button
                      _buildLoginButton(),
                    ],

                    // ── PHONE MODE FIELDS ──
                    if (!_isEmailMode) ...[
                      if (!_isPhoneSignupMode) ...[
                        // Phone number input
                        _buildPhoneField(),
                        SizedBox(height: h * 0.012),

                        // Remember me
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
                          ],
                        ),

                        SizedBox(height: h * 0.012),

                        // Error message
                        if (_errorText != null) ...[
                          Text(
                            _errorText!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Send SMS button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handlePhoneLogin,
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
                                    'Envoyer code SMS',
                                    style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ] else ...[
                        // SMS Code verification
                        Text(
                          'Entrez le code SMS reçu',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSmsCodeField(),
                        SizedBox(height: h * 0.012),

                        // Error message
                        if (_errorText != null) ...[
                          Text(
                            _errorText!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Verify button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleVerifyPhoneCodeLogin,
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
                                    'Vérifier et se connecter',
                                    style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        // Back button
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: _resetPhoneFlow,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: Text(
                              'Retour',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],

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
                          onPressed: _isLoading ? null : () => context.go(AppRoutes.createAccount),
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

  Widget _buildPhoneField() {
    return SizedBox(
      height: 52,
      child: TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
        onChanged: (_) {
          if (_phoneError) setState(() => _phoneError = false);
        },
        decoration: InputDecoration(
          isDense: true,
          prefixText: '+1 ',
          hintText: _phoneError ? 'Numéro requis' : '(555) 123-4567',
          hintStyle: GoogleFonts.poppins(
            color: _phoneError ? Colors.redAccent.withValues(alpha: 0.7) : Colors.grey.shade400,
            fontSize: 15,
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: _phoneError ? Colors.redAccent : Colors.grey.shade300,
              width: _phoneError ? 1.5 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: _phoneError ? Colors.redAccent : AppColors.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmsCodeField() {
    return SizedBox(
      height: 52,
      child: TextFormField(
        controller: _smsCodeController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
          letterSpacing: 8,
        ),
        onChanged: (_) {
          if (_smsCodeError) setState(() => _smsCodeError = false);
        },
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          hintText: '000000',
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade300,
            fontSize: 24,
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: _smsCodeError ? Colors.redAccent : Colors.grey.shade300,
              width: _smsCodeError ? 1.5 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: _smsCodeError ? Colors.redAccent : AppColors.primary,
              width: 1.5,
            ),
          ),
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

