import '../entities/shop.dart';

/// Contrato de dominio para acceder al directorio de cafeterías.
///
/// La capa `domain` sólo conoce esta interfaz. La implementación real
/// (REST, Firestore, cache local, etc.) vive en la capa `data` y se
/// inyecta en tiempo de composición (hoy manualmente en `main.dart`;
/// más adelante vía el contenedor de DI que se elija para el proyecto).
abstract interface class ShopRepository {
  /// Regresa todas las cafeterías del directorio.
  Future<List<Shop>> getShops();

  /// Regresa una cafetería por id, o `null` si no existe.
  Future<Shop?> getShopById(String id);
}
