import '../entities/shop_review.dart';

/// Contrato de dominio para reseñas de cafetería
/// (`shop_reviews` en `Base de datos.md` → changeset
/// `014_create_shop_reviews_table.sql`).
///
/// Ver `API endpoints.md` del vault:
/// `GET /shops/{id}/reviews` / `POST /shops/{id}/reviews` /
/// `PATCH /shops/{id}/reviews/mine` / `DELETE /shops/{id}/reviews/mine`.
abstract interface class ShopReviewRepository {
  Future<List<ShopReview>> getReviews(String shopId);

  /// Crea la reseña propia de [shopId]. Falla (ver
  /// `ShopReviewRepositoryImpl`) si el usuario ya tiene una — el
  /// backend la modela `unique(id_user, id_shop)`; hay que usar
  /// [updateMyReview] en ese caso.
  Future<ShopReview> createReview({
    required String shopId,
    required int rating,
    String? comment,
  });

  Future<ShopReview> updateMyReview({
    required String shopId,
    required int rating,
    String? comment,
  });

  Future<void> deleteMyReview(String shopId);
}
