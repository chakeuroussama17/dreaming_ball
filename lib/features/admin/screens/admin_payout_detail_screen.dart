import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';

/// Full payout detail for one game: where to send the agent, who paid,
/// and the match stats.
final payoutDetailProvider =
    FutureProvider.family<PayoutDetail, String>((ref, gameId) {
  // Re-reads when the list is invalidated (e.g. after marking paid out).
  ref.watch(adminPayoutsProvider);
  return AdminService.fetchPayoutDetail(gameId);
});

class AdminPayoutDetailScreen extends ConsumerWidget {
  final String gameId;
  const AdminPayoutDetailScreen({super.key, required this.gameId});

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

    final async = ref.watch(payoutDetailProvider(gameId));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('admin-payouts'),
        ),
        title: Text('Game details',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.orange, strokeWidth: 2.5)),
        error: (_, _) => Center(
          child: Text("Couldn't load this game",
              style: GoogleFonts.inter(fontSize: 13, color: secondary)),
        ),
        data: (d) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // ── Game ─────────────────────────────────────────────────────
            _card(surface, border, [
              Row(
                children: [
                  Expanded(
                    child: Text(d.fieldName,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: primary)),
                  ),
                  _statusChip(d.status),
                ],
              ),
              const SizedBox(height: 8),
              _kv(Icons.place_outlined, d.location, secondary, primary),
              _kv(
                  Icons.schedule,
                  DateFormat('EEE, MMM d · h:mm a').format(d.kickoff),
                  secondary,
                  primary),
              _kv(Icons.sports_soccer, d.format, secondary, primary),
              _kv(Icons.confirmation_number_outlined,
                  'RM ${d.price.toStringAsFixed(2)} per player', secondary,
                  primary),
            ]),
            const SizedBox(height: 16),

            // ── Agent + how to pay them ──────────────────────────────────
            Text('Pay the agent',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: primary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.pink.withValues(alpha: 0.08),
                  AppColors.orange.withValues(alpha: 0.08),
                ]),
                border:
                    Border.all(color: AppColors.orange.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.agentName,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: primary)),
                  if (d.agentPhone != null && d.agentPhone!.isNotEmpty)
                    _kv(Icons.phone_outlined, d.agentPhone!, secondary, primary),
                  const SizedBox(height: 10),
                  // Bank details — copy-tap each so you can paste into your
                  // banking / DuitNow app.
                  _copyRow('Bank', d.bankName ?? '— not provided —', context,
                      secondary, primary),
                  _copyRow('Account', d.accountNumber ?? '—', context,
                      secondary, primary),
                  _copyRow('Holder', d.accountHolder ?? '—', context, secondary,
                      primary),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Amount to send',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: secondary)),
                            Text('RM ${d.agentPayout.toStringAsFixed(2)}',
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.orange)),
                            Text(
                                'field RM ${d.fieldCost.toStringAsFixed(2)} + commission RM ${d.commission.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: secondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (d.paidOut)
                    Row(children: [
                      const Icon(Icons.verified,
                          size: 18, color: Color(0xFF22C55E)),
                      const SizedBox(width: 6),
                      Text('Paid out',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF22C55E))),
                    ])
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: d.allPaid
                              ? const LinearGradient(
                                  colors: [AppColors.pink, AppColors.orange])
                              : null,
                          color: d.allPaid ? null : const Color(0xFF444444),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: d.allPaid
                              ? () => _markPaid(context, ref)
                              : null,
                          child: Text(
                              d.allPaid
                                  ? 'Mark as paid out'
                                  : 'Wait — ${d.paidCount}/${d.numPlayers} players paid',
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
            const SizedBox(height: 20),

            // ── Players: who paid + stats ────────────────────────────────
            Row(
              children: [
                Text('Players',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primary)),
                const Spacer(),
                Text(
                    '${d.paidCount}/${d.numPlayers} paid · RM ${d.collected.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontSize: 12, color: secondary)),
              ],
            ),
            const SizedBox(height: 10),
            if (d.players.isEmpty)
              Text('No players have joined yet.',
                  style: GoogleFonts.inter(fontSize: 13, color: secondary))
            else
              ...d.players.map((p) => _playerRow(p, primary, secondary,
                  border, surface, d.status == 'completed')),
          ],
        ),
      ),
    );
  }

  Widget _card(Color surface, Color border, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _kv(IconData icon, String text, Color secondary, Color primary) =>
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 15, color: secondary),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text,
                    style: GoogleFonts.inter(fontSize: 13, color: primary))),
          ],
        ),
      );

  Widget _copyRow(String label, String value, BuildContext context,
      Color secondary, Color primary) {
    final copyable = value.isNotEmpty && !value.startsWith('—');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 70,
              child: Text(label,
                  style: GoogleFonts.inter(fontSize: 12, color: secondary))),
          Expanded(
            child: Text(value,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primary)),
          ),
          if (copyable)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copied')));
              },
              child: Icon(Icons.copy, size: 16, color: AppColors.orange),
            ),
        ],
      ),
    );
  }

  Widget _playerRow(PayoutPlayer p, Color primary, Color secondary,
      Color border, Color surface, bool showStats) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: primary)),
                if (showStats)
                  Text(
                      '${p.goals} goals · ${p.assists} assists'
                      '${p.statStatus == 'confirmed' ? ' · +${p.xp} XP' : p.statStatus == 'pending' ? ' · pending' : ''}',
                      style:
                          GoogleFonts.inter(fontSize: 12, color: secondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (p.paid ? const Color(0xFF22C55E) : AppColors.orange)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(p.paid ? 'Paid' : 'Unpaid',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: p.paid
                        ? const Color(0xFF22C55E)
                        : AppColors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
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

  void _markPaid(BuildContext context, WidgetRef ref) {
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
              Text('How did you pay the agent?',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primary)),
              const SizedBox(height: 12),
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
                  trailing:
                      const Icon(Icons.chevron_right, color: AppColors.orange),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      await AdminService.markAgentPaidOut(gameId,
                          paid: true, method: m.$2);
                      ref.invalidate(adminPayoutsProvider);
                      ref.invalidate(payoutDetailProvider(gameId));
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Could not update — try again')));
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
