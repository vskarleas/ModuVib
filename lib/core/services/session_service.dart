import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ══════════════════════════════════════════════════════════════
// SESSION SERVICE — Firestore session logging
// ══════════════════════════════════════════════════════════════
// Stores sessions under: users/{uid}/sessions/{docId}

class SessionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Reference to current user's sessions sub‑collection
  CollectionReference<Map<String, dynamic>>? _sessionsRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('sessions');
  }

  /// Log a completed session
  Future<void> logSession({
    required DateTime startTime,
    required int durationMinutes,
    required double meanIntensity,
    String? patternUsed,
  }) async {
    final ref = _sessionsRef();
    if (ref == null) return;

    await ref.add({
      'startTime': Timestamp.fromDate(startTime),
      'durationMinutes': durationMinutes,
      'meanIntensity': meanIntensity,
      'patternUsed': patternUsed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch recent sessions (last 30 days, max 100)
  Future<List<SessionRecord>> recentSessions() async {
    final ref = _sessionsRef();
    if (ref == null) return [];

    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final snap = await ref
        .where('startTime', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('startTime', descending: true)
        .limit(100)
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return SessionRecord(
        time: (data['startTime'] as Timestamp).toDate(),
        durationMinutes: (data['durationMinutes'] as num).toInt(),
        intensity: (data['meanIntensity'] as num).toDouble(),
        patternUsed: data['patternUsed'] as String?,
      );
    }).toList();
  }

  /// Log the current session using the start time from the provider.
  /// Returns true if a session was logged.
  Future<bool> logCurrentSession({
    required DateTime? startTime,
    required double meanIntensity,
    String? patternUsed,
  }) async {
    if (startTime == null) return false;
    final duration = DateTime.now().difference(startTime).inMinutes;
    if (duration < 1) return false; // ignore sessions < 1 min
    await logSession(
      startTime: startTime,
      durationMinutes: duration,
      meanIntensity: meanIntensity,
      patternUsed: patternUsed,
    );
    return true;
  }
}

/// Immutable session record read from Firestore
class SessionRecord {
  final DateTime time;
  final int durationMinutes;
  final double intensity;
  final String? patternUsed;

  const SessionRecord({
    required this.time,
    required this.durationMinutes,
    required this.intensity,
    this.patternUsed,
  });
}
