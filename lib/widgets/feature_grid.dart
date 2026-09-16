import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../screens/qibla_screen.dart';
import '../screens/zakat_screen.dart';
import '../screens/daily_duas_screen.dart';
import '../screens/asmaul_husna_screen.dart';
import '../screens/hajj_umrah_screen.dart';
import '../screens/tasbih_screen.dart';

/// Distilled MVP strip: one quiet horizontal row, not six equal cards.
/// Each item is a 48dp tappable with tonal circle + label underneath.
/// No nested cards, no repeated heavy borders — calm, scannable, elder-friendly.
class HomeFeatureStrip extends StatelessWidget {
  const HomeFeatureStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final items = <_StripItem>[
      _StripItem(Icons.auto_awesome_rounded, l.featureAsmaulHusna,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AsmaulHusnaScreen()))),
      _StripItem(Icons.menu_book_outlined, l.featureDailyDuas,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyDuasScreen()))),
      _StripItem(Icons.luggage_outlined, l.featureHajjUmrah,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HajjUmrahScreen()))),
      _StripItem(Icons.explore_outlined, l.featureQibla,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QiblaScreen()))),
      _StripItem(Icons.circle_outlined, l.featureTasbih, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasbihScreen()))),
      _StripItem(Icons.calculate_outlined, l.featureZakat,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ZakatScreen()))),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 4),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _stripButton(context, scheme, items[i]),
      ),
    );
  }

  Widget _stripButton(BuildContext context, ColorScheme scheme, _StripItem item) {
    return Semantics(
      button: true,
      label: item.label.replaceAll('\n', ' '),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(item.icon, size: 22, color: scheme.primary),
              ),
              const SizedBox(height: 8),
              Text(
                item.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StripItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _StripItem(this.icon, this.label, this.onTap);
}

/// Legacy 3x2 grid kept for compatibility — no longer used on Home.
/// Kept to avoid breaking other call sites; new code should use [HomeFeatureStrip].
class HomeFeatureGrid extends StatelessWidget {
  const HomeFeatureGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeFeatureStrip();
  }
}
