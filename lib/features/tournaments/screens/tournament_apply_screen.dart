import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/tournament_providers.dart';
import '../../../core/services/game_service.dart' show GameServiceException;
import '../../../core/services/tournament_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_input.dart';

class TournamentApplyScreen extends ConsumerStatefulWidget {
  const TournamentApplyScreen({super.key});

  @override
  ConsumerState<TournamentApplyScreen> createState() =>
      _TournamentApplyScreenState();
}

class _TournamentApplyScreenState extends ConsumerState<TournamentApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  static const _formats = ['5-aside', '6-aside', '7-aside', '11-aside'];
  String _format = '5-aside';
  TMode _mode = TMode.knockout;
  int _numTeams = 4;
  DateTime? _date;
  Uint8List? _banner;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _banner = bytes);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await TournamentService.createTournament(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        gameFormat: _format,
        mode: _mode,
        numTeams: _numTeams,
        startDate: _date,
        bannerBytes: _banner,
      );
      if (!mounted) return;
      ref.invalidate(tournamentsProvider);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Submitted! 🎉'),
          content: const Text(
              'Your tournament was sent for approval. You\'ll be notified once an admin reviews it.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );
      if (mounted) context.goNamed('tournaments');
    } on GameServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('tournaments'),
        ),
        title: Text('New Tournament',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            CustomInput(
              label: 'Tournament Name',
              hint: 'e.g. Ramadan Cup 2026',
              controller: _nameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            CustomInput(
              label: 'Description (optional)',
              hint: 'Short details — max 200 chars',
              controller: _descCtrl,
              maxLength: 200,
            ),
            const SizedBox(height: 16),

            _label('Game Format', secondary),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _formats
                  .map((f) => _choicePill(f, _format == f,
                      () => setState(() => _format = f), secondary, border))
                  .toList(),
            ),
            const SizedBox(height: 20),

            _label('Tournament Mode', secondary),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _modeCard(
                    title: 'Knockout',
                    desc: 'Single elimination — lose once and you\'re out.',
                    selected: _mode == TMode.knockout,
                    onTap: () => setState(() => _mode = TMode.knockout),
                    primary: primary,
                    secondary: secondary,
                    border: border,
                    surface: surface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _modeCard(
                    title: 'Group Stage',
                    desc: 'Teams split into groups, top 2 advance to knockout.',
                    selected: _mode == TMode.groupStage,
                    onTap: () => setState(() => _mode = TMode.groupStage),
                    primary: primary,
                    secondary: secondary,
                    border: border,
                    surface: surface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _label('Number of Teams', secondary),
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
                  _stepBtn(Icons.remove, _numTeams > 4,
                      () => setState(() => _numTeams -= 2)),
                  const SizedBox(width: 28),
                  Text('$_numTeams teams',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: primary)),
                  const SizedBox(width: 28),
                  _stepBtn(Icons.add, _numTeams < 32,
                      () => setState(() => _numTeams += 2)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text('Even numbers only (4, 6, 8, 10, 12…).',
                style: GoogleFonts.inter(fontSize: 11, color: secondary)),
            const SizedBox(height: 20),

            _label('Proposed Start Date', secondary),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now.add(const Duration(days: 7)),
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: secondary),
                    const SizedBox(width: 10),
                    Text(
                        _date == null
                            ? 'Select date'
                            : DateFormat('EEE, MMM d, yyyy').format(_date!),
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: _date == null ? secondary : primary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _label('Banner Image (optional)', secondary),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickBanner,
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: secondary.withValues(alpha: 0.4)),
                ),
                child: _banner != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.memory(_banner!,
                            fit: BoxFit.cover, width: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 32, color: secondary),
                          const SizedBox(height: 8),
                          Text('Add banner',
                              style: GoogleFonts.inter(
                                  fontSize: 13, color: secondary)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 28),

            CustomButton(
                label: 'Submit for Approval',
                isLoading: _submitting,
                onPressed: _submit),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _label(String t, Color secondary) => Text(t,
      style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w500, color: secondary));

  Widget _choicePill(
      String label, bool active, VoidCallback onTap, Color secondary, Color border) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? AppColors.brandGradient : null,
          border: Border.all(color: active ? Colors.transparent : border),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : secondary)),
      ),
    );
  }

  Widget _modeCard({
    required String title,
    required String desc,
    required bool selected,
    required VoidCallback onTap,
    required Color primary,
    required Color secondary,
    required Color border,
    required Color surface,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.08) : surface,
          border: Border.all(
              color: selected ? AppColors.gold : border,
              width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.gold : primary)),
            const SizedBox(height: 6),
            Text(desc,
                style: GoogleFonts.inter(
                    fontSize: 11, height: 1.4, color: secondary)),
          ],
        ),
      ),
    );
  }

  Widget _stepBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? const LinearGradient(colors: [AppColors.goldActionStart, AppColors.goldActionEnd])
              : null,
          color: enabled ? null : AppColors.darkTextMuted,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
