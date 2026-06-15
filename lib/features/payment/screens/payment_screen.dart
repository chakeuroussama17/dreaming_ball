import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/payment_config.dart';
import '../../../../core/providers/games_provider.dart';
import '../../../../core/services/game_service.dart';
import '../../../../core/services/payment_service.dart';
import '../../../../core/theme/app_colors.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String id;
  const PaymentScreen({super.key, required this.id});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  int _step = 0; // 0 review · 1 method · 2 processing/confirmed
  String _method = 'Card';
  bool _processing = false;
  bool _done = false;
  late final String _bookingRef;
  String _paidAt = '';

  final _cardCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bookingRef = 'DB${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  Timer? _pollTimer;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cardCtrl.dispose();
    _expCtrl.dispose();
    _cvvCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Billplz hosted checkout ─────────────────────────────────────────────
  bool _waitingForBillplz = false;

  Future<void> _payWithBillplz() async {
    setState(() {
      _step = 2;
      _processing = true;
    });
    try {
      final url = await PaymentService.createBill(widget.id);
      if (!mounted) return;
      // Open Billplz's hosted page (TNG / DuitNow / card live there).
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() {
        _processing = false;
        _waitingForBillplz = true;
      });
      _startPolling();
    } on GameServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _step = 1;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    // Webhook flips the slot to paid; poll until it lands (~5 min max).
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (t.tick > 100 || !mounted) {
        t.cancel();
        return;
      }
      if (await PaymentService.isPaid(widget.id)) {
        t.cancel();
        await _onBillplzPaid();
      }
    });
  }

  Future<void> _onBillplzPaid() async {
    await ref.read(gamesProvider.notifier).load();
    if (!mounted) return;
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final t = TimeOfDay.fromDateTime(now).format(context);
    setState(() {
      _waitingForBillplz = false;
      _done = true;
      _paidAt = '${now.day} ${months[now.month - 1]} ${now.year}, $t';
    });
  }

  Future<void> _checkBillplzNow() async {
    if (await PaymentService.isPaid(widget.id)) {
      _pollTimer?.cancel();
      await _onBillplzPaid();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No payment yet — finish on the Billplz page')));
    }
  }

  void _startProcessing() {
    setState(() {
      _step = 2;
      _processing = true;
    });
    _process();
  }

  Future<void> _process() async {
    // TODO: real payment gateway (FPX/Stripe) — this simulates approval.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final notifier = ref.read(gamesProvider.notifier);
    final game = notifier.byId(widget.id);

    // Race-safe join via join_game_safe RPC — can fail if the game filled up.
    final error = await notifier.join(widget.id);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _processing = false;
        _step = 1;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    try {
      await GameService.markPaid(
        gameId: widget.id,
        method: switch (_method) {
          'FPX' => 'fpx',
          'E-Wallet' => 'ewallet',
          _ => 'card',
        },
        amount: game?.price ?? 0,
        bookingRef: _bookingRef,
      );
    } catch (_) {
      // Slot is secured; the payment record can be reconciled later.
    }
    // TODO: notifications — booking confirmation push via OneSignal

    if (!mounted) return;
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final t = TimeOfDay.fromDateTime(now).format(context);
    setState(() {
      _processing = false;
      _done = true;
      _paidAt = '${now.day} ${months[now.month - 1]} ${now.year}, $t';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final game = ref.watch(gamesProvider.notifier).byId(widget.id);
    final price = game?.price ?? 13.0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () {
            if (_step == 0 || _done) {
              context.pop();
            } else if (_step == 1) {
              setState(() => _step = 0);
            }
          },
        ),
        title: Text('Payment',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: switch (_step) {
        0 => _review(isDark, game, price),
        1 => _methodStep(isDark, price),
        _ => _processingStep(isDark, game, price),
      },
    );
  }

  // ── STEP 1 — Review ─────────────────────────────────────────────────────
  Widget _review(bool isDark, Game? game, double price) {
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              _stepHeader('Review', 1, primary, secondary),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(game?.fieldName ?? 'Game',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: primary)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [AppColors.pink, AppColors.orange]),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text('RM ${price.toStringAsFixed(0)}',
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(game?.dateTime ?? 'Date & time',
                        style: GoogleFonts.inter(fontSize: 13, color: secondary)),
                    Text(game?.location ?? '',
                        style: GoogleFonts.inter(fontSize: 13, color: secondary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                    Text('Total to pay',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: primary)),
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.brandGradient.createShader(b),
                      child: Text('RM ${price.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
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
                    const Icon(Icons.lock_outline, size: 18, color: AppColors.cyan),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Held in escrow. Released to the agent 1hr before kick-off. Full refund if cancelled.',
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
        _bottomButton('Continue to Payment', () => setState(() => _step = 1)),
      ],
    );
  }

  // ── STEP 2 — Method ───────────────────────────────────────────────────────
  Widget _methodStep(bool isDark, double price) {
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    // Real payments: one button → Billplz hosted page (TNG/DuitNow/card there).
    if (PaymentConfig.billplzEnabled) {
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                _stepHeader('Payment', 2, primary, secondary),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surface,
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet,
                              color: AppColors.orange, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Pay securely with Billplz',
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You can pay with Touch ‘n Go, DuitNow, or card on the next screen. Your spot is held while you pay.',
                        style: GoogleFonts.inter(
                            fontSize: 12, height: 1.5, color: secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _bottomButton('Pay RM ${price.toStringAsFixed(2)}', _payWithBillplz),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              _stepHeader('Payment Method', 2, primary, secondary),
              const SizedBox(height: 16),
              _methodCard('Card', 'Visa / Mastercard', Icons.credit_card, primary,
                  secondary, border, surface),
              _methodCard('FPX', 'Maybank, CIMB, RHB…', Icons.account_balance,
                  primary, secondary, border, surface),
              _methodCard('E-Wallet', 'TnG, GrabPay, Boost', Icons.account_balance_wallet,
                  primary, secondary, border, surface),
              if (_method == 'Card') ...[
                const SizedBox(height: 8),
                _field(_cardCtrl, 'Card number', '1234 5678 9012 3456', primary,
                    secondary, border, surface,
                    keyboard: TextInputType.number,
                    formatters: [_CardNumberFormatter()], maxLength: 19),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(_expCtrl, 'Expiry', 'MM/YY', primary,
                          secondary, border, surface,
                          keyboard: TextInputType.number,
                          formatters: [_ExpiryFormatter()], maxLength: 5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(_cvvCtrl, 'CVV', '123', primary, secondary,
                          border, surface,
                          keyboard: TextInputType.number, obscure: true, maxLength: 4),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(_nameCtrl, 'Name on card', 'OUSSAMA C.', primary,
                    secondary, border, surface),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 14, color: secondary),
                  const SizedBox(width: 6),
                  Text('256-bit encrypted',
                      style: GoogleFonts.inter(fontSize: 12, color: secondary)),
                ],
              ),
            ],
          ),
        ),
        _bottomButton('Pay RM ${price.toStringAsFixed(2)}', _startProcessing),
      ],
    );
  }

  Widget _methodCard(String value, String sub, IconData icon, Color primary,
      Color secondary, Color border, Color surface) {
    final active = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? AppColors.orange.withValues(alpha: 0.08) : surface,
          border: Border.all(
              color: active ? AppColors.orange : border, width: active ? 1.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? AppColors.orange : secondary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 14, fontWeight: FontWeight.w700, color: primary)),
                  Text(sub, style: GoogleFonts.inter(fontSize: 12, color: secondary)),
                ],
              ),
            ),
            Icon(active ? Icons.radio_button_checked : Icons.radio_button_off,
                color: active ? AppColors.orange : secondary, size: 20),
          ],
        ),
      ),
    );
  }

  // ── STEP 3 — Processing / Confirmed ─────────────────────────────────────
  Widget _processingStep(bool isDark, Game? game, double price) {
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    if (_processing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.orange),
            SizedBox(height: 20),
            Text('Opening secure payment…'),
          ],
        ),
      );
    }

    // Billplz: page opened in the browser; wait for the webhook to confirm.
    if (_waitingForBillplz) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.orange),
              const SizedBox(height: 24),
              Text('Waiting for your payment…',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primary)),
              const SizedBox(height: 8),
              Text(
                'Finish on the Billplz page that just opened. This updates automatically once your payment is confirmed.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13, height: 1.5, color: secondary),
              ),
              const SizedBox(height: 24),
              _gradientButton("I've completed payment", _checkBillplzNow),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.pop(),
                child: Text('Pay later',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: secondary)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.pink, AppColors.orange]),
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
                    fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text('Spot confirmed. See you on the pitch.',
              style: GoogleFonts.inter(fontSize: 14, color: secondary)),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _confRow('Game', game?.fieldName ?? '-', secondary, primary),
              _confRow('Date', game?.dateTime ?? '-', secondary, primary),
              _confRow('Amount paid', 'RM ${price.toStringAsFixed(2)}', secondary,
                  primary),
              _confRow('Paid on', _paidAt, secondary, primary),
              _confRow('Booking ref', _bookingRef, secondary, primary),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_outlined,
                  size: 16, color: AppColors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text("You'll get a reminder 2hrs before kick-off",
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.orange)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _gradientButton('Back to Games', () => context.goNamed('home')),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => context.goNamed('profile'),
            child: Text('View My Bookings',
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700, color: primary)),
          ),
        ),
      ],
    );
  }

  Widget _confRow(String k, String v, Color secondary, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: GoogleFonts.inter(fontSize: 13, color: secondary)),
          Flexible(
            child: Text(v,
                textAlign: TextAlign.right,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
          ),
        ],
      ),
    );
  }

  // ── Shared bits ───────────────────────────────────────────────────────────
  Widget _stepHeader(String title, int step, Color primary, Color secondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step $step of 3', style: GoogleFonts.inter(fontSize: 12, color: secondary)),
        const SizedBox(height: 4),
        Text(title,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 20, fontWeight: FontWeight.w800, color: primary)),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, Color primary,
      Color secondary, Color border, Color surface,
      {TextInputType? keyboard,
      bool obscure = false,
      List<TextInputFormatter>? formatters,
      int? maxLength}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: secondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: keyboard,
          obscureText: obscure,
          inputFormatters: formatters,
          maxLength: maxLength,
          style: GoogleFonts.inter(fontSize: 14, color: primary),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 14, color: secondary),
            filled: true,
            fillColor: surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.orange),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomButton(String label, VoidCallback onTap) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: _gradientButton(label, onTap),
      ),
    );
  }

  Widget _gradientButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.pink, AppColors.orange]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onTap,
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }
}

// ── Formatters ────────────────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buf.write('/');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
