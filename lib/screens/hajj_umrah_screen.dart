import 'package:flutter/material.dart';
import '../data/hajj_guide.dart';
import '../l10n/l10n.dart';
import '../widgets/liquid_glass.dart';

class HajjUmrahScreen extends StatefulWidget {
  const HajjUmrahScreen({super.key});
  @override
  State<HajjUmrahScreen> createState() => _HajjUmrahScreenState();
}

class _HajjUmrahScreenState extends State<HajjUmrahScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: hajjUmrahGuides.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.hajjTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            Text(
              l.hajjSubtitle,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: .72),
                fontSize: 12,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurface.withValues(alpha: .72),
          indicatorColor: scheme.primary,
          tabs: [
            for (final g in hajjUmrahGuides) Tab(text: g.textFor(language).title),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final g in hajjUmrahGuides) _guideTab(g, language),
        ],
      ),
    );
  }

  Widget _guideTab(GuideSection g, String language) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        LiquidGlassCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Text(
            g.textFor(language).intro,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: scheme.onSurface.withValues(alpha: .75),
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < g.steps.length; i++) ...[
          _stepCard(g.steps[i], language),
          if (i != g.steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(left: 27),
              child: Container(
                width: 2,
                height: 14,
                color: scheme.primary.withValues(alpha: .25),
              ),
            ),
        ],
        const SizedBox(height: 12),
        Text(
          l.hajjFootnote,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: .72),
          ),
        ),
      ],
    );
  }

  Widget _stepCard(GuideStep s, String language) {
    final scheme = Theme.of(context).colorScheme;
    final text = s.textFor(language);
    return RepaintBoundary(
      child: LiquidGlassCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: .12),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: .22),
                ),
              ),
              child: Center(
                child: Text(
                  '${s.order}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text.place,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                      color: scheme.onSurface.withValues(alpha: .72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
