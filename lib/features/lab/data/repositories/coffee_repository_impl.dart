import '../../../../core/network/api_client.dart';
import '../../domain/entities/coffee.dart';
import '../../domain/repositories/coffee_repository.dart';

/// Implementación real de [CoffeeRepository] contra `GET /coffees`,
/// `GET /coffees/featured` y `GET /coffees/{id}` de
/// `coffee-passport-backend`.
///
/// **Construida en paralelo al backend/DB** (2026-08-04, arranque del
/// módulo Laboratorio): al momento de escribir esta clase, el
/// changeset `009_create_coffee_catalog_tables.sql` (`coffees` +
/// `coffee_flavor_notes`) todavía estaba pendiente de aplicar del lado
/// de DB (ver `Base de datos.md`) y los 3 endpoints de café no existían
/// todavía del lado de Backend (mismo patrón que ya funcionó sin
/// retrabajo para Mapa/Directorio y Diario de cata, ver
/// `Fase 1 - Funcionalidades.md`). El parseo es defensivo por eso:
/// acepta snake_case y camelCase, y el wrapper `{"data": [...]}` que ya
/// es el patrón confirmado de `core_http.BaseController` para toda
/// lista del backend (`/shops`, `/levels`, `/shops/{id}/reviews`,
/// `/diary`). Revisar y reconciliar cuando Backend confirme el shape
/// exacto.
class CoffeeRepositoryImpl implements CoffeeRepository {
  // Ver nota de `PassportRepositoryImpl`/`ShopRepositoryImpl` sobre por
  // qué no se usa `this._apiClient` como initializing formal acá.
  CoffeeRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient; // ignore: prefer_initializing_formals

  final ApiClient _apiClient;

  @override
  Future<List<Coffee>> getCoffees() => _getList('/coffees');

  @override
  Future<List<Coffee>> getFeaturedCoffees() => _getList('/coffees/featured');

  @override
  Future<Coffee> getCoffeeById(String id) async {
    final raw = await _apiClient.get('/coffees/$id');
    if (raw is! Map) {
      throw ApiException('Respuesta inesperada de GET /coffees/$id: $raw');
    }
    return _coffeeFromJson(raw.cast<String, dynamic>());
  }

  Future<List<Coffee>> _getList(String path) async {
    final raw = await _apiClient.get(path);
    final List<dynamic> coffeesJson;
    if (raw is List) {
      coffeesJson = raw;
    } else if (raw is Map && raw['data'] is List) {
      coffeesJson = raw['data'] as List<dynamic>;
    } else if (raw is Map && raw['coffees'] is List) {
      coffeesJson = raw['coffees'] as List<dynamic>;
    } else {
      throw ApiException('Respuesta inesperada de GET $path: $raw');
    }
    return coffeesJson
        .cast<Map<String, dynamic>>()
        .map(_coffeeFromJson)
        .toList(growable: false);
  }

  /// Parseo defensivo de un item de `GET /coffees`/`GET
  /// /coffees/featured`/`GET /coffees/{id}` — nombres de columna reales
  /// documentados en `Base de datos.md`
  /// (`009_create_coffee_catalog_tables.sql`): `roaster_name`,
  /// `origin_locality`, `altitude_masl`, `process`, `variety`,
  /// `producer`, `sca_score`,
  /// `body_score`/`acidity_score`/`sweetness_score`/`aftertaste_score`,
  /// `story_text`, `is_featured`. `coffee_flavor_notes` puede venir
  /// anidado como lista de objetos (`note_label` por fila, ya ordenados
  /// por `sort_order` del lado del backend) o, de forma más simple,
  /// como lista plana de strings — se acepta cualquiera de las dos
  /// formas.
  Coffee _coffeeFromJson(Map<String, dynamic> json) {
    return Coffee(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      roasterName: (json['roaster_name'] ?? json['roasterName']) as String?,
      originLocality:
          (json['origin_locality'] ?? json['originLocality']) as String?,
      altitudeMasl: _asNullableInt(
        json['altitude_masl'] ?? json['altitudeMasl'],
      ),
      process: json['process'] as String?,
      variety: json['variety'] as String?,
      producer: json['producer'] as String?,
      scaScore: _asNullableInt(json['sca_score'] ?? json['scaScore']),
      bodyScore: _asNullableInt(json['body_score'] ?? json['bodyScore']),
      acidityScore: _asNullableInt(
        json['acidity_score'] ?? json['acidityScore'],
      ),
      sweetnessScore: _asNullableInt(
        json['sweetness_score'] ?? json['sweetnessScore'],
      ),
      aftertasteScore: _asNullableInt(
        json['aftertaste_score'] ?? json['aftertasteScore'],
      ),
      storyText: (json['story_text'] ?? json['storyText']) as String?,
      isFeatured:
          (json['is_featured'] ?? json['isFeatured'] ?? json['featured']) ==
          true,
      flavorNotes: _flavorNotesFrom(
        json['coffee_flavor_notes'] ??
            json['coffeeFlavorNotes'] ??
            json['flavor_notes'] ??
            json['flavorNotes'],
      ),
    );
  }

  /// Acepta `coffee_flavor_notes` como lista de objetos (`note_label` +
  /// `sort_order`, forma real de la tabla — ver `Base de datos.md`) o,
  /// de forma más simple, como lista plana de strings. Se ordena por
  /// `sort_order` del lado del cliente (cuando viene) en vez de confiar
  /// en que el backend ya lo devuelva ordenado — mismo criterio
  /// defensivo que `RecipeRepositoryImpl._stepsFrom` con `step_order`.
  List<String> _flavorNotesFrom(dynamic raw) {
    if (raw is! List) return const [];
    final entries = <(int, String)>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      String? label;
      int order = i;
      if (item is String) {
        label = item;
      } else if (item is Map) {
        label = (item['note_label'] ?? item['noteLabel'] ?? item['note'])
            ?.toString();
        order = _asNullableInt(item['sort_order'] ?? item['sortOrder']) ?? i;
      } else {
        label = item?.toString();
      }
      if (label != null && label.trim().isNotEmpty) {
        entries.add((order, label));
      }
    }
    entries.sort((a, b) => a.$1.compareTo(b.$1));
    return entries.map((e) => e.$2).toList(growable: false);
  }

  int? _asNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
