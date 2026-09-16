import 'package:flutter_test/flutter_test.dart';
import 'package:quranku/services/update_service.dart';

void main() {
  group('isNewer', () {
    test('detects newer tags', () {
      expect(UpdateService.isNewer('v3.1.0', '3.0.0'), isTrue);
      expect(UpdateService.isNewer('3.0.1', '3.0.0'), isTrue);
      expect(UpdateService.isNewer('4.0.0', '3.9.9'), isTrue);
    });

    test('rejects same or older tags', () {
      expect(UpdateService.isNewer('v3.0.0', '3.0.0'), isFalse);
      expect(UpdateService.isNewer('3.0.0', '3.1.0'), isFalse);
      expect(UpdateService.isNewer('', '3.0.0'), isFalse);
    });
  });

  group('pickApk', () {
    const release = GithubRelease(
      tag: 'v3.1.0',
      name: 'v3.1.0',
      body: '',
      htmlUrl: '',
      assets: [
        GithubAsset(
          name: 'app-arm64.apk',
          size: 10,
          downloadUrl: 'https://example.com/a.apk',
        ),
        GithubAsset(
          name: 'notes.txt',
          size: 100,
          downloadUrl: 'https://example.com/n.txt',
        ),
        GithubAsset(
          name: 'app-universal.apk',
          size: 20,
          downloadUrl: 'https://example.com/b.apk',
        ),
      ],
    );

    test('picks largest apk, ignores non-apk', () {
      final picked = UpdateService.pickApk(release);
      expect(picked?.name, 'app-universal.apk');
    });

    test('null when no apk asset', () {
      const empty = GithubRelease(
        tag: 'v1',
        name: 'v1',
        body: '',
        htmlUrl: '',
        assets: [],
      );
      expect(UpdateService.pickApk(empty), isNull);
    });
  });
}
