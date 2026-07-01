import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/providers/content_providers.dart';
import '../../../../core/providers/games_provider.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/legal/terms.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_input.dart';
import '../../../../app/app.dart';
import '../widgets/terms_dialog.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  int _step = 1;

  // Step 1 — Account
  final _step1Key = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  int _passStrength = 0;

  // Step 2 — Role
  String? _role;

  // Step 3 — Profile
  String? _position;
  String? _ageGroup;
  // Demographics (for analytics / monetization)
  DateTime? _dob;
  String? _gender;
  String? _state;
  final _countryCtrl = TextEditingController(text: 'Malaysia');
  final _cityCtrl = TextEditingController();

  static const _genders = ['Male', 'Female', 'Other'];
  static const _myStates = [
    'Johor', 'Kedah', 'Kelantan', 'Melaka', 'Negeri Sembilan', 'Pahang',
    'Penang', 'Perak', 'Perlis', 'Sabah', 'Sarawak', 'Selangor',
    'Terengganu', 'Kuala Lumpur', 'Putrajaya', 'Labuan',
  ];

  // Step 4 — Photo
  Uint8List? _photoBytes;

  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _countryCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  int _calcStrength(String p) {
    if (p.isEmpty) return 0;
    int s = 0;
    if (p.length >= 8) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) s++;
    return s;
  }

  void _next() {
    if (_step == 1) {
      if (_step1Key.currentState!.validate()) setState(() => _step = 2);
    } else if (_step == 2) {
      if (_role == null) {
        _snack('Please select a role to continue');
        return;
      }
      setState(() => _step = 3);
    } else if (_step == 3) {
      if (_position == null) {
        _snack('Please select your position');
        return;
      }
      if (_dob == null) {
        _snack('Please select your date of birth');
        return;
      }
      if (_gender == null) {
        _snack('Please select your gender');
        return;
      }
      if (_countryCtrl.text.trim().isEmpty) {
        _snack('Please enter your country of origin');
        return;
      }
      if (_state == null) {
        _snack('Please select your state');
        return;
      }
      if (_cityCtrl.text.trim().isEmpty) {
        _snack('Please enter your city');
        return;
      }
      setState(() => _step = 4);
    } else {
      _submit();
    }
  }

  /// Creates the account in Supabase, uploads the avatar, then routes by
  /// role. Agents land on profile, where the verification banner lives.
  ///
  /// Registration is gated on accepting the Terms of Use — if the user declines
  /// the popup, no account is created.
  Future<void> _submit() async {
    if (_submitting) return;

    // Require Terms acceptance before creating the account. Their acceptance
    // (version + timestamp) is recorded on the profile for the record.
    final agreed = await showTermsDialog(context);
    if (agreed != true) return;
    if (!mounted) return;

    setState(() => _submitting = true);
    try {
      final role = _role == 'agent' ? 'agent' : 'player';
      final user = await AuthService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        role: role,
        position: _position,
        // UI labels use en-dashes ('16–20'); schema check uses '16-20'.
        ageGroup: _ageGroup?.replaceAll('–', '-'),
        gender: _gender,
        country: _countryCtrl.text.trim(),
        state: _state,
        city: _cityCtrl.text.trim(),
        dateOfBirth: _dob,
        termsVersion: kTermsVersion,
      );

      if (_photoBytes != null) {
        try {
          final storage = SupabaseService.supabase.storage.from('avatars');
          final path = '${user.id}/avatar.jpg';
          await storage.uploadBinary(path, _photoBytes!,
              fileOptions:
                  const FileOptions(upsert: true, contentType: 'image/jpeg'));
          // Cache-bust so the avatar always loads fresh (same path is reused
          // on re-upload, and CachedNetworkImage keys by URL).
          final url =
              '${storage.getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
          await SupabaseService.supabase
              .from('users')
              .update({'avatar_url': url}).eq('id', user.id);
        } catch (_) {
          // Photo is optional — account is already created, keep going.
        }
      }

      if (!mounted) return;
      ref.read(isAdminProvider.notifier).state = false;
      ref.read(userRoleProvider.notifier).state =
          role == 'agent' ? UserRole.agent : UserRole.player;
      ref.read(agentVerificationProvider.notifier).state =
          AgentVerification.notSubmitted;
      // Fresh account — drop any cached per-user data left from a previous
      // session on this device (profile, bell, joined flags...).
      resetUserScopedProviders(ref);
      ref.read(themeModeProvider.notifier).applyFor(SupabaseService.userId);
      ref.read(gamesProvider.notifier).load();
      // Agents are players too — but they start at profile so they see the
      // "verify to create games" path immediately.
      context.goNamed(role == 'agent' ? 'profile' : 'home');
    } on AuthFailure catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Something went wrong — please try again');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      context.goNamed('welcome');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickPhoto() async {
    final file =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() => _photoBytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: back + progress
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 24, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _StepProgress(current: _step, total: 4),
                  ),
                ],
              ),
            ),

            // Step content — animates on step change
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _buildStep(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(bool isDark) {
    switch (_step) {
      case 1:
        return _step1(isDark);
      case 2:
        return _step2(isDark);
      case 3:
        return _step3(isDark);
      default:
        return _step4(isDark);
    }
  }

  // ── Step 1: Account Info ───────────────────────────────────────────────────

  Widget _step1(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heading('Create Account', isDark),
            _subheading('Join the Dreaming Ball community'),
            const SizedBox(height: 28),

            CustomInput(
              label: 'Full Name',
              hint: 'Ahmad Zikri',
              controller: _nameCtrl,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Full name is required' : null,
            ),
            const SizedBox(height: 14),

            CustomInput(
              label: 'Email',
              hint: 'you@email.com',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            CustomInput(
              label: 'Phone Number',
              hint: '+60 12-345 6789',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Phone number is required' : null,
            ),
            const SizedBox(height: 14),

            CustomInput(
              label: 'Password',
              hint: 'Min. 8 characters',
              controller: _passCtrl,
              obscureText: _obscurePass,
              onChanged: (v) =>
                  setState(() => _passStrength = _calcStrength(v)),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePass = !_obscurePass),
                icon: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.darkTextMuted,
                  size: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8) return 'At least 8 characters required';
                return null;
              },
            ),

            if (_passCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PasswordStrength(strength: _passStrength),
            ],

            const SizedBox(height: 14),

            CustomInput(
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.darkTextMuted,
                  size: 20,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm your password';
                if (v != _passCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),

            const SizedBox(height: 28),
            CustomButton(label: 'Next', onPressed: _next),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Role ──────────────────────────────────────────────────────────

  Widget _step2(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('I am a...', isDark),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _RoleCard(
                  emoji: '⚽',
                  title: 'Player',
                  desc: 'Join games & rank up',
                  isSelected: _role == 'player',
                  accentColor: AppColors.orange,
                  onTap: () => setState(() => _role = 'player'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleCard(
                  emoji: '🛡️',
                  title: 'Agent',
                  desc: 'Organize & earn',
                  isSelected: _role == 'agent',
                  accentColor: AppColors.pink,
                  onTap: () => setState(() => _role = 'agent'),
                ),
              ),
            ],
          ),
          if (_role != null) ...[
            const SizedBox(height: 20),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color:
                        isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: Text(
                _role == 'player'
                    ? 'Play games, earn XP, climb the ranks'
                    : 'Create games, referee, receive payments',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          CustomButton(label: 'Next', onPressed: _next),
        ],
      ),
    );
  }

  // ── Step 3: Player Profile ────────────────────────────────────────────────

  Widget _step3(bool isDark) {
    const positions = [
      {'emoji': '🥅', 'label': 'GK'},
      {'emoji': '🛡️', 'label': 'Defender'},
      {'emoji': '⚙️', 'label': 'Midfielder'},
      {'emoji': '⚡', 'label': 'Striker'},
    ];
    const ageGroups = ['Under 16', '16–20', '21–25', '26–30', '30+'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Your Football Profile', isDark),
          _subheading('Help us match you with the right games'),
          const SizedBox(height: 24),

          _sectionLabel('Position', isDark),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 3,
            children: positions.map((p) {
              final sel = _position == p['label'];
              return GestureDetector(
                onTap: () => setState(() => _position = p['label']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    gradient: sel ? AppColors.brandGradient : null,
                    color: sel
                        ? null
                        : (isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel
                          ? Colors.transparent
                          : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p['emoji']!,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        p['label']!,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 22),
          // Everyone starts at Beginner and earns XP toward badges.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('🌱', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Everyone starts at Beginner. Play games to earn XP and climb to Bronze, Silver, Gold and beyond.',
                    style: GoogleFonts.inter(
                        fontSize: 12, height: 1.5, color: AppColors.orange),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),
          _sectionLabel('Age Group', isDark),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ageGroups.map((ag) {
              final sel = _ageGroup == ag;
              return GestureDetector(
                onTap: () => setState(() => _ageGroup = ag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: sel ? AppColors.brandGradient : null,
                    color: sel
                        ? null
                        : (isDark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: sel
                          ? Colors.transparent
                          : (isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder),
                    ),
                  ),
                  child: Text(
                    ag,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: sel
                          ? Colors.white
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          _aboutYouSection(isDark),

          const SizedBox(height: 28),
          CustomButton(label: 'Next', onPressed: _next),
        ],
      ),
    );
  }

  // Demographics — collected once at signup for analytics / monetization.
  Widget _aboutYouSection(bool isDark) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final dobText = _dob == null
        ? 'Select date of birth'
        : '${_dob!.day.toString().padLeft(2, '0')}/'
            '${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('About You', isDark),
        const SizedBox(height: 10),

        // Date of birth
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _dob ?? DateTime(now.year - 20, now.month, now.day),
              firstDate: DateTime(now.year - 80),
              lastDate: now,
              helpText: 'Select your date of birth',
            );
            if (picked != null) setState(() => _dob = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.cake_outlined, size: 18, color: secondary),
                const SizedBox(width: 10),
                Text(dobText,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _dob == null ? secondary : primary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Gender
        Text('Gender',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: secondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _genders.map((g) {
            final sel = _gender == g;
            return GestureDetector(
              onTap: () => setState(() => _gender = g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  gradient: sel ? AppColors.brandGradient : null,
                  color: sel ? null : surface,
                  borderRadius: BorderRadius.circular(100),
                  border:
                      Border.all(color: sel ? Colors.transparent : border),
                ),
                child: Text(g,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : secondary)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        CustomInput(
          label: 'Country of Origin',
          hint: 'e.g. Malaysia',
          controller: _countryCtrl,
        ),
        const SizedBox(height: 14),

        // State
        Text('State',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w500, color: secondary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _state,
          isExpanded: true,
          dropdownColor: surface,
          decoration: InputDecoration(
            filled: true,
            fillColor: surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.orange),
            ),
          ),
          hint: Text('Select state',
              style: GoogleFonts.inter(fontSize: 14, color: secondary)),
          style: GoogleFonts.inter(fontSize: 14, color: primary),
          items: [
            for (final s in _myStates)
              DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: (v) => setState(() => _state = v),
        ),
        const SizedBox(height: 14),

        CustomInput(
          label: 'City / Area',
          hint: 'e.g. Petaling Jaya',
          controller: _cityCtrl,
        ),
      ],
    );
  }

  // ── Step 4: Profile Photo ─────────────────────────────────────────────────

  Widget _step4(bool isDark) {
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Add a photo', isDark),
          _subheading('Optional — you can add this later'),
          const SizedBox(height: 48),

          // Circle avatar picker
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: _photoBytes != null
                    ? ClipOval(
                        child: Image.memory(
                          _photoBytes!,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                            size: 32,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap to add\nphoto',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 48),

          Center(
            child: TextButton(
              onPressed: () => context.goNamed('home'),
              child: Text(
                'Skip for now',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF555555),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          CustomButton(
              label: 'Complete Setup',
              isLoading: _submitting,
              onPressed: _next),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _heading(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      );

  Widget _subheading(String text) => Text(
        text,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF555555)),
      );

  Widget _sectionLabel(String text, bool isDark) => Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      );
}

// ── Step progress bar ─────────────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  final int current;
  final int total;

  const _StepProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = current / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Step $current of $total',
          style: GoogleFonts.inter(
            fontSize: 12,
            color:
                isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (ctx, constraints) => Stack(
            children: [
              Container(
                height: 4,
                width: constraints.maxWidth,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                width: constraints.maxWidth * progress,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Password strength indicator ───────────────────────────────────────────────

class _PasswordStrength extends StatelessWidget {
  final int strength;

  const _PasswordStrength({required this.strength});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;

    if (strength <= 1) {
      color = Colors.red;
      label = 'Weak';
    } else if (strength == 2) {
      color = Colors.orange;
      label = 'Medium';
    } else {
      color = Colors.green;
      label = 'Strong';
    }

    return Row(
      children: [
        ...List.generate(
          4,
          (i) => Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: i < strength ? color : const Color(0xFF1A1A24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: color),
        ),
      ],
    );
  }
}

// ── Role card ────────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _RoleCard({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accentColor
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 14,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? accentColor
                    : (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
