import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';

class AdminPayoutsScreen extends ConsumerWidget {
  const AdminPayoutsScreen({super.key});

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

    final async = ref.watch(adminPayoutsProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('admin-dashboard'),
        ),
        title: Text('Payouts',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.orange, strokeWidth: 2.5)),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Couldn't load payouts",
                  style: GoogleFonts.inter(fontSize: 13, color: secondary)),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => ref.invalidate(adminPayoutsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rows) {
          // Action needed first: everyone paid, not yet sent to the agent —
          // sorted by kickoff so the most urgent is on top.
          final toPay = rows
              .where((r) => r.allPaid && !r.paidOut)
              .toList();
          final waiting = rows
              .where((r) => !r.allPaid && !r.paidOut)
              .toList();
          final done = rows.where((r) => r.paidOut).toList();

          final owed = toPay.fold<double>(0, (s, r) => s + r.agentPayout);

          return RefreshIndicator(
            color: AppColors.orange,
            onRefresh: () async => ref.invalidate(adminPayoutsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                // Summary: total you owe agents right now
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.pink.withValues(alpha: 0.10),
                      AppColors.orange.withValues(alpha: 0.10),
                    ]),
                    border: Border.all(
                        color: AppColors.orange.withValues(alpha: 0.25)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('To send to agents now',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: secondary)),
                            const SizedBox(height: 4),
                            Text('RM ${owed.toStringAsFixed(2)}',
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.orange)),
                          ],
                        ),
                      ),
                      Text('${toPay.length} game${toPay.length == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: secondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (toPay.isNotEmpty) ...[
                  _sectionTitle('Ready to pay out', primary),
                  ...toPay.map((r) => _PayoutCard(
                      row: r,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      surface: surface,
                      highlight: true)),
                  const SizedBox(height: 16),
                ],

                if (waiting.isNotEmpty) ...[
                  _sectionTitle('Collecting payments', primary),
                  ...waiting.map((r) => _PayoutCard(
                      row: r,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      surface: surface)),
                  const SizedBox(height: 16),
                ],

                if (done.isNotEmpty) ...[
                  _sectionTitle('Paid out', primary),
                  ...done.map((r) => _PayoutCard(
                      row: r,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                      surface: surface)),
                ],

                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text('No games yet',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: secondary)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String label, Color primary) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 16, fontWeight: FontWeight.w700, color: primary)),
      );
}

class _PayoutCard extends ConsumerWidget {
  final PayoutRow row;
  final Color primary, secondary, border, surface;
  final bool highlight;
  const _PayoutCard({
    required this.row,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kickoff = DateFormat('EEE, MMM d · h:mm a').format(row.kickoff);
    return GestureDetector(
      onTap: () => context.pushNamed('admin-payout-detail',
          pathParameters: {'id': row.gameId}),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(
            color: highlight
                ? AppColors.orange.withValues(alpha: 0.4)
                : border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.fieldName,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primary)),
              ),
              _statusChip(),
            ],
          ),
          const SizedBox(height: 4),
          Text('Agent: ${row.agentName}',
              style: GoogleFonts.inter(fontSize: 13, color: secondary)),
          Text(kickoff,
              style: GoogleFonts.inter(fontSize: 12, color: secondary)),
          const SizedBox(height: 12),

          // Payment progress
          Row(
            children: [
              Icon(
                  row.allPaid
                      ? Icons.check_circle
                      : Icons.hourglass_bottom,
                  size: 16,
                  color: row.allPaid
                      ? const Color(0xFF22C55E)
                      : AppColors.orange),
              const SizedBox(width: 6),
              Text('${row.paidCount}/${row.numPlayers} paid',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primary)),
              const Spacer(),
              Text('Collected RM ${row.collected.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(fontSize: 12, color: secondary)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: border),
          const SizedBox(height: 12),

          // The number that matters: what to send the agent
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Send to agent',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: secondary)),
                    const SizedBox(height: 2),
                    Text('RM ${row.agentPayout.toStringAsFixed(2)}',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.orange)),
                    Text('field + commission',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: secondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(row.allPaid ? 'Your cut' : 'Cut when full',
                      style:
                          GoogleFonts.inter(fontSize: 12, color: secondary)),
                  const SizedBox(height: 2),
                  Text('RM ${row.projectedCut.toStringAsFixed(2)}',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF22C55E))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (row.paidOut)
            Row(
              children: [
                const Icon(Icons.verified, size: 16, color: Color(0xFF22C55E)),
                const SizedBox(width: 6),
                Text(
                    row.paidOutAt == null
                        ? 'Paid out'
                        : 'Paid out ${DateFormat('MMM d, h:mm a').format(row.paidOutAt!)}',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF22C55E))),
                const Spacer(),
                TextButton(
                  onPressed: () => _setPaid(context, ref, false),
                  child: Text('Undo',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: secondary)),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: row.allPaid
                      ? const LinearGradient(
                          colors: [AppColors.pink, AppColors.orange])
                      : null,
                  color: row.allPaid ? null : const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  // Only enabled once every player has paid.
                  onPressed:
                      row.allPaid ? () => _chooseMethod(context, ref) : null,
                  child: Text(
                      row.allPaid
                          ? 'Mark as paid out'
                          : 'Waiting for payments',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  Widget _statusChip() {
    final (label, color) = switch (row.status) {
      'live' => ('Live', AppColors.tierElite),
      'completed' => ('Finished', const Color(0xFF22C55E)),
      _ => ('Scheduled', const Color(0xFF3B82F6)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  void _chooseMethod(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How did you pay ${row.agentName}?',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primary)),
              const SizedBox(height: 4),
              Text('RM ${row.agentPayout.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.orange)),
              const SizedBox(height: 16),
              for (final m in const [
                ('TNG eWallet', 'tng'),
                ('DuitNow', 'duitnow'),
                ('Bank transfer', 'bank'),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.$1,
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: primary)),
                  trailing: const Icon(Icons.chevron_right,
                      color: AppColors.orange),
                  onTap: () {
                    Navigator.pop(ctx);
                    _setPaid(context, ref, true, method: m.$2);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setPaid(BuildContext context, WidgetRef ref, bool paid,
      {String? method}) async {
    try {
      await AdminService.markAgentPaidOut(row.gameId,
          paid: paid, method: method);
      ref.invalidate(adminPayoutsProvider);
      if (context.mounted && paid) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: const Color(0xFF22C55E),
            content: Text('${row.agentName} marked as paid out')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update — try again')));
      }
    }
  }
}
