// Tournament logic unit tests — bracket shape + group standings + a full
// end-to-end bracket simulation (pure, no DB).

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:dreaming_ball/core/services/tournament_service.dart';

TournamentMatch _m(String a, String b, int sa, int sb,
        {String group = 'A'}) =>
    TournamentMatch(
      id: '$a-$b',
      tournamentId: 't',
      roundName: 'Group $group',
      roundOrder: 1,
      groupName: group,
      teamAId: a,
      teamBId: b,
      teamAScore: sa,
      teamBScore: sb,
      status: 'completed',
    );

/// Plays out a whole knockout bracket in memory, mirroring exactly what
/// TournamentService._buildKnockoutBracket seats/links and what the DB trigger
/// `tournament_advance_winner` does (winner → next_match_id/next_slot; byes
/// auto-advance). Returns the champion and the number of REAL contests
/// (two-team matches). Used to verify a bracket always resolves to one winner.
({String champion, int contests}) _simulateKnockout(List<String> teams) {
  final n = teams.length;
  final plan = TournamentService.planKnockout(n);
  final bracket = plan.bracketSize;
  final round1 = bracket ~/ 2;
  final sizes = plan.roundSizes;

  // rounds[r][i] = [slotA, slotB]
  final rounds = [
    for (final s in sizes) List.generate(s, (_) => <String?>[null, null])
  ];

  // Seat round 1: full (2-team) matches first, byes (1-team) after — exactly as
  // the service does.
  final byes = bracket - n;
  final full = round1 - byes;
  var t = 0;
  for (var i = 0; i < round1; i++) {
    rounds[0][i][0] = teams[t++];
    if (i < full) rounds[0][i][1] = teams[t++]; // else a bye (slot b null)
  }

  void advance(int r, int i, String w) {
    if (r + 1 >= sizes.length) return;
    rounds[r + 1][i ~/ 2][i.isEven ? 0 : 1] = w; // next_match + next_slot rule
  }

  var contests = 0;
  String? champion;
  for (var r = 0; r < sizes.length; r++) {
    for (var i = 0; i < sizes[r]; i++) {
      final a = rounds[r][i][0];
      final b = rounds[r][i][1];
      String w;
      if (a != null && b != null) {
        contests++;
        w = (i + r).isEven ? a : b; // deterministic "result"
      } else if (a != null) {
        w = a; // bye auto-advances
      } else if (b != null) {
        w = b;
      } else {
        throw StateError('round $r match $i had no teams — broken bracket');
      }
      if (r == sizes.length - 1) {
        champion = w;
      } else {
        advance(r, i, w);
      }
    }
  }
  return (champion: champion!, contests: contests);
}

void main() {
  group('planKnockout — bracket shape', () {
    test('4 teams → 2 semis + final, no byes', () {
      final p = TournamentService.planKnockout(4);
      expect(p.bracketSize, 4);
      expect(p.roundSizes, [2, 1]);
      expect(p.byesFor(4), 0);
    });
    test('8 teams → QF/SF/F', () {
      final p = TournamentService.planKnockout(8);
      expect(p.bracketSize, 8);
      expect(p.roundSizes, [4, 2, 1]);
      expect(p.byesFor(8), 0);
    });
    test('6 teams → bracket of 8 with 2 byes', () {
      final p = TournamentService.planKnockout(6);
      expect(p.bracketSize, 8);
      expect(p.roundSizes, [4, 2, 1]);
      expect(p.byesFor(6), 2);
    });
    test('16 teams → 4 rounds', () {
      final p = TournamentService.planKnockout(16);
      expect(p.bracketSize, 16);
      expect(p.roundSizes, [8, 4, 2, 1]);
    });
    test('10 teams → bracket of 16 with 6 byes', () {
      final p = TournamentService.planKnockout(10);
      expect(p.bracketSize, 16);
      expect(p.byesFor(10), 6);
    });
  });

  group('planKnockout — more sizes + byes', () {
    test('12 teams → bracket 16, 4 byes, QF/SF/F after play-ins', () {
      final p = TournamentService.planKnockout(12);
      expect(p.bracketSize, 16);
      expect(p.roundSizes, [8, 4, 2, 1]);
      expect(p.byesFor(12), 4);
    });
    test('20 teams → bracket 32, 12 byes, 5 rounds', () {
      final p = TournamentService.planKnockout(20);
      expect(p.bracketSize, 32);
      expect(p.roundSizes, [16, 8, 4, 2, 1]);
      expect(p.byesFor(20), 12);
    });
    test('32 teams → exact 5 rounds, no byes', () {
      final p = TournamentService.planKnockout(32);
      expect(p.bracketSize, 32);
      expect(p.roundSizes, [16, 8, 4, 2, 1]);
      expect(p.byesFor(32), 0);
    });
  });

  group('knockoutRoundName', () {
    test('names rounds by match count', () {
      expect(TournamentService.knockoutRoundName(1), 'Final');
      expect(TournamentService.knockoutRoundName(2), 'Semi Final');
      expect(TournamentService.knockoutRoundName(4), 'Quarter Final');
      expect(TournamentService.knockoutRoundName(8), 'Round of 16');
      expect(TournamentService.knockoutRoundName(16), 'Round of 32');
    });
  });

  group('knockout simulation — always resolves to one champion', () {
    // Even counts the app allows: powers of two + ones needing byes.
    for (final n in [4, 6, 8, 10, 12, 16, 20, 32]) {
      test('$n teams → single champion + exactly ${n - 1} contests', () {
        final teams = [for (var i = 0; i < n; i++) 'T$i'];
        final res = _simulateKnockout(teams);
        expect(teams.contains(res.champion), isTrue);
        // Single elimination: n-1 teams must be beaten, so n-1 real contests
        // regardless of how many byes the bracket has.
        expect(res.contests, n - 1);
      });
    }
  });

  group('group → knockout simulation (World-Cup style)', () {
    test('top 2 of each group cross-pair into a bracket that resolves', () {
      const n = 8;
      final teams = [for (var i = 0; i < n; i++) 'T$i'];
      // Same group split the service uses.
      final numGroups = max(2, (n / 4).round());
      final groups = List.generate(numGroups, (_) => <String>[]);
      for (var i = 0; i < n; i++) {
        groups[i % numGroups].add(teams[i]);
      }

      final winners = <String>[];
      final runners = <String>[];
      for (final grp in groups) {
        // Deterministic round-robin: lower index scores more → stable order.
        final ms = <TournamentMatch>[];
        for (var i = 0; i < grp.length; i++) {
          for (var j = i + 1; j < grp.length; j++) {
            ms.add(_m(grp[i], grp[j], grp.length - i, grp.length - j));
          }
        }
        final ranked = TournamentService.rankGroup(ms);
        expect(ranked.length, grp.length);
        winners.add(ranked[0]);
        runners.add(ranked[1]);
      }

      // Cross-pair exactly like generateKnockoutFromGroups.
      final g = groups.length;
      final ordered = <String>[];
      for (var i = 0; i < g; i++) {
        ordered.add(winners[i]);
        ordered.add(runners[(i + 1) % g]);
      }

      final res = _simulateKnockout(ordered);
      expect(ordered.contains(res.champion), isTrue);
      expect(res.contests, ordered.length - 1);
    });
  });

  group('rankGroup — standings order', () {
    test('orders by points then goal difference', () {
      // A beats B 2-0, A beats C 1-0, B beats C 3-0.
      final ranked = TournamentService.rankGroup([
        _m('A', 'B', 2, 0),
        _m('A', 'C', 1, 0),
        _m('B', 'C', 3, 0),
      ]);
      expect(ranked, ['A', 'B', 'C']); // A=6pts, B=3pts, C=0pts
    });

    test('goal difference breaks a points tie', () {
      // X and Y both win once; X by more goals.
      final ranked = TournamentService.rankGroup([
        _m('X', 'Z', 5, 0),
        _m('Y', 'Z', 1, 0),
        _m('X', 'Y', 0, 0), // draw, both +1 pt
      ]);
      // X: win(3)+draw(1)=4, gd +5 ; Y: win(3)+draw(1)=4, gd +1 ; Z: 0
      expect(ranked.first, 'X');
      expect(ranked[1], 'Y');
      expect(ranked.last, 'Z');
    });

    test('full 4-team round robin ranks by points', () {
      final ranked = TournamentService.rankGroup([
        _m('A', 'B', 1, 0), _m('A', 'C', 1, 0), _m('A', 'D', 1, 0),
        _m('B', 'C', 1, 0), _m('B', 'D', 1, 0),
        _m('C', 'D', 1, 0),
      ]);
      // A 9pts, B 6, C 3, D 0.
      expect(ranked, ['A', 'B', 'C', 'D']);
    });

    test('goal difference resolves a three-way points tie', () {
      // A, B, C each finish on 6 pts (one win in the trio + beat D); D on 0.
      // Goal differences set so A > B > C.
      final ranked = TournamentService.rankGroup([
        _m('A', 'B', 5, 0),
        _m('B', 'C', 5, 0),
        _m('C', 'A', 5, 0),
        _m('A', 'D', 3, 0),
        _m('B', 'D', 2, 0),
        _m('C', 'D', 1, 0),
      ]);
      // GD → A +3, B +2, C +1, D −6.
      expect(ranked, ['A', 'B', 'C', 'D']);
    });

    test('a draw gives both teams a point', () {
      // P and Q draw; both beat R. P has the better goal difference.
      final ranked = TournamentService.rankGroup([
        _m('P', 'Q', 1, 1),
        _m('P', 'R', 3, 0),
        _m('Q', 'R', 1, 0),
      ]);
      // P: draw+win = 4pts gd +3 ; Q: draw+win = 4pts gd +1 ; R: 0
      expect(ranked, ['P', 'Q', 'R']);
    });
  });

  group('Tournament model', () {
    Tournament t(String format) => Tournament(
        id: 't',
        agentId: 'a',
        name: 'Cup',
        gameFormat: format,
        mode: TMode.knockout,
        numTeams: 4,
        status: 'approved');

    test('playersPerSide derives from format', () {
      expect(t('5-aside').playersPerSide, 5);
      expect(t('7-aside').playersPerSide, 7);
      expect(t('11-aside').playersPerSide, 11);
    });

    test('mode mapping round-trips', () {
      expect(tModeFrom('group_stage'), TMode.groupStage);
      expect(tModeFrom('knockout'), TMode.knockout);
      expect(tModeDb(TMode.groupStage), 'group_stage');
    });
  });
}
