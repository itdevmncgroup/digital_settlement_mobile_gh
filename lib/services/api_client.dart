import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb, TargetPlatform, defaultTargetPlatform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';

/// http.MultipartFile.fromBytes has no way to infer content-type from a
/// filename (that's fromPath-only, which needs dart:io and doesn't work on
/// web) - without an explicit contentType every upload defaults to
/// application/octet-stream, which the backend's image-only fileFilter
/// rejects as "Unsupported file type". Map by extension instead.
MediaType? _mediaTypeForFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  if (lower.endsWith('.webp')) return MediaType('image', 'webp');
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return MediaType('image', 'jpeg');
  return null;
}

const String _explicitApiBaseUrl = String.fromEnvironment('API_BASE_URL');

const _secureStorage = FlutterSecureStorage();
const _apiBaseUrlOverrideKey = 'apiBaseUrlOverride';

/// Runtime override set via the login screen's endpoint-settings (gear icon)
/// dialog, persisted in secure storage so it survives app restarts. Lets a QA
/// device point at staging/a colleague's LAN IP without a rebuild. Takes
/// priority over both the --dart-define default and the per-platform default
/// below. Must be loaded once at startup via [loadApiBaseUrlOverride] before
/// any request is made.
String? apiBaseUrlOverride;

/// A broken/invalidated Keystore entry (common after a reinstall on some
/// Android versions) makes secure-storage reads throw instead of returning
/// null - must not propagate, since this runs before runApp() in main() and
/// an uncaught throw there means the app never draws its first frame (stuck
/// on the native launch screen forever, indistinguishable from infinite
/// loading). Falls back to the compile-time/platform default on any error.
Future<void> loadApiBaseUrlOverride() async {
  try {
    final stored = await _secureStorage.read(key: _apiBaseUrlOverrideKey);
    if (stored != null && stored.isNotEmpty) apiBaseUrlOverride = stored;
  } catch (e, st) {
    developer.log('Failed to read apiBaseUrlOverride from secure storage', name: 'api', error: e, stackTrace: st);
  }
}

/// Sets or clears (`null`/empty) the endpoint override and persists it
/// immediately - takes effect on the very next request, no restart needed.
Future<void> setApiBaseUrlOverride(String? url) async {
  final trimmed = url?.trim();
  apiBaseUrlOverride = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  if (apiBaseUrlOverride == null) {
    await _secureStorage.delete(key: _apiBaseUrlOverrideKey);
  } else {
    await _secureStorage.write(key: _apiBaseUrlOverrideKey, value: apiBaseUrlOverride);
  }
}

/// Base URL for the NestJS backend (same API web-admin talks to). Override at
/// build/run time with `--dart-define=API_BASE_URL=http://HOST:3000/api/v1`,
/// or at runtime via [setApiBaseUrlOverride] (needed for a physical device,
/// which can't reach the dev machine via localhost/10.0.2.2 - use the dev
/// machine's LAN IP instead).
///
/// Without either override, the default depends on where this build runs:
///  - Flutter web (`flutter run -d chrome`): the browser IS on the dev
///    machine, so `localhost` reaches the backend directly.
///  - Android emulator: `10.0.2.2` is the emulator's alias for the host
///    machine's localhost - plain `localhost` would point at the emulator
///    itself, which has no backend running on it.
///  - Everything else (iOS simulator, desktop): `localhost` works.
///
/// `defaultTargetPlatform` (unlike dart:io's Platform) is safe to read on
/// every platform including web, so this needs no conditional imports.
String get apiBaseUrl {
  if (apiBaseUrlOverride != null) return apiBaseUrlOverride!;
  if (_explicitApiBaseUrl.isNotEmpty) return _explicitApiBaseUrl;
  if (kIsWeb) return 'http://localhost:3000/api/v1';
  if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000/api/v1';
  return 'http://localhost:3000/api/v1';
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

void _logError(String method, String path, Object error, StackTrace stackTrace) {
  developer.log(
    '$method $path failed: $error',
    name: 'api',
    error: error,
    stackTrace: stackTrace,
  );
}

/// Thin wrapper around the backend REST API - mirrors web-admin/src/lib/api.ts
/// (same endpoints, same JWT bearer auth, same error-message shape). A 401
/// from any call forces the session back to the login screen, same as web.
/// Every failure (network error or non-2xx response) is logged via
/// dart:developer so it shows up in `flutter run`'s console / DevTools,
/// instead of only surfacing as a generic on-screen message.
class ApiClient {
  final AuthService auth;
  ApiClient(this.auth);

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    final token = auth.accessToken;
    if (token != null) h['Authorization'] = 'Bearer $token';
    return h;
  }

  Uri _uri(String path) => Uri.parse('$apiBaseUrl$path');

  Future<dynamic> get(String path) async {
    try {
      final res = await http.get(_uri(path), headers: _headers());
      return _handle('GET', path, res);
    } catch (e, st) {
      if (e is ApiException) rethrow;
      _logError('GET', path, e, st);
      throw ApiException(0, 'Could not reach the server at $apiBaseUrl ($e)');
    }
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    try {
      final res = await http.post(_uri(path), headers: _headers(), body: body != null ? jsonEncode(body) : null);
      return _handle('POST', path, res);
    } catch (e, st) {
      if (e is ApiException) rethrow;
      _logError('POST', path, e, st);
      throw ApiException(0, 'Could not reach the server at $apiBaseUrl ($e)');
    }
  }

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    try {
      final res = await http.patch(_uri(path), headers: _headers(), body: body != null ? jsonEncode(body) : null);
      return _handle('PATCH', path, res);
    } catch (e, st) {
      if (e is ApiException) rethrow;
      _logError('PATCH', path, e, st);
      throw ApiException(0, 'Could not reach the server at $apiBaseUrl ($e)');
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final res = await http.delete(_uri(path), headers: _headers());
      return _handle('DELETE', path, res);
    } catch (e, st) {
      if (e is ApiException) rethrow;
      _logError('DELETE', path, e, st);
      throw ApiException(0, 'Could not reach the server at $apiBaseUrl ($e)');
    }
  }

  /// Uploads one file as multipart form data under the `file` field, same as
  /// the backend's FileInterceptor endpoints (photos, invoice files, OCR
  /// scan, bank-settlement upload).
  Future<dynamic> uploadFile(String path, {required List<int> bytes, required String filename, String? queryString}) async {
    final uri = _uri(queryString != null ? '$path?$queryString' : path);
    try {
      final req = http.MultipartRequest('POST', uri);
      final token = auth.accessToken;
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: _mediaTypeForFilename(filename)));
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      return _handle('POST', path, res);
    } catch (e, st) {
      if (e is ApiException) rethrow;
      _logError('POST (upload)', path, e, st);
      throw ApiException(0, 'Could not reach the server at $apiBaseUrl ($e)');
    }
  }

  dynamic _handle(String method, String path, http.Response res) {
    if (res.statusCode == 401) {
      developer.log('$method $path -> 401, logging out', name: 'api');
      auth.logout();
      throw ApiException(401, 'Session expired - please log in again.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      var message = 'Request failed (${res.statusCode})';
      try {
        final body = jsonDecode(res.body);
        final m = body['message'];
        if (m is List) {
          message = m.join(', ');
        } else if (m is String) {
          message = m;
        }
      } catch (_) {
        // Non-JSON error body - keep the generic message.
      }
      developer.log('$method $path -> ${res.statusCode}: $message', name: 'api');
      throw ApiException(res.statusCode, message);
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }
}
