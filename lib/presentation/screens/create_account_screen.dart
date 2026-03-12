import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';

// ══════════════════════════════════════════════════════════════
// CREATE ACCOUNT SCREEN — Écran d'inscription avec flux en étapes
// ══════════════════════════════════════════════════════════════

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final _authService = AuthService();

  int _currentStep = 0; // 0: Info, 1: Phone Verification, 2: Complete
  bool _isLoading = false;
  String? _errorText;
  bool _obscurePassword = true;
  String? _phoneVerificationId;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  /// Format phone number to remove non-digits
  String _formatPhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  /// Send SMS code to phone number (start verification)
  Future<void> _sendSmsCode() async {
    final phone = _formatPhoneNumber(_phoneController.text);

    if (phone.isEmpty || phone.length < 10) {
      setState(() => _errorText = 'Veuillez entrer un numéro de téléphone valide');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // Format phone with country code
      final formattedPhone = '+1$phone';

      // Send SMS code
      final verId = await _authService.sendPhoneCode(formattedPhone);

      if (mounted) {
        setState(() {
          _phoneVerificationId = verId;
          _currentStep = 1; // Move to SMS verification step
          _isLoading = false;
          _smsCodeController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Erreur lors de l\'envoi du code: ${e.toString().contains('operation-not-allowed') ? 'Authentification par SMS non disponible' : 'Vérifiez votre numéro'}';
          _isLoading = false;
        });
      }
    }
  }

  /// Verify SMS code and create account
  Future<void> _verifySmsAndCreateAccount() async {
    final smsCode = _smsCodeController.text.trim();

    if (smsCode.isEmpty || smsCode.length != 6) {
      setState(() => _errorText = 'Veuillez entrer un code à 6 chiffres');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      if (_phoneVerificationId == null) {
        throw Exception('ID de vérification non trouvé');
      }

      // Verify phone code
      await _authService.verifyPhoneCode(
        _phoneVerificationId!,
        smsCode,
      );

      // Create account with all data
      await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _formatPhoneNumber(_phoneController.text),
      );

      // Send email verification
      await _authService.sendEmailVerification();

      if (mounted) {
        context.go(AppRoutes.emailVerification);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Code SMS invalide ou erreur de création de compte';
          _isLoading = false;
        });
      }
    }
  }

  /// Go back to previous step
  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _errorText = null;
      });
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  ],
                ),
              ),
            ),
            // Content
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Créer un compte',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x),
                          onPressed: () => context.pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Step indicator
                    Text(
                      'Étape ${_currentStep + 1} sur 2',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / 2,
                        minHeight: 6,
                        backgroundColor: AppColors.divider.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Step content
                    if (_currentStep == 0) ...[
                      // Step 1: Personal Information
                      _buildPersonalInfoForm(isDark),
                    ] else if (_currentStep == 1) ...[
                      // Step 2: Phone Verification
                      _buildPhoneVerificationForm(isDark),
                    ],

                    const SizedBox(height: 32),

                    // Error message
                    if (_errorText != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.alertCircle,
                              color: AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorText!,
                                style: GoogleFonts.poppins(
                                  color: AppColors.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _previousStep,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              _currentStep == 0 ? 'Annuler' : 'Précédent',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : (_currentStep == 0 ? _sendSmsCode : _verifySmsAndCreateAccount),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    _currentStep == 0 ? 'Suivant' : 'Créer un compte',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build step 1: Personal info form
  Widget _buildPersonalInfoForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations personnelles',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),

          // First Name
          TextFormField(
            controller: _firstNameController,
            decoration: InputDecoration(
              labelText: 'Prénom',
              hintText: 'Jean',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(LucideIcons.user, size: 18),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Veuillez entrer votre prénom';
              }
              return null;
            },
            onChanged: (_) => setState(() => _errorText = null),
          ),
          const SizedBox(height: 16),

          // Last Name
          TextFormField(
            controller: _lastNameController,
            decoration: InputDecoration(
              labelText: 'Nom',
              hintText: 'Dupont',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(LucideIcons.user, size: 18),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Veuillez entrer votre nom';
              }
              return null;
            },
            onChanged: (_) => setState(() => _errorText = null),
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'jean@example.com',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(LucideIcons.mail, size: 18),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Veuillez entrer votre email';
              }
              if (!_isValidEmail(value!)) {
                return 'Veuillez entrer un email valide';
              }
              return null;
            },
            onChanged: (_) => setState(() => _errorText = null),
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              hintText: 'Minimum 6 caractères',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(LucideIcons.lock, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Veuillez entrer un mot de passe';
              }
              if (value!.length < 6) {
                return 'Le mot de passe doit contenir au moins 6 caractères';
              }
              return null;
            },
            onChanged: (_) => setState(() => _errorText = null),
          ),
          const SizedBox(height: 16),

          // Phone Number
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Numéro de téléphone',
              hintText: '(555) 123-4567',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(LucideIcons.phone, size: 18),
            ),
            validator: (value) {
              if (value?.trim().isEmpty ?? true) {
                return 'Veuillez entrer votre numéro de téléphone';
              }
              final digits = value!.replaceAll(RegExp(r'\D'), '');
              if (digits.length < 10) {
                return 'Veuillez entrer un numéro valide (10 chiffres minimum)';
              }
              return null;
            },
            onChanged: (_) => setState(() => _errorText = null),
          ),
        ],
      ),
    );
  }

  /// Build step 2: Phone verification form
  Widget _buildPhoneVerificationForm(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vérification du téléphone',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 16),

        // Verification code sent message
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Code envoyé',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Un code de vérification a été envoyé au numéro:\n+1${_formatPhoneNumber(_phoneController.text)}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // SMS Code input
        TextFormField(
          controller: _smsCodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: 12,
          ),
          decoration: InputDecoration(
            hintText: '000000',
            hintStyle: GoogleFonts.poppins(
              fontSize: 24,
              color: Colors.grey[300],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            counterText: '',
          ),
          onChanged: (_) => setState(() => _errorText = null),
        ),
        const SizedBox(height: 16),

        // Resend button
        Center(
          child: TextButton(
            onPressed: _isLoading
                ? null
                : () async {
                    setState(() => _isLoading = true);
                    try {
                      final phone = _formatPhoneNumber(_phoneController.text);
                      final verId = await _authService.sendPhoneCode('+1$phone');
                      if (mounted) {
                        setState(() {
                          _phoneVerificationId = verId;
                          _smsCodeController.clear();
                          _isLoading = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Code renvoyé', style: GoogleFonts.poppins()),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      setState(() => _isLoading = false);
                    }
                  },
            child: Text(
              'Renvoyer le code',
              style: GoogleFonts.poppins(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
