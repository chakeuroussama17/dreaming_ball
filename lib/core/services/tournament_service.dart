import 'dart:math';
import 'dart:typed_data';
import 'game_service.dart' show GameService, GameServiceException;
import 'supabase_service.dart';

// ── Models ───────────────────────────────────────────────────────────────────

enum TMode { groupStage, knockout }

TMode tModeFrom(String? s) =>
    s == 'group_stage' ? TMode.groupStage : TMode.knockout;
String tModeDb(TMode m) => m == TMode.groupStage ? 'group_stage' : 'knockout';

/// A tournament (row of tournaments / tournament_overview).
class Tournament {
  final String id;
  final String agentId;
  final String name;
  final String? description;
  final String gameFormat;
  final TMode mode;
  final int numTeams;
  final String status;
  final String? bannerImageUrl;
  final DateTime? startDate;
  final String? rejectionReason;
  // From the overview view (list cards):
  final String agentName;
  final String? agentAvatarUrl;
  final int teamCount;
  final int playerCount;

  const Tournament({
    required this.id,
    required this.agentId,
    required this.name,
    this.description,
    required this.gameFormat,
    required this.mode,
    required this.numTeams,
    required this.status,
    this.bannerImageUrl,
    this.startDate,
    this.rejectionReason,
    this.agentName = 'Organiser',
    this.agentAvatarUrl,
    this.teamCount = 0,
    this.playerCount = 0,
  });

  bool get mine => agentId == SupabaseService.userId;
  bool get isKnockout => mode == TMode.knockout;

  /// Minimum players per side for this format (5-aside → 5, etc.).
  int get playersPerSide => switch (gameFormat) {
        '6-aside' => 6,
        '7-aside' => 7,
        '11-aside' => 11,
        _ => 5,
      };

  factory Tournament.fromRow(Map<String, dynamic> r) => Tournament(
        id: r['id'] as String,
        agentId: r['agent_id'] as String,
        name: (r['name'] ?? 'Tournament') as String,
        description: r['description'] as String?,
        gameFormat: (r['game_format'] ?? '5-aside') as String,
        mode: tModeFrom(r['mode'] as String?),
        numTeams: (r['num_teams'] ?? 4) as int,
        status: (r['status'] ?? 'pending_approval') as String,
        bannerImageUrl: r['banner_image_url'] as String?,
        startDate: r['start_date'] == null
            ? null
            : DateTime.tryParse(r['start_date'] as String),
        rejectionReason: r['rejection_reason'] as String?,
        agentName: (r['agent_name'] ?? 'Organiser') as String,
        agentAvatarUrl: r['agent_avatar_url'] as String?,
        teamCount: (r['team_count'] ?? 0) as int,
        playerCount: (r['player_count'] ?? 0) as int,
      );
}

/// A team in a tournament (optionally with its players + group).
class TournamentTeam {
  final String id;
  final String tournamentId;
  final String name;
  final String? logoUrl;
  final String? groupId;
  final String? groupName;
  final List<TournamentPlayer> players;

  const TournamentTeam({
    required this.id,
    required this.tournamentId,
    required this.name,
    this.logoUrl,
    this.groupId,
    this.groupName,
    this.players = const [],
  });

  factory TournamentTeam.fromRow(Map<String, dynamic> r) {
    final pl = (r['tournament_team_players'] as List?) ?? const [];
    return TournamentTeam(
      id: r['id'] as String,
      tournamentId: r['tournament_id'] as String,
      name: (r['team_name'] ?? 'Team') as String,
      logoUrl: r['team_logo_url'] as String?,
      groupId: r['group_id'] as String?,
      players: [
        for (final p in pl) TournamentPlayer.fromRow(Map<String, dynamic>.from(p))
      ],
    );
  }
}

/// A player on a tournament team.
class TournamentPlayer {
  final String id; // tournament_team_players.id
  final String playerId; // users.id
  final String name;
  final String? position;
  final int? jerseyNumber;
  final String? avatarUrl;

  const TournamentPlayer({
    required this.id,
    required this.playerId,
    required this.name,
    this.position,
    this.jerseyNumber,
    this.avatarUrl,
  });

  factory TournamentPlayer.fromRow(Map<String, dynamic> r) {
    final user = (r['users'] ?? const {}) as Map;
    return TournamentPlayer(
      id: r['id'] as String,
      playerId: r['player_id'] as String,
      name: (user['full_name'] ?? 'Player') as String,
      position: r['position'] as String?,
      jerseyNumber: r['jersey_number'] as int?,
      avatarUrl: user['avatar_url'] as String?,
    );
  }
}

/// A searchable player result (registered player account).
class PlayerSearchResult {
  final String id;
  final String name;
  final String? position;
  final String? avatarUrl;
  const PlayerSearchResult(
      {required this.id, required this.name, this.position, this.avatarUrl});
}

/// A tournament match (bracket node).
class TournamentMatch {
  final String id;
  final String tournamentId;
  final String roundName;
  final int roundOrder;
  final String? groupName;
  final String? teamAId;
  final String? teamBId;
  final String? teamAName;
  final String? teamBName;
  final String? teamALogo;
  final String? teamBLogo;
  final int? teamAScore;
  final int? teamBScore;
  final DateTime? scheduledAt;
  final String status;
  final String? winnerTeamId;
  final String? nextMatchId;

  const TournamentMatch({
    required this.id,
    required this.tournamentId,
    required this.roundName,
    required this.roundOrder,
    this.groupName,
    this.teamAId,
    this.teamBId,
    this.teamAName,
    this.teamBName,
    this.teamALogo,
    this.teamBLogo,
    this.teamAScore,
    this.teamBScore,
    this.scheduledAt,
    required this.status,
    this.winnerTeamId,
    this.nextMatchId,
  });

  bool get isGroup => groupName != null;
  bool get bothTeamsSet => teamAId != null && teamBId != null;

  factory TournamentMatch.fromRow(Map<String, dynamic> r) {
    final a = (r['team_a'] ?? const {}) as Map;
    final b = (r['team_b'] ?? const {}) as Map;
    return TournamentMatch(
      id: r['id'] as String,
      tournamentId: r['tournament_id'] as String,
      roundName: (r['round_name'] ?? '') as String,
      roundOrder: (r['round_order'] ?? 0) as int,
      groupName: r['group_name'] as String?,
      teamAId: r['team_a_id'] as String?,
      teamBId: r['team_b_id'] as String?,
      teamAName: a['team_name'] as String?,
      teamBName: b['team_name'] as String?,
      teamALogo: a['team_logo_url'] as String?,
      teamBLogo: b['team_logo_url'] as String?,
      teamAScore: r['team_a_score'] as int?,
      teamBScore: r['team_b_score'] as int?,
      scheduledAt: r['scheduled_at'] == null
          ? null
          : DateTime.parse(r['scheduled_at'] as String).toLocal(),
      status: (r['status'] ?? 'unscheduled') as String,
      winnerTeamId: r['winner_team_id'] as String?,
      nextMatchId: r['next_match_id'] as String?,
    );
  }
}

// ── Service ──────────────────────────────────────────────────────────────────

class TournamentService {
  static final _sb = SupabaseService.supabase;

  static const _matchSelect = '*, '
      'team_a:tournament_teams!tournament_matches_team_a_id_fkey(team_name, team_logo_url), '
      'team_b:tournament_teams!tournament_matches_team_b_id_fkey(team_name, team_logo_url)';

  // ── Lists / detail ────────────────────────────────────────────────────────

  /// All tournaments (overview view with counts + organiser), newest first.
  static Future<List<Tournament>> fetchTournaments() async {
    try {
      final rows = await _sb
          .from('tournament_overview')
          .select()
          .order('created_at', ascending: false);
      return [for (final r in rows) Tournament.fromRow(Map<String, dynamic>.from(r))];
    } catch (e) {
      throw GameServiceException(GameService.friendlyError(e));
    }
  }

  static Future<Tournament?> fetchTournament(String id) async {
    try {
      final r = await _sb
          .from('tournament_overview')
          .select()
          .eq('id', id)
          .maybeSingle();
      return r == null ? null : Tournament.fromRow(Map<String, dynamic>.from(r));
    } catch (e) {
      throw GameServiceException(GameService.friendlyError(e));
    }
  }

  /// Tournaments awaiting admin approval.
  static Future<List<Tournament>> fetchPending() async {
    final rows = await _sb
        .from('tournament_overview')
        .select()
        .eq('status', 'pending_approval')
        .order('created_at', ascending: false);
    return [for (final r in rows) Tournament.fromRow(Map<String, dynamic>.from(r))];
  }

  // ── Apply / approve ─────────────────────────────────────────────────────────

  static Future<void> createTournament({
    required String name,
    String? description,
    required String gameFormat,
    required TMode mode,
    required int numTeams,
    DateTime? startDate,
    Uint8List? bannerBytes,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) throw GameServiceException('You must be signed in');
    if (numTeams < 4 || numTeams.isOdd) {
      throw GameServiceException('Number of teams must be an even number (min 4)');
    }
    try {
      String? bannerUrl;
      if (bannerBytes != null) {
        final storage = _sb.storage.from('tournament-banners');
        final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await storage.uploadBinary(path, bannerBytes);
        bannerUrl = storage.getPublicUrl(path);
      }
      await _sb.from('tournaments').insert({
        'agent_id': uid,
        'name': name,
        'description': description,
        'game_format': gameFormat,
        'mode': tModeDb(mode),
        'num_teams': numTeams,
        'status': 'pending_approval',
        'start_date': startDate?.toIso8601String(),
        'banner_image_url': bannerUrl,
      });
    } catch (e) {
      throw GameServiceException(GameService.friendlyError(e));
    }
  }

  static Future<void> approve(String id) async {
    await _sb.from('tournaments').update({
      'status': 'approved',
      'approved_by': SupabaseService.userId,
      'approved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> reject(String id, String reason) async {
    await _sb.from('tournaments').update({
      'status': 'rejected',
      'rejection_reason': reason,
    }).eq('id', id);
  }

  static Future<void> setStatus(String id, String status) async {
    await _sb.from('tournaments').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  // ── Teams + players ─────────────────────────────────────────────────────────

  static Future<List<TournamentTeam>> fetchTeams(String tournamentId) async {
    final rows = await _sb
        .from('tournament_teams')
        .select('*, tournament_team_players('
            'id, player_id, position, jersey_number, '
            'users!tournament_team_players_player_id_fkey(full_name, avatar_url))')
        .eq('tournament_id', tournamentId)
        .order('created_at', ascending: true);
    return [for (final r in rows) TournamentTeam.fromRow(Map<String, dynamic>.from(r))];
  }

  /// Search registered players by name (excludes those already in this
  /// tournament so a player can't be on two teams).
  static Future<List<PlayerSearchResult>> searchPlayers(
      String tournamentId, String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      final rows = await _sb
          .from('users')
          .select('id, full_name, avatar_url, '
              'player_profiles(position)')
          .eq('role', 'player')
          .ilike('full_name', '%$q%')
          .limit(20);
      final taken = await _playerIdsInTournament(tournamentId);
      final out = <PlayerSearchResult>[];
      for (final r in rows) {
        final id = r['id'] as String;
        if (taken.contains(id)) continue;
        final profiles = r['player_profiles'];
        final profile = (profiles is List
            ? (profiles.isEmpty ? const {} : profiles.first)
            : (profiles ?? const {})) as Map;
        out.add(PlayerSearchResult(
          id: id,
          name: (r['full_name'] ?? 'Player') as String,
          position: profile['position'] as String?,
          avatarUrl: r['avatar_url'] as String?,
        ));
      }
      return out;
    } catch (e) {
      throw GameServiceException(GameService.friendlyError(e));
    }
  }

  static Future<Set<String>> _playerIdsInTournament(String tournamentId) async {
    final rows = await _sb
        .from('tournament_team_players')
        .select('player_id, tournament_teams!inner(tournament_id)')
        .eq('tournament_teams.tournament_id', tournamentId);
    return {for (final r in rows) r['player_id'] as String};
  }

  /// Creates a team with its players. [players] = list of (playerId, position).
  static Future<void> createTeam({
    required String tournamentId,
    required String teamName,
    Uint8List? logoBytes,
    required List<({String playerId, String? position})> players,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) throw GameServiceException('You must be signed in');
    if (players.isEmpty) {
      throw GameServiceException('Add at least one player');
    }
    try {
      String? logoUrl;
      if (logoBytes != null) {
        final storage = _sb.storage.from('team-logos');
        final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await storage.uploadBinary(path, logoBytes);
        logoUrl = storage.getPublicUrl(path);
      }
      final team = await _sb
          .from('tournament_teams')
          .insert({
            'tournament_id': tournamentId,
            'team_name': teamName,
            'team_logo_url': logoUrl,
          })
          .select('id')
          .single();
      final teamId = team['id'] as String;
      await _sb.from('tournament_team_players').insert([
        for (final p in players)
          {
            'team_id': teamId,
            'player_id': p.playerId,
            'position': p.position,
          }
      ]);
    } catch (e) {
      throw GameServiceException(GameService.friendlyError(e));
    }
  }

  static Future<void> deleteTeam(String teamId) async {
    await _sb.from('tournament_teams').delete().eq('id', teamId);
  }

  // ── Matches ─────────────────────────────────────────────────────────────────

  static Future<List<TournamentMatch>> fetchMatches(String tournamentId) async {
    final rows = await _sb
        .from('tournament_matches')
        .select(_matchSelect)
        .eq('tournament_id', tournamentId)
        .order('round_order', ascending: true)
        .order('created_at', ascending: true);
    return [for (final r in rows) TournamentMatch.fromRow(Map<String, dynamic>.from(r))];
  }

  static Future<TournamentMatch?> fetchMatch(String matchId) async {
    final r = await _sb
        .from('tournament_matches')
        .select(_matchSelect)
        .eq('id', matchId)
        .maybeSingle();
    return r == null
        ? null
        : TournamentMatch.fromRow(Map<String, dynamic>.from(r));
  }

  static Future<void> scheduleMatch(String matchId, DateTime when) async {
    await _sb.from('tournament_matches').update({
      'scheduled_at': when.toUtc().toIso8601String(),
      'status': 'scheduled',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', matchId);
  }

  /// All real (both-teams-known) matches scheduled → tournament goes live.
  static Future<void> publishSchedule(String tournamentId) async {
    await setStatus(tournamentId, 'in_progress');
  }

  static Future<void> startMatch(String matchId) async {
    await _sb.from('tournament_matches').update({
      'status': 'live',
      'team_a_score': 0,
      'team_b_score': 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', matchId);
  }

  static Future<void> updateScore(String matchId, int a, int b) async {
    await _sb.from('tournament_matches').update({
      'team_a_score': a < 0 ? 0 : a,
      'team_b_score': b < 0 ? 0 : b,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', matchId);
  }

  /// Ends a match. [winnerTeamId] decides advancement (handled by the DB
  /// trigger). For a draw the caller passes the penalty-shootout winner.
  static Future<void> endMatch(String matchId, String winnerTeamId) async {
    await _sb.from('tournament_matches').update({
      'status': 'completed',
      'winner_team_id': winnerTeamId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', matchId);
  }

  /// Realtime stream for one match (live score watching).
  static Stream<List<Map<String, dynamic>>> matchStream(String matchId) {
    return _sb
        .from('tournament_matches')
        .stream(primaryKey: ['id']).eq('id', matchId);
  }

  /// Realtime stream for a whole tournament's matches (live bracket).
  static Stream<List<Map<String, dynamic>>> matchesStream(String tournamentId) {
    return _sb
        .from('tournament_matches')
        .stream(primaryKey: ['id']).eq('tournament_id', tournamentId);
  }

  // ── Bracket generation (client-side; advancement via DB trigger) ────────────

  /// Generates the bracket for an approved/building tournament, then sets
  /// status = bracket_generated.
  static Future<void> generateBracket(Tournament t) async {
    try {
      final teams = await fetchTeams(t.id);
      final ids = [for (final tm in teams) tm.id];
      if (ids.length < 4 || ids.length.isOdd) {
        throw GameServiceException('Need an even number of teams (min 4)');
      }
      if (t.isKnockout) {
        await _generateKnockout(t.id, ids);
      } else {
        await _generateGroupStage(t.id, ids);
      }
      await setStatus(t.id, 'bracket_generated');
    } on GameServiceException {
      rethrow;
    } catch (e) {
      throw GameServiceException(GameService.friendlyError(e));
    }
  }

  static String _knockoutRoundName(int matchesInRound) => switch (matchesInRound) {
        1 => 'Final',
        2 => 'Semi Final',
        4 => 'Quarter Final',
        _ => 'Round of ${matchesInRound * 2}',
      };

  static Future<void> _generateKnockout(
      String tId, List<String> teamIds) async {
    final teams = [...teamIds]..shuffle(Random());
    final n = teams.length;
    var bracket = 1;
    while (bracket < n) {
      bracket *= 2; // next power of two
    }
    final round1 = bracket ~/ 2;

    // Round sizes from first round down to the final.
    final roundSizes = <int>[];
    for (var s = round1; s >= 1; s ~/= 2) {
      roundSizes.add(s);
    }

    // Insert each round's matches, capturing their ids.
    final roundIds = <List<String>>[];
    for (var r = 0; r < roundSizes.length; r++) {
      final size = roundSizes[r];
      final inserted = await _sb
          .from('tournament_matches')
          .insert([
            for (var i = 0; i < size; i++)
              {
                'tournament_id': tId,
                'round_name': _knockoutRoundName(size),
                'round_order': r + 1,
                'status': 'unscheduled',
              }
          ])
          .select('id');
      roundIds.add([for (final m in inserted) m['id'] as String]);
    }

    // Link each match to its parent (winner advances to round r+1, slot a/b).
    for (var r = 0; r < roundSizes.length - 1; r++) {
      final cur = roundIds[r];
      final nxt = roundIds[r + 1];
      for (var i = 0; i < cur.length; i++) {
        await _sb.from('tournament_matches').update({
          'next_match_id': nxt[i ~/ 2],
          'next_slot': i.isEven ? 'a' : 'b',
        }).eq('id', cur[i]);
      }
    }

    // Seat teams into round 1, giving byes when not a power of two.
    final byes = bracket - n; // single-team matches
    final fullMatches = round1 - byes; // two-team matches
    final r1 = roundIds[0];
    var t = 0;
    for (var i = 0; i < round1; i++) {
      if (i < fullMatches) {
        await _sb.from('tournament_matches').update({
          'team_a_id': teams[t++],
          'team_b_id': teams[t++],
        }).eq('id', r1[i]);
      } else {
        // Bye: one team, auto-complete so the trigger advances them.
        final solo = teams[t++];
        await _sb
            .from('tournament_matches')
            .update({'team_a_id': solo}).eq('id', r1[i]);
        await _sb.from('tournament_matches').update({
          'status': 'completed',
          'winner_team_id': solo,
        }).eq('id', r1[i]);
      }
    }
  }

  /// Group stage: split into groups (~4 each), round-robin within each group.
  /// (Knockout-after-groups is shown once standings are known.)
  static Future<void> _generateGroupStage(
      String tId, List<String> teamIds) async {
    final teams = [...teamIds]..shuffle(Random());
    final n = teams.length;
    final numGroups = max(2, (n / 4).round());
    // Distribute teams across groups as evenly as possible.
    final groups = List.generate(numGroups, (_) => <String>[]);
    for (var i = 0; i < n; i++) {
      groups[i % numGroups].add(teams[i]);
    }

    for (var g = 0; g < numGroups; g++) {
      final groupName = String.fromCharCode(65 + g); // A, B, C...
      final grp = await _sb
          .from('tournament_groups')
          .insert({'tournament_id': tId, 'group_name': groupName})
          .select('id')
          .single();
      final groupId = grp['id'] as String;
      final members = groups[g];
      // Tag teams with their group.
      for (final teamId in members) {
        await _sb
            .from('tournament_teams')
            .update({'group_id': groupId}).eq('id', teamId);
      }
      // Round-robin: every pair plays once.
      final matches = <Map<String, dynamic>>[];
      for (var i = 0; i < members.length; i++) {
        for (var j = i + 1; j < members.length; j++) {
          matches.add({
            'tournament_id': tId,
            'round_name': 'Group $groupName',
            'group_name': groupName,
            'round_order': 1,
            'team_a_id': members[i],
            'team_b_id': members[j],
            'status': 'unscheduled',
          });
        }
      }
      if (matches.isNotEmpty) {
        await _sb.from('tournament_matches').insert(matches);
      }
    }
  }
}
