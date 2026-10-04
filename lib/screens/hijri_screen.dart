import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HijriScreen extends StatefulWidget {
  const HijriScreen({super.key});
  @override
  State<HijriScreen> createState() => _HijriScreenState();
}

class _HijriScreenState extends State<HijriScreen> {
  static const months = <String>[
    'Muharram','Safar','Rabiul Awal','Rabiul Akhir','Jumadil Awal','Jumadil Akhir',
    'Rajab','Syaban','Ramadan','Syawal','Zulkaidah','Zulhijah',
  ];

  List<int> _toHijri(DateTime g) {
    final a = ((14 - g.month) / 12).floor();
    final y = g.year + 4800 - a;
    final m = g.month + 12 * a - 3;
    final jdn = g.day + ((153 * m + 2) / 5).floor() + 365 * y + (y / 4).floor()
        - (y / 100).floor() + (y / 400).floor() - 32045;
    final l = jdn - 1948440 + 10632;
    final n = ((l - 1) / 10631).floor();
    final l2 = l - 10631 * n + 354;
    final j = (((10985 - l2) / 5316).floor()) * ((50 * l2 / 17719).floor())
        + ((l2 / 5670).floor()) * ((43 * l2 / 15238).floor());
    final l3 = l2 - ((30 - j) / 15).floor() * ((17719 * j) / 50).floor()
        - (j / 16).floor() * ((15238 * j) / 43).floor() + 29;
    final m2 = ((24 * l3) / 709).floor();
    final d2 = l3 - ((709 * m2) / 24).floor();
    final y2 = 30 * n + j - 30;
    return [y2, m2 - 1, d2];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final h = _toHijri(now);
    return Scaffold(
      appBar: AppBar(title: const Text('Kalender Hijriah')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Card(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Text('${h[2]} ${months[h[1].clamp(0,11)]} ${h[0]} H', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now)),
            ]),
          )),
          const SizedBox(height: 14),
          Text('30 hari sekitar hari ini', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...List.generate(30, (i) {
            final date = now.add(Duration(days: i - 14));
            final hh = _toHijri(date);
            final selected = i == 14;
            return Card(
              color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
              child: ListTile(
                leading: CircleAvatar(child: Text('${hh[2]}')),
                title: Text('${hh[2]} ${months[hh[1].clamp(0,11)]} ${hh[0]} H'),
                subtitle: Text(DateFormat('EEE, d MMM yyyy', 'id_ID').format(date)),
              ),
            );
          }),
        ],
      ),
    );
  }
}
