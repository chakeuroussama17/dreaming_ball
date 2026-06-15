import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/player_avatar.dart';
import '../../../../core/widgets/tier_badge.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'All';

  static const _filters = ['All', 'Players', 'Agents', 'Banned'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final users = ref.watch(adminUsersProvider).where((u) {
      final matchesQuery = _query.isEmpty ||
          u.name.toLowerCase().contains(_query) ||
          u.email.toLowerCase().contains(_query);
      final matchesFilter = switch (_filter) {
        'Players' => u.role == 'Player',
        'Agents' => u.role == 'Agent',
        'Banned' => u.banned,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.goNamed('admin-dashboard'),
        ),
        title: Text('All Users',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: GoogleFonts.inter(fontSize: 14, color: primary),
              decoration: InputDecoration(
                hintText: 'Search by name or email',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: secondary),
                prefixIcon: Icon(Icons.search, color: secondary, size: 20),
                filled: true,
                fillColor: surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.orange),
                ),
              ),
            ),
          ),
          // Filter pills
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final active = _filters[i] == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = _filters[i]),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.brandGradient : null,
                      border:
                          Border.all(color: active ? Colors.transparent : border),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(_filters[i],
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w400,
                            color: active ? Colors.white : secondary)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: users.isEmpty
                ? Center(
                    child: Text('No users found',
                        style:
                            GoogleFonts.inter(fontSize: 14, color: secondary)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: users.length,
                    itemBuilder: (ctx, i) {
                      final u = users[i];
                      return GestureDetector(
                        onTap: () => _detailSheet(
                            u, primary, secondary, border, surface),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: surface,
                            border: Border.all(color: border),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              PlayerAvatar(
                                  fallbackInitials: u.name.substring(0, 1),
                                  radius: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(u.name,
                                              style: GoogleFonts.spaceGrotesk(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: primary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        if (u.banned) ...[
                                          const SizedBox(width: 6),
                                          Text('BANNED',
                                              style: GoogleFonts.inter(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.tierElite)),
                                        ],
                                      ],
                                    ),
                                    Text(u.email,
                                        style: GoogleFonts.inter(
                                            fontSize: 12, color: secondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _rolePill(u.role, secondary),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _rolePill(String role, Color secondary) {
    final c = role == 'Agent' ? AppColors.pink : AppColors.cyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(role,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: c)),
    );
  }

  void _detailSheet(AppUserRecord u, Color primary, Color secondary,
      Color border, Color surface) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PlayerAvatar(
                    fallbackInitials: u.name.substring(0, 1), radius: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name,
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        TierBadge(tier: u.tier),
                        const SizedBox(width: 8),
                        _rolePill(u.role, secondary),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(u.email,
                style: GoogleFonts.inter(fontSize: 13, color: secondary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Lifetime stats from player_profiles (win % isn't
                  // tracked — XP shown instead).
                  _miniStat('Games', '${u.games}', primary, secondary),
                  _miniStat('Goals', '${u.goals}', primary, secondary),
                  _miniStat('XP', '${u.xp}', primary, secondary),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!u.banned)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tierElite,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _banDialog(u, primary, secondary, border, surface);
                  },
                  child: Text('Ban User',
                      style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.6)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    ref.read(adminUsersProvider.notifier).setBanned(u.id, false);
                    Navigator.pop(ctx);
                  },
                  child: Text('Unban User',
                      style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF22C55E))),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.orange.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset link sent')),
                  );
                },
                child: Text('Reset Password',
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w700, color: AppColors.orange)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color primary, Color secondary) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w800, color: primary)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: secondary)),
      ],
    );
  }

  void _banDialog(AppUserRecord u, Color primary, Color secondary, Color border,
      Color surface) {
    final reasonCtrl = TextEditingController();
    var duration = '7 days';
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Ban ${u.name}?',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: reasonCtrl,
                style: GoogleFonts.inter(fontSize: 14, color: primary),
                decoration: InputDecoration(
                  hintText: 'Reason (optional)',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: secondary),
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['7 days', '30 days', 'Permanent'].map((d) {
                  final active = d == duration;
                  return GestureDetector(
                    onTap: () => setD(() => duration = d),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: active ? AppColors.brandGradient : null,
                        border: Border.all(
                            color: active ? Colors.transparent : border),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(d,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active ? Colors.white : secondary)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, color: secondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tierElite,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                ref.read(adminUsersProvider.notifier).setBanned(u.id, true);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${u.name} banned ($duration)')),
                );
              },
              child:
                  const Text('Confirm Ban', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
