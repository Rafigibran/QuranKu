import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:quranku/l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../widgets/liquid_glass.dart';

class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});
  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  String _type = 'mal';
  final _amountCtrl = TextEditingController();
  final _goldCtrl = TextEditingController(text: '1500000');
  final _riceCtrl = TextEditingController(text: '15000');
  final _soulsCtrl = TextEditingController(text: '4');
  bool _loadingPrice = false;
  String? _priceNote;
  double? _result;
  String _resultLabel = '';

  @override
  void initState() {
    super.initState();
    _fetchGoldPrice();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _goldCtrl.dispose();
    _riceCtrl.dispose();
    _soulsCtrl.dispose();
    super.dispose();
  }

  String _idr(double v) {
    try {
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(v);
    } catch (_) {
      return 'Rp ${v.toStringAsFixed(0)}';
    }
  }

  Future<void> _fetchGoldPrice() async {
    setState(() {
      _loadingPrice = true;
      _priceNote = null;
    });
    try {
      // XAU USD per ounce, free no-key endpoint
      final goldRes = await http
          .get(Uri.parse('https://api.gold-api.com/price/XAU'))
          .timeout(const Duration(seconds: 10));
      final fxRes = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 10));
      if (goldRes.statusCode == 200 && fxRes.statusCode == 200) {
        final g = json.decode(goldRes.body) as Map<String, dynamic>;
        final f = json.decode(fxRes.body) as Map<String, dynamic>;
        final ounceUsd = (g['price'] as num?)?.toDouble();
        final usdIdr = ((f['rates'] as Map?)?['IDR'] as num?)?.toDouble();
        if (ounceUsd != null && usdIdr != null) {
          final perGram = ounceUsd * usdIdr / 31.1035;
          setState(() {
            _goldCtrl.text = perGram.toStringAsFixed(0);
            _priceNote =
                context.l10n.zakatGoldRateNote;
          });
          return;
        }
      }
      throw Exception('price unavailable');
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _priceNote =
            context.l10n.zakatGoldRateFailed,
      );
    } finally {
      if (mounted) setState(() => _loadingPrice = false);
    }
  }

  void _hitung() {
    setState(() {
      _result = null;
      _resultLabel = '';
    });
    if (_type == 'mal') {
      final harta =
          double.tryParse(
            _amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
          ) ??
          0;
      final gold =
          double.tryParse(_goldCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0;
      final nisab = gold * 85;
      if (harta <= 0 || gold <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.zakatInvalidMal),
          ),
        );
        return;
      }
      if (harta < nisab) {
        setState(() {
          _result = 0;
          _resultLabel =
              context.l10n.zakatBelowNisab(_idr(nisab), _idr(harta));
        });
        return;
      }
      setState(() {
        _result = harta * 0.025;
        _resultLabel =
            context.l10n.zakatMalResult(_idr(harta), _idr(nisab));
      });
    } else if (_type == 'fitrah') {
      final jiwa = int.tryParse(_soulsCtrl.text) ?? 0;
      final beras =
          double.tryParse(_riceCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0;
      if (jiwa <= 0 || beras <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.zakatInvalidFitrah),
          ),
        );
        return;
      }
      setState(() {
        _result = jiwa * 2.5 * beras;
        _resultLabel = context.l10n.zakatFitrahResult('$jiwa', _idr(beras));
      });
      return;
    } else if (_type == 'pertanian') {
      final hasil =
          double.tryParse(
            _amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
          ) ??
          0;
      if (hasil <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.zakatInvalidHarvest)),
        );
        return;
      }
      // Disederhanakan: tadah hujan 10%, irigasi 5%. Tampilkan keduanya agar akurat.
      setState(() {
        _result = hasil * 0.10;
        _resultLabel =
            context.l10n.zakatHarvestResult(_idr(hasil * 0.10), _idr(hasil * 0.05));
      });
    } else if (_type == 'emas') {
      final gram =
          double.tryParse(
            _amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
          ) ??
          0;
      final gold =
          double.tryParse(_goldCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0;
      if (gram < 85) {
        setState(() {
          _result = 0;
          _resultLabel = context.l10n.zakatGoldBelowNisab('$gram');
        });
        return;
      }
      setState(() {
        _result = gram * 0.025 * (gold > 0 ? gold : 0);
        _resultLabel = context.l10n.zakatGoldResult('$gram', _idr(gold));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.zakatTitle, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            Text(
              l10n.zakatSubtitle,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: .72),
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          LiquidGlassCard(
            radius: 20,
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in [
                  ['mal', context.l10n.zakatTypeMal],
                  ['fitrah', context.l10n.zakatTypeFitrah],
                  ['pertanian', context.l10n.zakatTypePertanian],
                  ['emas', context.l10n.zakatTypeGold],
                ])
                  ChoiceChip(
                    label: Text(t[1]),
                    selected: _type == t[0],
                    onSelected: (_) => setState(() {
                      _type = t[0];
                      _result = null;
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LiquidGlassCard(
            radius: 20,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_type == 'mal') ...[
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.zakatFieldWealth,
                      hintText: 'cth 100000000',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _goldCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.zakatFieldGoldPrice,
                      suffixIcon: _loadingPrice
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh_rounded),
                              onPressed: _fetchGoldPrice,
                            ),
                    ),
                  ),
                  if (_priceNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _priceNote!,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: .72),
                        ),
                      ),
                    ),
                ],
                if (_type == 'fitrah') ...[
                  TextField(
                    controller: _soulsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: context.l10n.zakatFieldSouls),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _riceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.zakatFieldRicePrice,
                    ),
                  ),
                ],
                if (_type == 'pertanian') ...[
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.zakatFieldHarvest,
                      hintText: 'cth 20000000',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.zakatHarvestNote,
                  ),
                ],
                if (_type == 'emas') ...[
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.zakatFieldGoldWeight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _goldCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.zakatFieldGoldPrice,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _hitung,
                    icon: const Icon(Icons.calculate_rounded),
                    label: Text(context.l10n.zakatCalculate),
                  ),
                ),
              ],
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            LiquidGlassCard(
              radius: 20,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.zakatResult,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _idr(_result!),
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(_resultLabel),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            context.l10n.zakatReference,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: .72),
            ),
          ),
        ],
      ),
    );
  }
}
