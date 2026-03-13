import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/services/local_security_service.dart';

// ══════════════════════════════════════════════════════════════
// PIN SCREEN — Local authentication via 4-digit PIN
// ══════════════════════════════════════════════════════════════
// Shown when the user has an active Firebase session but needs
// to authenticate locally before accessing the app.
// ══════════════════════════════════════════════════════════════

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final LocalSecurityService _securityService = LocalSecurityService();

  String _pin = '';
  int _attempts = 0;
  static const int _maxAttempts = 5;
  String? _errorText;
  bool _isVerifying = false;
  bool _biometricEnabled = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Lifecycle ──────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final uid = _uid;
    if (uid == null) return;

    final enabled = await _securityService.isBiometricEnabled(uid);
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled);

    if (enabled) {
      _triggerBiometric();
    }
  }

  // ── PIN Logic ──────────────────────────────────────────────

  Future<void> _onDigitPressed(String digit) async {
    if (_isVerifying || _pin.length >= 4) return;

    setState(() {
      _pin += digit;
      _errorText = null;
    });

    if (_pin.length == 4) {
      await _verifyPin();
    }
  }

  void _onBackspace() {
    if (_isVerifying || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorText = null;
    });
  }

  Future<void> _verifyPin() async {
    final uid = _uid;
    if (uid == null) return;

    setState(() => _isVerifying = true);

    final correct = await _securityService.verifyPin(uid, _pin);

    if (!mounted) return;

    if (correct) {
      context.go(AppRoutes.home);
    } else {
      _attempts++;
      if (_attempts >= _maxAttempts) {
        setState(() {
          _errorText = 'Trop de tentatives';
          _pin = '';
          _isVerifying = false;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.go(AppRoutes.login);
      } else {
        setState(() {
          _errorText = 'Code PIN incorrect';
          _pin = '';
          _isVerifying = false;
        });
      }
    }
  }

  // ── Biometric ──────────────────────────────────────────────

  Future<void> _triggerBiometric() async {
    final success = await _securityService.authenticateWithBiometric();
    if (!mounted) return;
    if (success) {
      context.go(AppRoutes.home);
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subtextColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final keypadTextColor = isDark ? Colors.white : AppColors.textPrimary;
    final keypadBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Title ──
            Text(
              'Entrez votre code PIN',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),

            const SizedBox(height: 8),

            // ── Error text ──
            SizedBox(
              height: 24,
              child: _errorText != null
                  ? Text(
                      _errorText!,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            // ── PIN Dots ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: filled
                          ? AppColors.primary
                          : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            const Spacer(flex: 2),

            // ── Numeric Keypad ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  // Row 1: 1 2 3
                  _buildKeypadRow(['1', '2', '3'], keypadTextColor, keypadBg),
                  const SizedBox(height: 16),
                  // Row 2: 4 5 6
                  _buildKeypadRow(['4', '5', '6'], keypadTextColor, keypadBg),
                  const SizedBox(height: 16),
                  // Row 3: 7 8 9
                  _buildKeypadRow(['7', '8', '9'], keypadTextColor, keypadBg),
                  const SizedBox(height: 16),
                  // Row 4: (empty / biometric) 0 backspace
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Bottom-left: biometric or empty
                      _biometricEnabled
                          ? _buildKeypadButton(
                              child: Icon(
                                LucideIcons.fingerprint,
                                color: AppColors.primary,
                                size: 28,
                              ),
                              onTap: _triggerBiometric,
                              bg: keypadBg,
                            )
                          : const SizedBox(width: 72, height: 72),

                      // 0
                      _buildDigitButton('0', keypadTextColor, keypadBg),

                      // Backspace
                      _buildKeypadButton(
                        child: Icon(
                          LucideIcons.delete,
                          color: keypadTextColor,
                          size: 24,
                        ),
                        onTap: _onBackspace,
                        bg: keypadBg,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // ── Email login link ──
            TextButton(
              onPressed: () => context.go(AppRoutes.login),
              child: Text(
                'Connexion par email',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: subtextColor,
                  decoration: TextDecoration.underline,
                  decorationColor: subtextColor,
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Keypad Helpers ─────────────────────────────────────────

  Widget _buildKeypadRow(List<String> digits, Color textColor, Color bg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((d) => _buildDigitButton(d, textColor, bg))
          .toList(),
    );
  }

  Widget _buildDigitButton(String digit, Color textColor, Color bg) {
    return _buildKeypadButton(
      child: Text(
        digit,
        style: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      onTap: () => _onDigitPressed(digit),
      bg: bg,
    );
  }

  Widget _buildKeypadButton({
    required Widget child,
    required VoidCallback onTap,
    required Color bg,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}
