import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/tournament_providers.dart';
import '../../../core/services/game_service.dart' show GameServiceException;
import '../../../core/services/tournament_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav.dart';
import '../../../core/widgets/player_avatar.dart';

class BuildTeamsScreen extends ConsumerWidget {
  final String id;
  const BuildTeamsScreen({super.key, required this.id});

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
    final teamsAsync = ref.watch(tournamentTeamsProvider(id));

    final t = tAsync.valueOrNull;
    final teams = teamsAsync.valueOrNull ?? const <TournamentTeam>[];
    final numTeams = t?.numTeams ?? 0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('tournaments'),
        ),
        title: Text('Build Teams (${teams.length}/$numTeams)',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: t == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.orange))
          : Column(
              children: [
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: const EdgeInsets.all(20),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.92,
                    children: [
                      for (final tm in teams)
                        _filledSlot(context, ref, t, tm, primary, secondary,
                            border, surface),
                      if (teams.length < numTeams)
                        _emptySlot(context, ref, t, primary, secondary, border),
                    ],
                  ),
                ),
                if (teams.length == numTeams)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: _gradientBtn(
                          'Generate Bracket ($numTeams/$numTeams ready)',
                          () => _generate(context, ref, t)),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _emptySlot(BuildContext context, WidgetRef ref, Tournament t,
      Color primary, Color secondary, Color border) {
    return GestureDetector(
      onTap: () => _openBuilder(context, ref, t),
      child: DottedLikeBox(
        border: secondary.withValues(alpha: 0.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 34, color: secondary),
            const SizedBox(height: 6),
            Text('Add Team',
                style: GoogleFonts.inter(fontSize: 13, color: secondary)),
          ],
        ),
      ),
    );
  }

  Widget _filledSlot(BuildContext context, WidgetRef ref, Tournament t,
      TournamentTeam tm, Color primary, Color secondary, Color border,
      Color surface) {
    return GestureDetector(
      onTap: () => _teamOptions(context, ref, tm),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (tm.logoUrl != null)
              CircleAvatar(radius: 30, backgroundImage: NetworkImage(tm.logoUrl!))
            else
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.orange.withValues(alpha: 0.18),
                child: Text(tm.name.isEmpty ? '?' : tm.name.substring(0, 1),
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.orange)),
              ),
            const SizedBox(height: 10),
            Text(tm.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primary)),
            const SizedBox(height: 2),
            Text('${tm.players.length} players',
                style: GoogleFonts.inter(fontSize: 12, color: secondary)),
          ],
        ),
      ),
    );
  }

  void _teamOptions(BuildContext context, WidgetRef ref, TournamentTeam tm) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.orange),
              title: const Text('Edit team'),
              onTap: () {
                Navigator.pop(ctx);
                final t = ref.read(tournamentProvider(id)).valueOrNull;
                if (t != null) _openBuilder(context, ref, t, existing: tm);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.tierElite),
              title: const Text('Delete team'),
              onTap: () async {
                Navigator.pop(ctx);
                await TournamentService.deleteTeam(tm.id);
                ref.invalidate(tournamentTeamsProvider(id));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openBuilder(BuildContext context, WidgetRef ref, Tournament t,
      {TournamentTeam? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeamBuilderSheet(tournamentId: t.id, existing: existing),
    );
    if (saved == true) {
      // First team created → move status to building_teams.
      if (t.status == 'approved') {
        await TournamentService.setStatus(t.id, 'building_teams');
        ref.invalidate(tournamentProvider(t.id));
      }
      ref.invalidate(tournamentTeamsProvider(t.id));
    }
  }

  Future<void> _generate(
      BuildContext context, WidgetRef ref, Tournament t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate bracket?'),
        content:
            const Text('Once generated, teams cannot be changed. Continue?'),
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
        context.pushReplacementNamed('tournament-bracket',
            pathParameters: {'id': t.id});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

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
}

/// Dashed-style empty slot box.
class DottedLikeBox extends StatelessWidget {
  final Widget child;
  final Color border;
  const DottedLikeBox({super.key, required this.child, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5, style: BorderStyle.solid),
      ),
      child: child,
    );
  }
}

// ── Team builder bottom sheet ────────────────────────────────────────────────

class _SelectedPlayer {
  final String playerId, name;
  final String? position, avatarUrl;
  _SelectedPlayer(this.playerId, this.name, this.position, this.avatarUrl);
}

class _TeamBuilderSheet extends StatefulWidget {
  final String tournamentId;
  final TournamentTeam? existing;
  const _TeamBuilderSheet({required this.tournamentId, this.existing});

  @override
  State<_TeamBuilderSheet> createState() => _TeamBuilderSheetState();
}

class _TeamBuilderSheetState extends State<_TeamBuilderSheet> {
  final _nameCtrl = TextEditingController();
  Uint8List? _logo;
  final _players = <_SelectedPlayer>[];
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _players.addAll(e.players.map(
          (p) => _SelectedPlayer(p.playerId, p.name, p.position, p.avatarUrl)));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _logo = bytes);
  }

  Future<void> _addPlayer() async {
    final picked = await showModalBottomSheet<PlayerSearchResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlayerSearchSheet(
        tournamentId: widget.tournamentId,
        alreadyAdded: {for (final p in _players) p.playerId},
      ),
    );
    if (picked != null) {
      setState(() => _players.add(_SelectedPlayer(
          picked.id, picked.name, picked.position, picked.avatarUrl)));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a team name')));
      return;
    }
    if (_players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add at least one player')));
      return;
    }
    setState(() => _saving = true);
    try {
      final roster = [
        for (final p in _players) (playerId: p.playerId, position: p.position)
      ];
      if (_isEdit) {
        await TournamentService.updateTeam(widget.existing!.id,
            name: _nameCtrl.text.trim(), logoBytes: _logo);
        await TournamentService.setTeamPlayers(widget.existing!.id, roster);
      } else {
        await TournamentService.createTeam(
          tournamentId: widget.tournamentId,
          teamName: _nameCtrl.text.trim(),
          logoBytes: _logo,
          players: roster,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on GameServiceException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: secondary, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(_isEdit ? 'Edit Team' : 'New Team',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: primary)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: secondary)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickLogo,
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: surface,
                      backgroundImage: _logo != null
                          ? MemoryImage(_logo!)
                          : (widget.existing?.logoUrl != null
                              ? NetworkImage(widget.existing!.logoUrl!)
                              : null) as ImageProvider?,
                      child: (_logo == null &&
                              widget.existing?.logoUrl == null)
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined,
                                    color: secondary, size: 24),
                                const SizedBox(height: 2),
                                Text('Logo',
                                    style: GoogleFonts.inter(
                                        fontSize: 10, color: secondary)),
                              ],
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Team Name',
                    style: GoogleFonts.inter(fontSize: 13, color: secondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  style: GoogleFonts.inter(color: primary),
                  decoration: _dec('e.g. Street Kings', surface, border, secondary),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Text('Squad (${_players.length})',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: primary)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addPlayer,
                      icon: const Icon(Icons.add, size: 18,
                          color: AppColors.orange),
                      label: Text('Add Player',
                          style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w700,
                              color: AppColors.orange)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_players.isEmpty)
                  Text('No players yet — add from registered accounts.',
                      style: GoogleFonts.inter(fontSize: 13, color: secondary))
                else
                  ..._players.asMap().entries.map((e) {
                    final p = e.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: surface,
                        border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          PlayerAvatar(
                              imageUrl: p.avatarUrl,
                              fallbackInitials: p.name.substring(0, 1),
                              radius: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: primary)),
                                if ((p.position ?? '').isNotEmpty)
                                  Text(p.position!,
                                      style: GoogleFonts.inter(
                                          fontSize: 11, color: secondary)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _players.removeAt(e.key)),
                            icon: const Icon(Icons.remove_circle_outline,
                                color: AppColors.tierElite, size: 20),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.pink, AppColors.orange]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Text('Save Team',
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
      ),
    );
  }

  InputDecoration _dec(String hint, Color surface, Color border, Color sec) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: sec),
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.orange)),
      );
}

// ── Player search sheet ──────────────────────────────────────────────────────

class _PlayerSearchSheet extends StatefulWidget {
  final String tournamentId;
  final Set<String> alreadyAdded;
  const _PlayerSearchSheet(
      {required this.tournamentId, required this.alreadyAdded});

  @override
  State<_PlayerSearchSheet> createState() => _PlayerSearchSheetState();
}

class _PlayerSearchSheetState extends State<_PlayerSearchSheet> {
  final _ctrl = TextEditingController();
  List<PlayerSearchResult> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await TournamentService.searchPlayers(widget.tournamentId, q);
      if (mounted) {
        setState(() {
          _results =
              r.where((p) => !widget.alreadyAdded.contains(p.id)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: secondary, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _search,
                style: GoogleFonts.inter(color: primary),
                decoration: InputDecoration(
                  hintText: 'Search player by name…',
                  hintStyle: GoogleFonts.inter(color: secondary),
                  prefixIcon: Icon(Icons.search, color: secondary),
                  filled: true,
                  fillColor: surface,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.orange)),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.orange))
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                              _ctrl.text.isEmpty
                                  ? 'Type a name to search'
                                  : 'No players found',
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: secondary)))
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final p = _results[i];
                            return ListTile(
                              leading: PlayerAvatar(
                                  imageUrl: p.avatarUrl,
                                  fallbackInitials: p.name.substring(0, 1),
                                  radius: 18),
                              title: Text(p.name,
                                  style: GoogleFonts.inter(
                                      fontSize: 14, color: primary)),
                              subtitle: (p.position ?? '').isEmpty
                                  ? null
                                  : Text(p.position!,
                                      style: GoogleFonts.inter(
                                          fontSize: 12, color: secondary)),
                              onTap: () => Navigator.pop(context, p),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
