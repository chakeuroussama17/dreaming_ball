import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/tournament_providers.dart';
import '../../../core/services/tournament_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav.dart';
import '../../../core/widgets/player_avatar.dart';
import '../widgets/status_chip.dart';

class TournamentDetailScreen extends ConsumerWidget {
  final String id;
  const TournamentDetailScreen({super.key, required this.id});

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

    final async = ref.watch(tournamentProvider(id));
    final teamsAsync = ref.watch(tournamentTeamsProvider(id));
    final matchesAsync = ref.watch(tournamentMatchesProvider(id));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('tournaments'),
        ),
        title: Text('Tournament',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
        actions: [
          if (async.valueOrNull?.mine == true)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: primary),
              onSelected: (v) {
                final t = async.valueOrNull;
                if (t == null) return;
                if (v == 'edit') _editDetails(context, ref, t);
                if (v == 'delete') _deleteTournament(context, ref, t);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit details')),
                PopupMenuItem(value: 'delete', child: Text('Delete tournament')),
              ],
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.orange)),
        error: (_, _) => Center(
            child: Text('Could not load',
                style: GoogleFonts.inter(color: secondary))),
        data: (t) {
          if (t == null) {
            return Center(
                child: Text('Tournament not found',
                    style: GoogleFonts.inter(color: secondary)));
          }
          final teams = teamsAsync.valueOrNull ?? const <TournamentTeam>[];
          final matches =
              matchesAsync.valueOrNull ?? const <TournamentMatch>[];
          return RefreshIndicator(
            color: AppColors.orange,
            onRefresh: () async {
              ref.invalidate(tournamentProvider(id));
              ref.invalidate(tournamentTeamsProvider(id));
              ref.invalidate(tournamentMatchesProvider(id));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                // Banner + title
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: t.bannerImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: t.bannerImageUrl!, fit: BoxFit.cover)
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                AppColors.pink.withValues(alpha: 0.25),
                                AppColors.orange.withValues(alpha: 0.25),
                              ]),
                            ),
                            child: const Center(
                                child: Icon(Icons.emoji_events,
                                    size: 50, color: Colors.white70)),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(t.name,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: primary)),
                    ),
                    TournamentStatusChip(t.status),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  _pill(t.gameFormat, secondary, border),
                  const SizedBox(width: 6),
                  _pill(t.isKnockout ? 'Knockout' : 'Group Stage', secondary,
                      border),
                  const SizedBox(width: 6),
                  _pill('${t.numTeams} teams', secondary, border),
                ]),
                if ((t.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(t.description!,
                      style: GoogleFonts.inter(
                          fontSize: 14, height: 1.5, color: secondary)),
                ],
                const SizedBox(height: 16),

                // Action area (status + role aware)
                _actions(context, ref, t, teams, matches, primary, secondary,
                    border, surface),

                // Match schedule (once bracket exists)
                if (matches.isNotEmpty &&
                    (t.status == 'in_progress' ||
                        t.status == 'completed')) ...[
                  const SizedBox(height: 24),
                  _sectionTitle('Matches', primary),
                  const SizedBox(height: 8),
                  ..._scheduledMatches(context, t, matches, teams, primary,
                      secondary, border, surface),
                ],

                // Teams (read-only, expandable rosters)
                const SizedBox(height: 24),
                _sectionTitle('Teams (${teams.length})', primary),
                const SizedBox(height: 8),
                if (teams.isEmpty)
                  Text('No teams yet.',
                      style: GoogleFonts.inter(fontSize: 13, color: secondary))
                else
                  ...teams.map((tm) =>
                      _teamTile(tm, primary, secondary, border, surface)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Action area ─────────────────────────────────────────────────────────
  Widget _actions(
      BuildContext context,
      WidgetRef ref,
      Tournament t,
      List<TournamentTeam> teams,
      List<TournamentMatch> matches,
      Color primary,
      Color secondary,
      Color border,
      Color surface) {
    final owner = t.mine;

    if (t.status == 'rejected') {
      return _infoBox(
          'This tournament was rejected.'
          '${(t.rejectionReason ?? '').isEmpty ? '' : '\nReason: ${t.rejectionReason}'}',
          AppColors.tierElite);
    }
    if (t.status == 'pending_approval') {
      return _infoBox('Waiting for admin approval.', const Color(0xFFFBBF24));
    }

    if ((t.status == 'approved' || t.status == 'building_teams') && owner) {
      final ready = teams.length == t.numTeams;
      return Column(
        children: [
          _infoBox('${teams.length} / ${t.numTeams} teams created.',
              const Color(0xFF3B82F6)),
          const SizedBox(height: 10),
          _gradientBtn(
              teams.isEmpty ? 'Build Your Teams' : 'Continue Building Teams',
              () async {
            await context.pushNamed('tournament-build-teams',
                pathParameters: {'id': t.id});
            ref.invalidate(tournamentProvider(t.id));
            ref.invalidate(tournamentTeamsProvider(t.id));
          }),
          if (ready) ...[
            const SizedBox(height: 10),
            _outlineBtn('Generate Bracket', () => _generate(context, ref, t)),
          ],
        ],
      );
    }

    if (t.status == 'bracket_generated') {
      return Column(
        children: [
          _gradientBtn('View Full Bracket', () {
            context.pushNamed('tournament-bracket', pathParameters: {'id': t.id});
          }),
          if (owner) ...[
            const SizedBox(height: 10),
            _outlineBtn('Schedule Matches', () async {
              await context.pushNamed('tournament-schedule',
                  pathParameters: {'id': t.id});
              ref.invalidate(tournamentProvider(t.id));
              ref.invalidate(tournamentMatchesProvider(t.id));
            }),
          ],
        ],
      );
    }

    if (t.status == 'in_progress') {
      return _gradientBtn('View Live Bracket', () {
        context.pushNamed('tournament-bracket', pathParameters: {'id': t.id});
      });
    }

    if (t.status == 'completed') {
      final champ = _champion(matches, teams);
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.pink.withValues(alpha: 0.15),
                AppColors.orange.withValues(alpha: 0.15),
              ]),
              border:
                  Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events,
                    size: 44, color: Color(0xFFFFD700)),
                const SizedBox(height: 8),
                Text('Champion',
                    style:
                        GoogleFonts.inter(fontSize: 12, color: secondary)),
                Text(champ ?? '—',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: primary)),
              ],
            ),
          ).animate().scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.easeOut),
          const SizedBox(height: 10),
          _outlineBtn('View Bracket', () {
            context.pushNamed('tournament-bracket', pathParameters: {'id': t.id});
          }),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  String? _champion(List<TournamentMatch> matches, List<TournamentTeam> teams) {
    final finals = matches.where((m) =>
        m.nextMatchId == null &&
        m.status == 'completed' &&
        m.winnerTeamId != null &&
        !m.isGroup);
    if (finals.isEmpty) return null;
    final winId = finals.last.winnerTeamId;
    for (final t in teams) {
      if (t.id == winId) return t.name;
    }
    return null;
  }

  // ── Scheduled matches list ──────────────────────────────────────────────
  List<Widget> _scheduledMatches(
      BuildContext context,
      Tournament t,
      List<TournamentMatch> matches,
      List<TournamentTeam> teams,
      Color primary,
      Color secondary,
      Color border,
      Color surface) {
    final scheduled = matches.where((m) => m.bothTeamsSet).toList()
      ..sort((a, b) => (a.scheduledAt ?? DateTime(2100))
          .compareTo(b.scheduledAt ?? DateTime(2100)));
    return [
      for (final m in scheduled)
        GestureDetector(
          onTap: () => context.pushNamed('tournament-match',
              pathParameters: {'id': m.id}),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(
                  color: m.status == 'live'
                      ? AppColors.tierElite.withValues(alpha: 0.5)
                      : border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.roundName,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: secondary)),
                      const SizedBox(height: 4),
                      Text(
                          '${m.teamAName ?? 'TBD'}  vs  ${m.teamBName ?? 'TBD'}',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: primary)),
                      const SizedBox(height: 2),
                      Text(
                          m.scheduledAt == null
                              ? 'Unscheduled'
                              : DateFormat('EEE, MMM d · h:mm a')
                                  .format(m.scheduledAt!),
                          style: GoogleFonts.inter(
                              fontSize: 12, color: secondary)),
                    ],
                  ),
                ),
                if (m.status == 'live')
                  const TournamentStatusChip('in_progress')
                else if (m.status == 'completed')
                  Text('${m.teamAScore ?? 0} - ${m.teamBScore ?? 0}',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primary))
                else
                  Icon(Icons.chevron_right, color: secondary),
              ],
            ),
          ),
        ),
    ];
  }

  // ── Team tile (expandable roster) ───────────────────────────────────────
  Widget _teamTile(TournamentTeam tm, Color primary, Color secondary,
      Color border, Color surface) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          leading: _logo(tm.logoUrl, tm.name),
          title: Text(tm.name,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 15, fontWeight: FontWeight.w700, color: primary)),
          subtitle: Text('${tm.players.length} players',
              style: GoogleFonts.inter(fontSize: 12, color: secondary)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final p in tm.players)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    PlayerAvatar(
                        imageUrl: p.avatarUrl,
                        fallbackInitials: p.name.substring(0, 1),
                        radius: 14),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(p.name,
                          style: GoogleFonts.inter(
                              fontSize: 13, color: primary)),
                    ),
                    if ((p.position ?? '').isNotEmpty)
                      Text(p.position!,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: secondary)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _logo(String? url, String name) {
    if (url != null) {
      return CircleAvatar(radius: 18, backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.orange.withValues(alpha: 0.18),
      child: Text(name.isEmpty ? '?' : name.substring(0, 1),
          style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w800, color: AppColors.orange)),
    );
  }

  Future<void> _generate(
      BuildContext context, WidgetRef ref, Tournament t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate bracket?'),
        content: const Text(
            'Once generated, teams cannot be changed. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generate')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await TournamentService.generateBracket(t);
      ref.invalidate(tournamentProvider(t.id));
      ref.invalidate(tournamentMatchesProvider(t.id));
      if (context.mounted) {
        context.pushNamed('tournament-bracket', pathParameters: {'id': t.id});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _editDetails(
      BuildContext context, WidgetRef ref, Tournament t) async {
    final nameCtrl = TextEditingController(text: t.name);
    final descCtrl = TextEditingController(text: t.description ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(
                controller: descCtrl,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await TournamentService.updateTournament(t.id,
        name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
        description:
            descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim());
    ref.invalidate(tournamentProvider(t.id));
  }

  Future<void> _deleteTournament(
      BuildContext context, WidgetRef ref, Tournament t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tournament?'),
        content: const Text(
            'This permanently removes the tournament, its teams and matches. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.tierElite))),
        ],
      ),
    );
    if (ok != true) return;
    await TournamentService.deleteTournament(t.id);
    ref.invalidate(tournamentsProvider);
    if (context.mounted) context.safePop('tournaments');
  }

  // ── small builders ──────────────────────────────────────────────────────
  Widget _sectionTitle(String t, Color primary) => Text(t,
      style: GoogleFonts.spaceGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700, color: primary));

  Widget _pill(String label, Color secondary, Color border) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: secondary)),
      );

  Widget _infoBox(String text, Color color) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: color)),
      );

  Widget _gradientBtn(String label, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient:
                const LinearGradient(colors: [AppColors.pink, AppColors.orange]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onTap,
            child: Text(label,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
      );

  Widget _outlineBtn(String label, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.orange),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onTap,
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange)),
        ),
      );
}
