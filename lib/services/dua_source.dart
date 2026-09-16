import '../data/daily_duas.dart';
import 'equran_service.dart';
import 'hisnulmuslim_service.dart';

/// Loads the remote dua set that matches a UI language.
///
/// Indonesian duas come from equran.id (227+, Indonesian only). English duas
/// come from Hisn al-Muslim, which publishes no bulk endpoint and is therefore
/// streamed chapter by chapter via [onBatch].
class DuaSource {
  DuaSource({HisnulmuslimService? hisnulmuslim})
    : _hisnulmuslim = hisnulmuslim ?? HisnulmuslimService();

  final HisnulmuslimService _hisnulmuslim;

  Future<List<DailyDua>> loadRemote(
    String languageCode, {
    void Function(List<DailyDua> batch)? onBatch,
    bool forceRefresh = false,
  }) {
    return duaLanguageCode(languageCode) == 'en'
        ? _hisnulmuslim.loadAll(
            onBatch: onBatch,
            forceRefresh: forceRefresh,
          )
        : _fromEquran();
  }

  Future<List<DailyDua>> _fromEquran() async {
    final list = await EquranService.fetchDoa();
    return [for (final e in list) equranDuaToDaily(e)];
  }
}

/// Maps an equran.id doa onto the app's [DailyDua] shape.
///
/// The id is the API's Indonesian `nama`: that set is Indonesian-only, so the
/// name never changes with the UI language, and existing bookmarks keyed by it
/// keep working.
DailyDua equranDuaToDaily(EquranDoa dua) => DailyDua(
  id: dua.nama,
  arabic: dua.arabic,
  latin: dua.latin,
  texts: {
    'id': DuaText(
      title: dua.nama,
      category: dua.grup.isNotEmpty ? dua.grup : 'Lainnya',
      translation: dua.translation,
      source: dua.source.isNotEmpty ? '${dua.source} • equran.id' : 'equran.id',
    ),
  },
);
