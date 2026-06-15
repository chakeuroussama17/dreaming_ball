import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/game_service.dart' show GameServiceException;
import '../../../../core/services/room_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/player_avatar.dart';
import '../../../../core/widgets/tier_badge.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  final String id; // private_rooms.id
  const RoomDetailScreen({super.key, required this.id});

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  Room? _room;
  List<RoomMember> _members = const [];
  bool _loading = true;
  bool _error = false;
  StreamSubscription<List<Map<String, dynamic>>>? _membersSub;

  bool get _isMember =>
      _members.any((m) => m.userId == SupabaseService.userId);

  @override
  void initState() {
    super.initState();
    _load();
    // Realtime: roster grows live as friends join.
    _membersSub = SupabaseService.supabase
        .from('room_players')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.id)
        .listen((_) {
          if (mounted) _refreshMembers();
        });
  }

  @override
  void dispose() {
    _membersSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final (room, members) = await RoomService.fetchRoomDetails(widget.id);
      if (!mounted) return;
      setState(() {
        _room = room;
        _members = members;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  Future<void> _refreshMembers() async {
    try {
      final (_, members) = await RoomService.fetchRoomDetails(widget.id);
      if (mounted) setState(() => _members = members);
    } catch (_) {
      // Keep showing the last roster on a transient failure.
    }
  }

  void _copyCode() {
    final code = _room?.code ?? '';
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copied!')),
    );
  }

  Future<void> _leave() async {
    try {
      await RoomService.leaveRoom(widget.id);
      if (mounted) context.goNamed('private-room');
    } on GameServiceException catch (e) {
      if (mounted) {
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

    final room = _room;
    final maxPlayers = room?.maxPlayers ?? 10;
    final emptySlots =
        (maxPlayers - _members.length).clamp(0, maxPlayers).toInt();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.goNamed('private-room'),
        ),
        title: ShaderMask(
          shaderCallback: (b) => AppColors.brandGradient.createShader(b),
          child: Text(
            room?.name ?? 'Room',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.pink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'Private',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.pink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.orange, strokeWidth: 2.5))
          : _error || room == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      "Couldn't load this room — it may have been closed.",
                      textAlign: TextAlign.center,
                      style:
                          GoogleFonts.inter(fontSize: 14, color: secondary),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    // ── Info card ─────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.pink.withValues(alpha: 0.04),
                        border: Border.all(
                            color: AppColors.pink.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _infoCell('Location', room.location ?? '—', primary,
                              secondary),
                          _vDivider(border),
                          _infoCell('Interested',
                              '${_members.length} / $maxPlayers', primary,
                              secondary),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.06, end: 0),

                    const SizedBox(height: 14),

                    // ── Code row ──────────────────────────────────────────
                    GestureDetector(
                      onTap: _copyCode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: surface,
                          border: Border.all(color: border),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Text('Code: ',
                                style: GoogleFonts.inter(
                                    fontSize: 14, color: secondary)),
                            Text(
                              room.code,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                                color: primary,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.copy,
                                size: 18, color: AppColors.orange),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      "Who's Coming (${_members.length})",
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._members.map((m) =>
                        _memberRow(m, primary, secondary, surface, border)),
                    ...List.generate(
                        emptySlots, (_) => _emptySlotRow(secondary, border)),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 18, color: secondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No stats are tracked in private rooms. Payments are handled between friends directly. Just show up and play.',
                              style: GoogleFonts.inter(
                                  fontSize: 12, height: 1.5, color: secondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

      bottomNavigationBar: (_loading || room == null)
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  if (_isMember) ...[
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _leave,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color:
                                    AppColors.tierElite.withValues(alpha: 0.6)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            'Leave',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.tierElite,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppColors.pink, AppColors.orange]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _copyCode,
                          icon: const Icon(Icons.share,
                              size: 18, color: Colors.white),
                          label: Text(
                            'Share Code',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoCell(
      String label, String value, Color primary, Color secondary) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: secondary)),
          ],
        ),
      ),
    );
  }

  Widget _vDivider(Color border) =>
      Container(width: 1, height: 48, color: border);

  Widget _memberRow(RoomMember m, Color primary, Color secondary,
      Color surface, Color border) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          PlayerAvatar(fallbackInitials: m.name.substring(0, 1), radius: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                Text(m.position,
                    style: GoogleFonts.inter(fontSize: 12, color: secondary)),
              ],
            ),
          ),
          if (m.isCreator) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'Creator',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orange,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          TierBadge(tier: playerTierFromLabel(m.tier)),
        ],
      ),
    );
  }

  Widget _emptySlotRow(Color secondary, Color border) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: secondary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.question_mark,
                size: 18, color: secondary.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Waiting for friends...',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: secondary.withValues(alpha: 0.7))),
              Text('Share code to invite',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: secondary.withValues(alpha: 0.4))),
            ],
          ),
        ],
      ),
    );
  }
}
