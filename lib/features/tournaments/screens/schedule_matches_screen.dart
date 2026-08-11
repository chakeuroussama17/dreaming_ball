import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/tournament_providers.dart';
import '../../../core/services/tournament_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav.dart';

class ScheduleMatchesScreen extends ConsumerWidget {
  final String id;
  const ScheduleMatchesScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final matchesAsync = ref.watch(tournamentMatchesProvider(id));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('tournaments'),
        ),
        title: Text('Schedule Matches',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: matchesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold)),
        error: (_, _) => Center(
            child: Text('Could not load',
                style: GoogleFonts.inter(color: secondary))),
        data: (all) {
          // Only matches whose teams are known can be scheduled now.
          final schedulable = all.where((m) => m.bothTeamsSet).toList();
          final allScheduled = schedulable.isNotEmpty &&
              schedulable.every((m) => m.scheduledAt != null);
          return Column(
            children: [
              Expanded(
                child: schedulable.isEmpty
                    ? Center(
                        child: Text('No matches to schedule yet',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: secondary)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        itemCount: schedulable.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) => _row(context, ref,
                            schedulable[i], primary, secondary, border, surface),
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: allScheduled
                            ? const LinearGradient(
                                colors: [AppColors.goldActionStart, AppColors.goldActionEnd])
                            : null,
                        color: allScheduled ? null : AppColors.darkTextMuted,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: allScheduled
                            ? () => _publish(context, ref)
                            : null,
                        child: Text('Publish Schedule',
                            style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, TournamentMatch m,
      Color primary, Color secondary, Color border, Color surface) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.roundName,
                    style: GoogleFonts.inter(fontSize: 11, color: secondary)),
                const SizedBox(height: 4),
                Text('${m.teamAName ?? 'TBD'}  vs  ${m.teamBName ?? 'TBD'}',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: primary)),
                const SizedBox(height: 4),
                Text(
                    m.scheduledAt == null
                        ? 'Not scheduled'
                        : DateFormat('EEE, MMM d · h:mm a')
                            .format(m.scheduledAt!),
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: m.scheduledAt == null
                            ? AppColors.gold
                            : AppColors.success)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _pick(context, ref, m),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.gold.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(m.scheduledAt == null ? 'Set' : 'Edit',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(
      BuildContext context, WidgetRef ref, TournamentMatch m) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: m.scheduledAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: m.scheduledAt == null
          ? const TimeOfDay(hour: 20, minute: 0)
          : TimeOfDay.fromDateTime(m.scheduledAt!),
    );
    if (time == null) return;
    final when =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    await TournamentService.scheduleMatch(m.id, when);
    ref.invalidate(tournamentMatchesProvider(id));
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    try {
      await TournamentService.publishSchedule(id);
      ref.invalidate(tournamentProvider(id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule published — tournament is live')));
        context.safePop('tournaments');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not publish — try again')));
      }
    }
  }
}
