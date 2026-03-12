import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

// ══════════════════════════════════════════════════════════════
// AUTH SERVICE — Firebase Authentication wrapper
// ══════════════════════════════════════════════════════════════

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Current Firebase user (null if signed out)
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ══════════════════════════════════════════════════════════════
  // EMAIL AUTHENTICATION
  // ══════════════════════════════════════════════════════════════

  /// Sign in with email + password
  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Create account with email + password + name + phone
  Future<UserCredential> signUp(
    String email,
    String password, {
    String? firstName,
    String? lastName,
    String? phoneNumber,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Store user info in Firestore
    await _firestore.collection('users').doc(credential.user!.uid).set(
      {
        'email': email.trim(),
        'firstName': firstName ?? '',
        'lastName': lastName ?? '',
        'phoneNumber': phoneNumber ?? '',
        'emailVerified': false,
        'phoneVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return credential;
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Check if user email is verified
  bool isEmailVerified() {
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Reload user to get latest email verification status
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  /// Get user full name from Firestore
  Future<String> getUserFullName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final firstName = doc.data()?['firstName'] as String? ?? '';
      final lastName = doc.data()?['lastName'] as String? ?? '';
      return '$firstName $lastName'.trim();
    } catch (e) {
      return '';
    }
  }

  // ══════════════════════════════════════════════════════════════
  // PHONE AUTHENTICATION
  // ══════════════════════════════════════════════════════════════

  /// Start phone sign-in flow
  /// Returns verificationId to pass to verifyPhoneCode
  /// Handles iOS-specific phone verification with proper error handling
  Future<String> sendPhoneCode(String phoneNumber) async {
    try {
      final Completer<String> completer = Completer();
      
      // Ensure phone number is properly formatted for Firebase
      final formattedPhone = _formatPhoneForFirebase(phoneNumber);
      
      // Use verifyPhoneNumber with explicit timeout for iOS stability
      final timeoutDuration = const Duration(seconds: 120);
      
      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: timeoutDuration,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-sign in on some platforms (like Android)
          try {
            await _auth.signInWithCredential(credential);
            if (!completer.isCompleted) {
              completer.complete(''); // Return empty string for auto-verified
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
      );

      // Wait for verification with timeout protection
      return await completer.future.timeout(
        const Duration(seconds: 150),
        onTimeout: () {
          if (!completer.isCompleted) {
            completer.completeError(
              FirebaseAuthException(
                code: 'timeout',
                message: 'Phone verification timed out. Please try again.',
              ),
            );
          }
          throw FirebaseAuthException(
            code: 'timeout',
            message: 'Phone verification timed out. Please try again.',
          );
        },
      );
    } catch (e) {
      rethrow;
    }
  }
  
  /// Format phone number for Firebase compatibility
  /// Removes formatting characters and ensures + prefix for international format
  String _formatPhoneForFirebase(String phoneNumber) {
    // Remove all non-digit characters except + at start
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Remove extra + signs (keep only the first one)
    while (cleaned.startsWith('++')) {
      cleaned = cleaned.substring(1);
    }
    
    // If no + prefix, add one (assuming US/Canada with +1)
    if (!cleaned.startsWith('+')) {
      // Remove leading 1 if present (will be added with +)
      if (cleaned.startsWith('1') && cleaned.length > 10) {
        cleaned = cleaned.substring(1);
      }
      cleaned = '+1$cleaned';
    }
    
    return cleaned;
  }

  /// Verify phone code and sign in
  Future<UserCredential> verifyPhoneCode(
    String verificationId,
    String smsCode,
  ) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Sign in with phone number (combines send + verify)
  Future<String> startPhoneSignIn(String phoneNumber) {
    return sendPhoneCode(phoneNumber);
  }

  /// Sign out
  Future<void> signOut() => _auth.signOut();

  /// Get user phone from Firestore
  Future<String?> getUserPhoneNumber(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['phoneNumber'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Store phone number in user profile
  Future<void> updateUserPhone(String uid, String phoneNumber) {
    return _firestore.collection('users').doc(uid).set(
      {
        'phoneNumber': phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
