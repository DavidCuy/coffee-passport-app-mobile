/// Entidad de dominio: un nivel de gamificación ("Nivel Catador", etc.)
/// tal como lo describe `GET /levels` (ver `API endpoints.md` y
/// `Modelo de recompensas.md` del vault).
///
/// Importante (ver `Agente Mobile.md`, sección "Rol y alcance"): la app
/// **no decide** cuál es el nivel actual del usuario — eso lo deriva el
/// backend a partir de `count(passport_stamps)`. Este cliente sólo
/// pinta lo que el backend ya resolvió (`isCurrent`), nunca recalcula
/// el nivel comparando umbrales por su cuenta.
class PassportLevel {
  const PassportLevel({
    required this.order,
    required this.name,
    required this.minStamps,
    this.badgeIconUrl,
    this.isCurrent = false,
  });

  final int order;
  final String name;
  final int minStamps;
  final String? badgeIconUrl;

  /// El backend ya indica si éste es el nivel vigente del usuario.
  final bool isCurrent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PassportLevel &&
          runtimeType == other.runtimeType &&
          order == other.order);

  @override
  int get hashCode => order.hashCode;

  @override
  String toString() =>
      'PassportLevel(order: $order, name: $name, isCurrent: $isCurrent)';
}
