import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../../../core/providers/content_providers.dart';
import '../../../../core/providers/session_provider.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/profile_service.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';
import '../../../../core/utils/share_utils.dart';
import '../../../../core/widgets/player_avatar.dart';
import '../../../../core/widgets/player_stat_card.dart';
import '../../../../core/widgets/tier_badge.dart';
import '../../../../core/widgets/xp_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/widgets/custom_button.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  /// When set, the screen shows another player's profile read-only
  /// (no settings, no agent section, no bottom nav).
  final String? viewUserId;
  const ProfileScreen({super.key, this.viewUserId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Profile data comes from Supabase (myProfileProvider) ──────────────────

  /// The profile being shown (own or guest view).
  PlayerProfile? get _profile => (widget.viewUserId != null
          ? ref.watch(playerProfileProvider(widget.viewUserId!))
          : ref.watch(myProfileProvider))
      .value;

  String get _name => _profile?.fullName ?? 'Player';
  String get _position => _profile?.position ?? 'Striker';
  PlayerTier get _tier => playerTierFromLabel(_profile?.tier);
  int get _xp => _profile?.totalXp ?? 0;
  int get _games => _profile?.totalGamesPlayed ?? 0;
  int get _goals => _profile?.totalGoals ?? 0;
  int get _assists => _profile?.totalAssists ?? 0;
  int get _cleanSheets => _profile?.cleanSheets ?? 0;

  /// FIFA-card overall rating derived from lifetime XP (50–99).
  int get _overall => math.min(99, 50 + _xp ~/ 80);

  static String _abbr(String position) => switch (position) {
        'GK' => 'GK',
        'Defender' => 'DF',
        'Midfielder' => 'MF',
        _ => 'ST',
      };

  /// (xp into current tier, xp span of current tier, next tier name).
  static (int, int, String) _tierProgress(int xp) {
    const steps = [
      (100, 'Bronze'), (300, 'Silver'), (600, 'Gold'), (1000, 'Platinum'),
      (1500, 'Diamond'), (2000, 'Elite'), (3000, 'Legend'),
    ];
    var lower = 0;
    for (final (threshold, name) in steps) {
      if (xp < threshold) return (xp - lower, threshold - lower, name);
      lower = threshold;
    }
    return (1, 1, 'Legend'); // max tier reached
  }

  void _sharePlayerCard() {
    final card = '⚽ $_name — $_position · ${_tier.label}\n'
        'Overall $_overall · $_goals goals · $_assists assists · '
        '$_games games · $_xp XP\n'
        'My Dreaming Ball player card 🔥';
    ShareUtils.shareText(card, subject: 'My Dreaming Ball player card');
  }

  List<PlayerStat> get _stats => [
        PlayerStat(icon: Icons.sports_soccer, label: 'Goals', value: _goals),
        PlayerStat(
            icon: Icons.handshake_outlined, label: 'Assists', value: _assists),
        PlayerStat(
            icon: Icons.shield_outlined, label: 'Clean Sh.', value: _cleanSheets),
        PlayerStat(
            icon: Icons.sports, label: 'Games', value: _games),
        PlayerStat(icon: Icons.bolt, label: 'XP', value: math.min(_xp, 9999)),
        PlayerStat(icon: Icons.gps_fixed, label: 'Overall', value: _overall),
      ];

  // ── Agent verification form state ─────────────────────────────────────────
  // Malaysian banks that support DuitNow.
  static const _banks = [
    'Maybank', 'CIMB', 'RHB', 'Public Bank',
    'Hong Leong', 'Bank Islam', 'AmBank',
  ];
  static const _idTypes = ['MyKad', 'Passport'];
  String _idType = 'MyKad';
  String? _selectedBank;
  final _fullNameCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();

  final _picker = ImagePicker();
  Uint8List? _idFront;
  Uint8List? _idBack;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _refreshAgentStatus();
  }

  /// Pulls the verification status from agent_profiles, so an admin approval
  /// shows up as soon as the agent opens their profile (no re-login needed).
  Future<void> _refreshAgentStatus() async {
    if (widget.viewUserId != null) return; // guest view
    if (ref.read(userRoleProvider) != UserRole.agent) return;
    final uid = SupabaseService.userId;
    if (uid == null) return;
    final status = await AuthService.fetchAgentStatus(uid);
    if (!mounted || status == null) return;
    ref.read(agentVerificationProvider.notifier).state =
        agentVerificationFromStatus(status);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameCtrl.dispose();
    _idNumberCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    super.dispose();
  }

  bool _submittingVerification = false;

  Future<void> _submitVerification() async {
    if (_fullNameCtrl.text.trim().isEmpty ||
        _idNumberCtrl.text.trim().isEmpty ||
        _selectedBank == null ||
        _accountNumberCtrl.text.trim().isEmpty ||
        _accountHolderCtrl.text.trim().isEmpty ||
        _idFront == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields and upload your ID')),
      );
      return;
    }
    if (_submittingVerification) return;
    setState(() => _submittingVerification = true);

    final uid = SupabaseService.userId;
    try {
      if (uid != null) {
        // KYC documents live in the private bucket, in the user's folder.
        final storage = SupabaseService.supabase.storage.from('kyc-documents');
        const opts = FileOptions(upsert: true, contentType: 'image/jpeg');
        final frontPath = '$uid/id_front.jpg';
        await storage.uploadBinary(frontPath, _idFront!, fileOptions: opts);
        String? backPath;
        if (_idBack != null) {
          backPath = '$uid/id_back.jpg';
          await storage.uploadBinary(backPath, _idBack!, fileOptions: opts);
        }

        await SupabaseService.supabase.from('agent_profiles').update({
          'id_type': _idType,
          'id_number': _idNumberCtrl.text.trim(),
          'id_front_url': frontPath,
          'id_back_url': backPath,
          'bank_name': _selectedBank,
          'account_number': _accountNumberCtrl.text.trim(),
          'account_holder': _accountHolderCtrl.text.trim(),
          'status': 'pending',
        }).eq('user_id', uid);
      }

      // Real pipeline: the admin reviews the documents in the admin panel
      // and approves/rejects there. Status refreshes when the profile opens
      // (and on every login).
      ref.read(agentVerificationProvider.notifier).state =
          AgentVerification.pending;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not submit verification — try again')));
      }
    } finally {
      if (mounted) setState(() => _submittingVerification = false);
    }
  }

  Future<void> _pickId({required bool front}) async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      if (front) {
        _idFront = bytes;
      } else {
        _idBack = bytes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final isGuest = widget.viewUserId != null;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isGuest)
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
                      onPressed: () => context.safePop(),
                    )
                  else
                    const SizedBox(width: 12),
                  Text(
                    isGuest ? 'Player Profile' : 'Profile',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  if (isGuest)
                    const SizedBox(width: 48)
                  else
                    IconButton(
                      icon: Icon(Icons.settings_outlined, color: primary),
                      onPressed: () => context.pushNamed('settings'),
                    ),
                ],
              ),
            ),

            // ── Identity row ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  PlayerAvatar(
                      imageUrl: _profile?.avatarUrl,
                      fallbackInitials: _name.substring(0, 1),
                      radius: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            TierBadge(tier: _tier),
                            const SizedBox(width: 8),
                            Text(
                              _position,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: secondary,
                              ),
                            ),
                            if (!isGuest &&
                                ref.watch(userRoleProvider) == UserRole.agent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                      colors: [AppColors.pink, AppColors.orange]),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text('Agent',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Tabs ──────────────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.orange,
              indicatorWeight: 2.5,
              labelColor: primary,
              unselectedLabelColor: secondary,
              labelStyle: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              tabs: const [
                Tab(text: 'My Stats'),
                Tab(text: 'My Games'),
              ],
            ),

            // ── Tab content ─────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildStatsTab(
                    isDark: isDark,
                    primary: primary,
                    secondary: secondary,
                    border: border,
                    surface: surface,
                    isGuest: isGuest,
                  ),
                  _buildGamesTab(
                    primary: primary,
                    secondary: secondary,
                    border: border,
                    surface: surface,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isGuest
          ? null
          : BottomNavigationBar(
              currentIndex: 4,
              type: BottomNavigationBarType.fixed,
              onTap: (i) {
                switch (i) {
                  case 0:
                    context.goNamed('home');
                  case 1:
                    context.goNamed('leaderboard');
                  case 2:
                    context.goNamed('tournaments');
                  case 3:
                    context.goNamed('private-room');
                  default:
                    break;
                }
              },
              items: [
                BottomNavigationBarItem(icon: const Icon(Icons.home_outlined), label: l.navHome),
                BottomNavigationBarItem(icon: const Icon(Icons.leaderboard_outlined), label: l.navLeaderboard),
                BottomNavigationBarItem(icon: const Icon(Icons.emoji_events_outlined), label: l.navTournaments),
                BottomNavigationBarItem(icon: const Icon(Icons.lock_outline), label: l.navPrivateRoom),
                BottomNavigationBarItem(icon: const Icon(Icons.person), label: l.navProfile),
              ],
            ),
    );
  }

  // ── STATS TAB ───────────────────────────────────────────────────────────

  Widget _buildStatsTab({
    required bool isDark,
    required Color primary,
    required Color secondary,
    required Color border,
    required Color surface,
    required bool isGuest,
  }) {
    // (xp into tier, tier span, next tier name) for the XP bar below.
    final (tierXp, tierSpan, nextTierName) = _tierProgress(_xp);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        PlayerStatCard(
          name: _name,
          positionAbbr: _abbr(_position),
          tier: _tier,
          overall: _overall,
          xp: _xp,
          stats: _stats,
          games: _games,
          // TODO: win tracking needs match results — not in schema yet.
          winRate: 0,
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),

        const SizedBox(height: 16),

        // Share button — ghost with pink border
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _sharePlayerCard,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.pink.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.share_outlined,
                size: 18, color: AppColors.pink),
            label: Text(
              'Share Player Card',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.pink,
              ),
            ),
          ),
        ),

        // ── Agent section (own profile, agents only) ───────────────────────
        if (!isGuest && ref.watch(userRoleProvider) == UserRole.agent) ...[
          const SizedBox(height: 24),
          _buildAgentDetails(
            primary: primary,
            secondary: secondary,
            border: border,
            surface: surface,
          ),
        ],

        const SizedBox(height: 24),

        // Career stats 4-column grid
        Text(
          'Career Stats',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _careerCell('Games', '$_games', primary, secondary, border, surface),
            const SizedBox(width: 10),
            _careerCell('Goals', '$_goals', primary, secondary, border, surface),
            const SizedBox(width: 10),
            _careerCell('Assists', '$_assists', primary, secondary, border, surface),
            const SizedBox(width: 10),
            _careerCell('Clean Sh.', '$_cleanSheets', primary, secondary, border, surface),
          ],
        ),

        const SizedBox(height: 24),

        // XP progress
        Text(
          'Progress to $nextTierName',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
        const SizedBox(height: 10),
        XpBar(currentXp: tierXp, maxXp: tierSpan, height: 10),
        const SizedBox(height: 8),
        Text(
          '$tierXp / $tierSpan XP · ${tierSpan - tierXp} XP to $nextTierName',
          style: GoogleFonts.inter(fontSize: 12, color: secondary),
        ),
      ],
    );
  }

  Widget _careerCell(String label, String value, Color primary,
      Color secondary, Color border, Color surface) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: surface,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: secondary),
            ),
          ],
        ),
      ),
    );
  }

  // ── GAMES TAB ─────────────────────────────────────────────────────────────

  Widget _buildGamesTab({
    required Color primary,
    required Color secondary,
    required Color border,
    required Color surface,
  }) {
    // Recent games only exist for the signed-in player.
    if (widget.viewUserId != null) {
      return Center(
        child: Text('Game history is private',
            style: GoogleFonts.inter(fontSize: 13, color: secondary)),
      );
    }
    final gamesAsync = ref.watch(myRecentGamesProvider);
    return gamesAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(
              color: AppColors.orange, strokeWidth: 2.5)),
      error: (_, _) => Center(
        child: Text("Couldn't load games — pull to retry",
            style: GoogleFonts.inter(fontSize: 13, color: secondary)),
      ),
      data: (recent) => recent.isEmpty
          ? Center(
              child: Text('No games yet — join one from Home!',
                  style: GoogleFonts.inter(fontSize: 13, color: secondary)),
            )
          : _gamesList(recent, primary, secondary, border, surface),
    );
  }

  Widget _gamesList(List<RecentGame> recent, Color primary, Color secondary,
      Color border, Color surface) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: recent.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final g = recent[i];
        return GestureDetector(
          // Opens the match report — during the dispute window players can
          // comment to the agent there.
          onTap: () => context
              .goNamed('live-match', pathParameters: {'id': g.gameId}),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sports_soccer,
                      color: AppColors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.fieldName,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${g.dateLabel}  ·  ${g.goals} goals · ${g.assists} assists'
                        '${g.status == 'pending' ? '  ·  pending' : ''}',
                        style:
                            GoogleFonts.inter(fontSize: 12, color: secondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '+${g.xp} XP',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, size: 18, color: secondary),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── AGENT DETAILS ───────────────────────────────────────────────────────

  Widget _buildAgentDetails({
    required Color primary,
    required Color secondary,
    required Color border,
    required Color surface,
  }) {
    final status = ref.watch(agentVerificationProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Agent Verification',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
            const SizedBox(width: 10),
            _statusBadge(status),
          ],
        ),
        const SizedBox(height: 14),

        // State-driven body
        if (status == AgentVerification.notSubmitted ||
            status == AgentVerification.rejected)
          _verificationForm(primary, secondary, border, surface)
        else if (status == AgentVerification.pending)
          _infoBox(
            color: const Color(0xFFFBBF24),
            icon: Icons.hourglass_top,
            text:
                'Submitted! An admin is reviewing your ID and bank details. You can play games meanwhile — creating games unlocks once approved.',
          )
        else
          _infoBox(
            color: const Color(0xFF22C55E),
            icon: Icons.verified,
            text:
                'You are a verified agent! The + button on the home screen is now unlocked — go create your first game.',
          ),

        const SizedBox(height: 16),

        // Dashboard entry
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => context.pushNamed('agent-dashboard'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.orange.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.dashboard_outlined,
                size: 18, color: AppColors.orange),
            label: Text('Agent Dashboard',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange)),
          ),
        ),
      ],
    );
  }

  Widget _verificationForm(
      Color primary, Color secondary, Color border, Color surface) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Full Legal Name', secondary),
        const SizedBox(height: 6),
        _textField(_fullNameCtrl, 'As shown on your ID', primary, secondary,
            border, surface),
        const SizedBox(height: 14),

        // ID type toggle
        _fieldLabel('ID Type', secondary),
        const SizedBox(height: 6),
        Row(
          children: _idTypes.map((t) {
            final active = t == _idType;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _idType = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: active ? AppColors.brandGradient : null,
                    border: Border.all(
                        color: active ? Colors.transparent : border),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(t,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? Colors.white : secondary,
                      )),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        _fieldLabel('$_idType Number', secondary),
        const SizedBox(height: 6),
        _textField(_idNumberCtrl, 'e.g. 990101-14-5678', primary, secondary,
            border, surface),
        const SizedBox(height: 14),

        // ID uploads
        _fieldLabel('Upload $_idType', secondary),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _uploadBox(
                label: 'Upload $_idType Front',
                image: _idFront,
                onTap: () => _pickId(front: true),
                secondary: secondary,
                border: border,
              ),
            ),
            if (_idType == 'MyKad') ...[
              const SizedBox(width: 12),
              Expanded(
                child: _uploadBox(
                  label: 'Upload MyKad Back',
                  image: _idBack,
                  onTap: () => _pickId(front: false),
                  secondary: secondary,
                  border: border,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // Bank — DuitNow
        Text('Bank Account (DuitNow)',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 15, fontWeight: FontWeight.w700, color: primary)),
        const SizedBox(height: 4),
        Text('Must be a Malaysian account that supports DuitNow.',
            style: GoogleFonts.inter(fontSize: 11, color: secondary)),
        const SizedBox(height: 12),
        _fieldLabel('Bank Name', secondary),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedBank,
              hint: Text('Select bank',
                  style: GoogleFonts.inter(fontSize: 14, color: secondary)),
              dropdownColor: surface,
              style: GoogleFonts.inter(fontSize: 14, color: primary),
              items: _banks
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedBank = v),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _fieldLabel('Account Number', secondary),
        const SizedBox(height: 6),
        _textField(_accountNumberCtrl, 'e.g. 1234567890', primary, secondary,
            border, surface,
            keyboardType: TextInputType.number),
        const SizedBox(height: 14),
        _fieldLabel('Account Holder Name', secondary),
        const SizedBox(height: 6),
        _textField(_accountHolderCtrl, 'Full name as per bank', primary,
            secondary, border, surface),
        const SizedBox(height: 16),

        CustomButton(
          label: 'Submit for Verification',
          onPressed: _submitVerification,
        ),
        const SizedBox(height: 10),
        Text(
          'Reviewed within 24 hours. You can browse and join games while you wait.',
          style: GoogleFonts.inter(fontSize: 11, height: 1.5, color: secondary),
        ),
      ],
    );
  }

  Widget _infoBox(
      {required Color color, required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 13, height: 1.5, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(AgentVerification status) {
    late final Color c;
    late final String label;
    switch (status) {
      case AgentVerification.notSubmitted:
        c = const Color(0xFF888888);
        label = 'Not Submitted';
      case AgentVerification.pending:
        c = const Color(0xFFFBBF24);
        label = 'Under Review';
      case AgentVerification.approved:
        c = const Color(0xFF22C55E);
        label = 'Verified Agent';
      case AgentVerification.rejected:
        c = AppColors.tierElite;
        label = 'Rejected';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        border: Border.all(color: c.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, Color secondary) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: secondary,
        ),
      );

  Widget _textField(
    TextEditingController ctrl,
    String hint,
    Color primary,
    Color secondary,
    Color border,
    Color surface, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: primary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: secondary),
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
    );
  }

  Widget _uploadBox({
    required String label,
    required Uint8List? image,
    required VoidCallback onTap,
    required Color secondary,
    required Color border,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: image == null ? secondary.withValues(alpha: 0.4) : border,
          ),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.memory(image, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, color: secondary, size: 24),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 11, color: secondary),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
