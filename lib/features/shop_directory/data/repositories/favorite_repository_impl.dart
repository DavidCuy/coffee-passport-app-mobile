import '../../../../core/network/api_client.dart';
import '../../domain/entities/shop.dart';
import '../../domain/repositories/favorite_repository.dart';

/// Implementación real de [FavoriteRepository] contra
/// `POST/DELETE /shops/{id}/favorite` y `GET /favorites` de
/// `coffee-passport-backend` (ver `API endpoints.md` del vault).
///
/// ⚠️ A la fecha de esta implementación (2026-08-02) estos 3 endpoints
/// los está terminando el Agente Backend en paralelo — no había
/// directorio `src/functions/*favorite*` todavía cuando se escribió
/// este archivo. El contrato de tabla sí está confirmado
/// (`Base de datos.md` → changeset `013_create_favorites_table.sql`:
/// `favorites(id_user, id_shop)`, `unique(id_user, id_shop)`), así que
/// el parseo de abajo sigue el mismo patrón defensivo
/// snake_case/camelCase + wrapper `{"data": [...]}` ya validado en
/// `ShopRepositoryImpl`/`PassportRepositoryImpl` para el resto de
/// endpoints tipo `core_http.BaseController`. Ajustar junto con el
/// Agente Backend si el shape final difiere (ej. si `GET /favorites`
/// no anida el objeto `shop` completo, sino que manda un
/// `shop_id`/`id_shop` plano — ambos casos ya están contemplados).
class FavoriteRepositoryImpl implements FavoriteRepository {
  FavoriteRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient; // ignore: prefer_initializing_formals

  final ApiClient _apiClient;

  @override
  Future<List<Shop>> getFavoriteShops() async {
    final raw = await _apiClient.get('/favorites');
    final List<dynamic> favoritesJson;
    if (raw is List) {
      favoritesJson = raw;
    } else if (raw is Map && raw['data'] is List) {
      favoritesJson = raw['data'] as List<dynamic>;
    } else if (raw is Map && raw['favorites'] is List) {
      favoritesJson = raw['favorites'] as List<dynamic>;
    } else {
      throw ApiException('Respuesta inesperada de GET /favorites: $raw');
    }
    return favoritesJson
        .cast<Map<String, dynamic>>()
        .map(_shopFromFavoriteJson)
        .whereType<Shop>()
        .toList(growable: false);
  }

  @override
  Future<Set<String>> getFavoriteShopIds() async {
    final shops = await getFavoriteShops();
    return shops.map((s) => s.id).toSet();
  }

  @override
  Future<void> addFavorite(String shopId) async {
    final response = await _apiClient.post('/shops/$shopId/favorite');
    if (!response.isSuccessStatus) {
      throw ApiException(
        'No se pudo marcar la cafetería como favorita.',
        statusCode: response.statusCode,
      );
    }
  }

  @override
  Future<void> removeFavorite(String shopId) async {
    final response = await _apiClient.delete('/shops/$shopId/favorite');
    if (!response.isSuccessStatus) {
      throw ApiException(
        'No se pudo quitar la cafetería de favoritos.',
        statusCode: response.statusCode,
      );
    }
  }

  /// `GET /favorites` puede venir de 2 formas razonables mientras el
  /// Backend termina el endpoint: cada elemento ES la cafetería
  /// completa (favoritos "resueltos", como hace `GET /passport` con
  /// `stamps[].shop`), o cada elemento es la fila cruda de la tabla
  /// `favorites` con un `shop` anidado o un `id_shop`/`shop_id` plano
  /// (sin datos de la cafetería, en cuyo caso no se puede construir un
  /// [Shop] completo aquí — se descarta con `null`, ver `whereType`
  /// arriba, y el caller debería resolverlo combinando con
  /// `GET /shops`).
  Shop? _shopFromFavoriteJson(Map<String, dynamic> json) {
    final nested = json['shop'];
    final shopJson = nested is Map
        ? nested.cast<String, dynamic>()
        : (json['name'] != null ? json : null);
    if (shopJson == null) return null;
    return Shop(
      id:
          (shopJson['id'] ??
                  shopJson['qr_slug'] ??
                  json['id_shop'] ??
                  json['shop_id'])
              .toString(),
      name: (shopJson['name'] ?? '').toString(),
      address: (shopJson['address'] ?? '').toString(),
      latitude: _asDouble(shopJson['lat'] ?? shopJson['latitude']),
      longitude: _asDouble(shopJson['lng'] ?? shopJson['longitude']),
      description: shopJson['description'] as String?,
      activePerkText:
          (shopJson['active_perk_text'] ?? shopJson['activePerkText'])
              as String?,
      isFavorite: true,
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
