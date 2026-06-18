import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'push_service.dart';
import 'supabase_service.dart';

/// Thrown by AuthService with a message that is safe to show in the UI.
class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);

  @override
  String toString() => message;
}

/// The signed-in user as the app sees them (public.users row).
class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String role; // 'player' | 'agent' | 'admin'
  final String? avatarUrl;
  final String? gender;
  final String? country; // country of origin
  final String? state;
  final String? city;
  final DateTime? dateOfBirth;

  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.avatarUrl,
    this.gender,
    this.country,
    this.state,
    this.city,
    this.dateOfBirth,
  });

  factory AppUser.fromRow(Map<String, dynamic> row) => AppUser(
        id: row['id'] as String,
        email: row['email'] as String,
        fullName: (row['full_name'] ?? '') as String,
        phone: row['phone'] as String?,
        role: (row['role'] ?? 'player') as String,
        avatarUrl: row['avatar_url'] as String?,
        gender: row['gender'] as String?,
        country: row['country'] as String?,
        state: row['state'] as String?,
        city: row['city'] as String?,
        dateOfBirth: row['date_of_birth'] == null
            ? null
            : DateTime.tryParse(row['date_of_birth'] as String),
      );

  bool get isAdmin => role == 'admin';
  bool get isAgent => role == 'agent';

  /// Age in whole years from date of birth, or null if unknown.
  int? get age {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var a = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      a--;
    }
    return a;
  }
}

class AuthService {
  static final _sb = SupabaseService.supabase;

  // Admin is recognised by email after a normal Supabase login — the password
  // lives only in Supabase Auth (hashed), never in the app. Both the original
  // and the backing email are accepted by is_admin() in the database.
  static const adminEmail = 'chakeur@gmail.com';
  static const _adminBackingEmail = 'admin.dreamingball@gmail.com';
  static const _adminEmails = {adminEmail, _adminBackingEmail};
  static bool _adminSession = false;
  static bool get isAdminSession => _adminSession;

  static const _admin = AppUser(
    id: 'admin',
    email: adminEmail,
    fullName: 'Admin',
    role: 'admin',
  );

  // Hardcoded test accounts (besides admin). On first sign-in they are
  // auto-provisioned as real Supabase accounts so every Supabase-backed
  // screen works. email -> (password, role).
  static const _testAccounts = <String, (String, String)>{
    'player@gmail.com': ('player123', 'player'),
    'agent@gmail.com': ('agent123', 'agent'),
  };

  /// Registers a new account, creates the public.users row (the
  /// on_user_created trigger then creates player_profiles, and
  /// agent_profiles when role = 'agent'), and stores position/age group
  /// on the auto-created player profile.
  static Future<AppUser> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role, // 'player' | 'agent'
    String? position, // 'GK' | 'Defender' | 'Midfielder' | 'Striker'
    String? ageGroup,
    String? gender,
    String? country, // country of origin
    String? state,
    String? city,
    DateTime? dateOfBirth,
  }) async {
    final dob = dateOfBirth == null
        ? null
        : '${dateOfBirth.year.toString().padLeft(4, '0')}-'
            '${dateOfBirth.month.toString().padLeft(2, '0')}-'
            '${dateOfBirth.day.toString().padLeft(2, '0')}';
    try {
      final res = await _sb.auth.signUp(
        email: email,
        password: password,
        // Keep profile details in auth metadata too, so they survive the
        // email-confirmation backfill path (where the users row is written
        // later, in signIn).
        data: {
          'full_name': fullName,
          'role': role,
          'phone': phone,
          'position': ?position,
          'age_group': ?ageGroup,
          'gender': ?gender,
          'country': ?country,
          'state': ?state,
          'city': ?city,
          'date_of_birth': ?dob,
        },
      );
      final user = res.user;
      if (user == null) {
        throw AuthFailure('Sign up failed — please try again');
      }
      if (res.session == null) {
        // Email confirmation is enabled on the project; without a session we
        // cannot write the users row yet (RLS). signIn() backfills it later.
        throw AuthFailure(
            'Account created — confirm your email, then sign in.');
      }

      await _sb.from('users').insert({
        'id': user.id,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'role': role,
        'gender': gender,
        'country': country,
        'state': state,
        'city': city,
        'date_of_birth': dob,
      });

      // The trigger created the player profile with a default position;
      // write the chosen one. (position/age_group live on player_profiles.)
      await _writeProfileExtras(user.id, position, ageGroup);

      PushService.registerToken();
      return AppUser(
        id: user.id,
        email: email,
        fullName: fullName,
        phone: phone,
        role: role,
        gender: gender,
        country: country,
        state: state,
        city: city,
        dateOfBirth: dateOfBirth,
      );
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      throw AuthFailure(friendlyAuthError(e.message));
    } catch (e) {
      throw AuthFailure(friendlyAuthError(e.toString()));
    }
  }

  /// Writes the chosen position/age group onto player_profiles, verifying the
  /// update actually landed. Right after signUp the new JWT can lag a beat,
  /// so an RLS-gated update may match 0 rows silently — retry once if so.
  static Future<void> _writeProfileExtras(
      String userId, String? position, String? ageGroup) async {
    final patch = <String, dynamic>{
      'position': ?position,
      'age_group': ?ageGroup,
    };
    if (patch.isEmpty) return;
    try {
      final updated = await _sb
          .from('player_profiles')
          .update(patch)
          .eq('user_id', userId)
          .select('user_id');
      if (updated.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 400));
        await _sb.from('player_profiles').update(patch).eq('user_id', userId);
      }
    } catch (_) {
      // Profile keeps the default position; user can fix it in Edit Profile.
    }
  }

  /// Signs in via real Supabase auth. Admin is recognised *by email after a
  /// successful login* — no admin password is stored in the app, so the
  /// compiled bundle leaks nothing. The test accounts auto-provision only in
  /// debug builds.
  static Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final lower = email.toLowerCase();
    try {
      final res = await _sb.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = res.user;
      if (user == null) throw AuthFailure('Wrong email or password');

      // Admin = a recognised admin email with a valid Supabase session.
      if (_adminEmails.contains(user.email?.toLowerCase())) {
        _adminSession = true;
        PushService.registerToken();
        return _admin;
      }

      final row = await _fetchOrBackfillUserRow(user);
      if (row['is_banned'] == true) {
        await _sb.auth.signOut();
        throw AuthFailure('This account has been suspended');
      }
      PushService.registerToken();
      return AppUser.fromRow(row);
    } on AuthFailure {
      rethrow;
    } on AuthException catch (e) {
      // First-ever login for a test account — debug builds only, so strangers
      // can't auto-create a pre-approved agent in production.
      final test = _testAccounts[lower];
      if (kDebugMode &&
          test != null &&
          test.$1 == password &&
          e.message.toLowerCase().contains('invalid login credentials')) {
        return _provisionTestAccount(lower, password, test.$2);
      }
      throw AuthFailure(friendlyAuthError(e.message));
    } catch (e) {
      throw AuthFailure(friendlyAuthError(e.toString()));
    }
  }

  /// Creates a hardcoded test account as a real Supabase user. The agent test
  /// account is pre-approved so create-game and the live tools work.
  static Future<AppUser> _provisionTestAccount(
      String email, String password, String role) async {
    final user = await signUp(
      email: email,
      password: password,
      fullName: role == 'agent' ? 'Test Agent' : 'Test Player',
      phone: '+60 11-0000 0000',
      role: role,
      position: 'Striker',
      ageGroup: '21-25',
    );
    if (role == 'agent') {
      try {
        await _sb.from('agent_profiles').update({
          'status': 'approved',
          'verified_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('user_id', user.id);
      } catch (_) {
        // Approval can be redone from the verification form if needed.
      }
    }
    return user;
  }

  /// users row for the session, creating it from auth metadata if signUp
  /// couldn't write it (e.g. email-confirmation flow).
  static Future<Map<String, dynamic>> _fetchOrBackfillUserRow(
      User user) async {
    final row = await _sb
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (row != null) return row;

    final meta = user.userMetadata ?? const {};
    final insert = {
      'id': user.id,
      'email': user.email,
      'full_name': meta['full_name'] ?? 'Player',
      'phone': meta['phone'],
      'role': meta['role'] ?? 'player',
      'gender': meta['gender'],
      'country': meta['country'],
      'state': meta['state'],
      'city': meta['city'],
      'date_of_birth': meta['date_of_birth'],
    };
    await _sb.from('users').insert(insert);
    // The trigger just created player_profiles with a default position;
    // restore the choices captured in metadata at signUp.
    await _writeProfileExtras(
        user.id, meta['position'] as String?, meta['age_group'] as String?);
    return insert;
  }

  static Future<void> signOut() async {
    _adminSession = false;
    try {
      // Drop this device's push token first (while we still have a session),
      // so a shared phone doesn't keep pushing to the signed-out account.
      await PushService.unregisterToken();
      // Admin and regular users both have a real Supabase session now.
      await _sb.auth.signOut();
    } catch (_) {
      // Already signed out / network hiccup — local session is gone anyway.
    }
  }

  /// Current user: hardcoded admin, the Supabase session user, or null.
  static Future<AppUser?> getCurrentUser() async {
    if (_adminSession) return _admin;
    final user = _sb.auth.currentUser;
    if (user == null) return null;
    // A restored session for an admin email is the admin, regardless of the
    // role stored on its backing users row.
    if (_adminEmails.contains(user.email?.toLowerCase())) {
      _adminSession = true;
      return _admin;
    }
    try {
      final row = await _fetchOrBackfillUserRow(user);
      return AppUser.fromRow(row);
    } catch (_) {
      return null;
    }
  }

  /// Raw auth state changes (sign in / out / token refresh).
  static Stream<AuthState> get onAuthStateChange =>
      _sb.auth.onAuthStateChange;

  /// Verification status from agent_profiles
  /// ('not_submitted' | 'pending' | 'approved' | 'rejected' | 'suspended'),
  /// or null if the user has no agent profile.
  static Future<String?> fetchAgentStatus(String userId) async {
    try {
      final row = await _sb
          .from('agent_profiles')
          .select('status')
          .eq('user_id', userId)
          .maybeSingle();
      return row?['status'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Maps raw Supabase/auth errors to messages safe for the UI.
  static String friendlyAuthError(String raw) {
    final m = raw.toLowerCase();
    if (m.contains('user already registered') ||
        m.contains('already been registered')) {
      return 'Email already in use';
    }
    if (m.contains('invalid login credentials')) {
      return 'Wrong email or password';
    }
    if (m.contains('password should be at least')) {
      return 'Password is too weak — use at least 8 characters';
    }
    if (m.contains('email not confirmed')) {
      return 'Confirm your email first — check your inbox';
    }
    if (m.contains('socketexception') ||
        m.contains('failed host lookup') ||
        m.contains('connection') ||
        m.contains('network')) {
      return 'Check your connection and try again';
    }
    return 'Something went wrong — please try again';
  }
}
