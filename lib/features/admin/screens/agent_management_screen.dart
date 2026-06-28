import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/plans.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/services/admin_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';
import '../../../../core/widgets/player_avatar.dart';

class AgentManagementScreen extends ConsumerStatefulWidget {
  const AgentManagementScreen({super.key});

  @override
  ConsumerState<AgentManagementScreen> createState() =>
      _AgentManagementScreenState();
}

class _AgentManagementScreenState extends ConsumerState<AgentManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final agents = ref.watch(adminAgentsProvider);
    final pending =
        agents.where((a) => a.status == AdminAgentStatus.pending).toList();
    final approved = agents
        .where((a) =>
            a.status == AdminAgentStatus.approved ||
            a.status == AdminAgentStatus.suspended)
        .toList();
    final rejected =
        agents.where((a) => a.status == AdminAgentStatus.rejected).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('admin-dashboard'),
        ),
        title: Text('Agent Verification',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.orange,
          labelColor: primary,
          unselectedLabelColor: secondary,
          labelStyle:
              GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Approved (${approved.length})'),
            Tab(text: 'Rejected (${rejected.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _list(pending, primary, secondary, isDark),
          _list(approved, primary, secondary, isDark),
          _list(rejected, primary, secondary, isDark),
        ],
      ),
    );
  }

  Widget _list(
      List<AgentRecord> items, Color primary, Color secondary, bool isDark) {
    if (items.isEmpty) {
      return Center(
        child: Text('Nothing here',
            style: GoogleFonts.inter(fontSize: 14, color: secondary)),
      );
    }
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: items.length,
      itemBuilder: (ctx, i) =>
          _card(items[i], primary, secondary, border, surface),
    );
  }

  Widget _card(AgentRecord a, Color primary, Color secondary, Color border,
      Color surface) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
              PlayerAvatar(fallbackInitials: a.name.substring(0, 1), radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: primary)),
                    Text(a.email,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: secondary)),
                  ],
                ),
              ),
              _statusPill(a.status),
            ],
          ),
          const SizedBox(height: 10),
          _kv('Phone', a.phone, secondary, primary),
          _kv('Registered', a.registeredAt, secondary, primary),
          _kv('Bank', '${a.bankName} · ${_mask(a.accountNumber)}', secondary,
              primary),
          if (a.rejectionReason != null)
            _kv('Reason', a.rejectionReason!, secondary, AppColors.tierElite),
          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: () => _showDocs(a, primary, secondary, border, surface),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(Icons.badge_outlined, size: 16, color: primary),
            label: Text('View Documents',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
          ),
          const SizedBox(height: 8),

          // Actions
          if (a.status == AdminAgentStatus.pending)
            Row(
              children: [
                Expanded(
                  child: _gradientBtn('Approve', () {
                    ref.read(adminAgentsProvider.notifier).approve(a.id);
                    _snack('${a.name} approved');
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectDialog(a, primary, secondary),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.tierElite.withValues(alpha: 0.6)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text('Reject',
                        style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            color: AppColors.tierElite)),
                  ),
                ),
              ],
            )
          else if (a.status == AdminAgentStatus.approved)
            OutlinedButton(
              onPressed: () {
                ref.read(adminAgentsProvider.notifier).suspend(a.id);
                _snack('${a.name} suspended');
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.orange.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text('Suspend',
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700, color: AppColors.orange)),
            )
          else if (a.status == AdminAgentStatus.suspended)
            _gradientBtn('Reinstate', () {
              ref.read(adminAgentsProvider.notifier).approve(a.id);
              _snack('${a.name} reinstated');
            }),

          // Grant a paid plan (after off-platform payment) to active agents.
          if (a.status == AdminAgentStatus.approved ||
              a.status == AdminAgentStatus.suspended) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _grantPlanSheet(a),
              style: OutlinedButton.styleFrom(
                side:
                    BorderSide(color: AppColors.orange.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(44),
              ),
              icon: const Icon(Icons.card_giftcard_rounded,
                  size: 18, color: AppColors.orange),
              label: Text('Grant games / plan',
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700, color: AppColors.orange)),
            ),
          ],
        ],
      ),
    );
  }

  /// Bottom sheet: pick a plan from the dropdown and grant it to [a].
  Future<void> _grantPlanSheet(AgentRecord a) async {
    SubPlan selected = kSubPlans.first;
    final granted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Grant plan to ${a.name}',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                DropdownButtonFormField<SubPlan>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Plan',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final p in kSubPlans)
                      DropdownMenuItem(
                        value: p,
                        child: Text('${p.label} — ${p.summary}',
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setSheet(() => selected = v ?? selected),
                ),
                const SizedBox(height: 8),
                Text(
                  selected.unlimited
                      ? 'Unlimited games for ${selected.days} days.'
                      : 'Adds ${selected.games} games, valid ${selected.days} days.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.orange),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: _gradientBtn(busy ? 'Granting…' : 'Grant plan', () async {
                    if (busy) return;
                    setSheet(() => busy = true);
                    try {
                      await AdminService.grantPlan(a.id, selected);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      setSheet(() => busy = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Failed: $e')));
                      }
                    }
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (granted == true) {
      _snack('${selected.label} granted to ${a.name}');
      ref.invalidate(adminAgentsProvider);
    }
  }

  Widget _gradientBtn(String label, VoidCallback onTap) {
    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.pink, AppColors.orange]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: onTap,
          child: Text(label,
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, Color secondary, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 80,
              child: Text(k,
                  style: GoogleFonts.inter(fontSize: 12, color: secondary))),
          Expanded(
            child: Text(v,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: valueColor)),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(AdminAgentStatus s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.15),
        border: Border.all(color: s.color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(s.label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: s.color)),
    );
  }

  String _mask(String acc) =>
      acc.length <= 4 ? acc : '••••${acc.substring(acc.length - 4)}';

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.orange));

  void _showDocs(AgentRecord a, Color primary, Color secondary, Color border,
      Color surface) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true, // allow the sheet to grow + scroll
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: secondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('${a.name} — Verification',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: primary)),
              Text(a.email,
                  style: GoogleFonts.inter(fontSize: 12, color: secondary)),
              const SizedBox(height: 16),

              // ── Identity ──────────────────────────────────────────────────
              _docSectionTitle('Identity', secondary),
              _docRow('ID Type', a.idType ?? '—', secondary, primary),
              _docRow('ID Number', a.idNumber ?? '—', secondary, primary),
              _docRow('Phone', a.phone, secondary, primary),
              _docRow('Registered', a.registeredAt, secondary, primary),
              const SizedBox(height: 16),

              // ── Bank (for payouts) ────────────────────────────────────────
              _docSectionTitle('Bank (DuitNow payout)', secondary),
              _docRow('Bank', a.bankName, secondary, primary),
              _docRow('Account No.', a.accountNumber.isEmpty ? '—' : a.accountNumber,
                  secondary, primary, copyable: true),
              _docRow('Account Holder', a.accountHolder ?? '—', secondary, primary),
              const SizedBox(height: 18),

              // ── Documents ─────────────────────────────────────────────────
              Row(
                children: [
                  _docSectionTitle('Documents', secondary),
                  const Spacer(),
                  Icon(Icons.touch_app_outlined, size: 13, color: secondary),
                  const SizedBox(width: 4),
                  Text('Tap to zoom',
                      style: GoogleFonts.inter(fontSize: 11, color: secondary)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: _docBox('${a.idType ?? 'ID'} Front', a.idFrontPath,
                          border, secondary)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _docBox('${a.idType ?? 'ID'} Back', a.idBackPath,
                          border, secondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _docSectionTitle(String text, Color secondary) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: secondary)),
      );

  Widget _docRow(String k, String v, Color secondary, Color valueColor,
      {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(k,
                  style: GoogleFonts.inter(fontSize: 13, color: secondary))),
          Expanded(
            child: Text(v,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor)),
          ),
          if (copyable && v != '—')
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: v));
                _snack('Copied');
              },
              child: Icon(Icons.copy, size: 15, color: secondary),
            ),
        ],
      ),
    );
  }

  Widget _docBox(String label, String? path, Color border, Color secondary) {
    return Column(
      children: [
        // Private bucket → fetch a short-lived signed URL, then show it.
        FutureBuilder<String?>(
          future: path == null ? Future.value(null) : AdminService.kycSignedUrl(path),
          builder: (ctx, snap) {
            Widget inner;
            String? url;
            if (path == null) {
              inner = Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      color: secondary, size: 28));
            } else if (snap.connectionState != ConnectionState.done) {
              inner = const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.orange)));
            } else if ((url = snap.data) == null) {
              inner = Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: secondary, size: 28));
            } else {
              inner = Image.network(url!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 140,
                  errorBuilder: (_, _, _) => Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: secondary, size: 28)));
            }
            return GestureDetector(
              onTap: url == null ? null : () => _openFullImage(url!, label),
              child: Container(
                height: 140,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(color: border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: inner,
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: secondary)),
      ],
    );
  }

  /// Full-screen, pinch-to-zoom view of a document image.
  void _openFullImage(String url, String label) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Stack(
        children: [
          // Pinch / pan to zoom.
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Image.network(url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48)),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
          Positioned(
            top: 32,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    );
  }

  void _rejectDialog(AgentRecord a, Color primary, Color secondary) {
    final ctrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Reject ${a.name}?',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          style: GoogleFonts.inter(fontSize: 14, color: primary),
          decoration: InputDecoration(
            hintText: 'Reason (e.g. blurry MyKad)',
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
              ref.read(adminAgentsProvider.notifier).reject(
                  a.id,
                  ctrl.text.trim().isEmpty
                      ? 'Not specified'
                      : ctrl.text.trim());
              Navigator.pop(ctx);
              _snack('${a.name} rejected');
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
