import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared Liquid Glass primitives for QuranKu.
///
/// The effect is deliberately restrained: blur + a translucent surface + a
/// subtle border. This keeps controls readable for older users while still
/// giving the app a modern glass aesthetic.
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 24,
    this.onTap,
    this.tint,
    this.blur = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final Color? tint;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = tint ?? (isDark ? Colors.white : Colors.white);
    final fill = base.withValues(alpha: isDark ? 0.07 : 0.60);
    final border = Colors.white.withValues(alpha: isDark ? 0.12 : 0.72);
    final shadow = Colors.black.withValues(alpha: isDark ? 0.20 : 0.06);

    Widget surface = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      surface = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          splashColor: scheme.primary.withValues(alpha: 0.10),
          highlightColor: scheme.primary.withValues(alpha: 0.05),
          child: surface,
        ),
      );
    }

    return Container(margin: margin, child: surface);
  }
}

class LiquidGlassPill extends StatelessWidget {
  const LiquidGlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      radius: 999,
      padding: padding,
      blur: 12,
      child: child,
    );
  }
}

class LiquidGlassIconButton extends StatelessWidget {
  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      label: semanticLabel ?? tooltip,
      child: SizedBox(
        width: 52,
        height: 52,
        child: LiquidGlassCard(
          radius: 18,
          padding: EdgeInsets.zero,
          onTap: onPressed,
          child: Icon(
            icon,
            size: 23,
            color: enabled
                ? scheme.onSurface
                : scheme.onSurface.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class LiquidGlassSectionTitle extends StatelessWidget {
  const LiquidGlassSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.62),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
