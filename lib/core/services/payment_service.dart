import 'game_service.dart' show GameServiceException;
import 'supabase_service.dart';

/// Billplz payments via the create-bill Edge Function. The function reserves a
/// pending slot and returns the hosted payment-page URL; the billplz-callback
/// webhook flips the slot to paid once Billplz confirms.
class PaymentService {
  static final _sb = SupabaseService.supabase;

  /// Creates a bill for [gameId] and returns the Billplz payment URL to open.
  static Future<String> createBill(String gameId) async {
    try {
      final res = await _sb.functions.invoke(
        'create-bill',
        body: {'game_id': gameId},
      );
      final data = res.data;
      if (data is Map && data['url'] is String) return data['url'] as String;
      // Edge Function returns { error } on the failure paths.
      final msg = (data is Map ? data['error'] : null) as String?;
      throw GameServiceException(msg ?? 'Could not start payment');
    } on GameServiceException {
      rethrow;
    } catch (e) {
      throw GameServiceException(
          'Could not reach the payment service — check your connection');
    }
  }

  /// True once the webhook has marked this player paid for the game. The
  /// payment screen polls this after the player returns from Billplz.
  static Future<bool> isPaid(String gameId) async {
    final uid = SupabaseService.userId;
    if (uid == null) return false;
    try {
      final row = await _sb
          .from('game_players')
          .select('payment_status')
          .eq('game_id', gameId)
          .eq('player_id', uid)
          .maybeSingle();
      return row?['payment_status'] == 'paid';
    } catch (_) {
      return false;
    }
  }
}
