import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/plans.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/theme/app_colors.dart';

/// Agent-facing subscription screen: shows how many games are left and lets the
/// agent request a plan (which messages the admin). Payment is arranged in chat.
class AgentPlansScreen extends StatefulWidget {
  const AgentPlansScreen({super.key});

  @override
  State<AgentPlansScreen> createState() => _AgentPlansScreenState();
}

class _AgentPlansScreenState extends State<AgentPlansScreen> {
  final Future<AgentQuota?> _quota = AuthService.fetchMyQuota();

  Future<void> _request(SubPlan plan) async {
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send request')),
        ],
      ),
    );
    if (ok != true) return;
    await ChatService.sendAsAgent(
        '📋 Agent requested the ${plan.label} plan (${plan.summary}).');
    if (!mounted) return;
    context.pushNamed('agent-chat');
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
          _quotaCard(scheme),
          const SizedBox(height: 8),
          Text('Choose a plan',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          Text('Tap a plan to message the admin and arrange payment.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final p in kSubPlans) _planCard(p, scheme),
        ],
      ),
    );
  }

  Widget _quotaCard(ColorScheme scheme) {
    return FutureBuilder<AgentQuota?>(
      future: _quota,
      builder: (context, snap) {
        final q = snap.data;
        final label = q?.label ?? '—';
        final out = q != null && !q.canCreateGame;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.pink, AppColors.orange]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your games',
                  style: GoogleFonts.inter(
                      color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              if (out) ...[
                const SizedBox(height: 6),
                Text('Pick a plan below to add more games.',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _planCard(SubPlan p, ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                color: AppColors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('RM${p.priceRm}',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppColors.orange,
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
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _request(p),
      ),
    );
  }
}
