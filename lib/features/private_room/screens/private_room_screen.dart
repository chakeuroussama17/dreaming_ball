import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/game_service.dart' show GameServiceException;
import '../../../../core/services/room_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/share_utils.dart';
import '../../../../core/widgets/custom_input.dart';
import '../../../../core/widgets/custom_button.dart';

class PrivateRoomScreen extends StatefulWidget {
  const PrivateRoomScreen({super.key});

  @override
  State<PrivateRoomScreen> createState() => _PrivateRoomScreenState();
}

class _PrivateRoomScreenState extends State<PrivateRoomScreen> {
  int _tab = 0; // 0 = create, 1 = join, 2 = my rooms

  // My Rooms tab — loaded lazily when the tab is opened.
  Future<List<RoomSummary>>? _myRoomsFuture;

  // Create form
  final _createFormKey = GlobalKey<FormState>();
  final _roomNameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _maxPlayersCtrl = TextEditingController(text: '10');
  DateTime? _date;
  TimeOfDay? _time;
  bool _creating = false;

  // Join form
  final _codeCtrl = TextEditingController();
  bool _finding = false;

  @override
  void dispose() {
    _roomNameCtrl.dispose();
    _locationCtrl.dispose();
    _maxPlayersCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
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

    // It's a root tab, so the system back button has nothing to pop and would
    // exit the app — send it to Home instead.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.goNamed('home');
      },
      child: Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.brandGradient.createShader(b),
                  child: Text(
                    'Private Room',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // ── Pill tab toggle ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  children: [
                    _tabPill('Create', 0, secondary),
                    _tabPill('Join', 1, secondary),
                    _tabPill('My Rooms', 2, secondary),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Animated tab content ────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: switch (_tab) {
                  0 => _buildCreate(
                      key: const ValueKey('create'),
                      isDark: isDark,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                    ),
                  1 => _buildJoin(
                      key: const ValueKey('join'),
                      isDark: isDark,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                    ),
                  _ => _buildMyRooms(
                      key: const ValueKey('myrooms'),
                      isDark: isDark,
                      primary: primary,
                      secondary: secondary,
                      border: border,
                    ),
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          switch (i) {
            case 0:
              context.goNamed('home');
            case 1:
              context.goNamed('leaderboard');
            case 3:
              context.goNamed('profile');
            default:
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Rankings'),
          BottomNavigationBarItem(icon: Icon(Icons.lock_outline), label: 'Private'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      // (Re)load the list every time My Rooms is opened so it reflects the
      // latest joins/leaves.
      if (index == 2) _myRoomsFuture = RoomService.fetchMyRooms();
    });
  }

  Widget _tabPill(String label, int index, Color secondary) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: active ? AppColors.brandGradient : null,
            borderRadius: BorderRadius.circular(99),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : secondary,
            ),
          ),
        ),
      ),
    );
  }

  // ── MY ROOMS TAB ────────────────────────────────────────────────────────

  Widget _buildMyRooms({
    required Key key,
    required bool isDark,
    required Color primary,
    required Color secondary,
    required Color border,
  }) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    return RefreshIndicator(
      key: key,
      onRefresh: () async {
        final f = RoomService.fetchMyRooms();
        setState(() => _myRoomsFuture = f);
        await f;
      },
      child: FutureBuilder<List<RoomSummary>>(
        future: _myRoomsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(
                child: Text('Could not load your rooms',
                    style: GoogleFonts.inter(fontSize: 14, color: secondary)),
              ),
            ]);
          }
          final rooms = snap.data ?? const [];
          if (rooms.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 70),
              Icon(Icons.groups_outlined,
                  size: 48, color: secondary.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Center(
                child: Text('No rooms yet',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primary)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text('Create a room or join one with a code',
                    style: GoogleFonts.inter(fontSize: 13, color: secondary)),
              ),
            ]);
          }
          // Upcoming = not yet ended (soonest first); Past = ended (latest first).
          final upcoming = rooms.where((s) => !s.room.isEnded).toList()
            ..sort((a, b) => (a.room.scheduledAt ?? DateTime(2100))
                .compareTo(b.room.scheduledAt ?? DateTime(2100)));
          final past = rooms.where((s) => s.room.isEnded).toList()
            ..sort((a, b) => (b.room.scheduledAt ?? DateTime(0))
                .compareTo(a.room.scheduledAt ?? DateTime(0)));
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              if (upcoming.isNotEmpty) ...[
                _sectionHeader('Upcoming', secondary),
                for (final s in upcoming)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _roomTile(s, primary, secondary, border, surface,
                        ended: false),
                  ),
              ],
              if (past.isNotEmpty) ...[
                if (upcoming.isNotEmpty) const SizedBox(height: 10),
                _sectionHeader('Past games', secondary),
                for (final s in past)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _roomTile(s, primary, secondary, border, surface,
                        ended: true),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String text, Color secondary) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: secondary)),
      );

  Widget _roomTile(RoomSummary s, Color primary, Color secondary, Color border,
      Color surface,
      {required bool ended}) {
    final dateLabel = s.room.scheduledAt == null
        ? null
        : DateFormat('EEE, MMM d · h:mm a').format(s.room.scheduledAt!);
    return Opacity(
      opacity: ended ? 0.65 : 1,
      child: GestureDetector(
        onTap: () async {
          await context
              .pushNamed('room-detail', pathParameters: {'id': s.room.id});
          // Coming back may have changed membership — refresh.
          if (mounted) {
            setState(() => _myRoomsFuture = RoomService.fetchMyRooms());
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: ended ? null : AppColors.brandGradient,
                  color: ended ? secondary.withValues(alpha: 0.15) : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(ended ? Icons.history : Icons.lock_outline,
                    color: ended ? secondary : Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(s.room.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: primary)),
                        ),
                        if (s.isCreator) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text('Host',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.orange)),
                          ),
                        ],
                      ],
                    ),
                    if (dateLabel != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        Icon(Icons.schedule, size: 13, color: secondary),
                        const SizedBox(width: 4),
                        Text(dateLabel,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: secondary)),
                      ]),
                    ],
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.people_outline, size: 13, color: secondary),
                      const SizedBox(width: 4),
                      Text('${s.memberCount}/${s.room.maxPlayers}',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: secondary)),
                      if ((s.room.location ?? '').isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.location_on_outlined,
                            size: 13, color: secondary),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(s.room.location!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: secondary)),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              if (!ended) ...[
                Text(s.room.code,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: AppColors.orange)),
                const SizedBox(width: 6),
              ],
              Icon(Icons.chevron_right, color: secondary),
            ],
          ),
        ),
      ),
    );
  }

  // ── CREATE TAB ──────────────────────────────────────────────────────────

  Widget _buildCreate({
    required Key key,
    required bool isDark,
    required Color primary,
    required Color secondary,
    required Color border,
  }) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final dateText = _date == null
        ? 'Select date'
        : '${_date!.day}/${_date!.month}/${_date!.year}';
    final timeText = _time == null ? 'Select time' : _time!.format(context);

    return ListView(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(
          'Set up a casual game with friends. No stats, no payments — just football.',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: secondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Form(
          key: _createFormKey,
          child: Column(
            children: [
              CustomInput(
                label: 'Room Name',
                hint: 'e.g. Friday Kickabout',
                controller: _roomNameCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Date picker field
              _pickerField(
                label: 'Date',
                value: dateText,
                icon: Icons.calendar_today_outlined,
                placeholderSelected: _date != null,
                primary: primary,
                secondary: secondary,
                border: border,
                surface: surface,
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 16),

              // Time picker field
              _pickerField(
                label: 'Time',
                value: timeText,
                icon: Icons.access_time,
                placeholderSelected: _time != null,
                primary: primary,
                secondary: secondary,
                border: border,
                surface: surface,
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) setState(() => _time = picked);
                },
              ),
              const SizedBox(height: 16),

              CustomInput(
                label: 'Location / Field Name',
                hint: 'e.g. Padang ABC, Banting',
                controller: _locationCtrl,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              CustomInput(
                label: 'Max Players',
                hint: '4 – 22',
                controller: _maxPlayersCtrl,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null) return 'Enter a number';
                  if (n < 4 || n > 22) return 'Must be between 4 and 22';
                  return null;
                },
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Friends can still join after limit — this is just a guide',
                  style: GoogleFonts.inter(fontSize: 11, color: secondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        CustomButton(
          label: 'Create Room',
          isLoading: _creating,
          onPressed: () => _createRoom(isDark),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Future<void> _createRoom(bool isDark) async {
    if (_creating) return;
    if (_date == null || _time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time')),
      );
      return;
    }
    if (!_createFormKey.currentState!.validate()) return;
    setState(() => _creating = true);
    try {
      // Combine the picked date + time into the match start. A room counts as
      // ended 2 hours after this (handled in Room.isEnded).
      final start = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _time!.hour,
        _time!.minute,
      );
      final room = await RoomService.createRoom(
        name: _roomNameCtrl.text.trim(),
        location: _locationCtrl.text.trim(),
        maxPlayers: int.tryParse(_maxPlayersCtrl.text) ?? 10,
        scheduledAt: start,
      );
      if (!mounted) return;
      setState(() => _creating = false);
      _showSuccessSheet(room.code, room.id, isDark);
    } on GameServiceException catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      final msg = e.message.contains('signed in')
          ? 'Session expired — please sign in again'
          : e.message;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Widget _pickerField({
    required String label,
    required String value,
    required IconData icon,
    required bool placeholderSelected,
    required Color primary,
    required Color secondary,
    required Color border,
    required Color surface,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: secondary,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: secondary),
                const SizedBox(width: 10),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: placeholderSelected ? primary : secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── JOIN TAB ────────────────────────────────────────────────────────────

  Widget _buildJoin({
    required Key key,
    required bool isDark,
    required Color primary,
    required Color secondary,
    required Color border,
  }) {
    return ListView(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 200,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline,
                    size: 48, color: secondary.withValues(alpha: 0.5)),
                const SizedBox(height: 10),
                Text(
                  'Have a code?',
                  style: GoogleFonts.inter(fontSize: 14, color: secondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _codeCtrl,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          inputFormatters: [
            UpperCaseTextFormatter(),
            FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
          ],
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
            color: primary,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Enter code e.g. QW112',
            hintStyle: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              letterSpacing: 1,
              color: secondary,
            ),
            filled: true,
            fillColor:
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        CustomButton(
          label: 'Find Room',
          isLoading: _finding,
          onPressed: _joinRoom,
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Future<void> _joinRoom() async {
    if (_finding) return;
    if (_codeCtrl.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code must be 6 characters')),
      );
      return;
    }
    setState(() => _finding = true);
    try {
      final room = await RoomService.joinRoomByCode(_codeCtrl.text);
      if (!mounted) return;
      setState(() => _finding = false);
      context.pushNamed('room-detail', pathParameters: {'id': room.id});
    } on GameServiceException catch (e) {
      if (!mounted) return;
      setState(() => _finding = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── SUCCESS SHEET ─────────────────────────────────────────────────────────

  void _showSuccessSheet(String code, String roomId, bool isDark) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.pink, AppColors.orange],
                ),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 34),
            )
                .animate()
                .scale(
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1, 1),
                ),
            const SizedBox(height: 16),
            Text(
              'Room Created!',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Share this code with your friends',
              style: GoogleFonts.inter(fontSize: 13, color: secondary),
            ),
            const SizedBox(height: 20),

            // Code box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.pink.withValues(alpha: 0.07),
                border:
                    Border.all(color: AppColors.pink.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [AppColors.pink, AppColors.orange],
                  ).createShader(b),
                  child: Text(
                    code,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Copy + WhatsApp
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied!')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(Icons.copy, size: 16, color: primary),
                      label: Text(
                        'Copy Code',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => ShareUtils.shareViaWhatsApp(
                          'Join my Dreaming Ball private room! '
                          'Open the app, tap "Join Room" and enter code: $code'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF25D366)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.chat,
                          size: 16, color: Color(0xFF25D366)),
                      label: Text(
                        'WhatsApp',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF25D366),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Or share the link:',
              style: GoogleFonts.inter(fontSize: 12, color: secondary),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {},
              child: Text(
                'dreamingball.app/room/$code',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.orange,
                ),
              ),
            ),
            const SizedBox(height: 20),
            CustomButton(
              label: 'Go to Room',
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pushNamed('room-detail', pathParameters: {'id': roomId});
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Forces typed text to uppercase (used by the join-code field).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
