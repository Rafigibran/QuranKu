import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/tasbih_service.dart';
import '../widgets/liquid_glass.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  final TasbihService _service = TasbihService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
    _service.init();
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tasbih'),
            Text('Bebas membuat dzikir dan shalawat sendiri', style: GoogleFonts.spaceGrotesk(fontSize: 12, color: scheme.onSurface.withValues(alpha: .55))),
          ],
        ),
        actions: [
          IconButton(onPressed: () => _openEditor(), icon: const Icon(Icons.add_rounded), tooltip: 'Tambah dzikir'),
          const SizedBox(width: 8),
        ],
      ),
      body: !_service.initialized
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              itemCount: _service.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) => _card(_service.items[index]),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah'),
      ),
    );
  }

  Widget _card(TasbihItem item) {
    final scheme = Theme.of(context).colorScheme;
    final progress = item.target == 0 ? 0.0 : item.count / item.target;
    final done = item.count >= item.target;
    return LiquidGlassCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') await _openEditor(item: item);
                  if (value == 'delete') await _confirmDelete(item);
                  if (value == 'reset') await _service.reset(item);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'reset', child: Text('Reset hitungan')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(item.text, textAlign: TextAlign.center, style: GoogleFonts.amiri(fontSize: 27, height: 1.6, color: scheme.primary)),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(minHeight: 8, value: progress.clamp(0, 1).toDouble(), backgroundColor: scheme.primary.withValues(alpha: .10)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${item.count} / ${item.target}', style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(done ? 'Selesai' : '${(progress * 100).round()}%', style: TextStyle(color: done ? scheme.primary : scheme.onSurface.withValues(alpha: .55), fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: done ? () => _service.reset(item) : () => _service.increment(item),
              icon: Icon(done ? Icons.restart_alt_rounded : Icons.touch_app_rounded),
              label: Text(done ? 'Mulai lagi' : 'Hitung', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor({TasbihItem? item}) async {
    final title = TextEditingController(text: item?.title ?? '');
    final text = TextEditingController(text: item?.text ?? '');
    final target = TextEditingController(text: (item?.target ?? 33).toString());
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: LiquidGlassCard(
            radius: 30,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [Expanded(child: Text(item == null ? 'Tambah dzikir' : 'Edit dzikir', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))), IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded))]),
                const SizedBox(height: 12),
                TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Nama', hintText: 'Contoh: Istighfar'), validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null),
                const SizedBox(height: 10),
                TextFormField(controller: text, minLines: 2, maxLines: 4, textDirection: TextDirection.rtl, decoration: const InputDecoration(labelText: 'Teks Arab / Latin', hintText: 'Masukkan bacaan sendiri'), validator: (v) => v == null || v.trim().isEmpty ? 'Teks wajib diisi' : null),
                const SizedBox(height: 10),
                TextFormField(controller: target, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target hitungan'), validator: (v) { final n = int.tryParse(v ?? ''); return n == null || n < 1 ? 'Target minimal 1' : null; }),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final n = int.parse(target.text);
                    if (item == null) {
                      await _service.add(title: title.text, text: text.text, target: n);
                    } else {
                      await _service.update(item, title: title.text, text: text.text, target: n);
                    }
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  child: Text(item == null ? 'Simpan dzikir' : 'Simpan perubahan'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    title.dispose();
    text.dispose();
    target.dispose();
  }

  Future<void> _confirmDelete(TasbihItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus dzikir?'),
        content: Text('"${item.title}" akan dihapus beserta hitungannya.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus'))],
      ),
    );
    if (ok == true) await _service.remove(item);
  }
}
