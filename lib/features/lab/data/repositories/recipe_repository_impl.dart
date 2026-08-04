import '../../../../core/brew/brew_method.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/recipe_step.dart';
import '../../domain/repositories/recipe_repository.dart';

/// Implementación real de [RecipeRepository] contra `GET /recipes` y
/// `GET /recipes/{id}` de `coffee-passport-backend`.
///
/// **Construida en paralelo al backend/DB** (2026-08-04, mismo aviso de
/// contrato que `CoffeeRepositoryImpl` — ver su docstring): el
/// changeset `010_create_recipes_tables.sql` (`recipes` +
/// `recipe_steps`) todavía estaba pendiente de aplicar del lado de DB
/// al momento de escribir esta clase. Parseo defensivo (snake_case +
/// camelCase, wrapper `{"data": [...]}`) hasta que Backend confirme el
/// shape exacto.
class RecipeRepositoryImpl implements RecipeRepository {
  RecipeRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient; // ignore: prefer_initializing_formals

  final ApiClient _apiClient;

  @override
  Future<List<Recipe>> getRecipes() async {
    final raw = await _apiClient.get('/recipes');
    final List<dynamic> recipesJson;
    if (raw is List) {
      recipesJson = raw;
    } else if (raw is Map && raw['data'] is List) {
      recipesJson = raw['data'] as List<dynamic>;
    } else if (raw is Map && raw['recipes'] is List) {
      recipesJson = raw['recipes'] as List<dynamic>;
    } else {
      throw ApiException('Respuesta inesperada de GET /recipes: $raw');
    }
    return recipesJson
        .cast<Map<String, dynamic>>()
        .map(_recipeFromJson)
        .toList(growable: false);
  }

  @override
  Future<Recipe> getRecipeById(String id) async {
    final raw = await _apiClient.get('/recipes/$id');
    if (raw is! Map) {
      throw ApiException('Respuesta inesperada de GET /recipes/$id: $raw');
    }
    return _recipeFromJson(raw.cast<String, dynamic>());
  }

  /// Parseo defensivo de un item de `GET /recipes`/`GET /recipes/{id}`
  /// — nombres de columna reales documentados en `Base de datos.md`
  /// (`010_create_recipes_tables.sql`): `brew_method`, `name`,
  /// `ratio_text`, `dose_grams`, `water_temp_celsius`, `grind_size`,
  /// `total_time_seconds`. `recipe_steps` (`step_order`,
  /// `instruction_text`, `suggested_seconds`) sólo viene poblado en
  /// `GET /recipes/{id}` — se ordena por `step_order` del lado del
  /// cliente por si el backend no lo garantiza.
  Recipe _recipeFromJson(Map<String, dynamic> json) {
    final stepsRaw = json['recipe_steps'] ?? json['recipeSteps'] ?? json['steps'];
    final steps = _stepsFrom(stepsRaw);
    return Recipe(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      brewMethod: BrewMethod.fromApiValue(
        (json['brew_method'] ?? json['brewMethod'])?.toString(),
      ),
      ratioText: (json['ratio_text'] ?? json['ratioText']) as String?,
      doseGrams: _asNullableNum(json['dose_grams'] ?? json['doseGrams']),
      waterTempCelsius: _asNullableNum(
        json['water_temp_celsius'] ?? json['waterTempCelsius'],
      ),
      grindSize: (json['grind_size'] ?? json['grindSize']) as String?,
      totalTimeSeconds: _asNullableInt(
        json['total_time_seconds'] ?? json['totalTimeSeconds'],
      ),
      steps: steps,
    );
  }

  List<RecipeStep> _stepsFrom(dynamic raw) {
    if (raw is! List) return const [];
    final steps = raw.whereType<Map>().map((item) {
      final map = item.cast<String, dynamic>();
      return RecipeStep(
        order: _asNullableInt(map['step_order'] ?? map['stepOrder']) ?? 0,
        instructionText:
            (map['instruction_text'] ?? map['instructionText'] ?? '')
                .toString(),
        suggestedSeconds:
            _asNullableInt(
              map['suggested_seconds'] ?? map['suggestedSeconds'],
            ) ??
            0,
      );
    }).toList();
    steps.sort((a, b) => a.order.compareTo(b.order));
    return List.unmodifiable(steps);
  }

  num? _asNullableNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  int? _asNullableInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
