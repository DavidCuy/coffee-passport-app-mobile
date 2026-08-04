import '../../../../core/brew/brew_method.dart';
import 'recipe_step.dart';

/// Entidad de dominio: una receta por método de extracción (Fase 1,
/// sección 5 — "Recetas por método de extracción (V60, prensa
/// francesa, espresso, chemex, aeropress, etc.) — ratios, temperatura,
/// tiempo, molienda").
///
/// Nombres de campo alineados 1:1 con `recipes` (`Base de datos.md`,
/// `010_create_recipes_tables.sql`): `brew_method`, `name`,
/// `ratio_text`, `dose_grams`, `water_temp_celsius`, `grind_size`,
/// `total_time_seconds`. [brewMethod] reutiliza el enum fijo
/// `core/brew/brew_method.dart` (compartido con el Diario de cata,
/// mismo set de 5 métodos — ver docstring de `BrewMethod`).
///
/// [steps] sólo viene completo desde `GET /recipes/{id}` (ficha
/// completa con `recipe_steps`, cada uno con `suggested_seconds` que
/// alimenta el timer guiado) — `GET /recipes` (catálogo/lista) puede
/// traerlo vacío.
class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    this.brewMethod,
    this.ratioText,
    this.doseGrams,
    this.waterTempCelsius,
    this.grindSize,
    this.totalTimeSeconds,
    this.steps = const [],
  });

  final String id;
  final String name;

  /// `null` si `brew_method` no matchea ninguno de los 5 valores fijos
  /// (`BrewMethod.fromApiValue`) — mismo criterio defensivo que
  /// `DiaryEntry.brewMethod`.
  final BrewMethod? brewMethod;

  /// Ej. `"1:16"` — referencia para la Calculadora de ratio (ver
  /// `RatioCalculator`), no se recalcula del lado del cliente.
  final String? ratioText;
  final num? doseGrams;
  final num? waterTempCelsius;
  final String? grindSize;
  final int? totalTimeSeconds;
  final List<RecipeStep> steps;

  Recipe copyWith({List<RecipeStep>? steps}) {
    return Recipe(
      id: id,
      name: name,
      brewMethod: brewMethod,
      ratioText: ratioText,
      doseGrams: doseGrams,
      waterTempCelsius: waterTempCelsius,
      grindSize: grindSize,
      totalTimeSeconds: totalTimeSeconds,
      steps: steps ?? this.steps,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Recipe && runtimeType == other.runtimeType && id == other.id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Recipe(id: $id, name: $name)';
}
