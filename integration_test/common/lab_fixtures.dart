// Fixtures/helpers de lectura para el flujo del Laboratorio (recetas +
// catálogo de café) — ver `test/e2e/test-matrices/laboratorio.md`.
//
// Agente QA Mobile — 1ra pasada, 2026-08-04.
//
// A diferencia de `shop_review_fixtures.dart`/`diary_fixtures.dart`,
// este archivo NO siembra nada: `/coffees`/`/coffees/featured`/
// `/recipes`/`/recipes/{id}` son 100% de lectura para la app (el CRUD
// admin de `coffees`/`recipes` es "Capacidad admin", explícitamente
// fuera de alcance — ver `API endpoints.md`, nota 2026-08-04). Las 5
// recetas vienen de un seed fijo de DB (`003_insert_...` de
// `03_DML`), y `coffees` está vacía a propósito (ver
// `Base de datos.md`) — no hay nada que este agente pueda/deba
// sembrar por API para ninguna de las dos tablas.
//
// Los `id` reales de las recetas dependen del orden de inserción del
// seed (confirmado por curl al momento de escribir esta pasada: V60=1,
// Prensa francesa=2, Espresso=3, Chemex=4, Aeropress=5) — igual que
// `shop_review_fixtures.dart::resolveShopId` con las cafeterías demo,
// NO se hardcodean acá: [resolveRecipeId] los resuelve en runtime
// contra `GET /recipes` por `name`.

import 'dart:convert';

import 'package:coffee_passport_app/core/config/env.dart';
import 'package:http/http.dart' as http;

Uri _resolve(String path) {
  final base = Uri.parse(Env.apiBaseUrl);
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  return base.replace(path: '${base.path}$normalizedPath');
}

/// Trae la lista cruda de recetas (`GET /recipes`, sin envolver del
/// `{"data": [...]}` genérico si aplica) — pública, sin auth
/// requerida, pero se manda un header igual por si el backend lo
/// empieza a exigir más adelante.
Future<List<Map<String, dynamic>>> fetchRecipes({String? sub}) async {
  final response = await http.get(
    _resolve('/recipes'),
    headers: sub == null ? const {} : {'X-Auth-User-Sub': sub},
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'GET /recipes falló (${response.statusCode}): ${response.body}',
    );
  }
  final decoded = jsonDecode(response.body);
  final List<dynamic> raw;
  if (decoded is List) {
    raw = decoded;
  } else if (decoded is Map && decoded['data'] is List) {
    raw = decoded['data'] as List<dynamic>;
  } else {
    throw Exception('Respuesta inesperada de GET /recipes: $decoded');
  }
  return raw.cast<Map<String, dynamic>>();
}

/// Resuelve el `id` real de la receta cuyo `name` es [recipeName] (ej.
/// `'V60'`, `'Espresso'`) — nunca hardcodeado, mismo criterio que
/// `resolveShopId` en `shop_review_fixtures.dart`.
Future<String> resolveRecipeId(String recipeName) async {
  final recipes = await fetchRecipes();
  final match = recipes.firstWhere(
    (r) => r['name'] == recipeName,
    orElse: () => throw Exception(
      'No se encontró ninguna receta con name=$recipeName en '
      'GET /recipes — ¿el seed de recetas sigue aplicado?',
    ),
  );
  return match['id'].toString();
}

/// Trae la lista cruda del catálogo de café (`GET /coffees`) — se
/// espera vacía a propósito (ver cabecera del archivo), usado sólo
/// para confirmar el precondition antes de correr los casos de estado
/// vacío.
Future<List<Map<String, dynamic>>> fetchCoffees() async {
  final response = await http.get(_resolve('/coffees'));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'GET /coffees falló (${response.statusCode}): ${response.body}',
    );
  }
  final decoded = jsonDecode(response.body);
  final List<dynamic> raw;
  if (decoded is List) {
    raw = decoded;
  } else if (decoded is Map && decoded['data'] is List) {
    raw = decoded['data'] as List<dynamic>;
  } else {
    throw Exception('Respuesta inesperada de GET /coffees: $decoded');
  }
  return raw.cast<Map<String, dynamic>>();
}
