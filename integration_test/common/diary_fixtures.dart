// Fixtures/helpers de seed para el flujo Diario de cata — ver
// `test/e2e/test-matrices/diario-de-cata.md`.
//
// Agente QA Mobile — 1ra pasada (EJECUTADA), 2026-08-03/04. Mismo
// criterio que `shop_review_fixtures.dart`: `package:http` directo (no
// `ApiClient`) para poder actuar como un `sub` explícito y arbitrario
// sin pisar el estado del dev-login activo de la app que ya está
// pumpeada.
//
// ⚠️ Confirmado en esta pasada, vía `curl` directo contra el backend
// real (ANTES de escribir el resto de esta suite): `POST /diary`
// exige `brew_method` y `visited_at` de hecho NOT NULL en la Postgres
// real (changeset `012_create_diary_entries_table.sql`), aunque el
// contrato documentado y el propio `create_diary_entry/function.py`
// los tratan como opcionales — con `brew_method`/`visited_at`
// omitidos, el INSERT revienta con `NotNullViolation` real (500
// crudo, expuesto como 422 genérico). Ver "Bug backend #1" en la
// matriz para el detalle completo (causa raíz, por qué no lo dispara
// la UI real de Mobile, y por qué no se arregló en este repo). Por
// las dudas, **este helper siempre manda ambos campos** — nunca se
// usa para reproducir ese bug (el bug se reprodujo una sola vez con
// `curl` directo, documentado aparte, no vía Patrol).
//
// Ids reales de cafetería: igual que `shop_review_fixtures.dart`, NO
// se hardcodean — se resuelven en runtime contra `GET /shops`
// (`resolveShopId`, reexportado desde ese archivo, se sigue usando
// tal cual).

import 'dart:convert';

import 'package:coffee_passport_app/core/config/env.dart';
import 'package:http/http.dart' as http;

Map<String, String> _authHeaders(String sub) {
  return {
    'X-Auth-User-Sub': sub,
    'Content-Type': 'application/json',
  };
}

Uri _resolve(String path) {
  final base = Uri.parse(Env.apiBaseUrl);
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return base.replace(path: '${base.path}$normalizedPath');
}

/// Trae las entradas del diario de [sub] tal cual las devuelve
/// `GET /diary` (ya desenvueltas del wrapper `{"data": [...]}` real).
Future<List<Map<String, dynamic>>> fetchDiaryEntries({
  required String sub,
}) async {
  final response = await http.get(_resolve('/diary'), headers: _authHeaders(sub));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('GET /diary falló (${response.statusCode}): ${response.body}');
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  return (decoded['data'] as List<dynamic>).cast<Map<String, dynamic>>();
}

/// Siembra una entrada de diario de [sub] contra `POST /diary` real —
/// SIEMPRE manda `brew_method`/`visited_at` (ver aviso de cabecera del
/// archivo sobre por qué). Regresa el body decodificado (trae el `id`
/// real, entre otros campos — ver `create_diary_entry/function.py`).
Future<Map<String, dynamic>> seedDiaryEntry(
  String shopId, {
  required String sub,
  required int rating,
  String brewMethod = 'v60',
  String? note,
  DateTime? visitedAt,
}) async {
  final response = await http.post(
    _resolve('/diary'),
    headers: _authHeaders(sub),
    body: jsonEncode({
      'id_shop': int.tryParse(shopId) ?? shopId,
      'brew_method': brewMethod,
      'rating': rating,
      // ignore: use_null_aware_elements
      if (note != null) 'note': note,
      'visited_at': (visitedAt ?? DateTime.now()).toUtc().toIso8601String(),
    }),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('POST /diary falló (${response.statusCode}): ${response.body}');
  }
  return jsonDecode(response.body) as Map<String, dynamic>;
}

/// Borra (soft-delete) una entrada de diario propia — usada como
/// limpieza best-effort en `tearDown` (mismo criterio que
/// `deleteOwnReview` de `shop_review_fixtures.dart`).
Future<void> deleteDiaryEntry(String id, {required String sub}) async {
  final response = await http.delete(_resolve('/diary/$id'), headers: _authHeaders(sub));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('DELETE /diary/$id falló (${response.statusCode}): ${response.body}');
  }
}
