import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/tournament_providers.dart';
import '../../../core/services/tournament_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav.dart';

class BracketViewScreen extends ConsumerWidget {
  final String id;
  const BracketViewScreen({super.key, required this.id});

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

    final tAsync = ref.watch(tournamentProvider(id));
    final matchesAsync = ref.watch(tournamentMatchesProvider(id));
    final shot = ScreenshotController();

    final t = tAsync.valueOrNull;
    final matches = matchesAsync.valueOrNull ?? const <TournamentMatch>[];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('tournaments'),
        ),
        title: Text('Bracket',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Share bracket',
            icon: Icon(Icons.ios_share, color: primary),
            onPressed: () => _share(context, shot),
          ),
        ],
      ),
      body: t == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orange))
          : RefreshIndicator(
              color: AppColors.orange,
              onRefresh: () async => ref.invalidate(tournamentMatchesProvider(id)),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Screenshot(
                  controller: shot,
                  child: Container(
                    color: bg,
                    padding: const EdgeInsets.all(16),
                    child: t.isKnockout
                        ? _knockout(context, matches, primary, secondary,
                            border, surface)
                        : _groups(context, matches, primary, secondary, border,
                            surface),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: t == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _share(context, shot),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.orange),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.download, color: AppColors.orange),
                    label: Text('Download / Share Bracket',
                        style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            color: AppColors.orange)),
                  ),
                ),
              ),
            ),
    );
  }

  // ── Knockout tree (rounds as columns) ───────────────────────────────────
  Widget _knockout(BuildContext context, List<TournamentMatch> matches,
      Color primary, Color secondary, Color border, Color surface) {
    final ko = matches.where((m) => !m.isGroup).toList();
    if (ko.isEmpty) {
      return _emptyNote('Bracket will appear here.', secondary);
    }
    final orders = ko.map((m) => m.roundOrder).toSet().toList()..sort();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final order in orders) ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    ko.firstWhere((m) => m.roundOrder == order).roundName,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: secondary),
                  ),
                ),
                for (final m in ko.where((m) => m.roundOrder == order))
                  _matchBox(context, m, primary, secondary, border, surface),
              ],
            ),
            if (order != orders.last)
              Icon(Icons.chevron_right, color: secondary.withValues(alpha: 0.5)),
          ],
        ],
      ),
    );
  }

  Widget _matchBox(BuildContext context, TournamentMatch m, Color primary,
      Color secondary, Color border, Color surface) {
    Widget row(String? name, int? score, bool winner) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(
                child: Text(name ?? 'TBD',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: winner ? FontWeight.w800 : FontWeight.w500,
                        color: name == null
                            ? secondary
                            : (winner ? AppColors.orange : primary))),
              ),
              const SizedBox(width: 6),
              Text(score?.toString() ?? '–',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: winner ? AppColors.orange : secondary)),
            ],
          ),
        );

    final aWin = m.winnerTeamId != null && m.winnerTeamId == m.teamAId;
    final bWin = m.winnerTeamId != null && m.winnerTeamId == m.teamBId;

    return GestureDetector(
      onTap: m.bothTeamsSet
          ? () => context.pushNamed('tournament-match',
              pathParameters: {'id': m.id})
          : null,
      child: Container(
        width: 180,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(
              color: m.status == 'live'
                  ? AppColors.tierElite.withValues(alpha: 0.6)
                  : border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            row(m.teamAName, m.teamAScore, aWin),
            Divider(height: 6, color: border),
            row(m.teamBName, m.teamBScore, bWin),
            if (m.status == 'live')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('LIVE',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.tierElite)),
              ),
          ],
        ),
      ),
    );
  }

  // ── Group tables ─────────────────────────────────────────────────────────
  Widget _groups(BuildContext context, List<TournamentMatch> matches,
      Color primary, Color secondary, Color border, Color surface) {
    final groupMatches = matches.where((m) => m.isGroup).toList();
    if (groupMatches.isEmpty) {
      return _emptyNote('Groups will appear here.', secondary);
    }
    final groupNames = groupMatches.map((m) => m.groupName!).toSet().toList()
      ..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in groupNames) ...[
          _groupTable(g, groupMatches.where((m) => m.groupName == g).toList(),
              primary, secondary, border, surface),
          const SizedBox(height: 18),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Knockout stage unlocks once the group matches are complete — top 2 of each group advance.',
            style: GoogleFonts.inter(
                fontSize: 12, height: 1.4, color: AppColors.orange),
          ),
        ),
      ],
    );
  }

  Widget _groupTable(String groupName, List<TournamentMatch> ms, Color primary,
      Color secondary, Color border, Color surface) {
    // Build standings from completed matches.
    final stats = <String, _Standing>{};
    final names = <String, String>{};
    void ensure(String? id, String? name) {
      if (id == null) return;
      stats.putIfAbsent(id, () => _Standing());
      if (name != null) names[id] = name;
    }

    for (final m in ms) {
      ensure(m.teamAId, m.teamAName);
      ensure(m.teamBId, m.teamBName);
      if (m.status == 'completed' &&
          m.teamAId != null &&
          m.teamBId != null &&
          m.teamAScore != null &&
          m.teamBScore != null) {
        final a = stats[m.teamAId]!, b = stats[m.teamBId]!;
        a.p++;
        b.p++;
        a.gf += m.teamAScore!;
        a.ga += m.teamBScore!;
        b.gf += m.teamBScore!;
        b.ga += m.teamAScore!;
        if (m.teamAScore! > m.teamBScore!) {
          a.w++;
          b.l++;
        } else if (m.teamAScore! < m.teamBScore!) {
          b.w++;
          a.l++;
        } else {
          a.d++;
          b.d++;
        }
      }
    }
    final rows = stats.entries.toList()
      ..sort((x, y) {
        final byPts = y.value.pts.compareTo(x.value.pts);
        if (byPts != 0) return byPts;
        return y.value.gd.compareTo(x.value.gd);
      });

    Widget cell(String t, {bool head = false, bool flexName = false}) {
      final w = Text(t,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: head ? FontWeight.w700 : FontWeight.w500,
              color: head ? secondary : primary));
      return flexName
          ? Expanded(child: w)
          : SizedBox(width: 26, child: Center(child: w));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Group $groupName',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w800, color: primary)),
          const SizedBox(height: 8),
          Row(children: [
            cell('Team', head: true, flexName: true),
            cell('P', head: true),
            cell('W', head: true),
            cell('D', head: true),
            cell('L', head: true),
            cell('GD', head: true),
            cell('Pts', head: true),
          ]),
          const Divider(height: 12),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                cell('${i + 1}. ${names[rows[i].key] ?? 'Team'}',
                    flexName: true),
                cell('${rows[i].value.p}'),
                cell('${rows[i].value.w}'),
                cell('${rows[i].value.d}'),
                cell('${rows[i].value.l}'),
                cell('${rows[i].value.gd}'),
                cell('${rows[i].value.pts}'),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _emptyNote(String t, Color secondary) => Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
            child: Text(t,
                style: GoogleFonts.inter(fontSize: 14, color: secondary))),
      );

  Future<void> _share(BuildContext context, ScreenshotController shot) async {
    try {
      final Uint8List? bytes = await shot.capture();
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = await File('${dir.path}/bracket.png').writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Tournament bracket');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not export bracket')));
      }
    }
  }
}

class _Standing {
  int p = 0, w = 0, d = 0, l = 0, gf = 0, ga = 0;
  int get gd => gf - ga;
  int get pts => w * 3 + d;
}
