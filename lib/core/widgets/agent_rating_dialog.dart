import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/rating_service.dart';
import '../theme/app_colors.dart';

/// Shows the "rate your agent" popup (agent name + 5 stars + submit). Resolves
/// once the player submits or dismisses. Submitting writes to agent_ratings.
Future<void> showAgentRatingDialog(
  BuildContext context, {
  required String gameId,
  required String agentId,
  required String agentName,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _AgentRatingDialog(
      gameId: gameId,
      agentId: agentId,
      agentName: agentName,
    ),
  );
}

class _AgentRatingDialog extends StatefulWidget {
  final String gameId, agentId, agentName;
  const _AgentRatingDialog({
    required this.gameId,
    required this.agentId,
    required this.agentName,
  });

  @override
  State<_AgentRatingDialog> createState() => _AgentRatingDialogState();
}

class _AgentRatingDialogState extends State<_AgentRatingDialog> {
  int _rating = 0;
  bool _submitting = false;

  Future<void> _submit() async {
    if (_rating == 0 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await RatingService.rateAgent(
        gameId: widget.gameId,
        agentId: widget.agentId,
        rating: _rating,
      );
    } catch (_) {
      // Best-effort — don't block the player if the write fails.
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Dialog(
      backgroundColor: surface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rate your agent',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: primary)),
            const SizedBox(height: 4),
            Text(widget.agentName,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: secondary)),
            const SizedBox(height: 18),

            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 40,
                      color: filled ? AppColors.gold : secondary,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _rating == 0
                      ? null
                      : const LinearGradient(
                          colors: [AppColors.goldActionStart, AppColors.goldActionEnd]),
                  color: _rating == 0 ? AppColors.darkTextMuted : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _rating == 0 ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Text('Submit',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed:
                  _submitting ? null : () => Navigator.of(context).pop(),
              child: Text('Maybe later',
                  style: GoogleFonts.inter(fontSize: 13, color: secondary)),
            ),
          ],
        ),
      ),
    );
  }
}
