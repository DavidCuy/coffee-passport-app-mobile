import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../screens/recipe_detail_screen.dart';
import 'recipe_list_tile.dart';

/// Contenido del sub-tab "Recetas" del Laboratorio — catálogo por
/// método de extracción (`GET /recipes`), equivalente a
/// `.lab-section[data-lab-panel="recetas"]`/`#recipeList` del mock
/// (`pasaporte-cafe-mock.html`).
///
/// Widget keys para QA:
/// - `Key('lab_recipe_catalog_view')` — raíz.
/// - `Key('lab_recipe_list')` — lista de recetas.
/// - `Key('lab_recipe_empty_state')` — si el catálogo está vacío.
/// - Ver `RecipeListTile` para el key de cada item
///   (`lab_recipe_card_<id>`).
class RecipeCatalogView extends StatefulWidget {
  const RecipeCatalogView({super.key, required this.repository});

  final RecipeRepository repository;

  @override
  State<RecipeCatalogView> createState() => _RecipeCatalogViewState();
}

class _RecipeCatalogViewState extends State<RecipeCatalogView> {
  late Future<List<Recipe>> _future = widget.repository.getRecipes();

  Future<void> _refresh() async {
    final next = widget.repository.getRecipes();
    setState(() {
      _future = next;
    });
    await next;
  }

  void _openDetail(Recipe recipe) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          repository: widget.repository,
          recipeId: recipe.id,
          fallback: recipe,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Recipe>>(
      key: const Key('lab_recipe_catalog_view'),
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No se pudo cargar el catálogo de recetas.\n'
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final recipes = snapshot.data ?? const [];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: recipes.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Padding(
                      key: const Key('lab_recipe_empty_state'),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: const Center(
                        child: Text(
                          'Todavía no hay recetas publicadas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: PassportColors.textFaint),
                        ),
                      ),
                    ),
                  ],
                )
              : ListView(
                  key: const Key('lab_recipe_list'),
                  padding: const EdgeInsets.all(16),
                  children: recipes
                      .map(
                        (recipe) => RecipeListTile(
                          recipe: recipe,
                          onTap: () => _openDetail(recipe),
                        ),
                      )
                      .toList(),
                ),
        );
      },
    );
  }
}
