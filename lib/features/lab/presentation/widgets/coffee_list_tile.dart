import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/coffee.dart';

/// Item de lista de un [Coffee] — usado tanto en la sección "Café
/// destacado" como en el catálogo completo de `CoffeeCatalogView`.
/// Equivalente (simplificado a lista, sin la ficha completa inline) al
/// `.coffee-top` del mock (`pasaporte-cafe-mock.html` → `#screen-lab`).
///
/// Widget key para QA: `Key('lab_coffee_card_\${coffee.id}')`.
class CoffeeListTile extends StatelessWidget {
  const CoffeeListTile({super.key, required this.coffee, this.onTap});

  final Coffee coffee;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (coffee.roasterName != null && coffee.roasterName!.isNotEmpty)
        coffee.roasterName!,
      if (coffee.originLocality != null && coffee.originLocality!.isNotEmpty)
        coffee.originLocality!,
    ];
    return InkWell(
      key: Key('lab_coffee_card_${coffee.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PassportColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PassportColors.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.coffee_outlined,
                color: PassportColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coffee.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: PassportColors.textPrimary,
                    ),
                  ),
                  if (subtitleParts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitleParts.join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: PassportColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (coffee.scaScore != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: PassportColors.surface2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${coffee.scaScore}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PassportColors.primary,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: PassportColors.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}
