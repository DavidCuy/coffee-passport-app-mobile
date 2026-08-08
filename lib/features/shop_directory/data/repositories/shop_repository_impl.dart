import '../../../../core/network/api_client.dart';
import '../../domain/entities/shop.dart';
import '../../domain/repositories/shop_repository.dart';

/// Implementación real de [ShopRepository] contra `GET /shops` /
/// `GET /shops/{id}` de `coffee-passport-backend` (ver
/// `API endpoints.md` del vault) — endpoints reales desde la primera
/// pasada de sellos (`list_shops`/`get_shop`), confirmados
/// end-to-end contra Postgres real por el Agente Backend (2026-07-30).
///
/// Ampliado 2026-08-02 (tarea "Mapa & Directorio — favoritos y
/// reseñas") para mapear también `description`/`hours_json`/
/// `active_perk_text`/redes (ver `core_db/models/shop.py`) y el rating
/// agregado que el Agente Backend confirmó contra la Supabase real ese
/// mismo día (ver `API endpoints.md`): `GET /shops/{id}` trae
/// `rating_average` (float, **`null`** — no `0.0` — si la cafetería
/// todavía no tiene reseñas, calculado "al leer" contra `shop_reviews`,
/// no materializado en la tabla `shops`) y `review_count` (int). Se
/// leen por su nombre exacto, sin heurísticas de nombres alternativos
/// (`avg_rating`/`average_rating`/etc. quedaron descartados una vez
/// confirmado el contrato real). `ShopDetailScreen` sigue teniendo un
/// cálculo de respaldo del lado del cliente a partir de
/// `GET /shops/{id}/reviews` por si este campo llega `null` genuinamente
/// (sin reseñas) — en ese caso ambas fuentes coinciden en "sin reseñas".
class ShopRepositoryImpl implements ShopRepository {
  // Ver nota de PassportRepositoryImpl sobre por qué no se usa
  // `this._apiClient` como initializing formal aquí.
  ShopRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient; // ignore: prefer_initializing_formals

  final ApiClient _apiClient;

  @override
  Future<List<Shop>> getShops() async {
    final raw = await _apiClient.get('/shops');
    final List<dynamic> shopsJson;
    if (raw is List) {
      shopsJson = raw;
    } else if (raw is Map && raw['data'] is List) {
      // `GET /shops` real (core_http.BaseController genérico del
      // backend) envuelve toda lista en `{"data": [...]}` — ver
      // `list_shops/function.py`. `GET /shops/{id}` (abajo, en
      // `getShopById`) no pasa por este método porque devuelve un
      // único objeto sin envolver.
      shopsJson = raw['data'] as List<dynamic>;
    } else if (raw is Map && raw['shops'] is List) {
      shopsJson = raw['shops'] as List<dynamic>;
    } else {
      throw ApiException('Respuesta inesperada de GET /shops: $raw');
    }
    return shopsJson
        .cast<Map<String, dynamic>>()
        .map(_shopFromJson)
        .toList(growable: false);
  }

  @override
  Future<Shop?> getShopById(String id) async {
    try {
      final raw = await _apiClient.get('/shops/$id');
      if (raw is! Map) return null;
      return _shopFromJson(raw.cast<String, dynamic>());
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Shop _shopFromJson(Map<String, dynamic> json) {
    return Shop(
      id: (json['id'] ?? json['qr_slug'] ?? json['slug']).toString(),
      name: (json['name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      latitude: _asDouble(json['lat'] ?? json['latitude']),
      longitude: _asDouble(json['lng'] ?? json['longitude']),
      isStamped:
          (json['is_stamped'] ?? json['isStamped'] ?? json['stamped']) ==
          true,
      description: (json['description'] as String?),
      // `hours_json` viaja como columna JSONB de forma libre (ver
      // `core_db/models/shop.py`) — se guarda tal cual, sin asumir
      // shape, y se formatea en la capa de presentación.
      hoursRaw: json['hours_json'] ?? json['hoursJson'] ?? json['hours'],
      activePerkText:
          (json['active_perk_text'] ?? json['activePerkText']) as String?,
      websiteUrl: (json['website_url'] ?? json['websiteUrl']) as String?,
      instagramUrl:
          (json['instagram_url'] ?? json['instagramUrl']) as String?,
      facebookUrl: (json['facebook_url'] ?? json['facebookUrl']) as String?,
      photoUrl: (json['photo_url'] ?? json['photoUrl']) as String?,
      // Nombres de campo confirmados contra la Supabase real por el
      // Agente Backend (2026-08-02, ver `API endpoints.md`):
      // `rating_average` (float, `null` sin reseñas — no `0.0`) y
      // `review_count` (int). Sin heurísticas de nombres alternativos.
      avgRating: _asNullableDouble(json['rating_average']),
      reviewCount: _asNullableInt(json['review_count']),
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  double? _asNullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _asNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
