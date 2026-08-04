import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/recipe.dart';

/// Item de lista de una [Recipe] — equivalente al `.recipe-head` del
/// mock (`pasaporte-cafe-mock.html` → `#recipeList`), sin el acordeón
/// inline: acá el tap navega a `RecipeDetailScreen` (mejor encaje con
/// `Navigator`/testing E2E por pantalla, mismo criterio ya usado por
/// `DiaryEntryFormScreen`/`ShopDetailScreen` en vez de un panel
/// expandible).
///
/// Widget key para QA: `Key('lab_recipe_card_\${recipe.id}')`.
class RecipeListTile extends StatelessWidget {
  const RecipeListTile({super.key, required this.recipe, this.onTap});

  final Recipe recipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final metaParts = [
      if (recipe.ratioText != null) 'Ratio ${recipe.ratioText}',
      if (recipe.totalTimeSeconds != null)
        _formatSeconds(recipe.totalTimeSeconds!),
    ];
    return InkWell(
      key: Key('lab_recipe_card_${recipe.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: PassportColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PassportColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PassportColors.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.local_cafe_outlined,
                size: 17,
                color: PassportColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: PassportColors.textPrimary,
                    ),
                  ),
                  if (metaParts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        metaParts.join(' · '),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: PassportColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
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

  String _formatSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
