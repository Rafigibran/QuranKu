import 'package:flutter/material.dart';
import '../models/surah.dart';
import '../services/api_service.dart';
import 'surah_detail_screen.dart';

class JuzScreen extends StatefulWidget {
  const JuzScreen({super.key});
  @override
  State<JuzScreen> createState() => _JuzScreenState();
}

class _JuzScreenState extends State<JuzScreen> {
  static const starts = <List<int>>[
    [1,1],[2,142],[2,253],[3,93],[4,24],[4,148],[5,82],[6,111],[7,88],[8,41],
    [9,93],[11,6],[12,53],[15,1],[17,1],[18,75],[21,1],[23,1],[25,21],[27,56],
    [29,46],[33,31],[36,28],[39,32],[41,47],[46,1],[51,31],[58,1],[67,1],[78,1],
  ];
  List<Surah> _surahs = [];

  @override
  void initState() {
    super.initState();
    ApiService().fetchSurahs().then((v) { if (mounted) setState(() => _surahs = v); });
  }

  Surah? _surah(int n) {
    for (final s in _surahs) { if (s.number == n) return s; }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Juz 1–30')),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: starts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.55,
        ),
        itemBuilder: (context, index) {
          final start = starts[index];
          final surah = _surah(start[0]);
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: surah == null ? null : () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => SurahDetailScreen(surah: surah, initialAyah: start[1]),
              )),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Juz ${index + 1}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(surah?.name ?? 'Memuat…'),
                  Text('Mulai ayat ${start[1]}', style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
