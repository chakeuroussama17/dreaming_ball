import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The role a user signed up as. An agent is also a player — they can join and
/// play games — but additionally may create games once verified.
enum UserRole { player, agent }

/// Where an agent is in the verification pipeline.
///
/// notSubmitted → agent hasn't submitted ID + bank details yet.
/// pending       → submitted, awaiting admin approval.
/// approved      → admin approved; create-game feature unlocked.
/// rejected      → admin rejected the submission.
enum AgentVerification { notSubmitted, pending, approved, rejected }

/// Current user's role. Set during registration.
/// TODO: replace with a Supabase-backed session once auth is connected.
final userRoleProvider = StateProvider<UserRole>((ref) => UserRole.player);

/// Current agent's verification status. Drives whether the create-game
/// feature is unlocked.
final agentVerificationProvider =
    StateProvider<AgentVerification>((ref) => AgentVerification.notSubmitted);

/// Convenience: can the current user create games right now?
final canCreateGamesProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == UserRole.agent &&
      ref.watch(agentVerificationProvider) == AgentVerification.approved;
});

/// Maps an agent_profiles.status string from Supabase onto the local enum.
/// Suspended agents are treated as rejected: create-game stays locked.
AgentVerification agentVerificationFromStatus(String? status) {
  return switch (status) {
    'pending' => AgentVerification.pending,
    'approved' => AgentVerification.approved,
    'rejected' || 'suspended' => AgentVerification.rejected,
    _ => AgentVerification.notSubmitted,
  };
}
