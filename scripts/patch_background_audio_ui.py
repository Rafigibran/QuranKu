from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'lib' / 'widgets' / 'full_player_view.dart'


def replace_method(text: str, signature: str, replacement: str) -> str:
    start = text.find(signature)
    if start == -1:
        raise RuntimeError(f'Method not found: {signature}')

    brace = text.find('{', start)
    if brace == -1:
        raise RuntimeError(f'Method opening brace not found: {signature}')

    depth = 0
    in_string = None
    escape = False
    i = brace
    while i < len(text):
        ch = text[i]
        if in_string:
            if escape:
                escape = False
            elif ch == '\\':
                escape = True
            elif ch == in_string:
                in_string = None
        else:
            if ch in ('"', "'"):
                in_string = ch
            elif ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    return text[:start] + replacement + text[i + 1:]
        i += 1

    raise RuntimeError(f'Unbalanced braces in: {signature}')


def replace_glass_sheet(text: str) -> str:
    marker = "class _GlassSheet extends StatelessWidget {"
    start = text.find(marker)
    if start == -1:
        raise RuntimeError('GlassSheet class not found')

    build_signature = '  Widget build(BuildContext context) {'
    build_start = text.find(build_signature, start)
    if build_start == -1:
        raise RuntimeError('GlassSheet build method not found')

    brace = text.find('{', build_start)
    depth = 0
    in_string = None
    escape = False
    i = brace
    while i < len(text):
        ch = text[i]
        if in_string:
            if escape:
                escape = False
            elif ch == '\\':
                escape = True
            elif ch == in_string:
                in_string = None
        else:
            if ch in ('"', "'"):
                in_string = ch
            elif ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    new = r'''  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }'''
                    return text[:build_start] + new + text[i + 1:]
        i += 1

    raise RuntimeError('Unbalanced GlassSheet build method')


def main() -> None:
    text = PATH.read_text(encoding='utf-8')

    replacement = r'''  Future<void> _openBackgroundSound() async {
    // Load persisted toggle/volume state before presenting the controls.
    // This removes the first-open race with BackgroundAudioService.init().
    await _background.init();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Keep exactly one native Material handle.
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: Colors.black.withValues(alpha: .38),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        // These values live for the lifetime of this sheet. The switch therefore
        // does not depend on a background-service rebuild to show its new state.
        var backgroundEnabled = _background.enabled;
        var mainVolume = _background.mainVolume;
        var rainVolume = _background.backgroundVolume;

        return _GlassSheet(
          title: 'Suara latar',
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final scheme = Theme.of(context).colorScheme;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: backgroundEnabled,
                    onChanged: (value) {
                      // Reflect the tap immediately. Do not wait for audio
                      // preparation or SharedPreferences before updating UI.
                      setSheetState(() => backgroundEnabled = value);

                      _background.setEnabled(value).catchError((error, stackTrace) {
                        debugPrint('Unable to change rain toggle: $error');
                        debugPrintStack(stackTrace: stackTrace);
                        if (context.mounted) {
                          setSheetState(
                            () => backgroundEnabled = _background.enabled,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Suara hujan tidak dapat diubah.'),
                            ),
                          );
                        }
                      });
                    },
                    title: const Text('Suara hujan'),
                    subtitle: const Text('Berjalan bersama audio Al-Qur’an'),
                    activeTrackColor: scheme.primary.withValues(alpha: .45),
                    activeThumbColor: scheme.primary,
                  ),
                  const SizedBox(height: 12),
                  _volumeSlider(
                    'Volume Al-Qur’an',
                    mainVolume,
                    (value) {
                      setSheetState(() => mainVolume = value);
                      _background.setMainVolume(value).catchError((error, stackTrace) {
                        debugPrint('Unable to set Quran volume: $error');
                        debugPrintStack(stackTrace: stackTrace);
                      });
                    },
                  ),
                  _volumeSlider(
                    'Volume hujan',
                    rainVolume,
                    (value) {
                      setSheetState(() => rainVolume = value);
                      _background.setBackgroundVolume(value).catchError((error, stackTrace) {
                        debugPrint('Unable to set rain volume: $error');
                        debugPrintStack(stackTrace: stackTrace);
                      });
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
'''

    text = replace_method(
        text,
        '  Future<void> _openBackgroundSound() async {',
        replacement,
    )

    text = replace_method(
        text,
        '  Widget _volumeSlider(String label, double value, ValueChanged<double> onChanged) {',
        r'''  Widget _volumeSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final safeValue = value.clamp(0.0, 1.0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${(safeValue * 100).round()}%',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Semantics(
            label: label,
            value: '${(safeValue * 100).round()}%',
            child: Slider(
              value: safeValue,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
''',
    )

    text = replace_glass_sheet(text)

    PATH.write_text(text, encoding='utf-8')
    print('Applied stable background toggle with immediate UI state and responsive volume controls.')


if __name__ == '__main__':
    main()
