import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_step.dart';
import '../../domain/repositories/recipe_repository.dart';
import 'brew_timer_screen.dart';

/// Ficha completa de una [Recipe] — `GET /recipes/{id}` (trae
/// `recipe_steps`, a diferencia del catálogo que puede no incluirlos).
/// Equivalente al `.recipe-body` expandido del mock
/// (`pasaporte-cafe-mock.html` → `#recipeList`): stats (temperatura,
/// molienda, tiempo), pasos ordenados y botón "Iniciar receta guiada".
///
/// [fallback] es la [Recipe] ya cargada desde la lista (sin `steps`
/// todavía) — se muestra de inmediato mientras se resuelve la ficha
/// completa (mismo criterio que `CoffeeDetailScreen`).
///
/// Widget keys para QA:
/// - `Key('recipe_detail_screen')` — raíz.
/// - `Key('recipe_detail_stats_row')` — pills de temp/molienda/tiempo.
/// - `Key('recipe_detail_steps_list')` — lista ordenada de pasos.
/// - `Key('recipe_detail_start_button')` — abre `BrewTimerScreen`.
class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.repository,
    required this.recipeId,
    this.fallback,
  });

  final RecipeRepository repository;
  final String recipeId;
  final Recipe? fallback;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late final Future<Recipe> _future = widget.repository.getRecipeById(
    widget.recipeId,
  );

  void _startGuidedBrew(Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BrewTimerScreen(recipe: recipe)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('recipe_detail_screen'),
      backgroundColor: PassportColors.background,
      appBar: AppBar(
        title: Text(widget.fallback?.name ?? 'Receta'),
        backgroundColor: PassportColors.background,
        foregroundColor: PassportColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<Recipe>(
          future: _future,
          builder: (context, snapshot) {
            final recipe = snapshot.data ?? widget.fallback;
            if (recipe == null) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No se pudo cargar esta receta.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final hasSteps = recipe.steps.isNotEmpty;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: PassportColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    key: const Key('recipe_detail_stats_row'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (recipe.ratioText != null)
                        _StatPill('Ratio ${recipe.ratioText}'),
                      if (recipe.waterTempCelsius != null)
                        _StatPill('Temp ${recipe.waterTempCelsius}°C'),
                      if (recipe.grindSize != null)
                        _StatPill('Molienda ${recipe.grindSize}'),
                      if (recipe.totalTimeSeconds != null)
                        _StatPill('Tiempo ${_formatSeconds(recipe.totalTimeSeconds!)}'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: hasSteps
                        ? ListView.separated(
                            key: const Key('recipe_detail_steps_list'),
                            itemCount: recipe.steps.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final step = recipe.steps[index];
                              return _StepTile(order: index + 1, step: step);
                            },
                          )
                        : const Center(
                            child: Text(
                              'Esta receta todavía no tiene pasos '
                              'publicados.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: PassportColors.textFaint,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('recipe_detail_start_button'),
                      onPressed: hasSteps
                          ? () => _startGuidedBrew(recipe)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: PassportColors.primary,
                      ),
                      child: const Text('Iniciar receta guiada'),
                    ),
                  ),
                ],
              ),
            );
          },
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

class _StatPill extends StatelessWidget {
  const _StatPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PassportColors.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: PassportColors.textSecondary,
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.order, required this.step});

  final int order;
  final RecipeStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PassportColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: PassportColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$order',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              step.instructionText,
              style: const TextStyle(
                fontSize: 13,
                color: PassportColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
