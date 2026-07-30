import 'package:flutter/material.dart';

import '../../domain/entities/shop.dart';

/// Widget de presentación puro: recibe una entidad de dominio [Shop] ya
/// resuelta y sólo se encarga de pintarla. No conoce repositorios,
/// fuentes de datos ni lógica de negocio — esas responsabilidades viven
/// en las capas `domain`/`data` y en el controller/ViewModel que se
/// agregue junto con la gestión de estado elegida para el proyecto.
class ShopCard extends StatelessWidget {
  const ShopCard({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          shop.isStamped ? Icons.local_cafe : Icons.local_cafe_outlined,
        ),
        title: Text(shop.name),
        subtitle: Text(shop.address),
        trailing: shop.isStamped
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
      ),
    );
  }
}
