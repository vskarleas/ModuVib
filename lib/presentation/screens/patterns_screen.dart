import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/providers/app_providers.dart';

// ══════════════════════════════════════════════════════════════
// PATTERNS SCREEN — Programmes automatiques de vibration
// ══════════════════════════════════════════════════════════════

/// Modèle décrivant un pattern vibratoire.
class _PatternInfo {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final IconData icon;
  final Color accentColor;

  const _PatternInfo({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}

const _kPatterns = <_PatternInfo>[
  _PatternInfo(
    id: 'wave',
    name: 'Vague',
    emoji: '\u{1F30A}',
    description: 'Les moteurs s\'activent de haut en bas',
    icon: LucideIcons.waves,
    accentColor: Color(0xFF2196F3),
  ),
  _PatternInfo(
    id: 'rain',
    name: 'Pluie',
    emoji: '\u{1F327}',
    description: 'Activations douces et aléatoires',
    icon: LucideIcons.cloudRain,
    accentColor: Color(0xFF5C6BC0),
  ),
  _PatternInfo(
    id: 'pulse',
    name: 'Impulsion',
    emoji: '\u{26A1}',
    description: 'Tous les moteurs en même temps',
    icon: LucideIcons.zap,
    accentColor: Color(0xFFFF9800),
  ),
  _PatternInfo(
    id: 'circle',
    name: 'Cercle',
    emoji: '\u{1F300}',
    description: 'Rotation autour du dos',
    icon: LucideIcons.refreshCw,
    accentColor: Color(0xFF26A69A),
  ),
];

/// Présélections du minuteur (en minutes).
const _kTimerPresets = [5, 10, 15, 30];

/// Provider local pour le minuteur sélectionné.
final _selectedTimerProvider = StateProvider<int?>((ref) => null);

// ══════════════════════════════════════════════════════════════

class PatternsScreen extends ConsumerStatefulWidget {
  const PatternsScreen({super.key});

  @override
  ConsumerState<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends ConsumerState<PatternsScreen> {
  // ── Actions ──────────────────────────────────────────────────

  void _togglePattern(String patternId) {
    if (!mounted) return;

    final current = ref.read(activePatternProvider);
    if (current == patternId) {
      ref.read(patternTimerNotifierProvider.notifier).stopPattern();
      return;
    }

    // Démarrer le pattern
    ref.read(activePatternProvider.notifier).state = patternId;
    ref.read(lastSessionTimeProvider.notifier).state = DateTime.now();

    // Lancer le minuteur si un preset est sélectionné
    final preset = ref.read(_selectedTimerProvider);
    if (preset != null) {
      ref.read(patternTimerNotifierProvider.notifier).startTimer(preset * 60);
    }
  }

  void _stopPattern() {
    ref.read(patternTimerNotifierProvider.notifier).stopPattern();
  }

  // ── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final activePattern = ref.watch(activePatternProvider);
    final timerSeconds = ref.watch(patternTimerSecondsProvider);
    final selectedPreset = ref.watch(_selectedTimerProvider);
    final masterIntensity = ref.watch(masterIntensityProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFE0E0E0) : AppColors.textPrimary;
    final textSecondary = isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondary;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ────────────────────────────────────────
            Text(
              'Programmes',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lancez un programme automatique',
              style: GoogleFonts.poppins(fontSize: 14, color: textSecondary),
            ),
            const SizedBox(height: 20),

            // ── Indicateur d'intensité ─────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.gauge, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Intensité globale : ${(masterIntensity * 100).round()}%',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Grille des patterns ────────────────────────────
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.05,
              ),
              itemCount: _kPatterns.length,
              itemBuilder: (_, index) {
                final pattern = _kPatterns[index];
                final isActive = activePattern == pattern.id;
                return _PatternCard(
                  pattern: pattern,
                  isActive: isActive,
                  cardColor: cardColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => _togglePattern(pattern.id),
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Section minuteur ───────────────────────────────
            Text(
              'MINUTEUR',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary.withValues(alpha: 0.6),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            _TimerSection(
              timerSeconds: timerSeconds,
              selectedPreset: selectedPreset,
              activePattern: activePattern,
              cardColor: cardColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              onPresetTap: (minutes) {
                if (selectedPreset == minutes) {
                  ref.read(_selectedTimerProvider.notifier).state = null;
                  if (timerSeconds != null) {
                    ref.read(patternTimerNotifierProvider.notifier).stopTimer();
                    ref.read(patternTimerSecondsProvider.notifier).state = null;
                  }
                } else {
                  ref.read(_selectedTimerProvider.notifier).state = minutes;
                  if (activePattern != null) {
                    ref.read(patternTimerNotifierProvider.notifier).startTimer(minutes * 60);
                  }
                }
              },
            ),
            const SizedBox(height: 20),

            // ── Bannière du pattern actif ──────────────────────
            if (activePattern != null)
              _ActivePatternBanner(
                pattern: _kPatterns.firstWhere((p) => p.id == activePattern),
                timerSeconds: timerSeconds,
                onStop: _stopPattern,
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Composants privés
// ══════════════════════════════════════════════════════════════

String _formatTime(int totalSeconds) {
  final min = totalSeconds ~/ 60;
  final sec = totalSeconds % 60;
  return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}

// ── Carte Pattern ────────────────────────────────────────────

class _PatternCard extends StatelessWidget {
  final _PatternInfo pattern;
  final bool isActive;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _PatternCard({
    required this.pattern,
    required this.isActive,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = pattern.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? accent.withValues(alpha: 0.12) : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? accent.withValues(alpha: 0.4)
                : AppColors.divider.withValues(alpha: 0.3),
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? accent.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: isActive ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(pattern.emoji, style: const TextStyle(fontSize: 28)),
                const Spacer(),
                if (isActive)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              pattern.name,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isActive ? accent : textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              pattern.description,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: isActive
                    ? accent.withValues(alpha: 0.7)
                    : textSecondary,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Minuteur ─────────────────────────────────────────

class _TimerSection extends StatelessWidget {
  final int? timerSeconds;
  final int? selectedPreset;
  final String? activePattern;
  final Color cardColor;
  final Color textPrimary;
  final Color textSecondary;
  final ValueChanged<int> onPresetTap;

  const _TimerSection({
    required this.timerSeconds,
    required this.selectedPreset,
    required this.activePattern,
    required this.cardColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.onPresetTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(LucideIcons.timer, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Arrêter après',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
              const Spacer(),
              if (timerSeconds != null)
                Text(
                  _formatTime(timerSeconds!),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: _kTimerPresets.map((minutes) {
              final isSelected = selectedPreset == minutes;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => onPresetTap(minutes),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.backgroundAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${minutes}m',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Bannière Pattern Actif ───────────────────────────────────

class _ActivePatternBanner extends StatelessWidget {
  final _PatternInfo pattern;
  final int? timerSeconds;
  final VoidCallback onStop;

  const _ActivePatternBanner({
    required this.pattern,
    required this.timerSeconds,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final accent = pattern.accentColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(pattern.emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pattern.name} en cours',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                if (timerSeconds != null)
                  Text(
                    'Arrêt dans ${_formatTime(timerSeconds!)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onStop,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error.withValues(alpha: 0.9),
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Arrêter',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
