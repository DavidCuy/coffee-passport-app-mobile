import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/shop_review.dart';
import 'rating_stars.dart';

/// Widget de presentación puro: pinta una [ShopReview] ya resuelta.
/// Si `review.isMine` es verdadero, muestra además los botones de
/// editar/borrar (delegados a los callbacks, sin lógica propia).
///
/// Widget keys para QA:
/// - `Key('shop_review_card_\${review.id}')` en la tarjeta.
/// - `Key('shop_review_edit_button')` / `Key('shop_review_delete_button')`
///   sólo quando `review.isMine` — como sólo puede existir una reseña
///   propia visible a la vez (regla `unique(id_user, id_shop)` del
///   backend), no hace falta sufijar estos 2 keys con el id.
class ShopReviewCard extends StatelessWidget {
  const ShopReviewCard({
    super.key,
    required this.review,
    this.onEdit,
    this.onDelete,
  });

  final ShopReview review;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('shop_review_card_${review.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PassportColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PassportColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.isMine
                      ? 'Tú'
                      : (review.authorName ?? 'Otro visitante'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: PassportColors.textPrimary,
                  ),
                ),
              ),
              RatingStars(rating: review.rating.toDouble()),
            ],
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                review.comment!,
                style: const TextStyle(color: PassportColors.textSecondary),
              ),
            ),
          if (review.isMine && (onEdit != null || onDelete != null))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (onEdit != null)
                    TextButton(
                      key: const Key('shop_review_edit_button'),
                      onPressed: onEdit,
                      child: const Text('Editar'),
                    ),
                  if (onDelete != null)
                    TextButton(
                      key: const Key('shop_review_delete_button'),
                      onPressed: onDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFB91C1C),
                      ),
                      child: const Text('Borrar'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
