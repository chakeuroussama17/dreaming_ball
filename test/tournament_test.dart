// Tournament logic unit tests — bracket shape + group standings (pure, no DB).

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

  group('knockoutRoundName', () {
    test('names rounds by match count', () {
      expect(TournamentService.knockoutRoundName(1), 'Final');
      expect(TournamentService.knockoutRoundName(2), 'Semi Final');
      expect(TournamentService.knockoutRoundName(4), 'Quarter Final');
      expect(TournamentService.knockoutRoundName(8), 'Round of 16');
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
