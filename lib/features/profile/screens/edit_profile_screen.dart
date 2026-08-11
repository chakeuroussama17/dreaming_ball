import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/content_providers.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';
import '../../../../core/widgets/custom_input.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  final _picker = ImagePicker();
  Uint8List? _avatarBytes;
  bool _saving = false;

  static const _ageGroups = ['Under 16', '16-20', '21-25', '26-30', '30+'];
  String _selectedAge = '21-25';

  static const _positions = [
    ('GK', '🥅'),
    ('Defender', '🛡️'),
    ('Midfielder', '⚙️'),
    ('Striker', '⚡'),
  ];
  String _selectedPosition = 'Striker';

  // Read-only account info (filled from the fetched profile)
  String _email = '';
  String? _currentAvatarUrl;
  String _initials = 'P';
  String get _role =>
      ref.watch(userRoleProvider) == UserRole.agent ? 'Agent' : 'Player';

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// Pre-fills the form with the player's current Supabase profile.
  Future<void> _prefill() async {
    final profile = await ref.read(myProfileProvider.future);
    if (!mounted || profile == null) return;
    setState(() {
      _nameCtrl.text = profile.fullName;
      _phoneCtrl.text = profile.phone ?? '';
      _email = profile.email;
      _currentAvatarUrl = profile.avatarUrl;
      _initials = profile.fullName.isNotEmpty
          ? profile.fullName.substring(0, 1).toUpperCase()
          : 'P';
      if (_ageGroups.contains(profile.ageGroup)) {
        _selectedAge = profile.ageGroup;
      }
      _selectedPosition = profile.position;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image must be under 5MB')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _avatarBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await ProfileService.updateProfile(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        position: _selectedPosition,
        ageGroup: _selectedAge,
        avatarBytes: _avatarBytes,
      );
      // Profile data changed — refetch wherever it's shown.
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save — try again')));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile updated!'),
      ),
    );
    context.safePop('profile');
  }

  Future<void> _confirmDelete() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Delete account?',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
        content: Text(
          'All your stats and XP will be permanently lost. This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: secondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: secondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.tierElite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Delete Forever',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
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
          onPressed: () => context.safePop('profile'),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // ── Avatar ────────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.brandGradient,
                          ),
                          child: _avatarBytes != null
                              ? ClipOval(
                                  child: Image.memory(_avatarBytes!,
                                      fit: BoxFit.cover, width: 90, height: 90),
                                )
                              : (_currentAvatarUrl != null &&
                                      _currentAvatarUrl!.isNotEmpty)
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: _currentAvatarUrl!,
                                        fit: BoxFit.cover,
                                        width: 90,
                                        height: 90,
                                        errorWidget: (_, _, _) =>
                                            _initialsAvatar(),
                                      ),
                                    )
                                  : _initialsAvatar(),
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.goldActionStart, AppColors.goldActionEnd],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: bg, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Text(
                      'Change Photo',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Full name ────────────────────────────────────────────────
            CustomInput(
              label: 'Full Name',
              hint: 'Your name',
              controller: _nameCtrl,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                if (v.trim().length < 2) return 'Name too short';
                return null;
              },
            ),
            const SizedBox(height: 18),

            // ── Phone with +60 prefix ─────────────────────────────────────
            CustomInput(
              label: 'Phone Number',
              hint: '12-345 6789',
              controller: _phoneCtrl,
              keyboardType: TextInputType.number,
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Align(
                  widthFactor: 1,
                  child: Text(
                    '+60',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: secondary,
                    ),
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone is required';
                final digits = v.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 8 || digits.length > 10) {
                  return 'Enter a valid Malaysian number';
                }
                return null;
              },
            ),
            const SizedBox(height: 22),

            // ── Age group selector ────────────────────────────────────────
            _sectionLabel('Age Group', secondary),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ageGroups.map((age) {
                final active = age == _selectedAge;
                return GestureDetector(
                  onTap: () => setState(() => _selectedAge = age),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.brandGradient : null,
                      border: Border.all(
                        color: active ? Colors.transparent : border,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      age,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? Colors.white : secondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),

            // ── Position selector ─────────────────────────────────────────
            _sectionLabel('Position', secondary),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: _positions.map((p) {
                final active = p.$1 == _selectedPosition;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPosition = p.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.gold.withValues(alpha: 0.1)
                          : surface,
                      gradient: active
                          ? LinearGradient(
                              colors: [
                                AppColors.goldDeep.withValues(alpha: 0.12),
                                AppColors.gold.withValues(alpha: 0.12),
                              ],
                            )
                          : null,
                      border: Border.all(
                        color: active ? AppColors.gold : border,
                        width: active ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(p.$2, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          p.$1,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: active ? AppColors.gold : primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // ── Account info (read-only) ───────────────────────────────────
            Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: secondary),
                const SizedBox(width: 6),
                Text(
                  'Account Info',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Cannot be changed',
                  style: GoogleFonts.inter(fontSize: 11, color: secondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _readOnlyField('Email', _email, secondary, border),
            const SizedBox(height: 12),
            Row(
              children: [
                _sectionLabel('Role', secondary),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    _role,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),
            Divider(color: border),
            const SizedBox(height: 16),

            // ── Danger zone ───────────────────────────────────────────────
            Text(
              'Danger Zone',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.tierElite,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _confirmDelete,
                style: OutlinedButton.styleFrom(
                  side:
                      BorderSide(color: AppColors.tierElite.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Delete Account',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tierElite,
                  ),
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 350.ms),
    );
  }

  Widget _initialsAvatar() => Center(
        child: Text(
          _initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _sectionLabel(String text, Color secondary) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: secondary,
        ),
      );

  Widget _readOnlyField(
      String label, String value, Color secondary, Color border) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label, secondary),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: secondary.withValues(alpha: 0.06),
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, color: secondary),
          ),
        ),
      ],
    );
  }
}
