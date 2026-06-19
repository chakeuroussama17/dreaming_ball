import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/config/app_links.dart';
import '../../../../core/providers/games_provider.dart';
import '../../../../core/services/game_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';
import '../../../../core/utils/share_utils.dart';
import '../../../../core/widgets/player_avatar.dart';
import '../../../../core/widgets/tier_badge.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const GameDetailScreen({super.key, required this.id});

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  String get id => widget.id;

  Game? _game;
  List<SquadPlayer> _squad = const [];
  bool _loadingSquad = true;
  bool _leaving = false;
  StreamSubscription<List<Map<String, dynamic>>>? _gameSub;

  @override
  void initState() {
    super.initState();
    _game = ref.read(gamesProvider.notifier).byId(id);
    _refresh();

    // Realtime: slot counter + status update live while the screen is open.
    _gameSub = SupabaseService.supabase
        .from('games')
        .stream(primaryKey: ['id'])
        .eq('id', id)
        .listen((rows) {
          if (!mounted || rows.isEmpty) return;
          final row = rows.first;
          final current = _game ?? ref.read(gamesProvider.notifier).byId(id);
          if (current == null) return;
          final status = (row['status'] ?? 'scheduled') as String;
          final updated = current.copyWith(
            filledSlots:
                (row['num_slots_filled'] ?? current.filledSlots) as int,
            live: status == 'live',
            ended: status == 'completed' || status == 'cancelled',
          );
          setState(() => _game = updated);
          ref.read(gamesProvider.notifier).upsertLocal(updated);
        });
  }

  @override
  void dispose() {
    _gameSub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        GameService.fetchGameById(id),
        GameService.fetchGamePlayers(id),
      ]);
      if (!mounted) return;
      final game = results[0] as Game?;
      setState(() {
        if (game != null) _game = game;
        _squad = results[1] as List<SquadPlayer>;
        _loadingSquad = false;
      });
      if (game != null) ref.read(gamesProvider.notifier).upsertLocal(game);
    } catch (_) {
      if (mounted) setState(() => _loadingSquad = false);
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    final error = await ref.read(gamesProvider.notifier).leave(id);
    if (!mounted) return;
    setState(() => _leaving = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _game = ref.read(gamesProvider.notifier).byId(id));
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You left the game — your slot is freed')),
    );
  }

  // Agent: which player row is mid-action (so we can show a spinner on it).
  String? _busyPlayerId;

  Future<void> _confirmPayment(SquadPlayer p) async {
    if (_busyPlayerId != null) return;
    setState(() => _busyPlayerId = p.userId);
    try {
      await GameService.confirmPayment(id, p.userId);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${p.name} confirmed — they\'re in')),
        );
      }
    } on GameServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busyPlayerId = null);
    }
  }

  Future<void> _rejectPayment(SquadPlayer p) async {
    if (_busyPlayerId != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject payment?'),
        content: Text(
            'This removes ${p.name} from the game and frees their slot. '
            'They\'ll be notified to pay again. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reject',
                  style: TextStyle(color: AppColors.tierElite))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyPlayerId = p.userId);
    try {
      await GameService.rejectPayment(id, p.userId);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${p.name} removed — slot freed')),
        );
      }
    } on GameServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busyPlayerId = null);
    }
  }

  // Share this game to WhatsApp / the native sheet with a deep link.
  Future<void> _shareGame(Game game) async {
    final price = game.isFree ? 'Free' : 'RM ${game.price.toStringAsFixed(0)}';
    final msg = '⚽ ${game.fieldName}\n'
        '📅 ${game.dateTime}\n'
        '📍 ${game.location}\n'
        '💰 $price per player\n'
        '👥 ${game.filledSlots}/${game.totalSlots} joined\n\n'
        'Join us on Dreaming Ball 👇\n${AppLinks.gameUrl(game.id)}';
    await ShareUtils.shareViaWhatsApp(msg);
  }

  // Free game: join instantly (no payment, no agent confirmation).
  Future<void> _joinFree() async {
    final error = await ref.read(gamesProvider.notifier).join(id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _game = ref.read(gamesProvider.notifier).byId(id));
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You're in! See you on the pitch.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final game = _game ?? ref.watch(gamesProvider.notifier).byId(id);
    final agentRating = (game?.agentId == null)
        ? null
        : ref.watch(agentRatingsProvider).valueOrNull?[game!.agentId];
    final fieldName = game?.fieldName ?? 'Game';
    final location = game?.location ?? '';
    final format = game?.format ?? '5-aside';
    final ageGroup = game?.ageGroup ?? 'Open';
    final kickoff = game?.dateTime ?? '—';
    final filled = game?.filledSlots ?? 0;
    final total = game?.totalSlots ?? 10;
    final price = game?.price ?? 0;
    final isFull = game?.isFull ?? false;
    final live = game?.live ?? false;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 240,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (game?.photoUrl != null)
                        CachedNetworkImage(
                            imageUrl: game!.photoUrl!, fit: BoxFit.cover)
                      else if (game?.photo != null)
                        Image.memory(game!.photo!, fit: BoxFit.cover)
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [const Color(0xFF1A1A2E), const Color(0xFF0D0D1A)]
                                  : [const Color(0xFFCBD5E1), const Color(0xFF94A3B8)],
                            ),
                          ),
                          child: Center(
                            child: Icon(Icons.sports_soccer,
                                size: 64,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08)),
                          ),
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.4, 1.0],
                            colors: [
                              Colors.transparent,
                              Color(0x55000000),
                              AppColors.darkBg,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              _pill(format, gradient: true),
                              const SizedBox(width: 8),
                              _pill(ageGroup, gradient: false),
                            ]),
                            const SizedBox(height: 8),
                            Text(fieldName,
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(location,
                                  style: GoogleFonts.inter(
                                      fontSize: 13, color: Colors.white70)),
                            ]),
                          ],
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 8,
                        right: 8,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _circleBtn(Icons.arrow_back_ios_new, () => context.safePop()),
                            _circleBtn(Icons.ios_share_outlined,
                                game == null ? () {} : () => _shareGame(game)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2x2 stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.8,
                    children: [
                      _stat(Icons.schedule, 'Kick-off', kickoff, isDark, primary, secondary, border, surface),
                      _stat(Icons.timer_outlined, 'Duration', '60 min', isDark, primary, secondary, border, surface),
                      _stat(Icons.people_outline, 'Players', '$filled / $total', isDark, primary, secondary, border, surface, valueColor: isFull ? AppColors.tierElite : null),
                      _stat(Icons.payments_outlined, 'Price', 'RM ${price.toStringAsFixed(0)}', isDark, primary, secondary, border, surface, valueColor: AppColors.orange),
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms, duration: 400.ms),
              ),

              if (isFull)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withValues(alpha: 0.12),
                        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: AppColors.orange, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "This game is full. Join the waitlist and we'll notify you if a slot opens.",
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.orange),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

              // Agent row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surface,
                      border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        PlayerAvatar(
                            fallbackInitials:
                                (game?.agentName ?? 'A').substring(0, 1),
                            radius: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(game?.agentName ?? 'Agent',
                                  style: GoogleFonts.spaceGrotesk(
                                      fontSize: 14, fontWeight: FontWeight.w700, color: primary)),
                              const SizedBox(height: 3),
                              (agentRating != null && agentRating.count > 0)
                                  ? Row(children: [
                                      const Icon(Icons.star_rounded,
                                          size: 14, color: Color(0xFFFBBF24)),
                                      const SizedBox(width: 3),
                                      Text(
                                          '${agentRating.avg.toStringAsFixed(1)} (${agentRating.count})',
                                          style: GoogleFonts.inter(
                                              fontSize: 12, color: secondary)),
                                    ])
                                  : Text('New agent',
                                      style: GoogleFonts.inter(
                                          fontSize: 12, color: secondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.cyan.withValues(alpha: 0.12),
                            border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text('✓  Verified Agent',
                              style: GoogleFonts.inter(
                                  fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.cyan)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Text('Squad',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
                ),
              ),
              if (_loadingSquad)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.orange, strokeWidth: 2.5)),
                  ),
                )
              else if (_squad.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Text('No players have joined yet — be the first!',
                        style:
                            GoogleFonts.inter(fontSize: 13, color: secondary)),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: _squad.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, indent: 72, color: border),
                  itemBuilder: (ctx, i) {
                    final p = _squad[i];
                    final isHost = game?.mine ?? false;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          PlayerAvatar(
                              imageUrl: p.avatarUrl,
                              fallbackInitials: p.name.substring(0, 1),
                              radius: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(p.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.spaceGrotesk(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: primary)),
                                    ),
                                    const SizedBox(width: 8),
                                    _payChip(p),
                                  ],
                                ),
                                Text(p.position,
                                    style: GoogleFonts.inter(
                                        fontSize: 12, color: secondary)),
                              ],
                            ),
                          ),
                          // Host sees confirm/reject on pending players;
                          // everyone else sees tier + XP.
                          if (isHost && p.pending)
                            _agentActions(p)
                          else ...[
                            TierBadge(tier: playerTierFromLabel(p.tier)),
                            const SizedBox(width: 10),
                            Text('+${p.totalXp} XP',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.orange)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: GestureDetector(
                    onTap: () {},
                    child: Text('View all $filled players →',
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.orange)),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // Bottom bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: border)),
              ),
              child: _bottomBar(game, live, isFull, price, secondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(
      Game? game, bool live, bool isFull, double price, Color secondary) {
    final isHost = game?.mine ?? false;
    final joined = game?.joined ?? false;
    final pending = game?.awaitingConfirmation ?? false;
    final isFree = game?.isFree ?? false;
    final pendingCount = _squad.where((p) => p.pending).length;

    // ── Host view: no join button; confirm payments in the squad list. ──
    if (isHost) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("You're hosting",
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.orange)),
                Text(
                    pendingCount > 0
                        ? '$pendingCount payment${pendingCount == 1 ? '' : 's'} to confirm above'
                        : 'No pending payments',
                    style: GoogleFonts.inter(fontSize: 12, color: secondary)),
              ],
            ),
          ),
          if (live)
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => context.pushNamed('live-match',
                    pathParameters: {'id': id}),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: Text('Live Match',
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
        ],
      );
    }

    // ── Player view ──
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isFree ? 'Free' : 'RM ${price.toStringAsFixed(0)}',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange)),
            Text(isFree ? 'no charge' : 'per player',
                style: GoogleFonts.inter(fontSize: 12, color: secondary)),
          ],
        ),
        const SizedBox(width: 20),
        // Joined (and not live yet) → offer to leave and free the slot.
        if (joined && !live) ...[
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _leaving ? null : _leave,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppColors.tierElite.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _leaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppColors.tierElite))
                    : Text('Leave',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.tierElite)),
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
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _bottomAction(game, live, isFull, joined, pending,
                    isFree),
                child: Text(
                    _bottomLabel(live, isFull, joined, pending, isFree),
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  VoidCallback? _bottomAction(Game? game, bool live, bool isFull, bool joined,
      bool pending, bool isFree) {
    if (live) {
      return () =>
          context.pushNamed('live-match', pathParameters: {'id': id});
    }
    if (pending) {
      // Tap to review the "awaiting confirmation" screen.
      return () => context.pushNamed('payment', pathParameters: {'id': id});
    }
    if (joined) return null; // confirmed — "Joined ✓", nothing to do
    if (isFull) return null; // full — can't join
    if (isFree) return _joinFree;
    return () => context.pushNamed('payment', pathParameters: {'id': id});
  }

  String _bottomLabel(
      bool live, bool isFull, bool joined, bool pending, bool isFree) {
    if (live) return 'View Live Match';
    if (pending) return 'Payment Pending';
    if (joined) return 'Joined ✓';
    if (isFull) return 'Game Full';
    return isFree ? 'Join Game' : 'Pay & Join';
  }

  // Small payment-status chip shown next to each player's name.
  Widget _payChip(SquadPlayer p) {
    if (p.paid) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.cyan.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, size: 12, color: AppColors.cyan),
          const SizedBox(width: 3),
          Text('Paid',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cyan)),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text('Pending',
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.orange)),
    );
  }

  // Host-only Confirm / Reject buttons for a pending player.
  Widget _agentActions(SquadPlayer p) {
    if (_busyPlayerId == p.userId) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.orange),
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionBtn(Icons.close, AppColors.tierElite, () => _rejectPayment(p)),
        const SizedBox(width: 8),
        _actionBtn(Icons.check, AppColors.cyan, () => _confirmPayment(p)),
      ],
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _pill(String label, {required bool gradient}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient
            ? const LinearGradient(colors: [AppColors.pink, AppColors.orange])
            : null,
        color: gradient ? null : Colors.black54,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value, bool isDark, Color primary,
      Color secondary, Color border, Color surface,
      {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 10, color: secondary)),
                Text(value,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 12, fontWeight: FontWeight.w700, color: valueColor ?? primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
