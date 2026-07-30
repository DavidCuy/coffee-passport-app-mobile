/// Entidad de dominio: representa una cafetería participante del
/// Pasaporte Café.
///
/// Es un modelo inmutable y agnóstico de infraestructura: no sabe nada
/// de REST, Firestore, JSON ni Flutter. Corresponde libremente a la
/// "Ficha de cafetería" descrita en la Fase 1 (sección 2, Mapa &
/// Directorio de Barras) del vault de producto, aunque los campos aquí
/// son solo los mínimos para ilustrar la capa de dominio — se ampliarán
/// (fotos, horarios, grano en servicio, beneficio activo, etc.) cuando
/// se implemente esa feature de verdad.
class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.isStamped = false,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  /// Si el usuario ya tiene el "sello" de esta cafetería en su pasaporte.
  final bool isStamped;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Shop && runtimeType == other.runtimeType && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Shop(id: $id, name: $name, isStamped: $isStamped)';
}
