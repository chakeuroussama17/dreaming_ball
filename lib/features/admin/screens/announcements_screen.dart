import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/admin_providers.dart';
import '../../../../core/providers/content_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/nav.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final items = ref.watch(announcementsProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: primary),
          onPressed: () => context.safePop('admin-dashboard'),
        ),
        title: Text('Announcements',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.gold),
            onPressed: () => _editSheet(context, ref, null, primary, secondary,
                border, surface),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final a = items[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Banner preview — uploaded photo behind the badge + title
                Container(
                  height: 70,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15)),
                    gradient: LinearGradient(colors: a.badge.gradient),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (a.photoUrl != null) ...[
                        CachedNetworkImage(
                          imageUrl: a.photoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                        Container(color: Colors.black.withValues(alpha: 0.35)),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(a.badge.label,
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                            const SizedBox(height: 4),
                            Text(a.title,
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(a.subtitle,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: secondary)),
                      ),
                      Switch(
                        value: a.isActive,
                        activeThumbColor: AppColors.gold,
                        onChanged: (_) async {
                          await ref
                              .read(announcementsProvider.notifier)
                              .toggle(a.id);
                          ref.invalidate(announcementsRemoteProvider);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            size: 18, color: secondary),
                        onPressed: () => _editSheet(context, ref, a, primary,
                            secondary, border, surface),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.tierElite),
                        onPressed: () =>
                            _confirmDelete(context, ref, a, primary, secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Announcement a,
      Color primary, Color secondary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete announcement?',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 18, fontWeight: FontWeight.w700, color: primary)),
        content: Text('"${a.title}" will be removed from the home feed.',
            style: GoogleFonts.inter(fontSize: 14, color: secondary)),
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
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(announcementsProvider.notifier).remove(a.id);
              ref.invalidate(announcementsRemoteProvider);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editSheet(BuildContext context, WidgetRef ref, Announcement? existing,
      Color primary, Color secondary, Color border, Color surface) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final subtitleCtrl = TextEditingController(text: existing?.subtitle ?? '');
    var badge = existing?.badge ?? BadgeType.news;
    var active = existing?.isActive ?? true;
    Uint8List? bannerBytes;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'New Announcement' : 'Edit Announcement',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: primary)),
              const SizedBox(height: 16),
              _field(titleCtrl, 'Title (max 50)', primary, secondary, border,
                  maxLength: 50),
              const SizedBox(height: 12),
              _field(subtitleCtrl, 'Subtitle (max 100)', primary, secondary,
                  border,
                  maxLength: 100),
              const SizedBox(height: 16),
              Text('Badge Type',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BadgeType.values.map((b) {
                  final activeB = b == badge;
                  return GestureDetector(
                    onTap: () => setSheet(() => badge = b),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: activeB
                            ? LinearGradient(colors: b.gradient)
                            : null,
                        border: Border.all(
                            color: activeB ? Colors.transparent : border),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(b.label,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: activeB ? Colors.white : secondary)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (file != null) {
                    final bytes = await file.readAsBytes();
                    setSheet(() => bannerBytes = bytes);
                  }
                },
                child: Container(
                  height: 80,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: bannerBytes != null
                      // Freshly-picked image preview
                      ? Image.memory(bannerBytes!,
                          fit: BoxFit.cover, width: double.infinity)
                      : existing?.photoUrl != null
                          // Current saved banner (editing)
                          ? CachedNetworkImage(
                              imageUrl: existing!.photoUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorWidget: (_, _, _) =>
                                  const SizedBox.shrink())
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    color: secondary, size: 24),
                                const SizedBox(height: 4),
                                Text('Banner image (optional)',
                                    style: GoogleFonts.inter(
                                        fontSize: 11, color: secondary)),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Active on home',
                      style: GoogleFonts.inter(fontSize: 13, color: primary)),
                  const Spacer(),
                  Switch(
                    value: active,
                    activeThumbColor: AppColors.gold,
                    onChanged: (v) => setSheet(() => active = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.goldActionStart, AppColors.goldActionEnd]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Title is required')),
                        );
                        return;
                      }
                      final notifier =
                          ref.read(announcementsProvider.notifier);
                      Navigator.pop(ctx);
                      final ok = existing == null
                          ? await notifier.add(Announcement(
                              id: 'pending',
                              title: titleCtrl.text.trim(),
                              subtitle: subtitleCtrl.text.trim(),
                              badge: badge,
                              isActive: active,
                              photo: bannerBytes,
                            ))
                          : await notifier.update(existing.copyWith(
                              title: titleCtrl.text.trim(),
                              subtitle: subtitleCtrl.text.trim(),
                              badge: badge,
                              isActive: active,
                              photo: bannerBytes,
                            ));
                      // Home banner reads its own provider — refresh it so
                      // players/agents see the change on next visit.
                      ref.invalidate(announcementsRemoteProvider);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor:
                              ok ? AppColors.gold : AppColors.tierElite,
                          content: Text(ok
                              ? 'Announcement published!'
                              : 'Could not save — check your connection')));
                    },
                    child: Text('Save Announcement',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, Color primary,
      Color secondary, Color border,
      {int? maxLength}) {
    return TextField(
      controller: ctrl,
      maxLength: maxLength,
      style: GoogleFonts.inter(fontSize: 14, color: primary),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 13, color: secondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }
}
