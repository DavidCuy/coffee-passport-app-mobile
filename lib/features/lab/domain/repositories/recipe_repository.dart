import '../entities/recipe.dart';

/// Contrato de dominio para el catálogo de recetas del Laboratorio
/// (Fase 1, sección 5). Ver `API endpoints.md` del vault: `GET
/// /recipes`, `GET /recipes/{id}`.
abstract interface class RecipeRepository {
  /// Catálogo de recetas por método de extracción — `GET /recipes`.
  /// Puede no traer `recipe_steps` (ver `Recipe.steps`); para el timer
  /// guiado hace falta [getRecipeById].
  Future<List<Recipe>> getRecipes();

  /// Receta completa con sus `recipe_steps` (cada uno con
  /// `suggested_seconds`, alimenta el timer guiado) — `GET
  /// /recipes/{id}`.
  Future<Recipe> getRecipeById(String id);
}
