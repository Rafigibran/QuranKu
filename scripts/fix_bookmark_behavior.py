from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "lib" / "screens" / "surah_detail_screen.dart"


def replace_method(text: str, signature: str, replacement: str) -> str:
    start = text.find(signature)
    if start < 0:
        raise RuntimeError(f"Method not found: {signature}")
    brace = text.find("{", start)
    if brace < 0:
        raise RuntimeError(f"Opening brace not found: {signature}")

    depth = 0
    quote = None
    escape = False
    for i in range(brace, len(text)):
        ch = text[i]
        if quote is not None:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == quote:
                quote = None
            continue

        if ch in ('"', "'"):
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[:start] + replacement + text[i + 1:]

    raise RuntimeError(f"Unbalanced braces: {signature}")


def remove_method(text: str, signature: str) -> str:
    start = text.find(signature)
    if start < 0:
        return text
    brace = text.find("{", start)
    if brace < 0:
        raise RuntimeError(f"Opening brace not found: {signature}")

    depth = 0
    quote = None
    escape = False
    for i in range(brace, len(text)):
        ch = text[i]
        if quote is not None:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == quote:
                quote = None
            continue

        if ch in ('"', "'"):
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = i + 1
                while end < len(text) and text[end] in "\r\n":
                    end += 1
                return text[:start] + text[end:]
    raise RuntimeError(f"Unbalanced braces: {signature}")


def insert_after_method(text: str, signature: str, addition: str) -> str:
    start = text.find(signature)
    if start < 0:
        raise RuntimeError(f"Method not found: {signature}")
    brace = text.find("{", start)
    if brace < 0:
        raise RuntimeError(f"Opening brace not found: {signature}")

    depth = 0
    quote = None
    escape = False
    for i in range(brace, len(text)):
        ch = text[i]
        if quote is not None:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == quote:
                quote = None
            continue

        if ch in ('"', "'"):
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[: i + 1] + "\n\n" + addition.rstrip() + text[i + 1:]

    raise RuntimeError(f"Unbalanced braces: {signature}")


def wrap_scaffold_return(text: str) -> str:
    if "onWillPop: () async {" in text:
        return text

    build_start = text.find("  Widget build(BuildContext context) {")
    if build_start < 0:
        raise RuntimeError("Widget build method not found")

    return_start = text.find("    return Scaffold(", build_start)
    if return_start < 0:
        raise RuntimeError("Scaffold return not found")

    scaffold_open = text.find("(", return_start)
    depth = 0
    quote = None
    escape = False
    end = -1

    for i in range(scaffold_open, len(text)):
        ch = text[i]
        if quote is not None:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == quote:
                quote = None
            continue

        if ch in ('"', "'"):
            quote = ch
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                end = i
                break

    if end < 0:
        raise RuntimeError("Unbalanced Scaffold parentheses")

    scaffold_expression = text[return_start:end + 1]
    wrapped = (
        "    return WillPopScope(\n"
        "      onWillPop: () async {\n"
        "        await _saveLastVisibleAyahOnExit();\n"
        "        return true;\n"
        "      },\n"
        "      child:\n"
        + scaffold_expression.replace("    return Scaffold(", "        Scaffold(", 1)
        + ",\n"
        "    );"
    )

    return text[:return_start] + wrapped + text[end + 1:]


def main() -> None:
    text = PATH.read_text(encoding="utf-8")

    # Option C: automatic reading position is persisted only when the reader
    # route is actually being exited. Manual bookmarks stay independent.
    if "int? _lastVisibleAyahCandidate;" not in text:
        anchor = "  int? _lastReadAyah;\n"
        if anchor not in text:
            raise RuntimeError("Last-read state anchor not found")
        text = text.replace(
            anchor,
            anchor
            + "  int? _lastVisibleAyahCandidate;\n"
            + "  List<GlobalKey> _ayahKeys = const [];\n"
            + "  bool _exitBookmarkSaved = false;\n",
            1,
        )
    else:
        if "List<GlobalKey> _ayahKeys" not in text:
            text = text.replace(
                "  int? _lastVisibleAyahCandidate;\n",
                "  int? _lastVisibleAyahCandidate;\n  List<GlobalKey> _ayahKeys = const [];\n",
                1,
            )
        if "bool _exitBookmarkSaved = false;" not in text:
            text = text.replace(
                "  List<GlobalKey> _ayahKeys = const [];\n",
                "  List<GlobalKey> _ayahKeys = const [];\n  bool _exitBookmarkSaved = false;\n",
                1,
            )

    # No auto-bookmark writes while scrolling.
    text = text.replace("    _scroll.addListener(_captureVisibleAyah);\n", "")
    text = text.replace("    _scroll.removeListener(_captureVisibleAyah);\n", "")

    if "_ensureAyahKeys(int length)" not in text:
        ensure_method = r'''  void _ensureAyahKeys(int length) {
    if (length <= 0 || _ayahKeys.length == length) return;
    _ayahKeys = List<GlobalKey>.generate(length, (_) => GlobalKey());
  }
'''
        text = insert_after_method(text, "  String _editionName(String id) {", ensure_method)

    capture_method = r'''  void _captureVisibleAyah() {
    if (!_scroll.hasClients) return;

    final ayahs = _ayahs;
    if (ayahs == null || ayahs.isEmpty) return;
    _ensureAyahKeys(ayahs.length);

    final viewportObject =
        _scroll.position.context.storageContext.findRenderObject();
    if (viewportObject is! RenderBox || !viewportObject.hasSize) return;

    final viewportTop = viewportObject.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewportObject.size.height;

    int? candidateIndex;

    for (var index = 0; index < ayahs.length; index++) {
      if (index >= _ayahKeys.length) break;

      final renderObject =
          _ayahKeys[index].currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;

      final top = renderObject.localToGlobal(Offset.zero).dy;
      final bottom = top + renderObject.size.height;
      final visibleTop = top < viewportTop ? viewportTop : top;
      final visibleBottom =
          bottom > viewportBottom ? viewportBottom : bottom;
      final visibleHeight = visibleBottom - visibleTop;

      if (visibleHeight <= 0) continue;

      final visibleRatio =
          visibleHeight / renderObject.size.height;
      if (visibleRatio >= 0.40) {
        candidateIndex = index;
      }
    }

    if (candidateIndex != null) {
      _lastVisibleAyahCandidate = ayahs[candidateIndex].number;
    }
  }
'''

    if "void _captureVisibleAyah()" not in text:
        text = insert_after_method(
            text,
            "  void _ensureAyahKeys(int length) {",
            capture_method,
        )
    else:
        text = replace_method(
            text,
            "  void _captureVisibleAyah() {",
            capture_method,
        )

    exit_method = r'''  Future<void> _saveLastVisibleAyahOnExit() async {
    if (_exitBookmarkSaved) return;

    _captureVisibleAyah();
    final target = _lastVisibleAyahCandidate;
    if (target == null) return;

    _exitBookmarkSaved = true;
    await _saveAyahAsLastRead(target);
  }
'''

    if "Future<void> _saveLastVisibleAyahOnExit() async {" in text:
        text = replace_method(
            text,
            "  Future<void> _saveLastVisibleAyahOnExit() async {",
            exit_method,
        )
    else:
        text = insert_after_method(
            text,
            "  void _captureVisibleAyah() {",
            exit_method,
        )

    # Restore the key list whenever data changes before the reader is built.
    for needle in [
        "      _ayahs = data;\n",
        "                  _ayahs = snapshot.data!;\n",
        "      _ayahs = cached;\n",
    ]:
        if needle in text and "_ensureAyahKeys(" not in text[text.find(needle):text.find(needle) + 180]:
            if "snapshot.data!" in needle:
                text = text.replace(
                    needle,
                    needle + "                  _ensureAyahKeys(snapshot.data!.length);\n",
                    1,
                )
            elif "data;" in needle:
                text = text.replace(
                    needle,
                    needle + "      _ensureAyahKeys(data.length);\n",
                    1,
                )
            else:
                text = text.replace(
                    needle,
                    needle + "      if (cached != null) _ensureAyahKeys(cached.length);\n",
                    1,
                )

    reader = "  Widget _buildReader(List<Ayah> ayahs) {"
    reader_start = text.find(reader)
    if reader_start < 0:
        raise RuntimeError("Reader build method not found")

    reader_end = text.find("\n}", reader_start)
    reader_slice = text[reader_start:reader_start + 500]
    if "_ensureAyahKeys(ayahs.length);" not in reader_slice:
        text = text.replace(
            reader,
            reader + "\n    _ensureAyahKeys(ayahs.length);",
            1,
        )

    # Every list-mode ayah gets a stable render key.
    plain_item = "itemBuilder: (context, index) => _ayahCard(ayahs[index]),"
    keyed_item = """itemBuilder: (context, index) => KeyedSubtree(
              key: _ayahKeys[index],
              child: _ayahCard(ayahs[index]),
            ),"""
    if plain_item in text:
        text = text.replace(plain_item, keyed_item, 1)

    # Never save last-reading position from a tap or restore operation.
    text = text.replace(
        "onTap: () => _saveAyahAsLastRead(ayah.number),\n",
        "",
    )
    text = text.replace(
        "    _saveAyahAsLastRead(target);\n",
        "",
    )

    # System back + AppBar BackButton both go through the route callback.
    text = wrap_scaffold_return(text)

    PATH.write_text(text, encoding="utf-8")
    print(
        "Applied bookmark Option C: no auto-save during reading; "
        "persist the last sufficiently visible ayah only when leaving the reader."
    )


if __name__ == "__main__":
    main()
