// E2E — El Laboratorio (catálogo de recetas + timer guiado, catálogo
// de café, calculadora de ratio con datos reales de red).
//
// Casos de test/e2e/test-matrices/laboratorio.md.
// Agente QA Mobile — 1ra pasada (EJECUTADA), 2026-08-04.
//
// Contra el backend real (`http://localhost:8000/prod`, Docker,
// imagen reconstruida con los endpoints de Laboratorio incluidos).
// `coffees` está VACÍA A PROPÓSITO (carga manual vía admin, fuera de
// alcance de este módulo — ver `Base de datos.md`); sólo
// `recipes`/`recipe_steps` tienen seed data (5 recetas). Por eso el
// catálogo de café sólo se prueba en su estado vacío esperado, nunca
// con datos reales — ver la matriz para el detalle.
//
// Nota de timing: `flutter test -d windows` corre estos casos sobre
// un binding "vivo" (Timer/HTTP reales, no un reloj simulado) — el
// timer guiado (`BrewTimerScreen`) usa `Timer.periodic` real, así que
// los casos que verifican el avance del countdown esperan tiempo real
// de pared (varios segundos por caso, ver comentarios inline).

import 'package:coffee_passport_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'common/dev_auth.dart';
import 'common/lab_fixtures.dart';

/// `PatrolTesterConfig.settleTimeout` default (10 s) resultó
/// insuficiente en esta pasada: `_HomeTabsState` (`lib/main.dart`)
/// monta las 5 pantallas del bottom nav de una sola vez (`IndexedStack`
/// no-lazy), así que CADA `pumpWidgetAndSettle(CoffeePassportApp())`
/// espera a que Pasaporte/Escanear/Cafeterías/Diario/Laboratorio
/// resuelvan sus llamadas de red en paralelo — bajo carga sostenida
/// (11 casos de este archivo relanzando la app completa en pocos
/// minutos contra un backend local de un solo proceso), esas 4
/// pantallas ajenas a este flujo empezaron a tardar más de 10 s reales
/// y tumbaban `pumpAndSettle()` con "timed out" antes de que Lab
/// llegara a montarse. 20 s da margen real sin ocultar una regresión
/// genuina (ningún caso de esta suite necesitó ni la mitad de eso una
/// vez agregado también `registerTestUser` en `setUp`, ver abajo).
const _labConfig = PatrolTesterConfig(settleTimeout: Duration(seconds: 20));

void main() {
  late String v60Id;
  late String v60Name;

  setUpAll(() async {
    // Resueltos una sola vez por archivo: `recipes` es catálogo
    // global de sólo lectura (sin CRUD desde la app), no hay riesgo de
    // aislamiento entre tests que justifique resolverlo por test.
    final recipes = await fetchRecipes();
    final v60 = recipes.firstWhere((r) => r['name'] == 'V60');
    v60Id = v60['id'].toString();
    v60Name = v60['name'] as String;
  });

  setUp(() async {
    final sub = 'qa-mobile-e2e-lab-${DateTime.now().microsecondsSinceEpoch}';
    seedDevLogin(sub: sub);
    // `_HomeTabsState` (`lib/main.dart`) monta las 5 pantallas del
    // bottom nav de una sola vez dentro de un `IndexedStack` (no
    // lazy) — aunque Lab no necesita perfil registrado (`/coffees`/
    // `/recipes` son públicos), Pasaporte/Diario SÍ (`GET /passport`/
    // `GET /diary` responden 404 "Perfil no encontrado" sin esto).
    // Encontrado en esta pasada: sin registrar, esas 2 pantallas
    // quedan en su rama de error, y el `pumpAndSettle()` de
    // `openLab()` empieza a ser más lento/inestable a medida que se
    // acumulan llamadas fallidas de las otras 4 pestañas en paralelo
    // — registrar el perfil de una vez es más barato que investigar
    // más a fondo el árbol completo de otras 4 features que no son
    // responsabilidad de este archivo.
    await registerTestUser(sub: sub);
  });

  Future<void> openLab(PatrolTester $) async {
    await $.pumpWidgetAndSettle(const CoffeePassportApp());
    await $(const Key('nav_lab_tab')).tap();
    await $.pumpAndSettle();
  }

  Future<void> openRecetasTab(PatrolTester $) async {
    await $(const Key('lab_tab_recetas_button')).tap();
    await $.pumpAndSettle();
  }

  Future<void> openUtilidadesTab(PatrolTester $) async {
    await $(const Key('lab_tab_utilidades_button')).tap();
    await $.pumpAndSettle();
  }

  /// Espera real (no simulada) hasta [maxSeconds], pumpeando cada
  /// segundo — necesaria porque `BrewTimerScreen` usa `Timer.periodic`
  /// real bajo `flutter test -d windows` (binding "vivo", no
  /// `FakeAsync`). Se corta apenas [condition] es verdadera.
  Future<void> waitRealSecondsUntil(
    PatrolTester $,
    bool Function() condition, {
    int maxSeconds = 20,
  }) async {
    for (var i = 0; i < maxSeconds && !condition(); i++) {
      await $.tester.pump(const Duration(seconds: 1));
    }
    await $.pumpAndSettle();
  }

  /// Tap en la card de la receta [recipeId] + espera real hasta que
  /// `GET /recipes/{id}` resuelva de verdad (`recipe_detail_steps_list`
  /// presente) — encontrado en esta pasada (no un bug, mismo hallazgo
  /// ya documentado en `mapa-directorio.md`/`diario-de-cata.md` sobre
  /// `pumpAndSettle()`): un `pumpAndSettle()` inmediatamente después del
  /// `tap()` sólo espera la animación de la transición de ruta, NO el
  /// `Future` de red en vuelo del `FutureBuilder` de
  /// `RecipeDetailScreen` (una espera de I/O real no programa ningún
  /// frame por sí sola, así que "no hay más frames pendientes" puede
  /// ser cierto mientras la respuesta todavía viaja por la red) — sin
  /// este margen, el botón "Iniciar receta guiada" a veces se
  /// encuentra todavía deshabilitado (`hasSteps == false`, con el
  /// `Recipe` de `fallback` que no trae `steps`).
  Future<void> openRecipeDetail(PatrolTester $, String recipeId) async {
    await $(Key('lab_recipe_card_$recipeId')).tap();
    await $.pumpAndSettle();
    for (
      var i = 0;
      i < 10 &&
          $(const Key('recipe_detail_steps_list')).exists == false &&
          $(const Key('recipe_detail_screen')).exists;
      i++
    ) {
      await $.tester.pump(const Duration(milliseconds: 300));
      await $.pumpAndSettle();
    }
  }

  patrolWidgetTest(
    'LAB-01: abrir Laboratorio muestra las 3 sub-pestañas, arranca en '
    'Cafés',
    ($) async {
      await openLab($);

      expect($(const Key('lab_screen')), findsOneWidget);
      expect($(const Key('lab_tab_cafes_button')), findsOneWidget);
      expect($(const Key('lab_tab_recetas_button')), findsOneWidget);
      expect($(const Key('lab_tab_utilidades_button')), findsOneWidget);
      // Arranca en Cafés: la vista de catálogo de café es la visible.
      expect($(const Key('lab_coffee_catalog_view')), findsOneWidget);
    },
    config: _labConfig,
  );

  patrolWidgetTest(
    'LAB-02: cambiar de sub-pestaña conserva el estado (IndexedStack) '
    '— la dosis de la calculadora sobrevive un viaje a Recetas y de '
    'vuelta',
    ($) async {
      await openLab($);
      await openUtilidadesTab($);

      await $(const Key('lab_calc_dose_plus_button')).tap();
      await $(const Key('lab_calc_dose_plus_button')).tap();
      await $.pumpAndSettle();
      expect(find.text('17 g'), findsOneWidget);

      await openRecetasTab($);
      expect($(const Key('lab_recipe_catalog_view')), findsOneWidget);

      await openUtilidadesTab($);
      // Si `RatioCalculatorView` se hubiera reconstruido desde cero
      // (mismo bug que ya se encontró y arregló en `PassportScreen`,
      // ver Fase 1 - Funcionalidades.md, bug #8), la dosis habría
      // vuelto al default de 15 g.
      expect(find.text('17 g'), findsOneWidget);
    },
    config: _labConfig,
  );

  patrolWidgetTest(
    'LAB-03: el catálogo de café vacío muestra el estado vacío '
    'esperado, sin sección de destacados',
    ($) async {
      final coffees = await fetchCoffees();
      expect(
        coffees,
        isEmpty,
        reason: 'Precondición del backend: "coffees" está vacía a '
            'propósito (carga manual vía admin, fuera de alcance) — si '
            'esto falla, alguien cargó datos y este caso deja de ser '
            'representativo, hay que revisar la matriz.',
      );

      await openLab($);

      expect($(const Key('lab_coffee_catalog_view')), findsOneWidget);
      expect($(const Key('lab_coffee_empty_state')), findsOneWidget);
      expect($(const Key('lab_coffee_featured_section')), findsNothing);
      expect($(const Key('lab_coffee_list')), findsNothing);
    },
    config: _labConfig,
  );

  patrolWidgetTest(
    'LAB-04: el catálogo de recetas trae las 5 recetas reales del seed',
    ($) async {
      await openLab($);
      await openRecetasTab($);

      expect($(const Key('lab_recipe_catalog_view')), findsOneWidget);
      expect($(const Key('lab_recipe_list')), findsOneWidget);
      expect($(const Key('lab_recipe_empty_state')), findsNothing);
      for (final name in [
        'V60',
        'Prensa francesa',
        'Espresso',
        'Chemex',
        'Aeropress',
      ]) {
        expect(find.text(name), findsOneWidget, reason: 'Falta "$name"');
      }
    },
    config: _labConfig,
  );

  patrolWidgetTest(
    'LAB-05: tap en una receta abre el detalle con los stats reales '
    '(ratio/temperatura/molienda/tiempo)',
    ($) async {
      await openLab($);
      await openRecetasTab($);

      await openRecipeDetail($, v60Id);

      expect($(const Key('recipe_detail_screen')), findsOneWidget);
      expect($(const Key('recipe_detail_stats_row')), findsOneWidget);
      // Valores reales confirmados por curl contra GET /recipes/1:
      // ratio_text=1:16, water_temp_celsius=93, grind_size=Media-fina,
      // total_time_seconds=180 (3:00).
      expect(find.textContaining('1:16'), findsWidgets);
      expect(find.textContaining('93'), findsWidgets);
      expect(find.textContaining('Media-fina'), findsWidgets);
      expect(find.textContaining('3:00'), findsWidgets);
    },
    config: _labConfig,
  );

  patrolWidgetTest(
    'LAB-06: el detalle muestra los 5 pasos del V60 ordenados y '
    'completos',
    ($) async {
      await openLab($);
      await openRecetasTab($);
      await openRecipeDetail($, v60Id);

      expect($(const Key('recipe_detail_steps_list')), findsOneWidget);
      // Texto/orden reales confirmados por curl contra GET /recipes/1
      // (steps ordenados por step_order, no por el id de la fila).
      const expectedSteps = [
        'Enjuaga el filtro con agua caliente.',
        'Agrega 15 g de café molido.',
        'Vierte 45 g de agua y espera 30 s (floración).',
        'Vierte el resto en pulsos hasta llegar a 240 g.',
        'Deja drenar hasta los 3:00.',
      ];
      for (final step in expectedSteps) {
        expect(find.text(step), findsOneWidget, reason: 'Falta "$step"');
      }
      // Orden real: el paso 1 (enjuagar el filtro) debe quedar arriba
      // del paso 5 (drenar) — no basta con "están todos", el orden
      // importa para un timer guiado.
      final firstTop = $.tester
          .getTopLeft(find.text(expectedSteps.first))
          .dy;
      final lastTop = $.tester.getTopLeft(find.text(expectedSteps.last)).dy;
      expect(firstTop < lastTop, isTrue);
    },
    config: _labConfig,
  );

  patrolWidgetTest(
    'LAB-07: "Iniciar receta guiada" abre el timer en el paso 1 con el '
    'countdown real (00:15)',
    ($) async {
      await openLab($);
      await openRecetasTab($);
      await openRecipeDetail($, v60Id);

      await $(const Key('recipe_detail_start_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('brew_timer_screen')), findsOneWidget);
      expect(
        find.text('Enjuaga el filtro con agua caliente.'),
        findsOneWidget,
      );
      expect(find.text('Paso 1 de 5'), findsOneWidget);
      expect(find.text('00:15'), findsOneWidget);
    },
    config: _labConfig,
  );

  patrolWidgetTest(
    'LAB-08: el countdown avanza automáticamente al siguiente paso al '
    'llegar a 0',
    ($) async {
      await openLab($);
      await openRecetasTab($);
      await openRecipeDetail($, v60Id);
      await $(const Key('recipe_detail_start_button')).tap();
      await $.pumpAndSettle();

      expect(find.text('Paso 1 de 5'), findsOneWidget);

      // El paso 1 dura 15 s reales (`suggested_seconds`) — espera
      // real de pared hasta ver "Paso 2 de 5" (tolerancia hasta 20 s).
      await waitRealSecondsUntil(
        $,
        () => find.text('Paso 2 de 5').evaluate().isNotEmpty,
      );

      expect(find.text('Paso 2 de 5'), findsOneWidget);
      expect(find.text('Agrega 15 g de café molido.'), findsOneWidget);
      // Paso 2 también dura 15 s — arranca de nuevo cerca de 00:15, no
      // continúa en negativo. No se asume el segundo EXACTO (`00:15`):
      // entre que `waitRealSecondsUntil` detecta "Paso 2 de 5" y este
      // `expect` corre, el `Timer.periodic` real (tiempo de pared, no
      // simulado) puede haber tickeado 1 s más — se acepta un margen
      // real de `00:15`..`00:12` en vez de un valor exacto.
      final remainingText = $.tester
          .widget<Text>(find.byKey(const Key('brew_timer_remaining_text')))
          .data;
      expect(
        RegExp(r'^00:1[0-5]$').hasMatch(remainingText ?? ''),
        isTrue,
        reason: 'Se esperaba un reinicio cerca de 00:15 al entrar al '
            'paso 2, se encontró "$remainingText".',
      );
    },
    timeout: const Timeout(Duration(seconds: 45)),
    config: _labConfig,
  );

  patrolWidgetTest(
    'LAB-09: pausar detiene el countdown; reanudar lo continúa',
    ($) async {
      await openLab($);
      await openRecetasTab($);
      await openRecipeDetail($, v60Id);
      await $(const Key('recipe_detail_start_button')).tap();
      await $.pumpAndSettle();

      expect(find.text('00:15'), findsOneWidget);
      await $(const Key('brew_timer_pause_button')).tap();
      await $.pumpAndSettle();

      // Con el timer en pausa, 3 s reales de espera NO deberían mover
      // el reloj.
      for (var i = 0; i < 3; i++) {
        await $.tester.pump(const Duration(seconds: 1));
      }
      await $.pumpAndSettle();
      expect(
        find.text('00:15'),
        findsOneWidget,
        reason: 'El countdown no debería avanzar mientras está pausado.',
      );

      // Reanudar: el ícono pasa a "pause" (ver icon del botón), y el
      // reloj vuelve a bajar.
      await $(const Key('brew_timer_pause_button')).tap();
      await $.pumpAndSettle();
      await waitRealSecondsUntil(
        $,
        () => find.text('00:15').evaluate().isEmpty,
        maxSeconds: 5,
      );
      expect(
        find.text('00:15'),
        findsNothing,
        reason: 'El countdown debería haber avanzado tras reanudar.',
      );
    },
    timeout: const Timeout(Duration(seconds: 30)),
    config: _labConfig,
  );

  patrolWidgetTest(
    'LAB-10: el botón de cerrar el timer regresa al detalle de la '
    'receta',
    ($) async {
      await openLab($);
      await openRecetasTab($);
      await openRecipeDetail($, v60Id);
      await $(const Key('recipe_detail_start_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('brew_timer_screen')), findsOneWidget);
      await $(const Key('brew_timer_back_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('brew_timer_screen')), findsNothing);
      expect($(const Key('recipe_detail_screen')), findsOneWidget);
      expect(find.text(v60Name), findsWidgets);
    },
    config: _labConfig,
  );

  patrolWidgetTest(
    'LAB-11: los chips de ratio de la calculadora reflejan los '
    'denominadores reales de las 5 recetas cargadas (1:2, 1:14, 1:15, '
    '1:16), no sólo los 3 default del mock',
    ($) async {
      await openLab($);
      await openUtilidadesTab($);
      // `_loadRatioOptions` corre en `initState` (best-effort, `GET
      // /recipes` real) — dale margen real a la respuesta antes de
      // revisar los chips.
      await $.pumpAndSettle();
      for (var i = 0; i < 5 && $(const Key('lab_calc_ratio_chip_2')).exists == false; i++) {
        await $.tester.pump(const Duration(milliseconds: 300));
        await $.pumpAndSettle();
      }

      // Denominadores reales (V60=16, Prensa francesa=15, Espresso=2,
      // Chemex=16, Aeropress=14 -> únicos ordenados: 2, 14, 15, 16).
      expect($(const Key('lab_calc_ratio_chip_2')), findsOneWidget);
      expect($(const Key('lab_calc_ratio_chip_14')), findsOneWidget);
      expect($(const Key('lab_calc_ratio_chip_15')), findsOneWidget);
      expect($(const Key('lab_calc_ratio_chip_16')), findsOneWidget);
      // El default del mock (1:17) ya NO debería estar, porque
      // ninguna receta real usa ese ratio.
      expect($(const Key('lab_calc_ratio_chip_17')), findsNothing);
      // El ratio preseleccionado (1:16) sigue siendo el default,
      // dose 15g -> 240g de agua.
      expect($(const Key('lab_calc_water_result')), findsOneWidget);
      expect(find.textContaining('240'), findsWidgets);
    },
    config: _labConfig,
  );
}
