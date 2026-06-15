import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/games_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_input.dart';
import '../../../../core/widgets/custom_button.dart';

class CreateGameScreen extends ConsumerStatefulWidget {
  const CreateGameScreen({super.key});

  @override
  ConsumerState<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends ConsumerState<CreateGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fieldNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  final _picker = ImagePicker();
  Uint8List? _photo;
  bool _photoError = false;

  static const _formats = ['5-aside', '6-aside', '7-aside', '11-aside'];
  String _format = '5-aside';

  int _players = 10;
  DateTime? _date;
  TimeOfDay? _time;

  @override
  void dispose() {
    _fieldNameCtrl.dispose();
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
    _contactCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  double get _cost => double.tryParse(_costCtrl.text) ?? 0;
  double get _playerPrice => Game.priceFor(_cost, _players);
  double get _commission => Game.commissionFor(_cost);

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = bytes;
      _photoError = false;
    });
  }

  bool _publishing = false;

  Future<void> _publish() async {
    if (_publishing) return;
    final photoOk = _photo != null;
    if (!photoOk) setState(() => _photoError = true);
    final formOk = _formKey.currentState!.validate();
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time')),
      );
      return;
    }
    if (!formOk || !photoOk) return;

    setState(() => _publishing = true);
    final error = await ref.read(gamesProvider.notifier).createGame(
          fieldName: _fieldNameCtrl.text.trim(),
          location: _addressCtrl.text.trim(),
          format: _format,
          kickoff: DateTime(_date!.year, _date!.month, _date!.day,
              _time!.hour, _time!.minute),
          details: _detailsCtrl.text.trim(),
          contact: _contactCtrl.text.trim(),
          numPlayers: _players,
          price: _playerPrice,
          fieldCost: _cost,
          commission: _commission,
          photoBytes: _photo,
        );
    if (!mounted) return;
    setState(() => _publishing = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Game published! Players can now join.'),
        backgroundColor: AppColors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.goNamed('home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final dateText =
        _date == null ? 'Select date' : DateFormat('EEE, MMM d').format(_date!);
    final timeText = _time == null ? 'Select time' : _time!.format(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.goNamed('home'),
        ),
        title: Text('Create Game',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Photo
            _label('Field Photo', secondary),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _photoError
                        ? AppColors.tierElite
                        : secondary.withValues(alpha: 0.4),
                  ),
                ),
                child: _photo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.memory(_photo!,
                            fit: BoxFit.cover, width: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 32, color: secondary),
                          const SizedBox(height: 8),
                          Text('Add field photo',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: secondary)),
                        ],
                      ),
              ),
            ),
            if (_photoError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Field photo is required',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.tierElite)),
              ),
            const SizedBox(height: 18),

            CustomInput(
              label: 'Field Name',
              hint: 'e.g. ABC Football Field',
              controller: _fieldNameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            CustomInput(
              label: 'Field Address',
              hint: 'Area / city, e.g. Petaling Jaya',
              controller: _addressCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            CustomInput(
              label: 'Details',
              hint: 'Turf type, parking, what to bring…',
              controller: _detailsCtrl,
            ),
            const SizedBox(height: 16),
            CustomInput(
              label: 'Contact Number',
              hint: '+60 12-345 6789',
              controller: _contactCtrl,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            // Format
            _label('Format', secondary),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _formats.map((f) {
                final active = f == _format;
                return GestureDetector(
                  onTap: () => setState(() => _format = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.brandGradient : null,
                      border: Border.all(
                          color: active ? Colors.transparent : border),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(f,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? Colors.white : secondary,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Date + time
            Row(
              children: [
                Expanded(
                  child: _pickerField('Date', dateText,
                      Icons.calendar_today_outlined, _date != null, primary,
                      secondary, border, surface, () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now.add(const Duration(days: 1)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _pickerField('Time', timeText, Icons.access_time,
                      _time != null, primary, secondary, border, surface,
                      () async {
                    final picked = await showTimePicker(
                        context: context, initialTime: TimeOfDay.now());
                    if (picked != null) setState(() => _time = picked);
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Players stepper
            _label('Number of Players', secondary),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: surface,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stepBtn(Icons.remove, _players > 4,
                      () => setState(() => _players--)),
                  const SizedBox(width: 28),
                  Text('$_players players',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: primary)),
                  const SizedBox(width: 28),
                  _stepBtn(Icons.add, _players < 22,
                      () => setState(() => _players++)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Field cost → auto price
            CustomInput(
              label: 'Field Rental Cost (RM)',
              hint: 'What you pay for the pitch',
              controller: _costCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Text('Player price is calculated automatically from this.',
                style: GoogleFonts.inter(fontSize: 11, color: secondary)),
            const SizedBox(height: 14),
            _priceBreakdown(primary, secondary),

            const SizedBox(height: 24),
            CustomButton(
                label: 'Publish Game',
                isLoading: _publishing,
                onPressed: _publish),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _priceBreakdown(Color primary, Color secondary) {
    Widget row(String label, String value, {Color? color, bool grad = false}) {
      final v = grad
          ? ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                      colors: [AppColors.pink, AppColors.orange])
                  .createShader(b),
              child: Text(value,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)))
          : Text(value,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color ?? primary));
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: GoogleFonts.inter(fontSize: 13, color: secondary)),
            v,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [
          AppColors.pink.withValues(alpha: 0.05),
          AppColors.orange.withValues(alpha: 0.05),
        ]),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💰  Price Breakdown',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 15, fontWeight: FontWeight.w700, color: primary)),
          const SizedBox(height: 8),
          row('Player pays:', 'RM ${_playerPrice.toStringAsFixed(2)}',
              color: AppColors.orange),
          row('Your commission:', 'RM ${_commission.toStringAsFixed(2)}',
              grad: true),
          row('Field owner gets:', 'RM ${_cost.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _label(String text, Color secondary) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w500, color: secondary));

  Widget _stepBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? const LinearGradient(colors: [AppColors.pink, AppColors.orange])
              : null,
          color: enabled ? null : const Color(0xFF444444),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _pickerField(
    String label,
    String value,
    IconData icon,
    bool selected,
    Color primary,
    Color secondary,
    Color border,
    Color surface,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, secondary),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(value,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: selected ? primary : secondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
