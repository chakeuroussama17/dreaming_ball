import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

enum ButtonVariant { filled, ghost }

/// The app's primary action.
///
/// The filled variant is a machined gold plate: a diagonal metal gradient, a
/// bright bevel along the top edge, a dark bevel along the bottom, and a gold
/// halo beneath. Pressing it physically depresses the plate — the button
/// shrinks slightly and its shadow collapses, so the touch reads as force
/// applied to a real object.
class CustomButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonVariant variant;

  const CustomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.filled,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  void _setPressed(bool v) {
    if (!_enabled || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    // Gold is a light surface, so its label is the deep navy from the crest.
    final filledLabelColor =
        _enabled ? AppColors.navyDeep : AppColors.darkTextSecondary;
    final ghostLabelColor =
        isDark ? AppColors.cream : AppColors.lightTextPrimary;

    Widget label(Color color) => widget.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: color, strokeWidth: 2),
          )
        : Text(
            widget.label,
            style: GoogleFonts.spaceGrotesk(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          );

    final child = widget.variant == ButtonVariant.ghost
        ? _ghost(bgColor, ghostLabelColor, label)
        : _filled(filledLabelColor, label);

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _enabled ? widget.onPressed : null,
      child: AnimatedScale(
        // The depress. Small enough to feel tactile, not bouncy.
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: SizedBox(width: double.infinity, height: 52, child: child),
      ),
    );
  }

  /// Outlined variant: a gold rim around the page background.
  Widget _ghost(Color bgColor, Color labelColor, Widget Function(Color) label) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      decoration: BoxDecoration(
        gradient: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(14),
        boxShadow: _pressed || !_enabled ? null : AppColors.shadowSoft,
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12.5),
        ),
        alignment: Alignment.center,
        child: label(labelColor),
      ),
    );
  }

  /// Filled variant: the machined gold plate.
  Widget _filled(Color labelColor, Widget Function(Color) label) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      decoration: BoxDecoration(
        gradient: _enabled ? AppColors.goldMetal : null,
        color: _enabled ? null : AppColors.navyElev,
        borderRadius: BorderRadius.circular(14),
        // The halo lifts the plate off the page; it collapses on press.
        boxShadow: !_enabled
            ? null
            : _pressed
                ? AppColors.shadowSoft
                : AppColors.glowGold,
      ),
      child: Stack(
        children: [
          if (_enabled) ...[
            // Bevel: bright top edge, dark bottom edge.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: const Border(
                    top: BorderSide(
                        color: AppColors.bevelGoldLight, width: 1.2),
                    bottom: BorderSide(color: Color(0x4D5A3F12), width: 1.2),
                  ),
                ),
              ),
            ),
            // Specular sheen across the upper third of the plate.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.28),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
          Center(child: label(labelColor)),
        ],
      ),
    );
  }
}
