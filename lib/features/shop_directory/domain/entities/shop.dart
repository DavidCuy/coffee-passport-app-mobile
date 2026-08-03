/// Entidad de dominio: representa una cafetería participante del
/// Pasaporte Café.
///
/// Es un modelo inmutable y agnóstico de infraestructura: no sabe nada
/// de REST, Firestore, JSON ni Flutter. Corresponde a la "Ficha de
/// cafetería" descrita en la Fase 1 (sección 2, Mapa & Directorio de
/// Barras) del vault de producto.
///
/// Ampliada 2026-08-02 (tarea "Mapa & Directorio — favoritos y
/// reseñas") con los campos reales de `GET /shops` / `GET /shops/{id}`
/// (ver `core_db/models/shop.py` en `coffee-passport-backend`):
/// descripción, dirección, horario (`hours_json`, forma libre —
/// renderizado best-effort, ver `ShopHours`), beneficio activo y
/// redes. `avgRating`/`reviewCount` sí vienen de `GET /shops/{id}`
/// (campos `rating_average`/`review_count`, confirmados contra la
/// Supabase real el mismo día — ver `ShopRepositoryImpl`); `isFavorite`
/// no viene de `Shop` en sí (se resuelve aparte con `GET /favorites`) y
/// se combina vía [copyWith] donde haga falta (ver
/// `ShopDirectoryScreen`/`FavoriteShopsScreen`).
class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.isStamped = false,
    this.description,
    this.hoursRaw,
    this.activePerkText,
    this.websiteUrl,
    this.instagramUrl,
    this.facebookUrl,
    this.avgRating,
    this.reviewCount,
    this.isFavorite = false,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  /// Si el usuario ya tiene el "sello" de esta cafetería en su pasaporte.
  final bool isStamped;

  final String? description;

  /// `hours_json` tal cual lo manda el backend (forma libre, no hay
  /// contrato de columnas fijo por día todavía) — puede ser un `Map`
  /// (ej. `{"mon": "08:00-18:00", ...}`) o un `String` ya formateado.
  /// El renderizado vive en la capa de presentación (ver
  /// `ShopHoursSection`) para no meter lógica de formato en el dominio.
  final Object? hoursRaw;

  final String? activePerkText;
  final String? websiteUrl;
  final String? instagramUrl;
  final String? facebookUrl;

  /// Promedio de `shop_reviews.rating` (1-5) — `rating_average` en
  /// `GET /shops/{id}`. `null` significa "sin reseñas todavía" (el
  /// backend nunca manda `0.0` como valor engañoso).
  final double? avgRating;
  final int? reviewCount;

  /// Si el usuario actual la marcó como favorita (`GET /favorites`).
  final bool isFavorite;

  Shop copyWith({bool? isFavorite, double? avgRating, int? reviewCount}) {
    return Shop(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      isStamped: isStamped,
      description: description,
      hoursRaw: hoursRaw,
      activePerkText: activePerkText,
      websiteUrl: websiteUrl,
      instagramUrl: instagramUrl,
      facebookUrl: facebookUrl,
      avgRating: avgRating ?? this.avgRating,
      reviewCount: reviewCount ?? this.reviewCount,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Shop && runtimeType == other.runtimeType && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Shop(id: $id, name: $name, isStamped: $isStamped)';
}
