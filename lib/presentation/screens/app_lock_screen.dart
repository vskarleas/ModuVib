import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/services/local_security_service.dart';
import '../../core/services/auth_service.dart';

// ══════════════════════════════════════════════════════════════
// APP LOCK SCREEN
// ══════════════════════════════════════════════════════════════
// Shown on app reopen when security setup is complete.
// Tries Face ID / biometric first; falls back to PIN.
// ══════════════════════════════════════════════════════════════

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _security = LocalSecurityService();
  final _authService = AuthService();

  bool _isLoading = true;
  bool _showPin = false;
  String? _pinError;

  final List<TextEditingController> _pinControllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tryBiometric();
  }

  @override
  void dispose() {
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final n in _pinFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    if (_uid == null) {
      _goToLogin();
      return;
    }

    final biometricEnabled = await _security.isBiometricEnabled(_uid!);

    if (!biometricEnabled) {
      setState(() {
        _isLoading = false;
        _showPin = true;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _pinFocusNodes[0].requestFocus();
      });
      return;
    }

    setState(() => _isLoading = false);

    final success = await _security.authenticateWithBiometric();
    if (success) {
      if (mounted) context.go(AppRoutes.home);
    } else {
      // Biometric failed or cancelled — show PIN
      setState(() => _showPin = true);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _pinFocusNodes[0].requestFocus();
      });
    }
  }

  void _onPinDigitChanged(int index, String value) {
    if (value.length > 1) {
      value = value[value.length - 1];
      _pinControllers[index].text = value;
    }

    if (value.isNotEmpty && index < 3) {
      _pinFocusNodes[index + 1].requestFocus();
    }

    final pin = _pinControllers.map((c) => c.text).join();

    if (_pinError != null) setState(() => _pinError = null);

    if (pin.length == 4) {
      _verifyPin(pin);
    }
  }

  Future<void> _verifyPin(String pin) async {
    if (_uid == null) {
      _goToLogin();
      return;
    }

    setState(() => _isLoading = true);
    final correct = await _security.verifyPin(_uid!, pin);
    if (!mounted) return;

    if (correct) {
      context.go(AppRoutes.home);
    } else {
      for (final c in _pinControllers) {
        c.clear();
      }
      setState(() {
        _isLoading = false;
        _pinError = 'Code PIN incorrect. Réessayez.';
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _pinFocusNodes[0].requestFocus();
      });
    }
  }

  void _goToLogin() async {
    await _authService.signOut();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _showPin ? LucideIcons.keyRound : LucideIcons.fingerprint,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    Text(
                      _showPin ? 'Entrez votre code PIN' : 'Déverrouillez l\'application',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      _showPin
                          ? 'Saisissez votre code à 4 chiffres'
                          : 'Utilisez Face ID ou Touch ID pour continuer',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 40),

                    if (_showPin) ...[
                      // PIN fields
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final hasValue = _pinControllers[index].text.isNotEmpty;
                          return Container(
                            width: 60,
                            height: 60,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasValue
                                  ? AppColors.primary
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.grey.withValues(alpha: 0.12)),
                              border: Border.all(
                                color: hasValue
                                    ? AppColors.primary
                                    : (isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!),
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: TextField(
                                controller: _pinControllers[index],
                                focusNode: _pinFocusNodes[index],
                                obscureText: true,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: hasValue
                                      ? Colors.white
                                      : (isDark ? Colors.white : Colors.black),
                                ),
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (v) => _onPinDigitChanged(index, v),
                              ),
                            ),
                          );
                        }),
                      ),

                      if (_pinError != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          _pinError!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // Try biometric again (if available)
                      TextButton.icon(
                        onPressed: _tryBiometric,
                        icon: const Icon(LucideIcons.fingerprint,
                            color: AppColors.primary, size: 18),
                        label: Text(
                          'Utiliser la biométrie',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Disconnect link
                    TextButton(
                      onPressed: _goToLogin,
                      child: Text(
                        'Se déconnecter',
                        style: GoogleFonts.poppins(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
