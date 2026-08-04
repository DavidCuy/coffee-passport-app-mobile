import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../../shop_directory/presentation/widgets/rating_stars.dart';
import '../../domain/entities/diary_entry.dart';

/// Widget de presentación puro: pinta una [DiaryEntry] ya resuelta
/// (nombre de cafetería incluido, ver `DiaryScreen._shopName`).
/// Equivalente al `.entry-card` del mock
/// (`pasaporte-cafe-mock.html` → `#diaryList`).
///
/// Widget keys para QA:
/// - `Key('diary_entry_card_\${entry.id}')` en la tarjeta.
/// - `Key('diary_entry_edit_button_\${entry.id}')` /
///   `Key('diary_entry_delete_button_\${entry.id}')` — siempre visibles
///   (a diferencia de `ShopReviewCard`, acá **todas** las entradas son
///   del usuario actual — `GET /diary` sólo devuelve las propias, no
///   hay noción de "de otro visitante").
class DiaryEntryCard extends StatelessWidget {
  const DiaryEntryCard({
    super.key,
    required this.entry,
    required this.shopName,
    this.onEdit,
    this.onDelete,
  });

  final DiaryEntry entry;
  final String shopName;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  String get _dateLabel {
    final date = entry.visitedAt ?? entry.createdAt;
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final methodLabel = entry.brewMethod?.label ?? 'Sin especificar';
    final meta = [methodLabel, if (_dateLabel.isNotEmpty) _dateLabel].join(' · ');
    return Container(
      key: Key('diary_entry_card_${entry.id}'),
      margin: const EdgeInsets.only(bottom: 12),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: PassportColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PassportColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              RatingStars(rating: entry.rating.toDouble(), size: 13),
            ],
          ),
          if (entry.note != null && entry.note!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                entry.note!,
                style: const TextStyle(
                  fontSize: 13,
                  color: PassportColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                if (onEdit != null)
                  TextButton(
                    key: Key('diary_entry_edit_button_${entry.id}'),
                    onPressed: onEdit,
                    child: const Text('Editar'),
                  ),
                if (onDelete != null)
                  TextButton(
                    key: Key('diary_entry_delete_button_${entry.id}'),
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
