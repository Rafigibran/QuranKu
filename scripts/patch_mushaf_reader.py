from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'lib' / 'screens' / 'surah_detail_screen.dart'


def replace_method(text: str, signature: str, replacement: str) -> str:
    start = text.find(signature)
    if start < 0:
        raise SystemExit(f'Method not found: {signature}')
    brace_start = text.find('{', start)
    if brace_start < 0:
        raise SystemExit(f'Method body not found: {signature}')

    depth = 0
    quote = None
    escape = False
    for i in range(brace_start, len(text)):
        ch = text[i]
        if quote is not None:
            if escape:
                escape = False
            elif ch == '\\':
                escape = True
            elif ch == quote:
                quote = None
            continue
        if ch in ('"', "'"):
            quote = ch
        elif ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                return text[:start] + replacement + text[i + 1:]
    raise SystemExit(f'Unbalanced braces: {signature}')


def main() -> None:
    text = PATH.read_text(encoding='utf-8')
    text = text.replace(
        "import 'package:flutter/services.dart' show rootBundle;",
        "import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;",
        1,
    )

    build_reader = r'''  Widget _buildReader(List<Ayah> ayahs) {
    _restoreReadingWhenReady();

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 116,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.bookmark_border_rounded,
                        size: 25, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text(
                      '19. ${_naming.displayName(widget.surah.number, widget.surah.name)}',
                      style: GoogleFonts.ebGaramond(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${widget.surah.type} • ${_settings.formatNumber(widget.surah.totalAyahs)} ayat',
                      style: GoogleFonts.ebGaramond(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _naming.displayName(widget.surah.number, widget.surah.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ebGaramond(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: .45),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.format_list_bulleted_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 2),
                            SizedBox(
                              width: 40,
                              height: 36,
                              child: Icon(
                                Icons.menu_book_rounded,
                                size: 20,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _openSettings,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.settings_rounded,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: .45),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
          sliver: SliverList.separated(
            itemCount: ayahs.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: .42),
            ),
            itemBuilder: (context, index) => _ayahCard(ayahs[index]),
          ),
        ),
      ],
    );
  }'''

    header_stub = r'''  Widget _buildHeaderCard(BuildContext context, List<Ayah> ayahs) {
    return const SizedBox.shrink();
  }'''

    ayah = r'''  Widget _ayahCard(Ayah ayah) {
    final scheme = Theme.of(context).colorScheme;
    final isSaved = _bookmarkedAyah == ayah.number;

    return Container(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 20),
      decoration: BoxDecoration(
        color: isSaved ? scheme.primary.withValues(alpha: .035) : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: isSaved ? scheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                _settings.formatNumber(ayah.number),
                style: GoogleFonts.ebGaramond(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 18),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: isSaved ? 'Hapus bookmark' : 'Simpan bookmark',
                onPressed: () => _toggleBookmark(ayah.number),
                icon: Icon(
                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isSaved ? scheme.primary : scheme.onSurfaceVariant,
                  size: 25,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Salin ayat',
                onPressed: () async {
                  final arabic = ayah.arabic.trim();
                  final translation = ayah.translation.trim();
                  final value = translation.isEmpty ? arabic : '$arabic\n\n$translation';
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ayat disalin')),
                  );
                },
                icon: Icon(Icons.copy_all_outlined, color: scheme.onSurfaceVariant, size: 24),
              ),
              const Spacer(),
            ],
          ),
          if (_showArabic) ...[
            const SizedBox(height: 6),
            if (_showTajwid && ayah.tajwidText != null && ayah.tajwidText!.trim().isNotEmpty)
              _buildTajwid(ayah.tajwidText!, scheme)
            else
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  ayah.arabic,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.amiri(
                    fontSize: 31,
                    height: 2.05,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            if (_showWordByWord && ayah.words.isNotEmpty) ...[
              const SizedBox(height: 13),
              _buildWordByWord(ayah.words, scheme),
            ],
          ],
          if (_showTranslation && ayah.translation.isNotEmpty) ...[
            const SizedBox(height: 13),
            Text(
              ayah.translation,
              style: GoogleFonts.ebGaramond(
                fontSize: 20,
                height: 1.46,
                color: scheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }'''

    skeleton = r'''  Widget _buildReaderSkeleton() {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverAppBar(
          pinned: true,
          toolbarHeight: 66,
          leading: BackButton(),
          title: Text('Membaca'),
          centerTitle: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
          sliver: SliverList.separated(
            itemCount: 4,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: scheme.outline.withValues(alpha: .42),
            ),
            itemBuilder: (_, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 16,
                    width: 70,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }'''

    text = replace_method(text, '  Widget _buildReader(List<Ayah> ayahs) {', build_reader)
    text = replace_method(text, '  Widget _buildHeaderCard(BuildContext context, List<Ayah> ayahs) {', header_stub)
    text = replace_method(text, '  Widget _ayahCard(Ayah ayah) {', ayah)
    text = replace_method(text, '  Widget _buildReaderSkeleton() {', skeleton)

    PATH.write_text(text, encoding='utf-8')
    print('Applied simplified mushaf reader layout: removed share/more controls and secondary reflection actions.')


if __name__ == '__main__':
    main()
