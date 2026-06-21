import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/tournament_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/tournament_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav.dart';

class AdminTournamentApprovalScreen extends ConsumerWidget {
  const AdminTournamentApprovalScreen({super.key});

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

    final async = ref.watch(pendingTournamentsProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('admin-dashboard'),
        ),
        title: Text('Tournament Approvals',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.orange)),
        error: (_, _) => Center(
          child: Text('Could not load',
              style: GoogleFonts.inter(fontSize: 14, color: secondary)),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text('No tournaments awaiting approval',
                  style: GoogleFonts.inter(fontSize: 14, color: secondary)),
            );
          }
          return RefreshIndicator(
            color: AppColors.orange,
            onRefresh: () async => ref.refresh(pendingTournamentsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (ctx, i) => _card(
                  context, ref, list[i], primary, secondary, border, surface),
            ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Tournament t, Color primary,
      Color secondary, Color border, Color surface) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.bannerImageUrl != null)
            SizedBox(
                height: 120,
                width: double.infinity,
                child: CachedNetworkImage(
                    imageUrl: t.bannerImageUrl!, fit: BoxFit.cover)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: primary)),
                const SizedBox(height: 2),
                Text('by ${t.agentName}',
                    style: GoogleFonts.inter(fontSize: 12, color: secondary)),
                if ((t.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(t.description!,
                      style: GoogleFonts.inter(
                          fontSize: 13, height: 1.4, color: secondary)),
                ],
                const SizedBox(height: 12),
                _row('Format', t.gameFormat, secondary, primary),
                _row('Mode', t.isKnockout ? 'Knockout' : 'Group Stage',
                    secondary, primary),
                _row('Teams', '${t.numTeams}', secondary, primary),
                _row(
                    'Start',
                    t.startDate == null
                        ? '—'
                        : DateFormat('MMM d, yyyy').format(t.startDate!),
                    secondary,
                    primary),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () => _reject(context, ref, t),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppColors.tierElite
                                    .withValues(alpha: 0.6)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.close,
                              size: 16, color: AppColors.tierElite),
                          label: Text('Reject',
                              style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.tierElite)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () => _approve(context, ref, t),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF22C55E),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check,
                              size: 16, color: Colors.white),
                          label: Text('Approve',
                              style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v, Color secondary, Color primary) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: GoogleFonts.inter(fontSize: 13, color: secondary)),
            Text(v,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
          ],
        ),
      );

  Future<void> _approve(
      BuildContext context, WidgetRef ref, Tournament t) async {
    try {
      await TournamentService.approve(t.id);
      NotificationService.notifyUserAsAdmin(
        userId: t.agentId,
        title: 'Tournament approved 🏆',
        body: '"${t.name}" is approved. Start building your teams!',
      );
      ref.invalidate(pendingTournamentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Approved "${t.name}"')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not approve — try again')));
      }
    }
  }

  Future<void> _reject(
      BuildContext context, WidgetRef ref, Tournament t) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject tournament?'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Reject',
                  style: TextStyle(color: AppColors.tierElite))),
        ],
      ),
    );
    if (reason == null) return; // cancelled
    try {
      await TournamentService.reject(
          t.id, reason.isEmpty ? 'Not approved' : reason);
      NotificationService.notifyUserAsAdmin(
        userId: t.agentId,
        title: 'Tournament not approved',
        body: '"${t.name}" was rejected${reason.isEmpty ? '' : ': $reason'}.',
      );
      ref.invalidate(pendingTournamentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Rejected "${t.name}"')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not reject — try again')));
      }
    }
  }
}
