/// Entidad de dominio: ficha técnica de un café del catálogo del
/// Laboratorio (Fase 1, sección 5 — "Ficha técnica del café: origen,
/// altitud, proceso, variedad, perfil de sabor/notas de cata").
///
/// Nombres de campo alineados 1:1 con las columnas reales documentadas
/// en `Base de datos.md` (`009_create_coffee_catalog_tables.sql`,
/// changeset todavía pendiente de aplicar al momento de escribir esta
/// clase — ver docstring de `CoffeeRepositoryImpl` para el criterio de
/// parseo defensivo mientras Backend/DB terminan en paralelo):
/// `roaster_name`, `origin_locality`, `altitude_masl`, `process`,
/// `variety`, `producer`, `sca_score`,
/// `body_score`/`acidity_score`/`sweetness_score`/`aftertaste_score`
/// (1-5, sección "ADN del café" del mock), `story_text`, `is_featured`.
/// `coffee_flavor_notes` (`note_label` por fila, `sort_order`) se
/// aplana a [flavorNotes] — sólo viene completo en `GET /coffees/{id}`
/// (ficha completa); `GET /coffees`/`GET /coffees/featured` pueden
/// traerlo vacío.
class Coffee {
  const Coffee({
    required this.id,
    required this.name,
    this.roasterName,
    this.originLocality,
    this.altitudeMasl,
    this.process,
    this.variety,
    this.producer,
    this.scaScore,
    this.bodyScore,
    this.acidityScore,
    this.sweetnessScore,
    this.aftertasteScore,
    this.storyText,
    this.isFeatured = false,
    this.flavorNotes = const [],
  });

  final String id;
  final String name;
  final String? roasterName;
  final String? originLocality;
  final int? altitudeMasl;
  final String? process;
  final String? variety;
  final String? producer;
  final int? scaScore;

  /// 1 a 5 — sección "ADN del café" del mock (cuerpo/acidez/dulzor/
  /// postgusto), cada uno con su propia barra.
  final int? bodyScore;
  final int? acidityScore;
  final int? sweetnessScore;
  final int? aftertasteScore;

  final String? storyText;

  /// "Café del mes" en el mock — `GET /coffees/featured`.
  final bool isFeatured;

  /// Notas de cata (`coffee_flavor_notes.note_label`), ya ordenadas por
  /// `sort_order` si el backend lo trae.
  final List<String> flavorNotes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Coffee && runtimeType == other.runtimeType && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Coffee(id: $id, name: $name)';
}
