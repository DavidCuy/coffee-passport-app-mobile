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
    this.showBackground = true,
  });

  final Shop shop;
  final VoidCallback? onTap;

  /// `null` oculta el botón de favorito por completo (ej. si la
  /// pantalla que la usa todavía no tiene un `FavoriteRepository` a
  /// mano).
  final VoidCallback? onToggleFavorite;

  /// `false` renderiza sólo la fila (sin `Container` con fondo/margen
  /// propio) — usado por `ShopDirectoryScreen` cuando varias filas
  /// viven juntas dentro de una única card contenedora (estilo lista
  /// "Activity" tipo PayPal) en vez de una card individual por
  /// cafetería. `FavoriteShopsScreen`/`ShopMapView` siguen usando el
  /// default (`true`, card individual).
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final row = Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        hoverColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: shop.isStamped
                ? PassportColors.primary
                : PassportColors.surface2,
            shape: BoxShape.circle,
          ),
          child: Icon(
            shop.isStamped ? Icons.local_cafe : Icons.local_cafe_outlined,
            color: shop.isStamped ? Colors.white : PassportColors.textFaint,
          ),
        ),
        title: Text(
          shop.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: PassportColors.textPrimary,
          ),
        ),
        subtitle: Text(
          shop.address.isEmpty ? 'Dirección no disponible' : shop.address,
          style: const TextStyle(color: PassportColors.textSecondary),
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
    if (!showBackground) {
      return KeyedSubtree(key: Key('shop_card_${shop.id}'), child: row);
    }
    return Container(
      key: Key('shop_card_${shop.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: PassportColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: row,
    );
  }
}
