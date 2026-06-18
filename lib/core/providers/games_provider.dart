import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/game_service.dart';

/// A game shown in the home feed. Created by agents, joined by players.
class Game {
  final String id;
  final String fieldName;
  final String location;
  final String format;
  final String dateTime; // display label, derived from kickoff
  final DateTime kickoff; // real match start time
  final String ageGroup;
  final String details;
  final String contact;
  final int filledSlots;
  final int totalSlots;
  final double price; // per-player price (auto-calculated)
  final double fieldCost; // pitch rental the agent pays
  final double commission; // agent's commission
  final Uint8List? photo; // local preview before upload
  final String? photoUrl; // field-photos bucket
  final String? paymentQrUrl; // agent's TNG / bank QR for players to pay
  final String? agentName;
  final bool mine; // created by the current agent
  final bool live; // match is currently being played live
  final bool joined; // current player registered for this game
  final String? myPaymentStatus; // null=not joined, 'pending', 'paid'
  final bool ended; // match finished, stats submitted
  final DateTime? endedAt; // when the agent submitted (review window start)
  final bool agentPaidOut; // admin has sent the agent their share

  const Game({
    required this.id,
    required this.fieldName,
    required this.location,
    required this.format,
    required this.dateTime,
    required this.kickoff,
    required this.ageGroup,
    required this.details,
    required this.contact,
    required this.filledSlots,
    required this.totalSlots,
    required this.price,
    required this.fieldCost,
    required this.commission,
    this.photo,
    this.photoUrl,
    this.paymentQrUrl,
    this.agentName,
    this.mine = false,
    this.live = false,
    this.joined = false,
    this.myPaymentStatus,
    this.ended = false,
    this.endedAt,
    this.agentPaidOut = false,
  });

  /// Builds a Game from a Supabase row (with users + game_players embedded).
  factory Game.fromRow(Map<String, dynamic> row, {String? uid}) {
    final kickoff = DateTime.parse(row['kickoff'] as String).toLocal();
    final roster = (row['game_players'] as List?) ?? const [];
    final agent = row['users'];
    final status = (row['status'] ?? 'scheduled') as String;

    // The current user's own roster row (if any) — drives joined/pending state.
    Map? myRow;
    if (uid != null) {
      for (final p in roster) {
        if (p is Map && p['player_id'] == uid) {
          myRow = p;
          break;
        }
      }
    }
    return Game(
      id: row['id'] as String,
      fieldName: (row['field_name'] ?? '') as String,
      location: (row['location'] ?? '') as String,
      format: (row['format'] ?? '5-aside') as String,
      dateTime: DateFormat('EEE, MMM d · h:mm a').format(kickoff),
      kickoff: kickoff,
      ageGroup: (row['age_group'] ?? 'Open') as String,
      details: (row['details'] ?? '') as String,
      contact: (row['contact'] ?? '') as String,
      filledSlots: (row['num_slots_filled'] ?? 0) as int,
      totalSlots: (row['num_players'] ?? 0) as int,
      price: ((row['price'] ?? 0) as num).toDouble(),
      fieldCost: ((row['field_cost'] ?? 0) as num).toDouble(),
      commission: ((row['commission'] ?? 0) as num).toDouble(),
      photoUrl: row['photo_url'] as String?,
      paymentQrUrl: row['payment_qr_url'] as String?,
      agentName: agent is Map ? agent['full_name'] as String? : null,
      mine: uid != null && row['agent_id'] == uid,
      live: status == 'live',
      ended: status == 'completed' || status == 'cancelled',
      endedAt: row['ended_at'] == null
          ? null
          : DateTime.parse(row['ended_at'] as String).toLocal(),
      agentPaidOut: (row['agent_paid_out'] ?? false) as bool,
      joined: myRow != null,
      myPaymentStatus: myRow?['payment_status'] as String?,
    );
  }

  bool get isFull => filledSlots >= totalSlots;

  /// Agent's match-day window: attendance + Start open 30 min before kickoff.
  bool get inAgentWindow =>
      !ended &&
      DateTime.now()
          .isAfter(kickoff.subtract(const Duration(minutes: 30)));

  /// Finished match whose 3-hour dispute window is still open — the report
  /// stays pinned on home (green) so players can comment and the agent can
  /// fix stats. Falls back to kickoff when ended_at hasn't loaded yet.
  bool get inReviewWindow =>
      ended &&
      DateTime.now()
          .isBefore((endedAt ?? kickoff).add(const Duration(hours: 3)));

  /// Kickoff time as text, e.g. '8:00 PM'.
  String get kickoffLabel => DateFormat('h:mm a').format(kickoff);

  Game copyWith(
          {int? filledSlots,
          bool? live,
          bool? joined,
          String? myPaymentStatus,
          bool? ended,
          DateTime? endedAt,
          bool? agentPaidOut}) =>
      Game(
        id: id,
        fieldName: fieldName,
        location: location,
        format: format,
        dateTime: dateTime,
        kickoff: kickoff,
        ageGroup: ageGroup,
        details: details,
        contact: contact,
        filledSlots: filledSlots ?? this.filledSlots,
        totalSlots: totalSlots,
        price: price,
        fieldCost: fieldCost,
        commission: commission,
        photo: photo,
        photoUrl: photoUrl,
        paymentQrUrl: paymentQrUrl,
        agentName: agentName,
        mine: mine,
        live: live ?? this.live,
        joined: joined ?? this.joined,
        myPaymentStatus: myPaymentStatus ?? this.myPaymentStatus,
        ended: ended ?? this.ended,
        endedAt: endedAt ?? this.endedAt,
        agentPaidOut: agentPaidOut ?? this.agentPaidOut,
      );

  /// Player has joined but the agent hasn't confirmed their payment yet.
  bool get awaitingConfirmation => joined && myPaymentStatus == 'pending';

  /// Player is officially in (agent confirmed, or it was a free game).
  bool get confirmedIn => joined && myPaymentStatus == 'paid';

  /// This is a free game — no payment / confirmation needed.
  bool get isFree => price <= 0;

  /// Per-player price: the pitch rental plus the agent's commission, split
  /// evenly across players. The platform takes no cut — every ringgit goes
  /// to the pitch owner (fieldCost) or the agent (commission).
  static double priceFor(double fieldCost, double commission, int players) =>
      players == 0 ? 0 : (fieldCost + commission) / players;
}

/// Where the games feed is in its load cycle (drives skeletons / retry).
enum GamesStatus { initial, loading, ready, error }

final gamesStatusProvider =
    StateProvider<GamesStatus>((ref) => GamesStatus.initial);

class GamesNotifier extends StateNotifier<List<Game>> {
  final Ref _ref;
  GamesNotifier(this._ref) : super(const []);

  /// Fetches the public feed plus the user's joined and created games
  /// (so past/own games still power the Live panel and dashboards).
  Future<void> load() async {
    _ref.read(gamesStatusProvider.notifier).state = GamesStatus.loading;
    try {
      // Sweep abandoned games (past kick-off, nobody joined) before fetching,
      // so they never show up in the feed.
      await GameService.cleanupEmptyGames();
      final results = await Future.wait([
        GameService.fetchPublicGames(),
        GameService.fetchMyGames(),
        GameService.fetchMyCreatedGames(),
      ]);
      final merged = <String, Game>{};
      for (final list in results) {
        for (final g in list) {
          final existing = merged[g.id];
          merged[g.id] = existing == null
              ? g
              : g.copyWith(joined: g.joined || existing.joined);
        }
      }
      state = merged.values.toList()
        ..sort((a, b) => a.kickoff.compareTo(b.kickoff));
      _ref.read(gamesStatusProvider.notifier).state = GamesStatus.ready;
    } catch (_) {
      _ref.read(gamesStatusProvider.notifier).state = GamesStatus.error;
    }
  }

  /// Creates a game in Supabase then refreshes the feed.
  /// Returns null on success, or a friendly error message.
  Future<String?> createGame({
    required String fieldName,
    required String location,
    required String format,
    required DateTime kickoff,
    required String details,
    required String contact,
    required int numPlayers,
    required double price,
    required double fieldCost,
    required double commission,
    Uint8List? photoBytes,
    Uint8List? qrBytes,
    String? qrUrl,
  }) async {
    try {
      await GameService.createGame(
        fieldName: fieldName,
        location: location,
        format: format,
        kickoff: kickoff,
        ageGroup: 'Open',
        details: details,
        contact: contact,
        numPlayers: numPlayers,
        price: price,
        fieldCost: fieldCost,
        commission: commission,
        photoBytes: photoBytes,
        qrBytes: qrBytes,
        qrUrl: qrUrl,
      );
      await load();
      return null;
    } on GameServiceException catch (e) {
      return e.message;
    }
  }

  /// Race-safe join via RPC; updates the local copy on success.
  /// Free games join as confirmed ('paid'); paid games as 'pending' (the
  /// player has tapped "I've Paid" and is awaiting the agent's confirmation).
  /// Returns null on success, or a friendly error message.
  Future<String?> join(String id) async {
    final error = await GameService.joinGame(id);
    if (error != null) return error;
    state = [
      for (final g in state)
        if (g.id == id)
          g.copyWith(
            filledSlots: g.filledSlots + 1,
            joined: true,
            myPaymentStatus: g.isFree ? 'paid' : 'pending',
          )
        else
          g,
    ];
    return null;
  }

  /// Mark a game live (agent started the match) or back to scheduled.
  Future<void> setLive(String id, bool live) async {
    state = [
      for (final g in state)
        if (g.id == id) g.copyWith(live: live) else g,
    ];
    try {
      await GameService.setStatus(id, live ? 'live' : 'scheduled');
      // Realtime: watchers see the change via their games subscription.
    } on GameServiceException {
      // Local state already flipped; next load() reconciles.
    }
  }

  /// Final stats submitted: the game leaves the live panel for good.
  Future<void> endMatch(String id) async {
    state = [
      for (final g in state)
        if (g.id == id) g.copyWith(live: false, ended: true) else g,
    ];
    try {
      await GameService.setStatus(id, 'completed');
    } on GameServiceException {
      // Next load() reconciles.
    }
  }

  Future<String?> leave(String id) async {
    final error = await GameService.leaveGame(id);
    if (error != null) return error;
    state = [
      for (final g in state)
        if (g.id == id && g.filledSlots > 0)
          g.copyWith(filledSlots: g.filledSlots - 1, joined: false)
        else
          g,
    ];
    return null;
  }

  /// Replaces (or inserts) one game in the local list — used by realtime
  /// updates and detail-screen refreshes.
  void upsertLocal(Game game) {
    final found = state.any((g) => g.id == game.id);
    state = found
        ? [for (final g in state) if (g.id == game.id) game else g]
        : [...state, game];
  }

  Game? byId(String id) {
    for (final g in state) {
      if (g.id == id) return g;
    }
    return null;
  }
}

final gamesProvider = StateNotifierProvider<GamesNotifier, List<Game>>(
    (ref) => GamesNotifier(ref));
