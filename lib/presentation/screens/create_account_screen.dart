import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';
import '../../core/services/auth_service.dart';

// ══════════════════════════════════════════════════════════════
// CREATE ACCOUNT SCREEN — Single-step registration
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
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorText;
  bool _obscurePassword = true;
  String _selectedCountryCode = '+1';

  static const List<Map<String, String>> _countryCodes = [
    {'code': '+1', 'country': 'US/CA', 'flag': '\u{1F1FA}\u{1F1F8}'},
    {'code': '+33', 'country': 'FR', 'flag': '\u{1F1EB}\u{1F1F7}'},
    {'code': '+44', 'country': 'UK', 'flag': '\u{1F1EC}\u{1F1E7}'},
    {'code': '+49', 'country': 'DE', 'flag': '\u{1F1E9}\u{1F1EA}'},
    {'code': '+34', 'country': 'ES', 'flag': '\u{1F1EA}\u{1F1F8}'},
    {'code': '+39', 'country': 'IT', 'flag': '\u{1F1EE}\u{1F1F9}'},
    {'code': '+81', 'country': 'JP', 'flag': '\u{1F1EF}\u{1F1F5}'},
    {'code': '+86', 'country': 'CN', 'flag': '\u{1F1E8}\u{1F1F3}'},
    {'code': '+91', 'country': 'IN', 'flag': '\u{1F1EE}\u{1F1F3}'},
    {'code': '+55', 'country': 'BR', 'flag': '\u{1F1E7}\u{1F1F7}'},
    {'code': '+61', 'country': 'AU', 'flag': '\u{1F1E6}\u{1F1FA}'},
    {'code': '+82', 'country': 'KR', 'flag': '\u{1F1F0}\u{1F1F7}'},
    {'code': '+30', 'country': 'GR', 'flag': '\u{1F1EC}\u{1F1F7}'},
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  Future<void> _handleCreateAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // Format phone number for storage
      final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      final fullPhone = '$_selectedCountryCode$phoneDigits';

      // Create account
      await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: fullPhone,
      );

      // Send email verification
      await _authService.sendEmailVerification();

      if (mounted) {
        context.go(AppRoutes.emailVerification);
      }
    } catch (e) {
      if (mounted) {
        String message = 'Erreur lors de la création du compte';
        final errorStr = e.toString();
        if (errorStr.contains('email-already-in-use')) {
          message = 'Un compte existe déjà avec cet email';
        } else if (errorStr.contains('weak-password')) {
          message = 'Le mot de passe doit contenir au moins 6 caractères';
        } else if (errorStr.contains('invalid-email')) {
          message = 'Adresse email invalide';
        }
        setState(() {
          _errorText = message;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade400;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
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
                        color: textColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.x, color: isDark ? Colors.grey[400] : Colors.black54),
                      onPressed: () => context.go(AppRoutes.login),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informations personnelles',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
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
                          if (value?.trim().isEmpty ?? true) return 'Veuillez entrer votre prénom';
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
                          if (value?.trim().isEmpty ?? true) return 'Veuillez entrer votre nom';
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
                          if (value?.trim().isEmpty ?? true) return 'Veuillez entrer votre email';
                          if (!_isValidEmail(value!)) return 'Veuillez entrer un email valide';
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
                          if (value?.isEmpty ?? true) return 'Veuillez entrer un mot de passe';
                          if (value!.length < 6) return 'Le mot de passe doit contenir au moins 6 caractères';
                          return null;
                        },
                        onChanged: (_) => setState(() => _errorText = null),
                      ),
                      const SizedBox(height: 16),

                      // Phone Number with country code
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCountryCode,
                                isDense: false,
                                dropdownColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                items: _countryCodes.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c['code'],
                                    child: Text(
                                      '${c['flag']} ${c['code']}',
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCountryCode = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Numéro de téléphone',
                                hintText: '555 123 4567',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              validator: (value) {
                                if (value?.trim().isEmpty ?? true) return 'Veuillez entrer votre numéro';
                                final digits = value!.replaceAll(RegExp(r'\D'), '');
                                if (digits.length < 8) return 'Numéro trop court';
                                return null;
                              },
                              onChanged: (_) => setState(() => _errorText = null),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

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
                        const Icon(LucideIcons.alertCircle, color: AppColors.error, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorText!,
                            style: GoogleFonts.poppins(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_errorText != null) const SizedBox(height: 16),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => context.go(AppRoutes.login),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(
                          'Annuler',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleCreateAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                                'Créer un compte',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
