import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';
import '../../../../core/widgets/player_avatar.dart';

class AdminDisputesScreen extends ConsumerStatefulWidget {
  const AdminDisputesScreen({super.key});

  @override
  ConsumerState<AdminDisputesScreen> createState() =>
      _AdminDisputesScreenState();
}

class _AdminDisputesScreenState extends ConsumerState<AdminDisputesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final all = ref.watch(adminDisputesProvider);
    final open = all.where((d) => d.status == AdminDisputeStatus.open).toList();
    final resolved =
        all.where((d) => d.status == AdminDisputeStatus.resolved).toList();
    final escalated =
        all.where((d) => d.status == AdminDisputeStatus.escalated).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('admin-dashboard'),
        ),
        title: Text('Disputes',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.gold,
          labelColor: primary,
          unselectedLabelColor: secondary,
          labelStyle:
              GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: 'Open (${open.length})'),
            Tab(text: 'Resolved (${resolved.length})'),
            Tab(text: 'Escalated (${escalated.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _list(open, primary, secondary, isDark, actionable: true),
          _list(resolved, primary, secondary, isDark),
          _list(escalated, primary, secondary, isDark),
        ],
      ),
    );
  }

  Widget _list(List<AdminDispute> items, Color primary, Color secondary,
      bool isDark,
      {bool actionable = false}) {
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 48,
                color: AppColors.success.withValues(alpha: 0.8)),
            const SizedBox(height: 10),
            Text('No disputes — all good!',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: items.length,
      itemBuilder: (ctx, i) =>
          _card(items[i], primary, secondary, border, surface, actionable),
    );
  }

  Widget _card(AdminDispute d, Color primary, Color secondary, Color border,
      Color surface, bool actionable) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${d.game} · ${d.date}',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primary)),
              ),
              _statusPill(d.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PlayerAvatar(fallbackInitials: d.player.substring(0, 1), radius: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${d.player}  vs  Agent ${d.agent}',
                    style: GoogleFonts.inter(fontSize: 13, color: secondary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${d.statType}: record ${d.recorded} · claim ${d.claimed}',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
          const SizedBox(height: 4),
          Text('"${d.reason}"',
              style: GoogleFonts.inter(
                  fontSize: 13, fontStyle: FontStyle.italic, color: secondary)),
          const SizedBox(height: 12),
          if (actionable)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.goldActionStart, AppColors.goldActionEnd]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () =>
                      _reviewSheet(d, primary, secondary, border, surface),
                  child: Text('Review',
                      style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusPill(AdminDisputeStatus s) {
    late final Color c;
    late final String label;
    switch (s) {
      case AdminDisputeStatus.open:
        c = AppColors.warning;
        label = 'Open';
      case AdminDisputeStatus.resolved:
        c = AppColors.success;
        label = 'Resolved';
      case AdminDisputeStatus.escalated:
        c = AppColors.tierElite;
        label = 'Escalated';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        border: Border.all(color: c.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: c)),
    );
  }

  void _reviewSheet(AdminDispute d, Color primary, Color secondary,
      Color border, Color surface) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review Dispute',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: primary)),
            const SizedBox(height: 12),
            _row('Game', '${d.game} · ${d.date}', secondary, primary),
            _row('Player', d.player, secondary, primary),
            _row('Agent', d.agent, secondary, primary),
            _row('Stat', d.statType, secondary, primary),
            _row('Agent record', '${d.recorded}', secondary, primary),
            _row('Player claim', '${d.claimed}', secondary, AppColors.gold),
            const SizedBox(height: 8),
            Text('Reason: "${d.reason}"',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: secondary)),
            const SizedBox(height: 18),
            _action('Accept Player Claim', AppColors.success, () {
              ref.read(adminDisputesProvider.notifier).acceptPlayer(d.id);
              Navigator.pop(ctx);
              _snack('Player claim accepted');
            }),
            const SizedBox(height: 10),
            _action('Keep Agent Record', AppColors.gold, () {
              ref.read(adminDisputesProvider.notifier).keepAgent(d.id);
              Navigator.pop(ctx);
              _snack('Agent record kept');
            }),
            const SizedBox(height: 10),
            _action('Escalate', secondary, () {
              ref.read(adminDisputesProvider.notifier).escalate(d.id);
              Navigator.pop(ctx);
              _snack('Marked for manual review');
            }, outlined: true, border: border),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v, Color secondary, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text(k,
                  style: GoogleFonts.inter(fontSize: 13, color: secondary))),
          Expanded(
            child: Text(v,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor)),
          ),
        ],
      ),
    );
  }

  Widget _action(String label, Color color, VoidCallback onTap,
      {bool outlined = false, Color? border}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: outlined
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: border ?? color),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onTap,
              child: Text(label,
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700, color: color)),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onTap,
              child: Text(label,
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700, color: color)),
            ),
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)));
}
