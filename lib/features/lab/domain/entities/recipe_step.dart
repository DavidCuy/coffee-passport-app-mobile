/// Un paso de una receta guiada (`recipe_steps` — ver
/// `Base de datos.md`, `010_create_recipes_tables.sql`): `id_recipe`
/// FK, `step_order`, `instruction_text`, `suggested_seconds`.
///
/// [suggestedSeconds] es lo que alimenta la cuenta regresiva de
/// `BrewTimerScreen` — cada paso avanza automáticamente al siguiente
/// cuando llega a 0 (mismo comportamiento que `brewTick()` del mock,
/// `pasaporte-cafe-mock.html`).
class RecipeStep {
  const RecipeStep({
    required this.order,
    required this.instructionText,
    required this.suggestedSeconds,
  });

  final int order;
  final String instructionText;
  final int suggestedSeconds;

  @override
  String toString() =>
      'RecipeStep(order: $order, suggestedSeconds: $suggestedSeconds)';
}
