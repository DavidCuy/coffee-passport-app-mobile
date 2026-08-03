import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/shop.dart';

/// Widget de presentación puro: recibe una entidad de dominio [Shop] ya
/// resuelta y sólo se encarga de pintarla + delegar sus 2 interacciones
/// (tocar la tarjeta, tocar el corazón de favorito) hacia quien la usa
/// — no conoce repositorios ni lógica de negocio.
///
/// Reutilizada tanto por el directorio en lista
/// (`ShopDirectoryScreen`) como por `FavoriteShopsScreen` y la hoja del
/// mapa (`ShopMapView`).
///
/// Widget keys para QA (dinámicos por `shop.id`, ver
/// `Fase 1 - Funcionalidades.md` en el vault para la convención):
/// - `Key('shop_card_\${shop.id}')` en la tarjeta completa.
/// - `Key('shop_card_favorite_\${shop.id}')` en el botón de corazón.
class ShopCard extends StatelessWidget {
  const ShopCard({
    super.key,
    required this.shop,
    this.onTap,
    this.onToggleFavorite,
  });

  final Shop shop;
  final VoidCallback? onTap;

  /// `null` oculta el botón de favorito por completo (ej. si la
  /// pantalla que la usa todavía no tiene un `FavoriteRepository` a
  /// mano).
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('shop_card_${shop.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          shop.isStamped ? Icons.local_cafe : Icons.local_cafe_outlined,
          color: shop.isStamped ? PassportColors.primary : null,
        ),
        title: Text(shop.name),
        subtitle: Text(
          shop.address.isEmpty ? 'Dirección no disponible' : shop.address,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shop.isStamped)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.check_circle, color: Color(0xFF2D6A4F)),
              ),
            if (onToggleFavorite != null)
              IconButton(
                key: Key('shop_card_favorite_${shop.id}'),
                onPressed: onToggleFavorite,
                icon: Icon(
                  shop.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: shop.isFavorite
                      ? PassportColors.primary
                      : PassportColors.textFaint,
                ),
                tooltip: shop.isFavorite
                    ? 'Quitar de favoritos'
                    : 'Marcar como favorita',
              ),
          ],
        ),
      ),
    );
  }
}
