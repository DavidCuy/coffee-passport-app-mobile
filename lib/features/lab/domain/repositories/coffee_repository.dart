import '../entities/coffee.dart';

/// Contrato de dominio para el catálogo de café del Laboratorio (Fase
/// 1, sección 5). Ver `API endpoints.md` del vault: `GET /coffees`,
/// `GET /coffees/featured`, `GET /coffees/{id}`.
abstract interface class CoffeeRepository {
  /// Catálogo completo — `GET /coffees`.
  Future<List<Coffee>> getCoffees();

  /// Cafés destacados ("Café del mes" en el mock) — `GET
  /// /coffees/featured`.
  Future<List<Coffee>> getFeaturedCoffees();

  /// Ficha completa de un café, incluyendo `coffee_flavor_notes` —
  /// `GET /coffees/{id}`.
  Future<Coffee> getCoffeeById(String id);
}
