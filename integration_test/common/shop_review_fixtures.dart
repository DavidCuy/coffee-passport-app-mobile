// Fixtures/helpers de seed para los flujos de Mapa/Directorio,
// Favoritos y Reseñas — ver
// `test/e2e/test-matrices/mapa-directorio.md`.
//
// Agente QA Mobile — tercera pasada (EJECUTADA), 2026-08-02. El
// coordinador confirmó que Backend/Mobile cerraron y reconciliaron el
// contrato real contra la Supabase migrada:
//   - `GET /shops/{id}`: `rating_average`/`review_count` (nombres ya
//     usados tal cual por `ShopRepositoryImpl`, sin heurísticas).
//   - `GET /shops/{id}/reviews`: pública, cada item trae
//     `reviewer_display_name` e **`is_mine`** calculado del lado del
//     backend contra el header opcional `X-Auth-User-Sub` — el gap de
//     "reload frío no reconoce mi reseña" (hallazgo #3 de la 2da pasada
//     de la matriz) quedó CERRADO. Ya no hace falta crear la reseña
//     propia pasando por la UI para que se reconozca como "mía": sembrar
//     por API con el mismo `sub` que usa la app funciona igual.
//
// `ApiClient` (Mobile) ya soporta `get`/`post`/`patch`/`delete`. Este
// archivo se mantiene con `package:http` directo de todos modos porque
// estos helpers necesitan actuar como un `sub` explícito y arbitrario
// (ej. `otherReviewerSub`, un "otro usuario" que NO es el que está
// logueado en el `ApiClient` que arma la app vía
// `DevAuthLocalDatasource`) — usar `ApiClient` real obligaría a pisar el
// `sub` guardado en `SharedPreferencesAsync` antes y después de cada
// llamada, con riesgo real de carreras contra el árbol de widgets ya
// pumpeado en paralelo. Réplica mínima y explícita de la misma cabecera
// (`X-Auth-User-Sub`) que usa `ApiClient._headers()`.
//
// Ids reales de cafetería: a diferencia de `test_fixtures.dart` (que sí
// puede hardcodear el string de QR porque está atado a un
// `MASTER_SECRET` fijo de un `.env` conocido), acá NO se hardcodea el
// `id`/`slug` de las cafeterías demo — se resuelven en runtime vía
// [fetchShops]/[resolveShopId] contra `GET /shops`, que no depende de
// ningún secreto. Confirmado leyendo `core_db/models/shop.py`: el `id`
// path param que esperan `add_favorite`/`create_shop_review`/etc. es el
// PK serial entero de `shops`, NO el `qr_slug` — por eso
// [resolveShopId] busca por `qr_slug` y regresa el `id` numérico real.

import 'dart:convert';

import 'package:coffee_passport_app/core/config/env.dart';
import 'package:http/http.dart' as http;

Map<String, String> _authHeaders(String sub, {bool withJsonBody = false}) {
  return {
    'X-Auth-User-Sub': sub,
    if (withJsonBody) 'Content-Type': 'application/json',
  };
}

Uri _resolve(String path) {
  final base = Uri.parse(Env.apiBaseUrl);
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return base.replace(path: '${base.path}$normalizedPath');
}

/// Trae la lista cruda de cafeterías (`GET /shops`, ya desenvuelta del
/// `{"data": [...]}` genérico si aplica) — usado para resolver ids
/// reales de las cafeterías demo sin hardcodearlos.
Future<List<Map<String, dynamic>>> fetchShops({required String sub}) async {
  final response = await http.get(
    _resolve('/shops'),
    headers: _authHeaders(sub),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'GET /shops falló (${response.statusCode}): ${response.body}',
    );
  }
  final decoded = jsonDecode(response.body);
  final List<dynamic> raw;
  if (decoded is List) {
    raw = decoded;
  } else if (decoded is Map && decoded['data'] is List) {
    raw = decoded['data'] as List<dynamic>;
  } else if (decoded is Map && decoded['shops'] is List) {
    raw = decoded['shops'] as List<dynamic>;
  } else {
    throw Exception('Respuesta inesperada de GET /shops: $decoded');
  }
  return raw.cast<Map<String, dynamic>>();
}

/// Resuelve el `id` numérico real (PK serial de `shops`) de la
/// cafetería demo cuyo `qr_slug` es [qrSlug] (ej. `'demo-cafe-uno'`,
/// `'demo-cafe-dos'`, ver `API endpoints.md`) — nunca hardcodear el
/// `id`, depende del orden real de inserción del seed del Agente DB.
Future<String> resolveShopId(String qrSlug, {required String sub}) async {
  final shops = await fetchShops(sub: sub);
  final match = shops.firstWhere(
    (s) => s['qr_slug'] == qrSlug,
    orElse: () => throw Exception(
      'No se encontró ninguna cafetería con qr_slug=$qrSlug en '
      'GET /shops — ¿el seed demo del Agente DB sigue aplicado?',
    ),
  );
  return match['id'].toString();
}

/// Trae `rating_average`/`review_count` reales de `GET /shops/{id}` —
/// usado para calcular el promedio esperado DINÁMICAMENTE a partir del
/// estado real (en vez de asumir una cafetería "limpia"/sin reseñas
/// previas). `shop_reviews` es una tabla real de la Supabase migrada,
/// sin reset entre corridas de esta suite — reseñas sembradas en
/// pasadas anteriores de esta misma sesión de diagnóstico quedan ahí
/// para siempre (no hay endpoint de limpieza masiva expuesto a la app).
Future<({double avg, int count})> fetchShopRatingSummary(
  String shopId, {
  required String sub,
}) async {
  final response = await http.get(
    _resolve('/shops/$shopId'),
    headers: _authHeaders(sub),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'GET /shops/$shopId falló (${response.statusCode}): '
      '${response.body}',
    );
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final avgRaw = decoded['rating_average'];
  final countRaw = decoded['review_count'];
  return (
    avg: avgRaw == null ? 0.0 : (avgRaw as num).toDouble(),
    count: countRaw == null ? 0 : (countRaw as num).toInt(),
  );
}

/// Cuenta cuántas reseñas **ajenas** (`is_mine == false`) tiene [shopId]
/// ahora mismo, vistas por [sub] — usado para adaptar dinámicamente
/// casos que necesitarían una cafetería "limpia" (ver
/// [fetchShopRatingSummary]).
Future<int> countOtherReviews(String shopId, {required String sub}) async {
  final response = await http.get(
    _resolve('/shops/$shopId/reviews'),
    headers: _authHeaders(sub),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'GET /shops/$shopId/reviews falló (${response.statusCode}): '
      '${response.body}',
    );
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final data = (decoded['data'] as List<dynamic>).cast<Map<String, dynamic>>();
  return data.where((r) => r['is_mine'] != true).length;
}

/// Marca [shopId] como favorita para [sub] (`POST /shops/{id}/favorite`,
/// idempotente — `add_favorite/function.py` real). Seguro de usar con el
/// `sub` del usuario logueado en la app (a diferencia de [seedReview],
/// ver el aviso de cabecera del archivo): `GET /favorites` es la fuente
/// de verdad real, sin heurística de "mine" en memoria de por medio.
Future<void> seedFavorite(String shopId, {required String sub}) async {
  final response = await http.post(
    _resolve('/shops/$shopId/favorite'),
    headers: _authHeaders(sub),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'POST /shops/$shopId/favorite falló (${response.statusCode}): '
      '${response.body}',
    );
  }
}

/// Quita [shopId] de favoritas para [sub] (`DELETE /shops/{id}/favorite`,
/// soft-delete — `remove_favorite/function.py` real). Mismo criterio de
/// seguridad que [seedFavorite].
Future<void> removeFavorite(String shopId, {required String sub}) async {
  final response = await http.delete(
    _resolve('/shops/$shopId/favorite'),
    headers: _authHeaders(sub),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'DELETE /shops/$shopId/favorite falló (${response.statusCode}): '
      '${response.body}',
    );
  }
}

/// Siembra una reseña de [sub] para [shopId] (`POST /shops/{id}/reviews`
/// — `create_shop_review/function.py` real, 409 si [sub] ya tiene una
/// reseña activa ahí). Regresa el body decodificado (se espera que
/// incluya el `id` de la reseña creada, para poder armar
/// `Key('shop_review_card_<id>')` en los asserts).
///
/// Seguro de usar con el `sub` del usuario logueado en la app (ver
/// cabecera del archivo): `is_mine` se calcula del lado del backend
/// contra `X-Auth-User-Sub` en cada `GET`, no depende de haberla creado
/// por la UI en la misma sesión.
Future<Map<String, dynamic>> seedReview(
  String shopId, {
  required String sub,
  required int rating,
  required String comment,
}) async {
  final response = await http.post(
    _resolve('/shops/$shopId/reviews'),
    headers: _authHeaders(sub, withJsonBody: true),
    body: jsonEncode({'rating': rating, 'comment': comment}),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'POST /shops/$shopId/reviews falló (${response.statusCode}): '
      '${response.body}',
    );
  }
  if (response.body.isEmpty) return const {};
  return jsonDecode(response.body) as Map<String, dynamic>;
}

/// Actualiza la reseña propia de [sub] para [shopId]
/// (`PATCH /shops/{id}/reviews/mine` — `update_my_review/function.py`
/// real). Útil como atajo de seed; `shop_reviews_flow_test.dart` también
/// cubre la edición pasando por `shop_review_edit_button` real para
/// probar el formulario en sí.
Future<void> updateOwnReview(
  String shopId, {
  required String sub,
  required int rating,
  required String comment,
}) async {
  final response = await http.patch(
    _resolve('/shops/$shopId/reviews/mine'),
    headers: _authHeaders(sub, withJsonBody: true),
    body: jsonEncode({'rating': rating, 'comment': comment}),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'PATCH /shops/$shopId/reviews/mine falló (${response.statusCode}): '
      '${response.body}',
    );
  }
}

/// Borra la reseña propia de [sub] para [shopId]
/// (`DELETE /shops/{id}/reviews/mine` — `delete_my_review/function.py`
/// real). Mismo criterio que [updateOwnReview] sobre para qué `sub`
/// tiene sentido usar este helper.
Future<void> deleteOwnReview(String shopId, {required String sub}) async {
  final response = await http.delete(
    _resolve('/shops/$shopId/reviews/mine'),
    headers: _authHeaders(sub),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'DELETE /shops/$shopId/reviews/mine falló (${response.statusCode}): '
      '${response.body}',
    );
  }
}

/// Sub de prueba fijo para representar a "otro usuario" en los casos que
/// necesitan una reseña ajena (REV-01, REV-07) — distinto del `sub`
/// principal (`testUserSub` de `dev_auth.dart`) que actúa como el
/// usuario logueado en la app durante el test.
final String otherReviewerSub =
    'qa-mobile-e2e-other-reviewer-${DateTime.now().millisecondsSinceEpoch}';
