import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/services/local_security_service.dart';

// ══════════════════════════════════════════════════════════════
// SECURITY SETUP SCREEN
// ══════════════════════════════════════════════════════════════
// Shown after email verification during account creation.
// Phase 1: Biometric setup (if available)
// Phase 2: PIN creation + confirmation
// ══════════════════════════════════════════════════════════════

class SecuritySetupScreen extends StatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  // ── State ────────────────────────────────────────────────────
  bool _isBiometricPhase = true;
  bool _isLoading = true;
  bool _isConfirming = false;
  String _pin = '';
  String _confirmPin = '';
  String? _pinError;

  final List<FocusNode> _pinFocusNodes = List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _pinControllers =
      List.generate(4, (_) => TextEditingController());

  final List<FocusNode> _confirmFocusNodes =
      List.generate(4, (_) => FocusNode());
  final List<TextEditingController> _confirmControllers =
      List.generate(4, (_) => TextEditingController());

  final _security = LocalSecurityService();
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Lifecycle ────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  @override
  void dispose() {
    for (final c in _pinControllers) {
      c.dispose();
    }
    for (final c in _confirmControllers) {
      c.dispose();
    }
    for (final n in _pinFocusNodes) {
      n.dispose();
    }
    for (final n in _confirmFocusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  // ── Biometric check ──────────────────────────────────────────

  Future<void> _checkBiometric() async {
    final available = await _security.isBiometricAvailable();
    setState(() {
      _isLoading = false;
      if (!available) {
        _isBiometricPhase = false;
      }
    });
  }

  Future<void> _enableBiometric() async {
    setState(() => _isLoading = true);
    try {
      final success = await _security.authenticateWithBiometric();
      if (success && _uid != null) {
        await _security.setBiometricEnabled(_uid!, true);
      }
    } catch (_) {
      // Biometric failed — continue to PIN setup
    }
    setState(() {
      _isBiometricPhase = false;
      _isLoading = false;
    });
  }

  void _skipBiometric() {
    setState(() {
      _isBiometricPhase = false;
    });
  }

  // ── PIN handling ─────────────────────────────────────────────

  void _onPinDigitChanged(int index, String value, {bool confirm = false}) {
    if (value.length > 1) {
      value = value[value.length - 1];
      if (confirm) {
        _confirmControllers[index].text = value;
      } else {
        _pinControllers[index].text = value;
      }
    }

    final controllers = confirm ? _confirmControllers : _pinControllers;
    final focusNodes = confirm ? _confirmFocusNodes : _pinFocusNodes;

    if (value.isNotEmpty && index < 3) {
      focusNodes[index + 1].requestFocus();
    }

    // Build pin string
    final pin = controllers.map((c) => c.text).join();

    if (confirm) {
      _confirmPin = pin;
    } else {
      _pin = pin;
    }

    // Clear any previous error
    if (_pinError != null) {
      setState(() => _pinError = null);
    }

    // Auto-advance: first entry complete → go to confirm
    if (!confirm && pin.length == 4) {
      setState(() => _isConfirming = true);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _confirmFocusNodes[0].requestFocus();
      });
    }

    // Auto-validate: confirm complete → check match
    if (confirm && pin.length == 4) {
      _validatePin();
    }
  }

  Future<void> _validatePin() async {
    if (_pin != _confirmPin) {
      setState(() {
        _pinError = 'Les codes PIN ne correspondent pas. Réessayez.';
        _isConfirming = false;
        _pin = '';
        _confirmPin = '';
      });
      for (final c in _pinControllers) {
        c.clear();
      }
      for (final c in _confirmControllers) {
        c.clear();
      }
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _pinFocusNodes[0].requestFocus();
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_uid != null) {
        await _security.savePin(_uid!, _pin);
        await _security.markSecuritySetupComplete(_uid!);
      }
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _pinError = 'Erreur lors de la sauvegarde. Réessayez.';
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : _isBiometricPhase
                ? _buildBiometricPhase(isDark)
                : _buildPinPhase(isDark),
      ),
    );
  }

  // ── Phase 1: Biometric ───────────────────────────────────────

  Widget _buildBiometricPhase(bool isDark) {
    return Padding(
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
            child: const Icon(
              LucideIcons.fingerprint,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            'Sécurité biométrique',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            'Activez l\'authentification biométrique pour\naccéder rapidement et en toute sécurité\nà votre compte.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),

          // Activer button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _enableBiometric,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Activer',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Plus tard button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _skipBiometric,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Plus tard',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 2: PIN ─────────────────────────────────────────────

  Widget _buildPinPhase(bool isDark) {
    return Padding(
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
            child: const Icon(
              LucideIcons.keyRound,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),

          // Title
          Text(
            _isConfirming
                ? 'Confirmez votre code PIN'
                : 'Créez votre code PIN',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),

          // Subtitle
          Text(
            _isConfirming
                ? 'Saisissez le même code à 4 chiffres'
                : 'Choisissez un code à 4 chiffres',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 40),

          // PIN dots / fields
          _buildPinFields(
            isDark,
            controllers: _isConfirming ? _confirmControllers : _pinControllers,
            focusNodes: _isConfirming ? _confirmFocusNodes : _pinFocusNodes,
            confirm: _isConfirming,
          ),

          // Error message
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
        ],
      ),
    );
  }

  Widget _buildPinFields(
    bool isDark, {
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
    required bool confirm,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final hasValue = controllers[index].text.isNotEmpty;

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
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: 40,
            height: 40,
            child: TextField(
              controller: controllers[index],
              focusNode: focusNodes[index],
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
              onChanged: (value) =>
                  _onPinDigitChanged(index, value, confirm: confirm),
            ),
          ),
        );
      }),
    );
  }
}
