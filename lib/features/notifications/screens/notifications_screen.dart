import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/content_providers.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the screen clears the bell badge (rows show as unread once,
    // realtime delivers the update back to the stream).
    NotificationService.markAllRead();
  }

  (IconData, Color) _style(String type) => switch (type) {
        'game' => (Icons.sports_soccer, AppColors.orange),
        'stats' => (Icons.emoji_events_outlined, AppColors.pink),
        'dispute' => (Icons.flag_outlined, AppColors.tierElite),
        'payment' => (Icons.payments_outlined, const Color(0xFF22C55E)),
        'announcement' => (Icons.campaign_outlined, AppColors.cyan),
        _ => (Icons.info_outline, AppColors.orange),
      };

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

    final async = ref.watch(notificationsStreamProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.pop(),
        ),
        title: Text('Notifications',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
      ),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                color: AppColors.orange, strokeWidth: 2.5)),
        error: (_, _) => Center(
          child: Text("Couldn't load notifications",
              style: GoogleFonts.inter(fontSize: 13, color: secondary)),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none,
                      size: 48, color: secondary.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('Nothing yet',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: primary)),
                  const SizedBox(height: 4),
                  Text('Match updates, stats and disputes land here.',
                      style:
                          GoogleFonts.inter(fontSize: 12, color: secondary)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final n = items[i];
              final (icon, color) = _style(n.type);
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: !n.isRead
                      ? AppColors.orange.withValues(alpha: 0.06)
                      : surface,
                  border: Border.all(
                      color: !n.isRead
                          ? AppColors.orange.withValues(alpha: 0.2)
                          : border),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(n.title,
                                    style: GoogleFonts.spaceGrotesk(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: primary)),
                              ),
                              Text(n.timeLabel,
                                  style: GoogleFonts.inter(
                                      fontSize: 11, color: secondary)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(n.body,
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: secondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
