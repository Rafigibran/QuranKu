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
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: scheme.primary,
          tabs: [
            for (final g in hajjUmrahGuides)
              Tab(text: g.textFor(language).title),
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
    final text = g.textFor(language);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        // The one focal card on this screen: what the guide covers.
        LiquidGlassCard(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Text(
            text.intro,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ),
        for (final list in text.lists) ...[
          const SizedBox(height: 22),
          _referenceBlock(list),
        ],
        const SizedBox(height: 26),
        LiquidGlassSectionTitle(
          title: l.hajjOrderTitle,
          subtitle: l.hajjOrderSubtitle,
        ),
        for (var i = 0; i < g.steps.length; i++)
          _stepRow(g.steps[i], language, i == g.steps.length - 1),
        const SizedBox(height: 22),
        Text(
          l.hajjArabicNotice,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          l.hajjFootnote,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// A titled reference list, for example the pillars or the prohibitions.
  /// It reads as a labelled block on the page, not as another card.
  Widget _referenceBlock(GuideList list) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          list.title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        for (final item in list.items) _bullet(item),
      ],
    );
  }

  Widget _stepRow(GuideStep s, String language, bool isLast) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = s.textFor(language);
    return SurfaceRow(
      divider: !isLast,
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The bead on the thread: the step number.
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: .12),
              border: Border.all(color: scheme.primary.withValues(alpha: .22)),
            ),
            alignment: Alignment.center,
            child: Text(
              '${s.order}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: scheme.primary,
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
                const SizedBox(height: 6),
                Text(
                  text.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.55,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (text.sunnah.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _subLabel(l.hajjSunnah),
                  const SizedBox(height: 4),
                  for (final item in text.sunnah) _bullet(item),
                ],
                if (text.dua != null) ...[
                  const SizedBox(height: 12),
                  _subLabel(l.hajjDua),
                  const SizedBox(height: 4),
                  Text(
                    text.dua!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (text.note != null) ...[
                  const SizedBox(height: 12),
                  _note(l.hajjNote, text.note!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subLabel(String label) => Text(
    label,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w800,
      color: Theme.of(context).colorScheme.primary,
    ),
  );

  Widget _bullet(String item) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7, right: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A ruling that needs a qualifier, or a point where the schools differ.
  Widget _note(String label, String body) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
