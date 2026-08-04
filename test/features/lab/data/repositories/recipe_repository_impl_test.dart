// Fija el contrato defensivo de `RecipeRepositoryImpl` mientras el
// Agente Backend/DB terminan `/recipes`/`recipe_steps` en paralelo a
// esta tarea (ver docstring de la clase). Cubre: el wrapper genérico
// `{"data": [...]}`, la lista plana de respaldo, el parseo snake_case/
// camelCase de `recipes`, el `brew_method` reutilizando el enum fijo
// de `core/brew`, y `recipe_steps` (incluido el orden por
// `step_order` del lado del cliente).

import 'dart:convert';

import 'package:coffee_passport_app/core/auth/dev_auth_local_datasource.dart';
import 'package:coffee_passport_app/core/brew/brew_method.dart';
import 'package:coffee_passport_app/core/network/api_client.dart';
import 'package:coffee_passport_app/features/lab/data/repositories/recipe_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  RecipeRepositoryImpl buildRepository(http.Client mockClient) {
    return RecipeRepositoryImpl(
      apiClient: ApiClient(
        httpClient: mockClient,
        authDatasource: DevAuthLocalDatasource(),
      ),
    );
  }

  test(
    'getRecipes desenvuelve {"data": [...]} y parsea las columnas '
    'snake_case reales de `recipes`',
    () async {
      final fixtureBody = jsonEncode({
        'data': [
          {
            'id': 1,
            'name': 'V60',
            'brew_method': 'v60',
            'ratio_text': '1:16',
            'dose_grams': 15,
            'water_temp_celsius': 93,
            'grind_size': 'Media-fina',
            'total_time_seconds': 180,
          },
        ],
      });
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/recipes'));
        return http.Response(fixtureBody, 200);
      });

      final recipes = await buildRepository(mockClient).getRecipes();

      expect(recipes, hasLength(1));
      final recipe = recipes.single;
      expect(recipe.id, '1');
      expect(recipe.name, 'V60');
      expect(recipe.brewMethod, BrewMethod.v60);
      expect(recipe.ratioText, '1:16');
      expect(recipe.doseGrams, 15);
      expect(recipe.waterTempCelsius, 93);
      expect(recipe.grindSize, 'Media-fina');
      expect(recipe.totalTimeSeconds, 180);
      expect(recipe.steps, isEmpty);
    },
  );

  test('getRecipes acepta una lista plana (sin wrapper)', () async {
    final fixtureBody = jsonEncode([
      {'id': 2, 'name': 'Espresso', 'brew_method': 'espresso'},
    ]);
    final mockClient = MockClient(
      (request) async => http.Response(fixtureBody, 200),
    );

    final recipes = await buildRepository(mockClient).getRecipes();

    expect(recipes.single.brewMethod, BrewMethod.espresso);
  });

  test(
    'getRecipes deja brewMethod en null si el valor no matchea ninguno '
    'de los 5 métodos fijos',
    () async {
      final fixtureBody = jsonEncode([
        {'id': 3, 'name': 'Moka', 'brew_method': 'moka'},
      ]);
      final mockClient = MockClient(
        (request) async => http.Response(fixtureBody, 200),
      );

      final recipes = await buildRepository(mockClient).getRecipes();

      expect(recipes.single.brewMethod, isNull);
    },
  );

  test(
    'getRecipeById parsea recipe_steps y los ordena por step_order '
    'aunque lleguen desordenados',
    () async {
      final fixtureBody = jsonEncode({
        'id': 1,
        'name': 'V60',
        'brew_method': 'v60',
        'recipe_steps': [
          {
            'step_order': 2,
            'instruction_text': 'Vierte 45 g de agua.',
            'suggested_seconds': 15,
          },
          {
            'step_order': 1,
            'instruction_text': 'Enjuaga el filtro.',
            'suggested_seconds': 15,
          },
        ],
      });
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/recipes/1'));
        return http.Response(fixtureBody, 200);
      });

      final recipe = await buildRepository(mockClient).getRecipeById('1');

      expect(recipe.steps, hasLength(2));
      expect(recipe.steps[0].instructionText, 'Enjuaga el filtro.');
      expect(recipe.steps[0].suggestedSeconds, 15);
      expect(recipe.steps[1].instructionText, 'Vierte 45 g de agua.');
    },
  );

  test(
    'getRecipeById lanza ApiException si el backend responde error',
    () async {
      final mockClient = MockClient(
        (request) async => http.Response('{"message":"not found"}', 404),
      );

      expect(
        () => buildRepository(mockClient).getRecipeById('99'),
        throwsA(isA<ApiException>()),
      );
    },
  );
}
