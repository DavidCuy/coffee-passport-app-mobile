/// Entidad de dominio: una reseña de cafetería (`shop_reviews` en
/// `Base de datos.md` → changeset `014_create_shop_reviews_table.sql`).
///
/// **Distinta** del Diario de cata (`diary_entries`) — es la reseña
/// pública que se ve en la ficha de la cafetería (Fase 1, sección 2),
/// una por usuario por cafetería (`unique(id_user, id_shop)`),
/// editable.
class ShopReview {
  const ShopReview({
    required this.id,
    required this.shopId,
    required this.rating,
    this.comment,
    this.authorName,
    this.createdAt,
    this.updatedAt,
    this.isMine = false,
  });

  final String id;
  final String shopId;

  /// 1 a 5 — mismo rango que el `check` de `shop_reviews.rating`.
  final int rating;
  final String? comment;

  /// Nombre a mostrar del autor, si el backend lo trae. `null` cae en
  /// un texto genérico en la UI (ver `ShopReviewCard`).
  final String? authorName;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Si esta reseña es la del usuario actual.
  ///
  /// Viene directo de `is_mine` en `GET /shops/{id}/reviews`, calculado
  /// por el backend contra el usuario resuelto de `X-Auth-User-Sub`
  /// (siempre presente en la respuesta, `true`/`false` — confirmado por
  /// el Agente Backend el 2026-08-02, ver `ShopReviewRepositoryImpl` y
  /// `API endpoints.md`). No se infiere en el cliente comparando ids/
  /// subs, así que el valor sobrevive un reload frío de la pantalla.
  final bool isMine;

  ShopReview copyWith({bool? isMine}) {
    return ShopReview(
      id: id,
      shopId: shopId,
      rating: rating,
      comment: comment,
      authorName: authorName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isMine: isMine ?? this.isMine,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShopReview &&
          runtimeType == other.runtimeType &&
          id == other.id);

  @override
  int get hashCode => id.hashCode;
}
