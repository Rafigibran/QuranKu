import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quranku/l10n/app_localizations.dart';
import '../data/asmaul_husna.dart';
import '../services/settings_service.dart';
import '../widgets/liquid_glass.dart';

class AsmaulHusnaScreen extends StatefulWidget {
  const AsmaulHusnaScreen({super.key});
  @override
  State<AsmaulHusnaScreen> createState() => _AsmaulHusnaScreenState();
}

class _AsmaulHusnaScreenState extends State<AsmaulHusnaScreen> {
  String _query = '';
  bool _savedOnly = false;
  final _searchCtrl = TextEditingController();
  final _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settings.removeListener(_refresh);
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final q = _query.toLowerCase();
    final items = asmaulHusna.where((a) {
      if (_savedOnly && !_settings.isAsmaulSaved(a.number)) return false;
      if (q.isEmpty) return true;
      return a.latin.toLowerCase().contains(q) ||
          asmaulMeaning(a.number, language).toLowerCase().contains(q) ||
          a.number.toString() == _query ||
          a.arabic.contains(_query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.asmaulTitle,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            Text(
              l10n.asmaulSubtitle,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: .72),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: LiquidGlassCard(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: l10n.asmaulSearchHint,
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() {
                            _query = '';
                            _searchCtrl.clear();
                          }),
                        )
                      : null,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(l10n.commonFilterAll),
                  selected: !_savedOnly,
                  onSelected: (_) => setState(() => _savedOnly = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: Icon(
                    Icons.bookmark_rounded,
                    size: 16,
                    color: _savedOnly
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: .72),
                  ),
                  label: Text(
                    l10n.asmaulSavedCount(_settings.savedAsmaul.length),
                  ),
                  selected: _savedOnly,
                  onSelected: (_) => setState(() => _savedOnly = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      _savedOnly
                          ? l10n.bookmarksEmptyAsmaul
                          : l10n.commonNoResults,
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.92,
                        ),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _nameCard(items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _nameCard(AsmaulHusna a) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final meaning = asmaulMeaning(
      a.number,
      Localizations.localeOf(context).languageCode,
    );
    final saved = _settings.isAsmaulSaved(a.number);
    return RepaintBoundary(
      child: LiquidGlassCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        onTap: () async {
          await Clipboard.setData(
            ClipboardData(
              text: '${a.number}. ${a.latin} (${a.arabic}) - $meaning',
            ),
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${a.latin} ${l10n.commonCopied}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${a.number}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  a.arabic,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.amiri(
                    fontSize: 22,
                    height: 1.6,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  a.latin,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  meaning,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: .72),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _settings.toggleAsmaulSaved(a.number),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: saved
                        ? scheme.primary.withValues(alpha: .14)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 18,
                    color: saved ? scheme.primary : scheme.outline,
                    semanticLabel: saved
                        ? l10n.asmaulUnsaveName
                        : l10n.asmaulSaveName,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
