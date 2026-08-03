// E2E — Directorio de cafeterías: lista y mapa.
//
// Casos de test/e2e/test-matrices/mapa-directorio.md, sección "Flujo 1".
// Agente QA Mobile — tercera pasada (EJECUTADA), 2026-08-02, contra los
// `Key(...)` reales de `ShopDirectoryScreen`/`ShopMapView`/
// `ShopDetailScreen`.
//
// Riesgo documentado antes de correr (`google_maps_flutter` sin soporte
// oficial de Windows desktop): NO se materializó — el `GoogleMap` monta
// igual (probablemente en blanco/"for development purposes only" sin
// key real de Google Maps, ver `pubspec.yaml`) y expone
// `Key('shop_map_view')`/`Key('shop_map_sheet')` con normalidad bajo
// `flutter test -d windows`. 6/6 PASS real (ver la matriz).
//
// Pumpea `CoffeePassportApp` completa (no hace falta GPS determinístico
// para este flujo, a diferencia de `scan_flow_test.dart`).

import 'package:coffee_passport_app/core/network/api_client.dart';
import 'package:coffee_passport_app/features/shop_directory/data/repositories/favorite_repository_impl.dart';
import 'package:coffee_passport_app/features/shop_directory/data/repositories/shop_repository_impl.dart';
import 'package:coffee_passport_app/features/shop_directory/data/repositories/shop_review_repository_impl.dart';
import 'package:coffee_passport_app/features/shop_directory/presentation/screens/shop_detail_screen.dart';
import 'package:coffee_passport_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'common/dev_auth.dart';
import 'common/shop_review_fixtures.dart';

void main() {
  late String demoShopOneId;

  setUp(() async {
    seedDevLogin();
    await registerTestUser();
    demoShopOneId = await resolveShopId('demo-cafe-uno', sub: testUserSub);
  });

  patrolWidgetTest(
    'DIR-01: la vista por defecto del directorio es la lista',
    ($) async {
      await $.pumpWidgetAndSettle(const CoffeePassportApp());

      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();

      expect($(const Key('shop_directory_list_view')), findsOneWidget);
      expect($(const Key('shop_map_view')), findsNothing);
    },
  );

  patrolWidgetTest(
    'DIR-02: toggle a mapa oculta la lista y muestra el mapa',
    // Riesgo google_maps_flutter/Windows (ver "Riesgo de entorno
    // conocido" en la matriz) — se corre igual para confirmarlo.
    ($) async {
      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();

      await $(const Key('shop_view_toggle_map_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('shop_map_view')), findsOneWidget);
      expect($(const Key('shop_map_sheet')), findsOneWidget);
      expect($(const Key('shop_directory_list_view')), findsNothing);
    },
  );

  patrolWidgetTest(
    'DIR-03: toggle de vuelta a lista desde mapa',
    // Mismo riesgo que DIR-02.
    ($) async {
      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();

      await $(const Key('shop_view_toggle_map_button')).tap();
      await $.pumpAndSettle();
      expect($(const Key('shop_map_view')), findsOneWidget);

      await $(const Key('shop_view_toggle_list_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('shop_directory_list_view')), findsOneWidget);
      expect($(const Key('shop_map_view')), findsNothing);
    },
  );

  patrolWidgetTest(
    'DIR-04: la lista trae las cafeterías reales de GET /shops',
    ($) async {
      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();

      // Backend real siembra 2 cafeterías demo (demo-cafe-uno,
      // demo-cafe-dos) — ver API endpoints.md. `ShopCard` expone
      // `Key('shop_card_<id>')` por cafetería.
      expect(
        find.descendant(
          of: find.byKey(const Key('shop_directory_list_view')),
          matching: find.byType(ListTile),
        ),
        findsNWidgets(2),
      );
    },
  );

  patrolWidgetTest(
    'DIR-05: tap en una cafetería de la lista abre la ficha completa',
    ($) async {
      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();

      await $(Key('shop_card_$demoShopOneId')).tap();
      await $.pumpAndSettle();

      expect($(const Key('shop_detail_screen')), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'DIR-06: tap en una cafetería dentro de la hoja del mapa abre la '
    'ficha completa',
    // Nota: se interactúa con el `ShopCard` reusado dentro de
    // `shop_map_sheet`, NO con un pin nativo del `GoogleMap` — un pin
    // del mapa no es interactuable de forma confiable desde
    // `flutter test` (plataforma nativa/plugin), ver la matriz.
    ($) async {
      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();

      await $(const Key('shop_view_toggle_map_button')).tap();
      await $.pumpAndSettle();

      // La hoja arranca colapsada (`initialChildSize: 0.16` en
      // `ShopMapView`) — el `ShopCard` existe en el árbol pero no es
      // "hit-testable" hasta expandirla. `DraggableScrollableSheet` sólo
      // responde a gestos sobre su `ListView` interno (no sobre su
      // propio `Key`, que sólo envuelve el contenedor visual) — se
      // simula con un `fling` (patrón recomendado por Flutter para
      // expandir este widget en tests) sobre el `ListView` real.
      await $.tester.fling(
        find.descendant(
          of: find.byKey(const Key('shop_map_sheet')),
          matching: find.byType(ListView),
        ),
        const Offset(0, -600),
        2000,
      );
      await $.pumpAndSettle();

      await $(
        find.descendant(
          of: find.byKey(const Key('shop_map_sheet')),
          matching: find.byKey(Key('shop_card_$demoShopOneId')),
        ),
      ).tap();
      await $.pumpAndSettle();

      expect($(const Key('shop_detail_screen')), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'DIR-07: una cafetería inexistente (404) debe mostrar el estado de '
    'error de la ficha, no una ficha vacía/fantasma',
    ($) async {
      // Pumpea `ShopDetailScreen` directo (no navega desde el
      // directorio) con un id inexistente, para forzar el estado de
      // error (`ApiException` de `getShopById`) sin depender de mockear
      // el backend — mismo criterio que `scan_flow_test.dart` al
      // pumpear `ScanScreen` directo para un caso puntual.
      final apiClient = ApiClient();
      await $.pumpWidgetAndSettle(
        MaterialApp(
          home: ShopDetailScreen(
            shopId: '999999999',
            shopRepository: ShopRepositoryImpl(apiClient: apiClient),
            favoriteRepository: FavoriteRepositoryImpl(apiClient: apiClient),
            shopReviewRepository: ShopReviewRepositoryImpl(
              apiClient: apiClient,
            ),
          ),
        ),
      );

      // Bug real distinto al de `setState` (ya arreglado por Mobile en
      // los 3 archivos, ver la matriz) — confirmado con `print` de
      // diagnóstico en esta pasada: `ApiClient.get()`
      // (`lib/core/network/api_client.dart`) nunca valida
      // `response.statusCode`, sólo intenta `jsonDecode` del body. Un
      // 404 real (`GET /shops/999999999` → `{"message":"Cafetería no
      // encontrada"}`) tiene un body JSON válido, así que `get()` lo
      // regresa como si fuera éxito. `ShopRepositoryImpl.getShopById`
      // atrapa `ApiException` para mapear 404 a `null` — código MUERTO,
      // porque `get()` nunca llega a lanzar esa excepción para un 404
      // con body parseable. Resultado real observado: `_shopFromJson`
      // arma una `Shop` "fantasma" con campos vacíos/`null` (`id` sale
      // literalmente `'null'`) en vez de que `_load()` detecte
      // `shop == null` y lance el error esperado — la ficha nunca
      // muestra "No se pudo cargar la cafetería", muestra una ficha
      // vacía/rota. No es aislado a esta pantalla: cualquier
      // repositorio que use `ApiClient.get()` para un recurso por id
      // tiene el mismo problema latente.
      expect(find.textContaining('No se pudo cargar la cafetería'),
          findsOneWidget);

      apiClient.close();
    },
  );
}
