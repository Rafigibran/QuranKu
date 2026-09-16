import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/khatam.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import '../services/khatam_service.dart';
import '../l10n/l10n.dart';
import '../utils/formatters.dart';
import '../widgets/liquid_glass.dart';
import 'settings_screen.dart';

class KhatamScreen extends StatefulWidget {
  const KhatamScreen({super.key});
  @override
  State<KhatamScreen> createState() => _KhatamScreenState();
}

class _KhatamScreenState extends State<KhatamScreen> {
  final KhatamService _svc = KhatamService();
  List<Surah> _surahs = [];
  bool _loadingSurahs = true;

  // Wizard state
  KhatamType _type = KhatamType.pagesPerDay;
  int _pagesPerDay = 5;
  DateTime? _targetDate;
  int _startSurah = 1;
  final _startAyahCtrl = TextEditingController(text: '1');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onUpdate);
    _svc.init();
    _loadSurahs();
  }

  @override
  void dispose() {
    _svc.removeListener(_onUpdate);
    _startAyahCtrl.dispose();
    super.dispose();
  }

  void _onUpdate() => mounted ? setState(() {}) : null;

  Future<void> _loadSurahs() async {
    try {
      final s = await ApiService().fetchSurahs();
      if (!mounted) return;
      setState(() {
        _surahs = s;
        _loadingSurahs = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSurahs = false);
    }
  }

  Surah? _surahOf(int n) {
    for (final s in _surahs) {
      if (s.number == n) return s;
    }
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _saveTarget() async {
    final startAyah = int.tryParse(_startAyahCtrl.text.trim()) ?? 0;
    final s = _surahOf(_startSurah);
    if (s == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.khatamPickSurahFirst)));
      return;
    }
    if (startAyah < 1 || startAyah > s.totalAyahs) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.khatamStartAyahRange(s.totalAyahs, s.name)),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _svc.createTarget(
        type: _type,
        pagesPerDay: _pagesPerDay,
        targetDate: _targetDate,
        startSurah: _startSurah,
        startAyah: startAyah,
        surahs: _surahs,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.khatamTargetSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openLogSheet() async {
    final t = _svc.target;
    if (t == null) return;
    int toSurah = t.curSurah;
    final toAyahCtrl = TextEditingController(text: '${t.curAyah}');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final s = _surahOf(toSurah);
          final maxAyah = s?.totalAyahs ?? 0;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: LiquidGlassCard(
                radius: 24,
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      context.l10n.khatamMarkReading,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.khatamMarkRange(t.curSurah, t.curAyah),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .72),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.khatamUntilSurah,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: toSurah,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        isDense: true,
                      ),
                      items: _surahs
                          .where((e) => e.number >= t.curSurah)
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.number,
                              child: Text(
                                '${e.number}. ${e.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setSheet(() => toSurah = v ?? toSurah),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: toAyahCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: maxAyah > 0
                            ? context.l10n.khatamUntilAyahRange(maxAyah)
                            : context.l10n.khatamUntilAyah,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(context.l10n.commonCancel),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final toAyah =
                                  int.tryParse(toAyahCtrl.text.trim()) ?? 0;
                              try {
                                await _svc.logReading(
                                  toSurah: toSurah,
                                  toAyah: toAyah,
                                  surahs: _surahs,
                                );
                                if (ctx.mounted) Navigator.pop(ctx, true);
                              } catch (e) {
                                if (ctx.mounted)
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '$e'.replaceFirst('Exception: ', ''),
                                      ),
                                    ),
                                  );
                              }
                            },
                            child: Text(context.l10n.commonSave),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (ok == true && mounted) {
      final done = _svc.target == null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            done
                ? context.l10n.readerKhatamComplete
                : context.l10n.khatamReadingLogged,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.khatamDeleteTargetTitle),
        content: Text(
          context.l10n.khatamDeleteTargetBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok == true) await _svc.deleteTarget();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.khatamTitle,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
            Text(
              context.l10n.khatamSubtitle,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: .72),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          if (_svc.hasActive)
            IconButton(
              tooltip: context.l10n.khatamDeleteTargetAction,
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _svc.hasActive ? _activeView() : _setupView(),
    );
  }

  Widget _activeView() {
    final scheme = Theme.of(context).colorScheme;
    final t = _svc.target!;
    final days = _svc.daysRemaining();
    final left = _svc.todayQuotaLeft();
    final dateFmt = dateFormatOf(context, 'd MMM yyyy');
    String quotaText;
    if (days != null) {
      quotaText = days < 0
          ? context.l10n.khatamLateDays(-days)
          : days == 0
          ? context.l10n.khatamLastDay
          : context.l10n.khatamDaysLeft(days);
    } else {
      final est = t.pagesPerDay > 0
          ? (t.totalPages - t.pagesDone) / t.pagesPerDay
          : 0;
      quotaText =
          context.l10n.khatamEstimate(est.ceil(), t.pagesPerDay);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
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
                        t.type == KhatamType.pagesPerDay
                            ? context.l10n.khatamDailyTarget
                            : context.l10n.khatamDateTarget,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      context.l10n.khatamCompletedCount(_svc.completedCount),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: .72),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: t.progress,
                        strokeWidth: 12,
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(scheme.primary),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(t.progress * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${t.pagesDone}/${t.totalPages} hlm',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withValues(alpha: .72),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  quotaText,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${context.l10n.khatamPosition(t.curSurah, t.curAyah, t.startSurah, t.startAyah)}${t.targetDate != null ? context.l10n.khatamPositionTarget(dateFmt.format(t.targetDate!)) : ''}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: .72),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LiquidGlassCard(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    context.l10n.khatamTodayTarget,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    '${t.doneTodayPages}/${t.pagesPerDay} hlm',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ThreadProgress(
                value: t.pagesPerDay > 0
                    ? (t.doneTodayPages / t.pagesPerDay).clamp(0.0, 1.0)
                    : 0,
              ),
              const SizedBox(height: 6),
              Text(
                left > 0
                    ? context.l10n.khatamRemainingToday(left)
                    : context.l10n.khatamTodayReached,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: .72),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openLogSheet,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(context.l10n.khatamMarkReading),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.khatamSummary,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (_svc.logs.isEmpty)
          LiquidGlassCard(
            radius: 16,
            padding: const EdgeInsets.all(16),
            child: Text(
              context.l10n.khatamSummaryEmpty,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: .72),
              ),
            ),
          )
        else
          ..._svc.logs
              .take(20)
              .map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LiquidGlassCard(
                    radius: 16,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '+${l.pages} hlm',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QS ${l.fromSurah}:${l.fromAyah} → QS ${l.toSurah}:${l.toAyah}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${l.date} • ${l.ayahs} ayat',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        if (_svc.history.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.khatamHistoryTitle(_svc.completedCount),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ..._svc.history.map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LiquidGlassCard(
                radius: 16,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      color: Colors.amber.shade700,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.l10n.khatamHistoryEntry(dateFormatOf(context, 'd MMM yyyy').format(h.completedAt), h.totalPages, h.daysUsed),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _setupView() {
    final scheme = Theme.of(context).colorScheme;
    final s = _surahOf(_startSurah);
    final dateFmt = dateFormatOf(context, 'd MMM yyyy');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (_svc.completedCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LiquidGlassCard(
              radius: 16,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.khatamAlreadyCompleted(_svc.completedCount),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        Text(
          context.l10n.khatamTargetType,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text(context.l10n.khatamPagesPerDay),
                selected: _type == KhatamType.pagesPerDay,
                onSelected: (_) =>
                    setState(() => _type = KhatamType.pagesPerDay),
                selectedColor: scheme.primary.withValues(alpha: .18),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: Text(context.l10n.khatamDateLabel),
                selected: _type == KhatamType.byDate,
                onSelected: (_) => setState(() => _type = KhatamType.byDate),
                selectedColor: scheme.primary.withValues(alpha: .18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_type == KhatamType.pagesPerDay) ...[
          LiquidGlassCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(child: Text(context.l10n.khatamPagesPerDayLabel)),
                IconButton(
                  onPressed: _pagesPerDay > 1
                      ? () => setState(() => _pagesPerDay--)
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    '$_pagesPerDay',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _pagesPerDay < 604
                      ? () => setState(() => _pagesPerDay++)
                      : null,
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
              ],
            ),
          ),
        ] else ...[
          LiquidGlassCard(
            radius: 18,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(child: Text(context.l10n.khatamMustFinishBy)),
                FilledButton.tonal(
                  onPressed: _pickDate,
                  child: Text(
                    _targetDate == null
                        ? context.l10n.khatamPickDate
                        : dateFmt.format(_targetDate!),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.khatamDailyNeedNote,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: .72),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          context.l10n.khatamStartFrom,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        LiquidGlassCard(
          radius: 18,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.khatamSurahLabel),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: _startSurah,
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  isDense: true,
                ),
                items: _loadingSurahs
                    ? []
                    : _surahs
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.number,
                              child: Text(
                                '${e.number}. ${e.name} (${e.totalAyahs} ayat)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                onChanged: (v) => setState(() => _startSurah = v ?? 1),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _startAyahCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: s != null
                      ? context.l10n.khatamFromAyahRange(s.totalAyahs)
                      : context.l10n.khatamFromAyah,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saving ? null : _saveTarget,
            icon: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.flag_rounded, size: 18),
            label: Text(context.l10n.khatamStartTarget),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.khatamStoredNote,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: .72),
          ),
        ),
        if (_svc.logs.isNotEmpty || _svc.history.isNotEmpty) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(context.l10n.khatamDeleteHistoryTitle),
                  content: Text(
                    context.l10n.khatamDeleteHistoryBody,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.l10n.commonCancel),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.l10n.commonDelete),
                    ),
                  ],
                ),
              );
              if (ok == true) await _svc.clearHistory();
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: Text(context.l10n.khatamDeleteHistoryAction),
          ),
        ],
      ],
    );
  }
}
