import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';

/// A player's avatar, set in a gold ring.
///
/// Photos and initials both sit inside the same bevelled gold rim so avatars
/// read as one consistent object — a medallion — rather than two different
/// shapes. The initials fallback fills with the brand metal and carves the
/// letters out in navy.
class PlayerAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackInitials;
  final double radius;

  const PlayerAvatar({
    super.key,
    this.imageUrl,
    required this.fallbackInitials,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final ringWidth = (radius * 0.09).clamp(1.5, 3.0);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.goldMetal,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.28),
            blurRadius: radius * 0.5,
            offset: Offset(0, radius * 0.12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: radius * 0.25,
            offset: Offset(0, radius * 0.06),
          ),
        ],
      ),
      padding: EdgeInsets.all(ringWidth),
      child: hasImage
          ? DecoratedBox(
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (_, _) =>
                      const ColoredBox(color: AppColors.navySurface),
                  errorWidget: (_, _, _) => _initials(),
                ),
              ),
            )
          : _initials(),
    );
  }

  Widget _initials() => DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppColors.navySurface, AppColors.navyDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            fallbackInitials.toUpperCase(),
            style: TextStyle(
              color: AppColors.gold,
              fontSize: radius * 0.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
}
