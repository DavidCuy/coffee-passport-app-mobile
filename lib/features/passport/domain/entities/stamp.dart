/// Entidad de dominio: un renglón de la grilla del pasaporte — una
/// cafetería, y si el usuario ya tiene o no el "sello" de haberla
/// visitado (ver `GET /passport` en `API endpoints.md` del vault).
///
/// Agnóstica de infraestructura: no sabe nada de JSON/REST/Flutter.
class Stamp {
  const Stamp({
    required this.shopId,
    required this.shopName,
    required this.isUnlocked,
    this.unlockedAt,
  });

  final String shopId;
  final String shopName;

  /// `true` si el usuario ya tiene el sello de esta cafetería.
  ///
  /// Nota de contrato (confirmado 2026-07-30 contra el backend real,
  /// ver `PassportRepositoryImpl`): hoy `GET /passport` sólo devuelve
  /// sellos que el usuario YA tiene — no hay entrada "bloqueada" en esa
  /// respuesta, así que en la práctica todo [Stamp] construido desde
  /// esa API llega con `isUnlocked == true`. El campo se conserva en la
  /// entidad porque la UI (grid/tarjeta) sigue soportando un estado
  /// visual "bloqueado" pensado para cuando exista un directorio
  /// completo de cafeterías; no se elimina para no romper esas vistas.
  final bool isUnlocked;

  /// Fecha/hora en la que se desbloqueó el sello. `null` si sigue
  /// bloqueado.
  final DateTime? unlockedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Stamp &&
          runtimeType == other.runtimeType &&
          shopId == other.shopId);

  @override
  int get hashCode => shopId.hashCode;

  @override
  String toString() =>
      'Stamp(shopId: $shopId, shopName: $shopName, isUnlocked: $isUnlocked)';
}
