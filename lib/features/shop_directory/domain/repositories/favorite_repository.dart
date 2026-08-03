import '../entities/shop.dart';

/// Contrato de dominio para favoritos de cafeterías
/// (`favorites` en `Base de datos.md` → changeset
/// `013_create_favorites_table.sql`: `id_user`, `id_shop`,
/// `unique(id_user, id_shop)`).
///
/// Ver `API endpoints.md` del vault:
/// `POST /shops/{id}/favorite` / `DELETE /shops/{id}/favorite` /
/// `GET /favorites`.
abstract interface class FavoriteRepository {
  /// Cafeterías marcadas como favoritas por el usuario actual.
  Future<List<Shop>> getFavoriteShops();

  /// Solo los ids, para marcar rápidamente el corazón en listas/mapa
  /// sin tener que comparar objetos [Shop] completos.
  Future<Set<String>> getFavoriteShopIds();

  Future<void> addFavorite(String shopId);

  Future<void> removeFavorite(String shopId);
}
