import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/content_providers.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/dispute_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';
import '../../../../core/widgets/player_avatar.dart';

class DisputeScreen extends ConsumerStatefulWidget {
  final String id;
  const DisputeScreen({super.key, required this.id});

  @override
  ConsumerState<DisputeScreen> createState() => _DisputeScreenState();
}

class _DisputeScreenState extends ConsumerState<DisputeScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Re-tick once a minute so the dispute-window countdowns stay current.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    // Agents review disputes; players review their own pending stats.
    final isAgent = ref.watch(userRoleProvider) == UserRole.agent;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop(),
        ),
        title: Text(isAgent ? 'Review Disputes' : 'Your Stats',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: isAgent ? _agentBody(isDark) : _playerBody(isDark),
    );
  }

  // ── PLAYER VIEW ───────────────────────────────────────────────────────────
  Widget _playerBody(bool isDark) {
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final async = ref.watch(myPendingStatsProvider);
    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.orange, strokeWidth: 2.5)),
      error: (_, _) => _errorRetry(secondary, myPendingStatsProvider),
      data: (stats) {
        if (stats.isEmpty) {
          return _emptyState(
            Icons.check_circle_outline,
            'Nothing to review',
            'Stats you can dispute appear here for 3 hours after a match.',
            primary,
            secondary,
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            for (final s in stats)
              _PendingStatCard(
                key: ValueKey(s.statId),
                stat: s,
                primary: primary,
                secondary: secondary,
                border: border,
                surface: surface,
                onSubmitted: () => ref.invalidate(myPendingStatsProvider),
              ),
          ],
        );
      },
    );
  }

  // ── AGENT VIEW ────────────────────────────────────────────────────────────
  Widget _agentBody(bool isDark) {
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final async = ref.watch(agentDisputesProvider);
    return async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.orange, strokeWidth: 2.5)),
      error: (_, _) => _errorRetry(secondary, agentDisputesProvider),
      data: (disputes) {
        if (disputes.isEmpty) {
          return _emptyState(
            Icons.check_circle_outline,
            'No disputes — all good!',
            'When a player contests a stat from one of your games, it shows up here.',
            primary,
            secondary,
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            for (final d in disputes)
              _disputeCard(d, primary, secondary, border, surface),
          ],
        );
      },
    );
  }

  Widget _disputeCard(Dispute d, Color primary, Color secondary, Color border,
      Color surface) {
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
              PlayerAvatar(
                  fallbackInitials: d.playerName.substring(0, 1), radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${d.playerName} — ${_statLabel(d.statType)}',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primary)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(d.fieldName,
              style: GoogleFonts.inter(fontSize: 12, color: secondary)),
          const SizedBox(height: 10),
          Text('Recorded: ${d.recordedValue}  ·  Claim: ${d.claimedValue}',
              style: GoogleFonts.inter(fontSize: 13, color: secondary)),
          const SizedBox(height: 4),
          Text('Reason: "${d.reason}"',
              style: GoogleFonts.inter(
                  fontSize: 13, fontStyle: FontStyle.italic, color: secondary)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF22C55E).withValues(alpha: 0.15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _resolve(d, accept: true),
                    icon: const Icon(Icons.check,
                        size: 16, color: Color(0xFF22C55E)),
                    label: Text('Accept',
                        style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF22C55E))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.tierElite.withValues(alpha: 0.15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _resolve(d, accept: false),
                    icon: const Icon(Icons.close,
                        size: 16, color: AppColors.tierElite),
                    label: Text('Reject',
                        style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            color: AppColors.tierElite)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resolve(Dispute d, {required bool accept}) async {
    try {
      await DisputeService.resolveDispute(disputeId: d.id, accept: accept);
      if (!mounted) return;
      ref.invalidate(agentDisputesProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(accept
              ? 'Accepted — stat updated to ${d.claimedValue}'
              : 'Rejected — your record stands')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not resolve — check your connection')));
      }
    }
  }

  // ── Shared bits ───────────────────────────────────────────────────────────
  Widget _emptyState(IconData icon, String title, String body, Color primary,
      Color secondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 56, color: const Color(0xFF22C55E).withValues(alpha: 0.8)),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 16, fontWeight: FontWeight.w700, color: primary)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, height: 1.5, color: secondary)),
          ],
        ).animate().fadeIn(duration: 350.ms),
      ),
    );
  }

  Widget _errorRetry(Color secondary, ProviderBase provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Couldn't load — check your connection",
              style: GoogleFonts.inter(fontSize: 13, color: secondary)),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => ref.invalidate(provider),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.orange),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Retry',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700, color: AppColors.orange)),
          ),
        ],
      ),
    );
  }

  static String _statLabel(String statType) => switch (statType) {
        'goals' => 'Goals',
        'assists' => 'Assists',
        'goals_conceded' => 'Goals Conceded',
        'good_behavior' => 'Good Behavior',
        _ => statType,
      };
}

// ── Player's pending-stat card with per-stat dispute panels ───────────────────

class _PendingStatCard extends StatefulWidget {
  final PendingStat stat;
  final Color primary, secondary, border, surface;
  final VoidCallback onSubmitted;
  const _PendingStatCard({
    super.key,
    required this.stat,
    required this.primary,
    required this.secondary,
    required this.border,
    required this.surface,
    required this.onSubmitted,
  });

  @override
  State<_PendingStatCard> createState() => _PendingStatCardState();
}

class _PendingStatCardState extends State<_PendingStatCard> {
  String? _expanded; // which stat type's dispute panel is open
  final _claim = <String, int>{};
  final _disputed = <String>{}; // stat types already submitted
  final _reason = TextEditingController();
  bool _submitting = false;

  late final List<(String type, String icon, String label, int value)> _lines =
      [
    ('goals', '⚽', 'Goals', widget.stat.goals),
    ('assists', '🎯', 'Assists', widget.stat.assists),
    ('goals_conceded', '🥅', 'Goals Conceded', widget.stat.goalsConceded),
    ('good_behavior', widget.stat.goodBehavior == 1 ? '👍' : '👎',
        'Good Behavior', widget.stat.goodBehavior),
  ];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String get _countdown {
    final r = widget.stat.disputeDeadline.difference(DateTime.now());
    if (r.isNegative) return 'closed';
    return '${r.inHours}h ${r.inMinutes % 60}m';
  }

  Future<void> _submit(String statType) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await DisputeService.raiseDispute(
        statId: widget.stat.statId,
        statType: statType,
        claimedValue: _claim[statType] ?? 0,
        reason: _reason.text.trim().isEmpty
            ? 'No reason given'
            : _reason.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _disputed.add(statType);
        _expanded = null;
        _reason.clear();
        _submitting = false;
      });
      widget.onSubmitted();
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not submit dispute — try again')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.primary, s = widget.secondary, b = widget.border;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: widget.surface,
        border: Border.all(color: b),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(widget.stat.fieldName,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: p)),
                ),
                Text('Closes in $_countdown',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.orange)),
              ],
            ),
          ),
          Divider(height: 1, color: b),
          for (final line in _lines) _statLine(line, p, s, b),
        ],
      ),
    );
  }

  Widget _statLine((String, String, String, int) line, Color p, Color s,
      Color b) {
    final (type, icon, label, value) = line;
    final done = _disputed.contains(type);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p)),
              ),
              Text('$value',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 18, fontWeight: FontWeight.w800, color: p)),
              const SizedBox(width: 12),
              if (done)
                _pill('Submitted', const Color(0xFFFBBF24))
              else
                GestureDetector(
                  onTap: () => setState(() {
                    if (_expanded == type) {
                      _expanded = null;
                    } else {
                      _expanded = type;
                      _claim[type] = value;
                    }
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.tierElite.withValues(alpha: 0.6)),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('Dispute',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tierElite)),
                  ),
                ),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _expanded == type
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: _disputePanel(type, p, s, b),
        ),
      ],
    );
  }

  Widget _disputePanel(String type, Color p, Color s, Color b) {
    final claim = _claim[type] ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: b),
          Text('What should the correct value be?',
              style: GoogleFonts.inter(fontSize: 13, color: s)),
          const SizedBox(height: 10),
          Row(
            children: [
              _miniBtn(Icons.remove, claim > 0,
                  () => setState(() => _claim[type] = claim > 0 ? claim - 1 : 0)),
              SizedBox(
                width: 44,
                child: Text('$claim',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 20, fontWeight: FontWeight.w800, color: p)),
              ),
              _miniBtn(Icons.add, true,
                  () => setState(() => _claim[type] = claim + 1)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 200,
            maxLines: 2,
            style: GoogleFonts.inter(fontSize: 13, color: p),
            decoration: InputDecoration(
              hintText: 'Reason (optional)',
              hintStyle: GoogleFonts.inter(fontSize: 13, color: s),
              counterStyle: GoogleFonts.inter(fontSize: 10, color: s),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: b),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.orange),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.tierElite, AppColors.pink]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submitting ? null : () => _submit(type),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white))
                          : Text('Submit Dispute',
                              style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => setState(() => _expanded = null),
                child: Text('Cancel',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: s)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(99)),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: c)),
      );

  Widget _miniBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? const LinearGradient(colors: [AppColors.pink, AppColors.orange])
              : null,
          color: enabled ? null : const Color(0xFF444444),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
