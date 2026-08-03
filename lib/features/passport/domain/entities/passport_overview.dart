import 'stamp.dart';

/// Agrupa la respuesta completa de `GET /passport`: la grilla de
/// sellos más los contadores que alimentan la barra de progreso
/// ("3 de 18 cafeterías completadas", ver `Fase 1 - Funcionalidades.md`
/// del vault).
class PassportOverview {
  const PassportOverview({
    required this.stamps,
    required this.unlockedCount,
    required this.totalShops,
  });

  final List<Stamp> stamps;
  final int unlockedCount;
  final int totalShops;
}
