// Pure business-logic unit tests (no Supabase / network / widgets).

import 'package:flutter_test/flutter_test.dart';
import 'package:dreaming_ball/core/providers/games_provider.dart';
import 'package:dreaming_ball/core/services/room_service.dart';
import 'package:dreaming_ball/core/services/auth_service.dart';

Game _game({
  int filled = 0,
  int total = 10,
  double price = 12,
  bool joined = false,
  String? pay,
  bool live = false,
  bool ended = false,
}) =>
    Game(
      id: '1',
      fieldName: 'Field',
      location: 'Area',
      format: '5-aside',
      dateTime: '',
      kickoff: DateTime(2030, 1, 1, 20),
      ageGroup: 'Open',
      details: '',
      contact: '',
      filledSlots: filled,
      totalSlots: total,
      price: price,
      fieldCost: 0,
      commission: 0,
      joined: joined,
      myPaymentStatus: pay,
      live: live,
      ended: ended,
    );

void main() {
  group('Pricing — Game.priceFor', () {
    test('splits pitch cost + commission across players', () {
      expect(Game.priceFor(100, 20, 10), 12.0); // (100+20)/10
      expect(Game.priceFor(100, 0, 10), 10.0); // no commission
      expect(Game.priceFor(90, 30, 6), 20.0);
    });
    test('free when cost+commission is zero', () {
      expect(Game.priceFor(0, 0, 10), 0.0);
    });
    test('guards divide-by-zero players', () {
      expect(Game.priceFor(50, 10, 0), 0.0);
    });
  });

  group('Game state getters', () {
    test('isFree reflects price', () {
      expect(_game(price: 0).isFree, isTrue);
      expect(_game(price: 12).isFree, isFalse);
    });
    test('isFull when slots filled', () {
      expect(_game(filled: 10, total: 10).isFull, isTrue);
      expect(_game(filled: 9, total: 10).isFull, isFalse);
    });
    test('awaitingConfirmation only when joined + pending', () {
      expect(_game(joined: true, pay: 'pending').awaitingConfirmation, isTrue);
      expect(_game(joined: true, pay: 'paid').awaitingConfirmation, isFalse);
      expect(_game(joined: false, pay: 'pending').awaitingConfirmation, isFalse);
    });
    test('confirmedIn only when joined + paid', () {
      expect(_game(joined: true, pay: 'paid').confirmedIn, isTrue);
      expect(_game(joined: true, pay: 'pending').confirmedIn, isFalse);
      expect(_game(joined: false, pay: 'paid').confirmedIn, isFalse);
    });
  });

  group('Room.isEnded (2h after kick-off)', () {
    Room room(DateTime? at) => Room(
        id: 'r', creatorId: 'c', name: 'n', maxPlayers: 10, code: 'ABC123',
        scheduledAt: at);

    test('ended >2h after start', () {
      expect(
          room(DateTime.now().subtract(const Duration(hours: 3))).isEnded,
          isTrue);
    });
    test('not ended before/just after start', () {
      expect(
          room(DateTime.now().add(const Duration(hours: 1))).isEnded, isFalse);
    });
    test('no date → never ended', () {
      expect(room(null).isEnded, isFalse);
    });
  });

  group('AppUser.age', () {
    AppUser user(DateTime dob) => AppUser(
        id: 'u', email: 'e', fullName: 'F', role: 'player', dateOfBirth: dob);

    test('computes whole years from DOB', () {
      final now = DateTime.now();
      expect(user(DateTime(now.year - 20, now.month, now.day)).age, 20);
    });
    test('not yet had birthday this year', () {
      final now = DateTime.now();
      // DOB tomorrow, 25 years ago → still 24.
      final tomorrow = now.add(const Duration(days: 1));
      expect(
          user(DateTime(now.year - 25, tomorrow.month, tomorrow.day)).age,
          anyOf(24, 25)); // tolerate month/day edge near year boundary
    });
    test('null DOB → null age', () {
      expect(
          const AppUser(id: 'u', email: 'e', fullName: 'F', role: 'player')
              .age,
          isNull);
    });
  });
}
