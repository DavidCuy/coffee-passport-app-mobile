import '../../../../core/network/api_client.dart';
import '../../domain/entities/shop_review.dart';
import '../../domain/repositories/shop_review_repository.dart';

/// Implementación real de [ShopReviewRepository] contra
/// `GET/POST /shops/{id}/reviews` y
/// `PATCH/DELETE /shops/{id}/reviews/mine` de
/// `coffee-passport-backend` (ver `API endpoints.md` del vault).
///
/// Confirmado contra `Base de datos.md` → changeset
/// `014_create_shop_reviews_table.sql`: `shop_reviews(id_user, id_shop,
/// rating check 1-5, comment)`, `unique(id_user, id_shop)` — una reseña
/// por usuario por cafetería, **editable** (de ahí que actualizar/
/// borrar sea sobre `.../mine`, sin necesitar el id de la reseña).
///
/// `GET /shops/{id}/reviews` es pública (nunca 401), pero el Agente
/// Backend confirmó y cerró el gap real que encontró QA Mobile
/// (2026-08-02, ver `API endpoints.md`): el endpoint ahora acepta
/// `X-Auth-User-Sub` de forma **opcional** — [ApiClient] ya lo manda en
/// cada request por defecto — y cada item de `data[]` trae `is_mine`
/// **siempre presente** (`true`/`false`), calculado del lado del
/// backend contra el usuario resuelto de ese header. Ya no hace falta
/// (ni corresponde) inferir "es mía" comparando el `sub` local contra
/// el autor de cada reseña: se usa `is_mine` tal cual, tanto en el
/// listado como después de crear/editar, así sobrevive un reload frío.
class ShopReviewRepositoryImpl implements ShopReviewRepository {
  ShopReviewRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient; // ignore: prefer_initializing_formals

  final ApiClient _apiClient;

  @override
  Future<List<ShopReview>> getReviews(String shopId) async {
    final raw = await _apiClient.get('/shops/$shopId/reviews');
    final List<dynamic> reviewsJson;
    if (raw is List) {
      reviewsJson = raw;
    } else if (raw is Map && raw['data'] is List) {
      reviewsJson = raw['data'] as List<dynamic>;
    } else {
      throw ApiException(
        'Respuesta inesperada de GET /shops/$shopId/reviews: $raw',
      );
    }
    return reviewsJson
        .cast<Map<String, dynamic>>()
        .map((json) => _reviewFromJson(json, shopId))
        .toList(growable: false);
  }

  @override
  Future<ShopReview> createReview({
    required String shopId,
    required int rating,
    String? comment,
  }) async {
    final response = await _apiClient.post(
      '/shops/$shopId/reviews',
      body: {
        'rating': rating,
        // ignore: use_null_aware_elements
        if (comment != null) 'comment': comment,
      },
    );
    if (!response.isSuccessStatus) {
      throw ApiException(
        'No se pudo publicar tu reseña.',
        statusCode: response.statusCode,
      );
    }
    return _reviewFromResponseOrFallback(
      response.body,
      shopId: shopId,
      rating: rating,
      comment: comment,
    );
  }

  @override
  Future<ShopReview> updateMyReview({
    required String shopId,
    required int rating,
    String? comment,
  }) async {
    final response = await _apiClient.patch(
      '/shops/$shopId/reviews/mine',
      body: {
        'rating': rating,
        // ignore: use_null_aware_elements
        if (comment != null) 'comment': comment,
      },
    );
    if (!response.isSuccessStatus) {
      throw ApiException(
        'No se pudo actualizar tu reseña.',
        statusCode: response.statusCode,
      );
    }
    return _reviewFromResponseOrFallback(
      response.body,
      shopId: shopId,
      rating: rating,
      comment: comment,
    );
  }

  @override
  Future<void> deleteMyReview(String shopId) async {
    final response = await _apiClient.delete('/shops/$shopId/reviews/mine');
    if (!response.isSuccessStatus) {
      throw ApiException(
        'No se pudo borrar tu reseña.',
        statusCode: response.statusCode,
      );
    }
  }

  /// El body de `POST`/`PATCH` puede venir vacío o sin `id` (contrato
  /// de esa respuesta puntual todavía sin confirmar contra código
  /// real) — en ese caso se arma un [ShopReview] "optimista" con lo
  /// que el usuario acaba de enviar. Ya **no** se fuerza `isMine: true`
  /// en memoria (ver docstring de la clase): si el body sí trae la
  /// reseña completa, `isMine` sale de `is_mine` tal cual lo mande el
  /// backend; si no trae nada, queda en el `false` por defecto de
  /// [ShopReview] — de todas formas `ShopReviewsPanel` guarda esta
  /// reseña aparte en `_myReview` (no depende de `isMine` para
  /// mostrarla) y refresca desde `getReviews` inmediatamente después,
  /// que sí trae la verdad del backend.
  ShopReview _reviewFromResponseOrFallback(
    dynamic body, {
    required String shopId,
    required int rating,
    String? comment,
  }) {
    if (body is Map) {
      final json = body.cast<String, dynamic>();
      final nested = json['review'];
      final reviewJson = nested is Map
          ? nested.cast<String, dynamic>()
          : json;
      if (reviewJson['id'] != null) {
        return _reviewFromJson(reviewJson, shopId);
      }
    }
    return ShopReview(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      shopId: shopId,
      rating: rating,
      comment: comment,
    );
  }

  /// Parsea un item de `data[]` de `GET /shops/{id}/reviews` según el
  /// contrato exacto confirmado por el Agente Backend (2026-08-02, ver
  /// `API endpoints.md`): `id`, `id_shop`, `rating`, `comment`,
  /// `created_at`, `updated_at`, `reviewer_display_name` (nombre del
  /// autor — no `author_name`/`user_name`, el backend no expone el
  /// `User` completo por privacidad) e `is_mine` (siempre presente,
  /// calculado por el backend contra `X-Auth-User-Sub`).
  ShopReview _reviewFromJson(Map<String, dynamic> json, String fallbackShopId) {
    return ShopReview(
      id: json['id'].toString(),
      shopId: (json['id_shop'] ?? fallbackShopId).toString(),
      rating: _asInt(json['rating']) ?? 0,
      comment: json['comment'] as String?,
      authorName: json['reviewer_display_name'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
      isMine: json['is_mine'] == true,
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
