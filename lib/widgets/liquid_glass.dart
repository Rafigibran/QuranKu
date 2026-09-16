import 'package:flutter/material.dart';

/// Tonal surface primitives for QuranKu (malam-veranda world).
///
/// Deliberately no blur: depth comes from Material 3 tonal elevation and
/// hairline dividers, so the interface stays calm, cheap to render, and
/// conformant on both Android (M3) and iOS (HIG bars/sheets) targets.
/// The historic `LiquidGlass*` names are kept so existing call sites
/// migrate worlds without per-screen rewrites; `blur`/`tint` are accepted
/// and ignored/resolved to tonal roles.
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 22,
    this.onTap,
    this.tint,
    this.blur = 0,
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
    final fill = tint ?? scheme.surfaceContainerLow;
    final border = scheme.outlineVariant;

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );

    if (onTap != null) {
      surface = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          splashColor: scheme.primary.withValues(alpha: 0.10),
          highlightColor: scheme.primary.withValues(alpha: 0.06),
          child: surface,
        ),
      );
    }

    return Container(margin: margin, child: surface);
  }
}

/// A row in a list. Deliberately not a card.
///
/// This is the composition rule of the world made executable. `DESIGN.md`
/// reserves the card for the one focal element per screen, and lists are rows
/// on the page separated by hairlines. A screen that stacks a card per item is
/// the "glass shelf" the surface brief refuses, and it is what made 25 screens
/// read as one repeated screen. Swapping a list's `LiquidGlassCard` for
/// `SurfaceRow` is the whole change.
class SurfaceRow extends StatelessWidget {
  const SurfaceRow({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    this.divider = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Hairline under the row. Turn off for the final row in a list.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget row = Padding(padding: padding, child: child);
    if (onTap != null) {
      row = Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: row),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: scheme.outlineVariant))
            : null,
      ),
      child: row,
    );
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onSecondaryContainer),
        child: child,
      ),
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
    return Semantics(
      button: true,
      label: semanticLabel ?? tooltip,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: scheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            splashColor: scheme.primary.withValues(alpha: 0.10),
            child: Icon(
              icon,
              size: 23,
              color: onPressed != null
                  ? scheme.onSurfaceVariant
                  : scheme.onSurface.withValues(alpha: 0.35),
            ),
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
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Single continuous thread: khatam, read progress, audio progress.
/// One 4px track, green fill, no floating knob — the tasbih string.
class ThreadProgress extends StatelessWidget {
  const ThreadProgress({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        minHeight: 4,
        value: value.clamp(0.0, 1.0),
        backgroundColor: scheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
      ),
    );
  }
}

/// Read-bead dot: filled green when read, tonal ring when unread.
/// Perceivable without color alone via filled vs ring shape.
class BeadDot extends StatelessWidget {
  const BeadDot({super.key, required this.filled, this.size = 8});

  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? scheme.primary : Colors.transparent,
        border: Border.all(
          color: filled ? scheme.primary : scheme.outline,
          width: 1.4,
        ),
      ),
    );
  }
}
