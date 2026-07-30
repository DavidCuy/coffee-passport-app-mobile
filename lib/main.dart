import 'package:flutter/material.dart';

import 'features/shop_directory/data/repositories/shop_repository_impl.dart';
import 'features/shop_directory/domain/entities/shop.dart';
import 'features/shop_directory/domain/repositories/shop_repository.dart';
import 'features/shop_directory/presentation/widgets/shop_card.dart';

void main() {
  runApp(const CoffeePassportApp());
}

/// Punto de entrada de la app.
///
/// La composición de dependencias es manual y explícita por ahora (sin
/// get_it/riverpod todavía): `main.dart` arma la implementación de
/// `ShopRepository` y se la pasa a la pantalla. Ver `ARCHITECTURE.md`
/// en la raíz del repo para la decisión de organización de capas
/// (feature-first) y los pendientes.
class CoffeePassportApp extends StatelessWidget {
  const CoffeePassportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pasaporte Café',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6F4E37)),
        useMaterial3: true,
      ),
      home: ShopDirectoryScaffold(shopRepository: ShopRepositoryImpl()),
    );
  }
}

/// Esqueleto ilustrativo de pantalla.
///
/// IMPORTANTE: esto NO es la pantalla real de "Mapa & Directorio de
/// Barras" (Fase 1, sección 2 del vault de producto). Sólo demuestra el
/// cableado domain -> data -> presentation de la feature de ejemplo
/// `shop_directory` antes de construir la UI real de esa sección.
class ShopDirectoryScaffold extends StatefulWidget {
  const ShopDirectoryScaffold({super.key, required this.shopRepository});

  final ShopRepository shopRepository;

  @override
  State<ShopDirectoryScaffold> createState() => _ShopDirectoryScaffoldState();
}

class _ShopDirectoryScaffoldState extends State<ShopDirectoryScaffold> {
  late final Future<List<Shop>> _shopsFuture =
      widget.shopRepository.getShops();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pasaporte Café — esqueleto')),
      body: FutureBuilder<List<Shop>>(
        future: _shopsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final shops = snapshot.data!;
          return ListView.builder(
            itemCount: shops.length,
            itemBuilder: (context, index) => ShopCard(shop: shops[index]),
          );
        },
      ),
    );
  }
}
