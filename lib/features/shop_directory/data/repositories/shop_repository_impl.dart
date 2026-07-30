import '../../domain/entities/shop.dart';
import '../../domain/repositories/shop_repository.dart';

/// Implementación stub de [ShopRepository].
///
/// TODO(fase-1): reemplazar por una fuente de datos real (REST/Firestore)
/// cuando existan los endpoints documentados en el vault del proyecto
/// (`10 - Proyectos/Pasaporte Café/API endpoints`). Hoy regresa datos en
/// memoria únicamente para validar de punta a punta el cableado
/// domain -> data -> presentation.
class ShopRepositoryImpl implements ShopRepository {
  static const List<Shop> _mockShops = [
    Shop(
      id: 'shop-001',
      name: 'Café Tinto',
      address: 'Calle 60 x 55, Centro, Mérida',
      latitude: 20.9674,
      longitude: -89.6237,
      isStamped: true,
    ),
    Shop(
      id: 'shop-002',
      name: 'La Fisgona Café',
      address: 'Calle 47, García Ginerés, Mérida',
      latitude: 20.9776,
      longitude: -89.6321,
    ),
  ];

  @override
  Future<List<Shop>> getShops() async => _mockShops;

  @override
  Future<Shop?> getShopById(String id) async {
    for (final shop in _mockShops) {
      if (shop.id == id) return shop;
    }
    return null;
  }
}
