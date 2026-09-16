import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Over-the-air updates from GitHub releases (Rafigibran/QuranKu).
/// Check latest tag, compare with the installed version, download the
/// release APK, and open the system installer. Android only.
class UpdateService extends ChangeNotifier {
  static const String owner = 'Rafigibran';
  static const String repo = 'QuranKu';
  static const String latestApi =
      'https://api.github.com/repos/$owner/$repo/releases/latest';

  final Dio _dio = Dio();

  String installedVersion = '';
  GithubRelease? latest;
  double downloadProgress = 0;
  bool busy = false;
  String? error;

  /// Pure semver compare used by tests: true when [latest] is newer.
  static bool isNewer(String latest, String current) {
    List<int> parts(String v) {
      return v
          .replaceFirst(RegExp(r'^[vV]'), '')
          .split(RegExp(r'[-+.]'))
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
    }

    final l = parts(latest);
    final c = parts(current);
    for (var i = 0; i < 3; i++) {
      final li = i < l.length ? l[i] : 0;
      final ci = i < c.length ? c[i] : 0;
      if (li != ci) return li > ci;
    }
    return false;
  }

  /// Pick the release APK asset (largest .apk), null when absent.
  static GithubAsset? pickApk(GithubRelease release) {
    GithubAsset? best;
    for (final a in release.assets) {
      if (!a.name.toLowerCase().endsWith('.apk')) continue;
      if (best == null || a.size > best.size) best = a;
    }
    return best;
  }

  Future<void> loadInstalled() async {
    try {
      final info = await PackageInfo.fromPlatform();
      installedVersion = info.version;
    } catch (_) {
      installedVersion = '';
    }
    notifyListeners();
  }

  /// Fetch latest release. Sets [error] when no release exists or offline.
  Future<bool> checkLatest() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final res = await _dio
          .get(
            latestApi,
            options: Options(headers: {'Accept': 'application/vnd.github+json'}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200 && res.data is Map) {
        latest = GithubRelease.parse(res.data as Map<String, dynamic>);
      } else if (res.statusCode == 404) {
        error = 'No GitHub release found yet.';
      } else {
        error = 'Update check failed (${res.statusCode}).';
      }
    } catch (e) {
      debugPrint('Update check error: $e');
      error = 'Check failed. Connect to the internet and try again.';
    }
    busy = false;
    notifyListeners();
    return error == null && latest != null;
  }

  bool get updateAvailable {
    final tag = latest?.tag;
    if (tag == null || tag.isEmpty || installedVersion.isEmpty) return false;
    return isNewer(tag, installedVersion);
  }

  /// Download the APK with progress, then open the system installer.
  /// [onProgress] receives 0.0-1.0. Returns true when installer opened.
  Future<bool> downloadAndInstall({
    void Function(double progress)? onProgress,
  }) async {
    final asset = latest == null ? null : pickApk(latest!);
    if (asset == null) {
      error = 'Release has no APK file.';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    downloadProgress = 0;
    notifyListeners();
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${asset.name}';
      await _dio.download(
        asset.downloadUrl,
        path,
        deleteOnError: true,
        onReceiveProgress: (count, total) {
          if (total > 0) {
            downloadProgress = count / total;
            onProgress?.call(downloadProgress);
            notifyListeners();
          }
        },
      );
      busy = false;
      notifyListeners();
      final result = await OpenFilex.open(
        path,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type != ResultType.done) {
        error = 'Installer did not open: ${result.message}';
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('OTA download error: $e');
      error = 'Download failed. Connect to the internet and try again.';
      busy = false;
      notifyListeners();
      return false;
    }
  }
}

class GithubRelease {
  final String tag;
  final String name;
  final String body;
  final String htmlUrl;
  final List<GithubAsset> assets;
  const GithubRelease({
    required this.tag,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.assets,
  });

  factory GithubRelease.parse(Map<String, dynamic> json) {
    return GithubRelease(
      tag: '${json['tag_name'] ?? ''}',
      name: '${json['name'] ?? json['tag_name'] ?? ''}',
      body: '${json['body'] ?? ''}',
      htmlUrl: '${json['html_url'] ?? ''}',
      assets: [
        for (final a in (json['assets'] as List<dynamic>? ?? []))
          GithubAsset.parse(a as Map<String, dynamic>),
      ],
    );
  }
}

class GithubAsset {
  final String name;
  final int size;
  final String downloadUrl;
  const GithubAsset({
    required this.name,
    required this.size,
    required this.downloadUrl,
  });

  factory GithubAsset.parse(Map<String, dynamic> json) {
    return GithubAsset(
      name: '${json['name'] ?? ''}',
      size: (json['size'] as num? ?? 0).toInt(),
      downloadUrl: '${json['browser_download_url'] ?? ''}',
    );
  }
}
