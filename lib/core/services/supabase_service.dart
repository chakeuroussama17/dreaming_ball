import 'package:supabase_flutter/supabase_flutter.dart';

/// Central access point for the Supabase client and auth session info.
class SupabaseService {
  static final supabase = Supabase.instance.client;

  static User? get currentUser => supabase.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  static String? get userId => currentUser?.id;

  static String? get userRole =>
      currentUser?.userMetadata?['role'] as String?;

  static bool get isAdmin => currentUser?.email == 'chakeur@gmail.com';
}
