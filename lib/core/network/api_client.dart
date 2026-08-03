import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/dev_auth_local_datasource.dart';
import '../config/env.dart';

/// Excepción de red/API genérica usada por los repositorios de las
/// distintas features. Guarda el status code (si lo hay) para que la
/// UI pueda distinguir, por ejemplo, un 404 de un timeout.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Cliente HTTP compartido para hablar con `coffee-passport-backend`.
///
/// Responsabilidad única: apuntar a [Env.apiBaseUrl] y adjuntar en cada
/// request el header `X-Auth-User-Sub` que el backend exige (ver
/// `Deploy en producción.md` en el vault, sección "Auth"), leyendo el
/// sub de prueba desde [DevAuthLocalDatasource] — ver el comentario de
/// esa clase para el porqué es temporal.
///
/// Vive en `lib/core/` (no dentro de una sola feature) porque tanto
/// `passport`, `scan` como `shop_directory` lo necesitan por igual —
/// exactamente el caso que `ARCHITECTURE.md` describe como el momento
/// correcto para poblar `core/`.
class ApiClient {
  ApiClient({http.Client? httpClient, DevAuthLocalDatasource? authDatasource})
    : _httpClient = httpClient ?? http.Client(),
      _authDatasource = authDatasource ?? DevAuthLocalDatasource();

  final http.Client _httpClient;
  final DevAuthLocalDatasource _authDatasource;

  Uri _resolve(String path, [Map<String, dynamic>? queryParameters]) {
    final base = Uri.parse(Env.apiBaseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return base.replace(
      path: '${base.path}$normalizedPath',
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }

  Future<Map<String, String>> _headers({bool withJsonBody = false}) async {
    final sub = await _authDatasource.getDevSub();
    return {
      // ignore: use_null_aware_elements
      if (sub != null) 'X-Auth-User-Sub': sub,
      if (withJsonBody) 'Content-Type': 'application/json',
    };
  }

  /// GET a [path] del backend. Regresa el body ya decodificado como
  /// JSON (`Map` o `List`, según lo que responda el endpoint).
  ///
  /// No lanza por status codes que traigan un body JSON parseable con
  /// significado propio (ej. `POST /scan` responde 409 con
  /// `{"result": "out_of_range", "distance_meters": ...}`) — es
  /// responsabilidad de cada repositorio decidir qué hacer con el
  /// status + body. Sólo lanza [ApiException] si la respuesta no trae
  /// JSON decodificable, o si es un error de red/timeout.
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final uri = _resolve(path, query);
    final http.Response response;
    try {
      response = await _httpClient.get(uri, headers: await _headers());
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el backend: $e');
    }
    return _decode(response);
  }

  /// POST a [path] con [body] serializado a JSON.
  Future<ApiResponse> post(String path, {Object? body}) async {
    final uri = _resolve(path);
    final http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: await _headers(withJsonBody: true),
        body: body == null ? null : jsonEncode(body),
      );
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el backend: $e');
    }
    final decoded = _decode(response, allowEmptyOn2xx: true);
    return ApiResponse(statusCode: response.statusCode, body: decoded);
  }

  /// PATCH a [path] con [body] serializado a JSON.
  ///
  /// Usado por `shop_directory` para `PATCH /shops/{id}/reviews/mine`
  /// (editar la reseña propia — ver `API endpoints.md` del vault).
  Future<ApiResponse> patch(String path, {Object? body}) async {
    final uri = _resolve(path);
    final http.Response response;
    try {
      response = await _httpClient.patch(
        uri,
        headers: await _headers(withJsonBody: true),
        body: body == null ? null : jsonEncode(body),
      );
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el backend: $e');
    }
    final decoded = _decode(response, allowEmptyOn2xx: true);
    return ApiResponse(statusCode: response.statusCode, body: decoded);
  }

  /// DELETE a [path]. Usado por `shop_directory` para
  /// `DELETE /shops/{id}/favorite` y `DELETE /shops/{id}/reviews/mine`.
  Future<ApiResponse> delete(String path) async {
    final uri = _resolve(path);
    final http.Response response;
    try {
      response = await _httpClient.delete(uri, headers: await _headers());
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el backend: $e');
    }
    final decoded = _decode(response, allowEmptyOn2xx: true);
    return ApiResponse(statusCode: response.statusCode, body: decoded);
  }

  dynamic _decode(http.Response response, {bool allowEmptyOn2xx = false}) {
    if (response.body.isEmpty) {
      if (allowEmptyOn2xx &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        return null;
      }
      throw ApiException(
        'Respuesta vacía del backend',
        statusCode: response.statusCode,
      );
    }
    try {
      return jsonDecode(response.body);
    } on FormatException catch (e) {
      throw ApiException(
        'Respuesta del backend no es JSON válido: $e',
        statusCode: response.statusCode,
      );
    }
  }

  void close() => _httpClient.close();
}

/// Envuelve el status code + body decodificado de una respuesta POST,
/// para que el repositorio pueda inspeccionar ambos (necesario para
/// `POST /scan`, donde el status code distingue casos como
/// `out_of_range` de `success`).
class ApiResponse {
  ApiResponse({required this.statusCode, required this.body});

  final int statusCode;
  final dynamic body;

  bool get isSuccessStatus => statusCode >= 200 && statusCode < 300;
}
