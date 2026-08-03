// E2E — Favoritos (toggle agregar/quitar + pantalla de favoritos).
//
// Casos de test/e2e/test-matrices/mapa-directorio.md, sección "Flujo 2".
// Agente QA Mobile — tercera pasada (EJECUTADA), 2026-08-02. Reescrita
// contra el código real: `FavoriteShopsScreen` es una PANTALLA dedicada
// (`Key('favorite_shops_screen')`), navegable desde
// `shop_favorites_action_button` en el `AppBar` del directorio — no un
// filtro inline como proponía la 1ra pasada de este archivo.
//
// Es seguro sembrar favoritos por API directa
// (`common/shop_review_fixtures.dart::seedFavorite`) antes de pumpear la
// UI: `GET /favorites` es la fuente de verdad real, sin ninguna
// heurística de "mine" en memoria de por medio.

import 'package:coffee_passport_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'common/dev_auth.dart';
import 'common/shop_review_fixtures.dart';

void main() {
  late String demoShopOneId;

  /// `pumpAndSettle()` a veces se da por "asentado" antes de que un
  /// round-trip real de 2 llamadas secuenciales (ej. `_toggleFavorite`:
  /// `DELETE` seguido de `_refresh()` -> `GET`) termine — encontrado en
  /// esta pasada con FAV-06 (el backend real ya reflejaba el cambio
  /// vía `curl`, la UI seguía mostrando el estado viejo hasta forzar más
  /// tiempo real). No es un bug de Mobile: con margen extra la UI se
  /// actualiza sola. Se usa después de cualquier toggle que dispare 2
  /// llamadas reales seguidas.
  Future<void> settleAfterRoundTrip(PatrolTester $) async {
    for (var i = 0; i < 10; i++) {
      await $.tester.pump(const Duration(milliseconds: 300));
    }
    await $.pumpAndSettle();
  }

  setUp(() async {
    seedDevLogin();
    await registerTestUser();
    demoShopOneId = await resolveShopId('demo-cafe-uno', sub: testUserSub);
  });

  patrolWidgetTest(
    'FAV-01: marcar favorita desde la ficha completa',
    ($) async {
      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();
      await $(Key('shop_card_$demoShopOneId')).tap();
      await $.pumpAndSettle();

      await $(const Key('shop_detail_favorite_button')).tap();
      await $.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('shop_detail_favorite_button')),
          matching: find.byIcon(Icons.favorite),
        ),
        findsOneWidget,
      );
    },
  );

  patrolWidgetTest(
    'FAV-02: marcar/quitar favorita desde la card de la lista, sin '
    'navegar a la ficha',
    ($) async {
      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();

      await $(Key('shop_card_favorite_$demoShopOneId')).tap();
      await $.pumpAndSettle();

      // No debe haber navegado.
      expect($(const Key('shop_detail_screen')), findsNothing);
      expect($(const Key('shop_directory_list_view')), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'FAV-03: quitar de favoritos una cafetería ya marcada',
    ($) async {
      await seedFavorite(demoShopOneId, sub: testUserSub);

      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();
      await $(Key('shop_card_$demoShopOneId')).tap();
      await $.pumpAndSettle();

      // Ya favorita por el seed de arriba — este tap debe des-marcarla.
      await $(const Key('shop_detail_favorite_button')).tap();
      await $.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('shop_detail_favorite_button')),
          matching: find.byIcon(Icons.favorite_border),
        ),
        findsOneWidget,
      );
    },
  );

  patrolWidgetTest(
    'FAV-04: el estado favorito persiste al salir y volver a entrar',
    ($) async {
      await seedFavorite(demoShopOneId, sub: testUserSub);

      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();

      // Sin ningún tap previo en esta sesión — el ícono ya debe salir
      // marcado (ShopDirectoryScreen._load combina GET /shops + GET
      // /favorites reales antes de construir la lista).
      expect(
        find.descendant(
          of: find.byKey(Key('shop_card_favorite_$demoShopOneId')),
          matching: find.byIcon(Icons.favorite),
        ),
        findsOneWidget,
      );
    },
  );

  patrolWidgetTest(
    'FAV-05: la pantalla de favoritos muestra sólo las cafeterías '
    'marcadas',
    ($) async {
      await seedFavorite(demoShopOneId, sub: testUserSub);
      // demo-cafe-dos queda sin marcar a propósito.

      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();

      await $(const Key('shop_favorites_action_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('favorite_shops_screen')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('favorite_shops_screen')),
          matching: find.byType(ListTile),
        ),
        findsOneWidget,
      );
      expect($(Key('shop_card_$demoShopOneId')), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'FAV-06: quitar el favorito desde la pantalla de favoritos la saca '
    'de esa lista',
    ($) async {
      await seedFavorite(demoShopOneId, sub: testUserSub);

      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();
      await $(const Key('shop_favorites_action_button')).tap();
      await $.pumpAndSettle();

      expect($(Key('shop_card_$demoShopOneId')), findsOneWidget);

      await $(Key('shop_card_favorite_$demoShopOneId')).tap();
      await settleAfterRoundTrip($);

      expect($(Key('shop_card_$demoShopOneId')), findsNothing);
    },
  );

  patrolWidgetTest(
    'FAV-07: pantalla de favoritos vacía muestra el estado vacío',
    ($) async {
      // Sin seed — el usuario de prueba de este test es único por
      // corrida (testUserSub), nunca tuvo favoritos.
      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_shops_tab')).tap();
      await $.pumpAndSettle();
      await $(const Key('shop_favorites_action_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('favorite_shops_empty_state')), findsOneWidget);
    },
  );
}
