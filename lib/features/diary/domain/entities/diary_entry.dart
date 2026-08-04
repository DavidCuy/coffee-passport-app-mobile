import 'brew_method.dart';

/// Entidad de dominio: una entrada del Diario de cata
/// (`diary_entries` — ver `Fase 1 - Funcionalidades.md`, sección 4, y
/// `API endpoints.md`: `GET/POST /diary`, `PATCH/DELETE /diary/{id}`).
///
/// **Distinta** de `ShopReview` (`shop_reviews`, reseña pública de la
/// ficha de cafetería) — el diario es una nota personal del usuario
/// sobre lo que tomó, cómo lo preparó y qué le pareció, sin geofencing
/// ni validación de ubicación (CRUD simple), y admite múltiples
/// entradas por cafetería (a diferencia de `passport_stamps`, sin
/// `unique` constraint documentado — confirmado en `API endpoints.md`).
class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.shopId,
    this.shopName,
    this.brewMethod,
    required this.rating,
    this.note,
    this.visitedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String shopId;

  /// Nombre de la cafetería, **sólo** si el backend lo trae anidado
  /// (ej. `shop.name`, mismo patrón que `GET /passport` con `Stamp` —
  /// ver `PassportRepositoryImpl`). Si viene `null`, la pantalla
  /// (`DiaryScreen`) lo resuelve cruzando `shopId` contra
  /// `ShopRepository.getShops()` de `shop_directory` (import cruzado
  /// explícito entre features, caso contemplado por `ARCHITECTURE.md`).
  final String? shopName;

  /// `null` si el backend manda un valor que no matchea ninguno de los
  /// 5 métodos fijos (`BrewMethod.fromApiValue`) — la UI lo muestra
  /// como "Sin especificar", igual que el mock cuando no se elige
  /// método. El formulario de creación/edición sí lo exige (ver
  /// `DiaryEntryFormScreen`).
  final BrewMethod? brewMethod;

  /// 1 a 5 — mismo rango/constraint que `shop_reviews.rating`.
  final int rating;

  final String? note;

  /// Fecha de la visita/consumo — puede ser distinta a `createdAt`
  /// porque el Diario admite registrar visitas pasadas (ver
  /// `API endpoints.md`: "notas personales, pueden ser de visitas
  /// pasadas").
  final DateTime? visitedAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  DiaryEntry copyWith({String? shopName}) {
    return DiaryEntry(
      id: id,
      shopId: shopId,
      shopName: shopName ?? this.shopName,
      brewMethod: brewMethod,
      rating: rating,
      note: note,
      visitedAt: visitedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id);

  @override
  int get hashCode => id.hashCode;
}
