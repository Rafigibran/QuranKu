import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const int _lbrace = 0x7B; // {
const int _lbracket = 0x5B; // [

class MirroredJsonException implements Exception {
  final String message;
  MirroredJsonException(this.message);

  @override
  String toString() => 'MirroredJsonException: $message';
}

/// Decodes a JSON body, or returns null when [body] is not a JSON object/array.
///
/// CDNs answer a missing file with a plain-text body such as
/// `Couldn't find the requested file ... in spa5k/tafsir_api.`, so a 2xx
/// response cannot be trusted to carry JSON.
dynamic decodeJsonBody(String body) {
  final trimmed = body.trimLeft();
  if (trimmed.isEmpty) return null;
  final first = trimmed.codeUnitAt(0);
  if (first != _lbrace && first != _lbracket) return null;
  try {
    return json.decode(body);
  } on FormatException {
    return null;
  }
}

/// Minimal read-only JSON client that tries a list of mirror base URLs in order
/// and returns the first usable payload.
///
/// Both upstream data sets (tafsir_api, Hisn al-Muslim) are static files hosted
/// on a CDN with a GitHub fallback, so they share this behaviour exactly.
class MirroredJsonClient {
  MirroredJsonClient({
    required this.mirrors,
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  }) : _client = client ?? http.Client();

  /// Base URLs, tried in order. `getJson('a/b.json')` requests
  /// `<mirror>/a/b.json`.
  final List<String> mirrors;
  final Duration timeout;
  final http.Client _client;

  /// Returns the decoded body, or null when the resource is absent on every
  /// mirror. Throws [MirroredJsonException] only when no mirror could be
  /// reached at all.
  Future<dynamic> getJson(String path) async {
    var sawNotFound = false;
    Object? transportError;

    for (final mirror in mirrors) {
      final url = '$mirror/$path';
      try {
        final res = await _client
            .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
            .timeout(timeout);

        if (res.statusCode == 404) {
          sawNotFound = true;
          continue;
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          transportError = MirroredJsonException(
            'GET $url: ${res.statusCode}',
          );
          continue;
        }

        // Decode as UTF-8 explicitly: `response.body` falls back to latin-1
        // when the mirror omits a charset, which mangles Arabic text.
        final decoded = decodeJsonBody(
          utf8.decode(res.bodyBytes, allowMalformed: true),
        );
        if (decoded == null) {
          // 2xx with a non-JSON body: some mirrors serve HTML error pages.
          sawNotFound = true;
          continue;
        }
        return decoded;
      } on TimeoutException catch (e) {
        transportError = MirroredJsonException('GET $url timeout: $e');
      } catch (e) {
        transportError = MirroredJsonException('GET $url gagal: $e');
      }
    }

    if (sawNotFound && transportError == null) return null;
    if (transportError != null) throw transportError;
    debugPrint('MirroredJsonClient: no mirror could resolve $path');
    return null;
  }

  /// Like [getJson] but unwraps a `{"data": ...}` envelope when present.
  Future<dynamic> getData(String path) async {
    final decoded = await getJson(path);
    return decoded is Map ? decoded['data'] : decoded;
  }
}
