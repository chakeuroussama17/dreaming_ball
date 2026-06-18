import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/games_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';

/// Manual payment: the agent uploaded a TNG/bank QR on the game. The player
/// scans it in their own app, pays, then taps "I've Paid" — which joins them
/// as *pending* (slot held). The agent later confirms the payment, at which
/// point the player gets a push and becomes officially in.
class PaymentScreen extends ConsumerStatefulWidget {
  final String id;
  const PaymentScreen({super.key, required this.id});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _submitting = false;

  Future<void> _markPaid(Game game) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final error = await ref.read(gamesProvider.notifier).join(widget.id);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
    // On success the provider flips the game to pending/paid and the build
    // method below re-renders into the matching state — no navigation needed.
  }

  void _zoomQr(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Center(child: Image.network(url)),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final game = ref.watch(gamesProvider.notifier).byId(widget.id);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop(),
        ),
        title: Text('Payment',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: game == null
          ? const Center(child: CircularProgressIndicator())
          : game.confirmedIn
              ? _confirmedView(isDark, game)
              : game.awaitingConfirmation
                  ? _pendingView(isDark, game)
                  : _payView(isDark, game),
    );
  }

  // ── Pay: show price + QR + "I've Paid" ──────────────────────────────────
  Widget _payView(bool isDark, Game game) {
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              _gameCard(game, primary, secondary, border, surface),
              const SizedBox(height: 20),

              // Amount
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Amount to pay',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: primary)),
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.brandGradient.createShader(b),
                      child: Text('RM ${game.price.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // QR
              Text('Scan to pay',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: primary)),
              const SizedBox(height: 4),
              Text(
                'Open your TNG / banking app, scan this QR, and pay the exact '
                'amount. Then tap "I\'ve Paid" below.',
                style: GoogleFonts.inter(
                    fontSize: 12, height: 1.5, color: secondary),
              ),
              const SizedBox(height: 12),
              if (game.paymentQrUrl != null)
                GestureDetector(
                  onTap: () => _zoomQr(game.paymentQrUrl!),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        Image.network(game.paymentQrUrl!,
                            height: 240, fit: BoxFit.contain),
                        const SizedBox(height: 6),
                        Text('Tap to enlarge',
                            style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: AppColors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No QR was set for this game. Contact the agent'
                          '${game.contact.isNotEmpty ? ' on ${game.contact}' : ''} '
                          'to arrange payment.',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.orange),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_clock_outlined,
                        size: 18, color: AppColors.cyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your spot is held as soon as you tap "I\'ve Paid". The '
                        'agent confirms once your payment arrives — you\'ll get '
                        'a notification when you\'re officially in.',
                        style: GoogleFonts.inter(
                            fontSize: 12, height: 1.5, color: AppColors.cyan),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _bottomButton(
          _submitting ? 'Please wait…' : "I've Paid",
          _submitting ? null : () => _markPaid(game),
        ),
      ],
    );
  }

  // ── Pending: paid, waiting for the agent ────────────────────────────────
  Widget _pendingView(bool isDark, Game game) {
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.orange.withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.hourglass_top,
                color: AppColors.orange, size: 36),
          ).animate().scale(
              duration: 400.ms,
              curve: Curves.elasticOut,
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1)),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('Awaiting confirmation',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 22, fontWeight: FontWeight.w800, color: primary)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Thanks! Your spot is held. The agent will confirm your payment '
              'shortly — you\'ll get a notification once you\'re officially in.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, height: 1.5, color: secondary),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _gameCard(game, primary, secondary, border, surface),
        const SizedBox(height: 24),
        _gradientButton('Back to Games', () => context.goNamed('home')),
      ],
    );
  }

  // ── Confirmed: officially in ────────────────────────────────────────────
  Widget _confirmedView(bool isDark, Game game) {
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  LinearGradient(colors: [AppColors.pink, AppColors.orange]),
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 38),
          ).animate().scale(
              duration: 400.ms,
              curve: Curves.elasticOut,
              begin: const Offset(0.4, 0.4),
              end: const Offset(1, 1)),
        ),
        const SizedBox(height: 16),
        Center(
          child: ShaderMask(
            shaderCallback: (b) => AppColors.brandGradient.createShader(b),
            child: Text("You're in!",
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text('Spot confirmed. See you on the pitch.',
              style: GoogleFonts.inter(fontSize: 14, color: secondary)),
        ),
        const SizedBox(height: 24),
        _gameCard(game, primary, secondary, border, surface),
        const SizedBox(height: 24),
        _gradientButton('Back to Games', () => context.goNamed('home')),
      ],
    );
  }

  // ── Shared bits ─────────────────────────────────────────────────────────
  Widget _gameCard(Game game, Color primary, Color secondary, Color border,
      Color surface) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(game.fieldName,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w700, color: primary)),
          const SizedBox(height: 6),
          Text(game.dateTime,
              style: GoogleFonts.inter(fontSize: 13, color: secondary)),
          Text(game.location,
              style: GoogleFonts.inter(fontSize: 13, color: secondary)),
        ],
      ),
    );
  }

  Widget _bottomButton(String label, VoidCallback? onTap) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: _gradientButton(label, onTap),
      ),
    );
  }

  Widget _gradientButton(String label, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [AppColors.pink, AppColors.orange]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onTap,
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    );
  }
}
