import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

/// Coloured status pill for a tournament's lifecycle state. The in_progress
/// pill pulses to read as "LIVE".
class TournamentStatusChip extends StatelessWidget {
  final String status;
  const TournamentStatusChip(this.status, {super.key});

  ({String label, Color color, bool pulse}) get _style => switch (status) {
        'pending_approval' => (
            label: 'Pending Approval',
            color: const Color(0xFFFBBF24),
            pulse: false
          ),
        'approved' => (
            label: 'Registration Open',
            color: const Color(0xFF3B82F6),
            pulse: false
          ),
        'building_teams' => (
            label: 'Teams Forming',
            color: const Color(0xFF3B82F6),
            pulse: false
          ),
        'bracket_generated' => (
            label: 'Bracket Ready',
            color: AppColors.orange,
            pulse: false
          ),
        'in_progress' =>
          (label: 'LIVE', color: AppColors.tierElite, pulse: true),
        'completed' => (
            label: 'Completed',
            color: const Color(0xFF22C55E),
            pulse: false
          ),
        'rejected' => (
            label: 'Rejected',
            color: AppColors.tierElite,
            pulse: false
          ),
        _ => (label: status, color: Colors.grey, pulse: false),
      };

  @override
  Widget build(BuildContext context) {
    final s = _style;
    Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: s.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.pulse) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(s.label,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w700, color: s.color)),
        ],
      ),
    );
    if (s.pulse) {
      pill = pill
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn()
          .then()
          .fade(begin: 1, end: 0.45, duration: 800.ms);
    }
    return pill;
  }
}
