import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/plans.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_service.dart';

/// Agent-facing subscription screen: shows how many games are left (live, in a
/// banner coloured by the current plan) and lets the agent request a plan,
/// which messages the admin. Payment is arranged in chat.
class AgentPlansScreen extends StatelessWidget {
  const AgentPlansScreen({super.key});

  Future<void> _request(BuildContext context, SubPlan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Request ${plan.label}?'),
        content: Text(
            'This sends the admin a message:\n\n"Agent requested the ${plan.label} plan (${plan.summary})."\n\nThe admin will reply with the price and payment details.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: plan.color),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send request')),
        ],
      ),
    );
    if (ok != true) return;
    await ChatService.sendAsAgent(
        '📋 Agent requested the ${plan.label} plan (${plan.summary}).');
    if (context.mounted) context.pushNamed('agent-chat');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans'),
        actions: [
          IconButton(
            tooltip: 'Chat with admin',
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: () => context.pushNamed('agent-chat'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _quotaBanner(),
          const SizedBox(height: 8),
          Text('Choose a plan',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          Text('Tap a plan to message the admin and arrange payment.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final p in kSubPlans) _planCard(context, p, scheme),
        ],
      ),
    );
  }

  /// Live banner; falls back to a one-time fetch if realtime isn't enabled.
  Widget _quotaBanner() {
    return StreamBuilder<AgentQuota?>(
      stream: AuthService.myQuotaStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return FutureBuilder<AgentQuota?>(
            future: AuthService.fetchMyQuota(),
            builder: (context, f) => _banner(f.data),
          );
        }
        return _banner(snap.data);
      },
    );
  }

  Widget _banner(AgentQuota? q) {
    final canPlay = q != null && q.canCreateGame;
    final color = canPlay ? planColor(q.currentPlan) : const Color(0xFF64748B);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Your games',
                  style:
                      GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              if (q?.currentPlan != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${planLabel(q!.currentPlan)} plan',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(q?.label ?? '—',
              style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800)),
          if (!canPlay) ...[
            const SizedBox(height: 6),
            Text('Pick a plan below to add more games.',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context, SubPlan p, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.color.withValues(alpha: 0.55), width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 6,
          height: 44,
          decoration: BoxDecoration(
            color: p.color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Row(
          children: [
            Text(p.label,
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: p.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('RM${p.priceRm}',
                  style: GoogleFonts.spaceGrotesk(
                      color: p.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
              '${p.unlimited ? 'Unlimited games' : '${p.games} games'} · ${p.days} days\n${p.bestFor}',
              style: GoogleFonts.inter(
                  fontSize: 12, color: scheme.onSurfaceVariant, height: 1.4)),
        ),
        isThreeLine: true,
        trailing: Icon(Icons.chevron_right_rounded, color: p.color),
        onTap: () => _request(context, p),
      ),
    );
  }
}
