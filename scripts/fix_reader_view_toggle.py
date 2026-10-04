from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'lib' / 'screens' / 'surah_detail_screen.dart'


def replace_method(text: str, signature: str, replacement: str) -> str:
    start = text.find(signature)
    if start == -1:
        raise RuntimeError(f'Method not found: {signature}')
    brace = text.find('{', start)
    if brace == -1:
        raise RuntimeError(f'Opening brace not found: {signature}')

    depth = 0
    quote = None
    escape = False
    for i in range(brace, len(text)):
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
    raise RuntimeError(f'Unbalanced braces: {signature}')


def insert_before_class_end(text: str, addition: str) -> str:
    marker = '\n}'
    end = text.rfind(marker)
    if end == -1:
        raise RuntimeError('Class end not found')
    return text[:end] + '\n' + addition.rstrip() + text[end:]


def main() -> None:
    text = PATH.read_text(encoding='utf-8')

    if 'bool _readerBookMode = false;' not in text:
        anchors = [
            '  int? _bookmarkedAyah;\n',
            '  bool _savedCurrentAyah = false;\n',
        ]
        for anchor in anchors:
            if anchor in text:
                text = text.replace(
                    anchor,
                    anchor + '  bool _readerBookMode = false;\n',
                    1,
                )
                break
        else:
            raise RuntimeError('Reader state anchor not found')

    build_reader = r'''  Widget _buildReader(List<Ayah> ayahs) {
    _restoreReadingWhenReady();
    final scheme = Theme.of(context).colorScheme;

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
                    Icon(
                      Icons.bookmark_border_rounded,
                      size: 25,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '19. ${_naming.displayName(widget.surah.number, widget.surah.name)}',
                      style: GoogleFonts.ebGaramond(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${widget.surah.type} • ${_settings.formatNumber(widget.surah.totalAyahs)} ayat',
                      style: GoogleFonts.ebGaramond(
                        fontSize: 16,
                        color: scheme.onSurfaceVariant,
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
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    _buildReaderModeToggle(context),
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
                            color: scheme.onSurface,
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
              color: scheme.outline.withValues(alpha: .45),
            ),
          ),
        ),
        if (_readerBookMode)
          _buildMushafAyahSliver(ayahs)
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
            sliver: SliverList.separated(
              itemCount: ayahs.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: scheme.outline.withValues(alpha: .42),
              ),
              itemBuilder: (context, index) => _ayahCard(ayahs[index]),
            ),
          ),
      ],
    );
  }
'''

    mode_toggle = r'''  Widget _buildReaderModeToggle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget button({
      required IconData icon,
      required String tooltip,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: selected ? scheme.surface : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 36,
              child: Icon(
                icon,
                size: 20,
                color: selected
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outline.withValues(alpha: .45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            button(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: 'Tampilan daftar',
              selected: !_readerBookMode,
              onTap: () => setState(() => _readerBookMode = false),
            ),
            button(
              icon: Icons.menu_book_rounded,
              tooltip: 'Tampilan mushaf',
              selected: _readerBookMode,
              onTap: () => setState(() => _readerBookMode = true),
            ),
          ],
        ),
      ),
    );
  }
'''

    mushaf_sliver = r'''  Widget _buildMushafAyahSliver(List<Ayah> ayahs) {
    final scheme = Theme.of(context).colorScheme;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      sliver: SliverList.separated(
        itemCount: ayahs.length,
        separatorBuilder: (_, __) => Divider(
          height: 34,
          color: scheme.outline.withValues(alpha: .34),
        ),
        itemBuilder: (context, index) {
          final ayah = ayahs[index];
          final isSaved = _bookmarkedAyah == ayah.number;

          return GestureDetector(
            onTap: () => _saveAyahAsLastRead(ayah.number),
              child: Container(
              color: isSaved
                  ? scheme.primary.withValues(alpha: .025)
                  : Colors.transparent,
              padding: const EdgeInsets.fromLTRB(0, 18, 0, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: .45),
                          ),
                        ),
                        child: Text(
                          _settings.formatNumber(ayah.number),
                          style: GoogleFonts.ebGaramond(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: isSaved ? 'Hapus bookmark' : 'Simpan bookmark',
                        onPressed: () => _toggleBookmark(ayah.number),
                        icon: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isSaved
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (_showArabic) ...[
                    const SizedBox(height: 10),
                    if (_showTajwid &&
                        ayah.tajwidText != null &&
                        ayah.tajwidText!.trim().isNotEmpty)
                      _buildTajwid(ayah.tajwidText!, scheme)
                    else
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          ayah.arabic,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.amiri(
                            fontSize: 35,
                            height: 2.15,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    if (_showWordByWord && ayah.words.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildWordByWord(ayah.words, scheme),
                    ],
                  ],
                  if (_showTranslation && ayah.translation.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Text(
                      ayah.translation,
                      style: GoogleFonts.ebGaramond(
                        fontSize: 21,
                        height: 1.55,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
'''

    text = replace_method(text, '  Widget _buildReader(List<Ayah> ayahs) {', build_reader)

    if '  Widget _buildReaderModeToggle(BuildContext context) {' not in text:
        text = insert_before_class_end(text, mode_toggle + '\n' + mushaf_sliver)
    else:
        text = replace_method(
            text,
            '  Widget _buildReaderModeToggle(BuildContext context) {',
            mode_toggle,
        )
        text = replace_method(
            text,
            '  Widget _buildMushafAyahSliver(List<Ayah> ayahs) {',
            mushaf_sliver,
        )

    PATH.write_text(text, encoding='utf-8')
    print('Enabled functional reader mode toggle: List <-> Mushaf.')


if __name__ == '__main__':
    main()
