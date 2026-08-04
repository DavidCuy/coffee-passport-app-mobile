// Widget test PURO de `RatioCalculatorView` — sin Patrol, sin tocar
// `coffee-passport-backend` real. Ver
// test/e2e/test-matrices/laboratorio.md (sección "Calculadora de
// ratio — widget test puro").
//
// La calculadora es 100% cliente (ver `API endpoints.md`:
// "Calculadora de ratio: sin endpoint, 100% cliente") — el único uso
// de red es opcional/best-effort (`GET /recipes`, para poblar los
// chips de ratio con valores reales en vez de sólo los 3 default). Acá
// se inyecta un [_FakeRecipeRepository] controlable en vez del
// `RecipeRepositoryImpl` real, así el archivo entero corre sin
// `ApiClient`/`http` real — ni siquiera necesita el backend levantado.
//
// Agente QA Mobile — 1ra pasada, 2026-08-04.

import 'package:coffee_passport_app/features/lab/domain/entities/recipe.dart';
import 'package:coffee_passport_app/features/lab/domain/repositories/recipe_repository.dart';
import 'package:coffee_passport_app/features/lab/presentation/widgets/ratio_calculator_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio en memoria, sin red — controla exactamente qué
/// devuelve `getRecipes()` para cada caso.
class _FakeRecipeRepository implements RecipeRepository {
  _FakeRecipeRepository({List<Recipe>? recipes, this.throwOnGetRecipes = false})
    : recipes = recipes ?? const [];

  final List<Recipe> recipes;
  final bool throwOnGetRecipes;

  @override
  Future<List<Recipe>> getRecipes() async {
    if (throwOnGetRecipes) {
      throw Exception('GET /recipes no disponible (simulado)');
    }
    return recipes;
  }

  @override
  Future<Recipe> getRecipeById(String id) {
    throw UnimplementedError('No usado por RatioCalculatorView');
  }
}

Recipe _recipeWithRatio(String id, String ratioText) =>
    Recipe(id: id, name: 'Receta $id', ratioText: ratioText);

Future<void> _pumpCalculator(
  WidgetTester tester, {
  required RecipeRepository repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: RatioCalculatorView(repository: repository)),
    ),
  );
  // Deja resolver el `Future` best-effort de `_loadRatioOptions` (sea
  // que resuelva una lista o lance una excepción) antes de asertar.
  await tester.pumpAndSettle();
}

void main() {
  group('CALC-01: estado por defecto', () {
    testWidgets('15 g @ 1:16 = 240 g de agua', (tester) async {
      await _pumpCalculator(
        tester,
        repository: _FakeRecipeRepository(throwOnGetRecipes: true),
      );

      expect(find.text('15 g'), findsOneWidget);
      expect(find.byKey(const Key('lab_calc_ratio_chip_16')), findsOneWidget);
      expect(find.textContaining('240'), findsWidgets);
    });
  });

  group('CALC-02: stepper de dosis', () {
    testWidgets('incrementar suma 1 g y recalcula el agua', (tester) async {
      await _pumpCalculator(
        tester,
        repository: _FakeRecipeRepository(throwOnGetRecipes: true),
      );

      await tester.tap(find.byKey(const Key('lab_calc_dose_plus_button')));
      await tester.pump();

      expect(find.text('16 g'), findsOneWidget);
      // 16 g @ 1:16 = 256 g.
      expect(find.textContaining('256'), findsWidgets);
    });

    testWidgets('no baja de 5 g (mínimo)', (tester) async {
      await _pumpCalculator(
        tester,
        repository: _FakeRecipeRepository(throwOnGetRecipes: true),
      );

      for (var i = 0; i < 15; i++) {
        await tester.tap(find.byKey(const Key('lab_calc_dose_minus_button')));
        await tester.pump();
      }

      expect(find.text('5 g'), findsOneWidget);
    });

    testWidgets('no sube de 40 g (máximo)', (tester) async {
      await _pumpCalculator(
        tester,
        repository: _FakeRecipeRepository(throwOnGetRecipes: true),
      );

      for (var i = 0; i < 30; i++) {
        await tester.tap(find.byKey(const Key('lab_calc_dose_plus_button')));
        await tester.pump();
      }

      expect(find.text('40 g'), findsOneWidget);
    });
  });

  group('CALC-03: selección de ratio', () {
    testWidgets('tocar otro chip recalcula el resultado al instante', (
      tester,
    ) async {
      await _pumpCalculator(
        tester,
        repository: _FakeRecipeRepository(throwOnGetRecipes: true),
      );

      // Default: 15 g -> 240 g @ 1:16. Cambiar a 1:15 -> 225 g.
      await tester.tap(find.byKey(const Key('lab_calc_ratio_chip_15')));
      await tester.pump();

      expect(find.textContaining('225'), findsWidgets);
      expect(find.textContaining('240'), findsNothing);
    });
  });

  group('CALC-04: `GET /recipes` real (best-effort)', () {
    testWidgets(
      'si falla, la calculadora sigue usando los 3 ratios default sin '
      'romperse',
      (tester) async {
        await _pumpCalculator(
          tester,
          repository: _FakeRecipeRepository(throwOnGetRecipes: true),
        );

        expect(
          find.byKey(const Key('lab_ratio_calculator_view')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('lab_calc_ratio_chip_15')), findsOneWidget);
        expect(find.byKey(const Key('lab_calc_ratio_chip_16')), findsOneWidget);
        expect(find.byKey(const Key('lab_calc_ratio_chip_17')), findsOneWidget);
      },
    );

    testWidgets(
      'si resuelve, los chips reflejan los ratio_text reales (no sólo '
      'los 3 default)',
      (tester) async {
        await _pumpCalculator(
          tester,
          repository: _FakeRecipeRepository(
            recipes: [
              _recipeWithRatio('1', '1:16'),
              _recipeWithRatio('2', '1:15'),
              _recipeWithRatio('3', '1:2'),
              _recipeWithRatio('4', '1:16'), // duplicado, no se repite
              _recipeWithRatio('5', '1:14'),
            ],
          ),
        );

        expect(find.byKey(const Key('lab_calc_ratio_chip_2')), findsOneWidget);
        expect(find.byKey(const Key('lab_calc_ratio_chip_14')), findsOneWidget);
        expect(find.byKey(const Key('lab_calc_ratio_chip_15')), findsOneWidget);
        expect(find.byKey(const Key('lab_calc_ratio_chip_16')), findsOneWidget);
        // El default del mock (1:17) ya no aplica: ninguna receta
        // real lo usa.
        expect(find.byKey(const Key('lab_calc_ratio_chip_17')), findsNothing);
      },
    );
  });
}
