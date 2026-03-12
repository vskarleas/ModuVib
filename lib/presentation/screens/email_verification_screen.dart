import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';

// ══════════════════════════════════════════════════════════════
// EMAIL VERIFICATION SCREEN
// ══════════════════════════════════════════════════════════════

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late AuthService _authService;
  bool _isChecking = false;
  int _checkCount = 0;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    // Start checking every 3 seconds
    _autoCheckEmail();
  }

  void _autoCheckEmail() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      _checkEmailVerification();
    }
  }

  Future<void> _checkEmailVerification() async {
    setState(() => _isChecking = true);

    try {
      // Reload user to get latest email verification status
      await _authService.reloadUser();

      if (_authService.isEmailVerified()) {
        // Email is verified, go to home
        if (mounted) {
          context.go(AppRoutes.home);
        }
      } else {
        // Not verified yet, schedule next check
        _checkCount++;
        if (_checkCount < 20) {
          // Check up to 20 times (60 seconds)
          await Future.delayed(const Duration(seconds: 3));
          if (mounted) {
            _autoCheckEmail();
          }
        }
        setState(() => _isChecking = false);
      }
    } catch (e) {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isChecking = true);

    try {
      await _authService.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Email de vérification renvoyé',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de l\'envoi',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
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
                  LucideIcons.mail,
                  size: 60,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Vérifiez votre email',
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
                'Un lien de vérification a été envoyé à:\n${user?.email ?? ""}',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // Checking status
              if (_isChecking)
                const Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                    SizedBox(height: 16),
                  ],
                ),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comment faire:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Vérifiez votre boîte de réception\n2. Cliquez sur le lien de vérification\n3. Vous serez automatiquement redirigé une fois vérifié',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _resendVerificationEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Renvoyer l\'email',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isChecking ? null : _logout,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Déconnexion',
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
        ),
      ),
    );
  }
}
