import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quranku/l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../models/dhikr.dart';
import '../services/tasbih_service.dart';
import '../widgets/liquid_glass.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});
  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

/// Display label for a dhikr category. The categories themselves are stored as
/// stable slugs, so they must not be shown raw.
String _tasbihCategoryLabel(BuildContext context, String category) {
  final l = AppLocalizations.of(context)!;
  switch (category) {
    case 'dzikir':
      return l.tasbihCategoryDzikir;
    case 'shalawat':
      return l.tasbihCategoryShalawat;
    case 'doa':
      return l.tasbihCategoryDoa;
    default:
      return l.tasbihCategoryCustom;
  }
}

class _TasbihScreenState extends State<TasbihScreen>
    with SingleTickerProviderStateMixin {
  final TasbihService _svc = TasbihService();
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onUpdate);
    _svc.init();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _svc.removeListener(_onUpdate);
    _pulse.dispose();
    super.dispose();
  }

  void _onUpdate() => mounted ? setState(() {}) : null;

  Future<void> _increment() async {
    if (!MediaQuery.disableAnimationsOf(context)) {
      _pulse.forward(from: 0.96).then((_) => _pulse.reverse());
    }
    final done = await _svc.increment();
    if (done == null || !mounted) return;
    final advanced = done.autoAdvanced && done.next != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          advanced
              ? context.l10n.tasbihCompletedNext(done.completed.target, done.next!.arabic)
              : context.l10n.tasbihCompletedOne(
                  done.completed.target,
                  done.completed.arabic,
                ),
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: advanced ? 5 : 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        action: advanced
            ? SnackBarAction(
                label: 'Undo',
                onPressed: () => _svc.undoLastCompletion(),
              )
            : null,
      ),
    );
  }

  void _openAddSheet({Dhikr? edit}) {
    final arabicCtrl = TextEditingController(text: edit?.arabic ?? '');
    final latinCtrl = TextEditingController(text: edit?.latin ?? '');
    final transCtrl = TextEditingController(text: edit?.translation ?? '');
    final targetCtrl = TextEditingController(
      text: (edit?.target ?? 33).toString(),
    );
    String category = edit?.category ?? 'custom';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final l10n = AppLocalizations.of(ctx)!;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: LiquidGlassCard(
                radius: 24,
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        edit == null
                            ? context.l10n.tasbihAddTitle
                            : context.l10n.tasbihEditTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.tasbihAddHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: .72),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: arabicCtrl,
                        maxLines: 2,
                        textAlign: TextAlign.right,
                        style: GoogleFonts.amiri(fontSize: 22, height: 1.6),
                        decoration: InputDecoration(
                          labelText: context.l10n.tasbihFieldArabic,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          hintText: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: latinCtrl,
                        decoration: InputDecoration(
                          labelText: context.l10n.tasbihFieldLatin,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          hintText: 'Allahumma sholli ala Muhammad',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: transCtrl,
                        decoration: InputDecoration(
                          labelText: context.l10n.tasbihFieldTranslation,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          hintText: context.l10n.tasbihTranslationHint,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: targetCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Target',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                hintText: '33',
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          DropdownButton<String>(
                            value: category,
                            items: const [
                              DropdownMenuItem(
                                value: 'dzikir',
                                child: Text('Dzikir'),
                              ),
                              DropdownMenuItem(
                                value: 'shalawat',
                                child: Text('Shalawat'),
                              ),
                              DropdownMenuItem(
                                value: 'doa',
                                child: Text('Doa'),
                              ),
                              DropdownMenuItem(
                                value: 'custom',
                                child: Text('Custom'),
                              ),
                            ],
                            onChanged: (v) => setSheet(() => category = v!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l10n.commonCancel),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                final arabic = arabicCtrl.text.trim();
                                if (arabic.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        context.l10n.tasbihArabicRequired,
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final target =
                                    int.tryParse(targetCtrl.text) ?? 33;
                                if (edit == null) {
                                  await _svc.addCustom(
                                    arabic: arabic,
                                    latin: latinCtrl.text.trim(),
                                    translation: transCtrl.text.trim(),
                                    category: category,
                                    target: target.clamp(1, 10000),
                                  );
                                } else {
                                  await _svc.updateDhikr(
                                    edit.copyWith(
                                      arabic: arabic,
                                      latin: latinCtrl.text.trim(),
                                      translation: transCtrl.text.trim(),
                                      // The user typed their own translation, so
                                      // the shipped English no longer applies.
                                      translationEn: '',
                                      category: category,
                                      target: target.clamp(1, 10000),
                                    ),
                                  );
                                }
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: Text(edit == null ? l10n.commonSave : l10n.commonEdit),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          context.l10n.tasbihTargetHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: .72),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final dh = _svc.current;
    final progress = _svc.progressPercent / 100.0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tasbihTitle,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            Text(
              l10n.tasbihSubtitle,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: .72),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.tasbihReset,
            onPressed: dh == null ? null : () => _confirmReset(),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          IconButton(
            tooltip: context.l10n.tasbihAddTooltip,
            onPressed: () => _openAddSheet(),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: dh == null
          ? Center(
              child: Text(
                context.l10n.tasbihEmpty,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                // Current dhikr header — purpose: fokus utama per layar (antislop one focal point)
                RepaintBoundary(
                  child: LiquidGlassCard(
                    radius: 24,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                _tasbihCategoryLabel(context, dh.category),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              context.l10n.tasbihTotalKhatam(dh.totalCompleted),
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurface.withValues(alpha: .72),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _openAddSheet(edit: dh),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.outline.withValues(
                                      alpha: .20,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SelectableText(
                          dh.arabic,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.amiri(
                            fontSize: 26,
                            height: 1.8,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (dh.latin.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            dh.latin,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              height: 1.5,
                              color: scheme.onSurface.withValues(alpha: .72),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (dh.translationFor(language).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            dh.translationFor(language),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: scheme.onSurface.withValues(alpha: .72),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${context.l10n.tasbihTarget}: ${dh.target} • ',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurface.withValues(alpha: .72),
                              ),
                            ),
                            Text(
                              '${dh.count} / ${dh.target}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ThreadProgress(value: progress),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Big tasbih button — purpose: primary action, 44+ tap, haptic feedback, RepaintBoundary for performance
                RepaintBoundary(
                  child: Center(
                    child: ScaleTransition(
                      scale: _pulse,
                      child: Semantics(
                        button: true,
                        label: context.l10n.tasbihGoTo(dh.arabic),
                        value: context.l10n.tasbihCounter(dh.count, dh.target),
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: _increment,
                          child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .18),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                            border: Border.all(
                              color: scheme.outlineVariant,
                              width: 1.2,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Progress ring
                              SizedBox(
                                width: 220,
                                height: 220,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 6,
                                  backgroundColor: scheme.onPrimary.withValues(
                                    alpha: .18,
                                  ),
                                  valueColor: AlwaysStoppedAnimation(
                                    scheme.onPrimary,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${dh.count}',
                                    style: TextStyle(
                                      fontSize: 56,
                                      fontWeight: FontWeight.w800,
                                      color: scheme.onPrimary,
                                      height: 1.0,
                                    ),
                                  ),
                                  Text(
                                    '/ ${dh.target}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.onPrimary.withValues(
                                        alpha: .86,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: scheme.onPrimary.withValues(
                                        alpha: .18,
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      'TAP',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: scheme.onPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    l10n.tasbihTapHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withValues(alpha: .72),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: LiquidGlassSectionTitle(
                        title: context.l10n.tasbihListTitle,
                        subtitle: context.l10n.tasbihListSubtitle,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openAddSheet(),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(context.l10n.tasbihAdd),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Preset list —Purpose: hierarchy, not copy-paste cards (antislop R-14)
                ..._svc.items.map((d) {
                  final isActive = d.id == dh.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LiquidGlassCard(
                      radius: 16,
                      padding: EdgeInsets.zero,
                      onTap: () => _svc.setCurrent(d.id),
                      child: Container(
                        decoration: isActive
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: scheme.primary.withValues(alpha: .28),
                                ),
                                color: scheme.primary.withValues(alpha: .06),
                              )
                            : null,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? scheme.primary
                                  : scheme.surfaceContainerHighest,
                              border: Border.all(
                                color: scheme.outline.withValues(alpha: .14),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${d.count}/${d.target}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isActive
                                      ? scheme.onPrimary
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            d.arabic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.amiri(
                              fontSize: 16,
                              color: scheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            d.latin.isNotEmpty
                                ? d.latin
                                : d.translationFor(language),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: .72),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _openAddSheet(edit: d);
                              if (v == 'delete') _confirmDelete(d);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(l10n.commonDelete),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // Settings row
                LiquidGlassCard(
                  radius: 16,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          context.l10n.tasbihVibration,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          context.l10n.tasbihVibrationHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: .72),
                          ),
                        ),
                        value: _svc.vibration,
                        onChanged: (v) => _svc.setVibration(v),
                      ),
                      Divider(
                        height: 1,
                        color: scheme.outline.withValues(alpha: .12),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          context.l10n.playerRepeatAuto,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          context.l10n.tasbihAutoAdvanceHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: .72),
                          ),
                        ),
                        value: _svc.autoAdvance,
                        onChanged: (v) => _svc.setAutoAdvance(v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Future<void> _confirmReset() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.tasbihResetTitle),
        content: Text(
          context.l10n.tasbihResetBody(_svc.current?.arabic ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.tasbihReset),
          ),
        ],
      ),
    );
    if (ok == true) await _svc.resetCurrent();
  }

  Future<void> _confirmDelete(Dhikr d) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.tasbihDeleteTitle),
        content: Text(d.arabic),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok == true) await _svc.delete(d.id);
  }
}
