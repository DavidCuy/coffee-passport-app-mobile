// E2E — Reseñas de cafetería (CRUD) + rating promedio en el detalle.
//
// Casos de test/e2e/test-matrices/mapa-directorio.md, sección "Flujo 3".
// Agente QA Mobile — tercera pasada (EJECUTADA), 2026-08-02.
//
// El gap de "reload frío no reconoce mi reseña" (hallazgo #3 de la 2da
// pasada) quedó CERRADO: `GET /shops/{id}/reviews` calcula `is_mine` del
// lado del backend contra `X-Auth-User-Sub`, así que sembrar la reseña
// propia por API (`common/shop_review_fixtures.dart::seedReview`, mismo
// `sub` que usa la app) y abrir la ficha directamente ya alcanza — no
// hace falta pasar por el formulario real salvo para probar el
// formulario en sí (REV-03/05/06/09).
//
// ⚠️ Historial de esta pasada (detalle completo en la matriz, sección
// "Resultados de ejecución"):
//
// 1. BUG REAL DE MOBILE (ya ARREGLADO, confirmado en esta corrida):
//    `_ShopReviewsPanelState._refresh()`
//    (`presentation/widgets/shop_reviews_panel.dart:88`) usaba
//    `setState(() => _future = next)` — la forma flecha hacía que el
//    closure "devolviera" el `Future` asignado, algo que Flutter
//    rechaza en tiempo de test/debug. Mobile lo cambió a la forma de
//    bloque (mismo fix aplicado en `FavoriteShopsScreen`/
//    `ShopDetailScreen`) — ya no aparece la excepción en ninguna
//    corrida de este archivo.
//
// 2. Hallazgo de higiene de datos de este agente (no es bug de Mobile/
//    Backend): `shop_reviews` es una tabla real de la Supabase migrada,
//    sin reset entre corridas — cada reseña sembrada durante TODA esta
//    sesión de diagnóstico (varias corridas repetidas de este mismo
//    archivo, incluso antes del fix de arriba, cuando el bug SÍ dejaba
//    la reseña insertada en el backend antes de que la UI se cayera)
//    quedó ahí para siempre en ambas cafeterías demo. Esto rompía 2
//    tipos de asserts que asumían una base "limpia":
//    - Texto literal de comentario repetido entre corridas (ej.
//      "Excelente espresso, volvería." en REV-03) — cada corrida creaba
//      OTRA fila con el mismo texto, así que `findsOneWidget` fallaba
//      con "demasiados". Arreglado sufijando cada comentario con
//      [stamp] (único por test) — ver `withStamp()`.
//    - Promedio/conteo asumido en 0 (REV-02, REV-08, REV-09) — con
//      reseñas ajenas acumuladas de corridas previas, ni `demo-cafe-uno`
//      ni `demo-cafe-dos` siguen "limpias". Arreglado calculando el
//      promedio/estado esperado DINÁMICAMENTE a partir del baseline real
//      (`fetchShopRatingSummary`/`countOtherReviews`) en vez de asumir
//      cafetería vacía — así el resultado es correcto sin importar
//      cuánta pollution real haya acumulado la sesión.

import 'package:coffee_passport_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'common/dev_auth.dart';
import 'common/shop_review_fixtures.dart';

void main() {
  late String demoShopOneId;
  late String demoShopTwoId;
  late String mySub;
  late String otherSub;
  late String stamp;
  var counter = 0;

  setUp(() async {
    counter += 1;
    stamp = '${DateTime.now().microsecondsSinceEpoch}-$counter';
    mySub = 'qa-mobile-e2e-reviews-mine-$stamp';
    otherSub = 'qa-mobile-e2e-reviews-other-$stamp';
    seedDevLogin(sub: mySub);
    await registerTestUser(sub: mySub);
    demoShopOneId = await resolveShopId('demo-cafe-uno', sub: mySub);
    demoShopTwoId = await resolveShopId('demo-cafe-dos', sub: mySub);
  });

  tearDown(() async {
    // Best-effort: no todos los tests dejan una reseña propia, y no
    // importa si esto falla (ej. 404 porque nunca hubo una) — es sólo
    // higiene para no seguir ensuciando la Supabase real en corridas
    // futuras (ver hallazgo #2 de cabecera).
    //
    // `otherSub` se limpia también acá: REV-09 lo registra y le siembra
    // una reseña en `demoShopTwoId` para tener una 2da reseña ajena con
    // la que promediar. Antes sólo se borraba `mySub` — la de
    // `otherSub` quedaba huérfana en `demo-cafe-dos` para siempre, y
    // cada corrida de la suite sumaba una reseña ajena más, rompiendo
    // el conteo dinámico que espera REV-02 en corridas futuras.
    for (final shopId in {demoShopOneId, demoShopTwoId}) {
      for (final sub in {mySub, otherSub}) {
        try {
          await deleteOwnReview(shopId, sub: sub);
        } catch (_) {}
      }
    }
  });

  Future<void> openShopDetail(PatrolTester $, String shopId) async {
    await $.pumpWidgetAndSettle(const CoffeePassportApp());
    await $(const Key('nav_shops_tab')).tap();
    await $.pumpAndSettle();
    await $(Key('shop_card_$shopId')).tap();
    await $.pumpAndSettle();
  }

  /// Sufija [text] con [stamp] (único por test) para que los
  /// `find.text*` de este archivo nunca choquen con texto idéntico
  /// dejado por una corrida anterior de esta misma suite contra la
  /// Supabase real (ver hallazgo #2 de cabecera).
  String withStamp(String text) => '$text [$stamp]';

  /// Crea la reseña propia pasando por el formulario real — usado sólo
  /// por los casos que prueban el formulario en sí.
  Future<void> writeOwnReview(
    PatrolTester $, {
    required int stars,
    required String comment,
  }) async {
    await $(const Key('shop_review_write_button')).tap();
    await $.pumpAndSettle();
    await $(Key('shop_review_star_$stars')).tap();
    await $(const Key('shop_review_comment_input')).enterText(comment);
    await $(const Key('shop_review_submit_button')).tap();
    await $.pumpAndSettle();
  }

  // ---------------------------------------------------------------------
  // Grupo A: no pasan por `_submit`/`_delete` de `ShopReviewsPanel` — no
  // disparan el bug real #1, van primero para no arrastrar corrupción de
  // binding hacia el resto.
  // ---------------------------------------------------------------------

  patrolWidgetTest(
    'REV-01: ver una reseña ajena existente de una cafetería',
    ($) async {
      await registerTestUser(sub: otherSub);
      final theirs = await seedReview(
        demoShopOneId,
        sub: otherSub,
        rating: 4,
        comment: 'Buen café, ambiente tranquilo.',
      );

      await openShopDetail($, demoShopOneId);

      expect($(const Key('shop_reviews_panel')), findsOneWidget);
      expect($(Key('shop_review_card_${theirs['id']}')), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'REV-02: cafetería sin reseñas ajenas muestra el estado vacío '
    '(o, si la Supabase real ya acumuló reseñas de corridas previas, '
    'muestra exactamente esas y NO el estado vacío)',
    ($) async {
      // `demo-cafe-dos` pudo haber acumulado reseñas ajenas de corridas
      // previas de esta misma suite (Supabase real, sin reset — ver
      // hallazgo #2 de cabecera) — se verifica el estado real en vez de
      // asumir "limpia", así el caso sigue siendo válido en cualquiera
      // de los 2 escenarios.
      final othersBefore = await countOtherReviews(demoShopTwoId, sub: mySub);

      await openShopDetail($, demoShopTwoId);

      // Siempre válido sin importar la pollution: todavía no hay
      // reseña PROPIA en esta cafetería para este `mySub` recién creado.
      expect($(const Key('shop_review_write_button')), findsOneWidget);

      if (othersBefore == 0) {
        expect($(const Key('shop_reviews_empty_state')), findsOneWidget);
      } else {
        expect($(const Key('shop_reviews_empty_state')), findsNothing);
        expect(
          find.byType(Card).evaluate().length >= othersBefore,
          isTrue,
          reason: 'Se esperaban al menos $othersBefore reseñas ajenas '
              'ya existentes en demo-cafe-dos.',
        );
      }
    },
  );

  patrolWidgetTest(
    'REV-04: reabrir el formulario de la reseña propia la precarga en '
    'vez de ofrecer crear una segunda',
    ($) async {
      await seedReview(
        demoShopOneId,
        sub: mySub,
        rating: 3,
        comment: withStamp('Reseña original.'),
      );
      await openShopDetail($, demoShopOneId);

      await $(const Key('shop_review_edit_button')).tap();
      await $.pumpAndSettle();

      expect(find.text(withStamp('Reseña original.')), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'REV-07: una reseña ajena no expone editar/borrar',
    ($) async {
      await registerTestUser(sub: otherSub);
      final theirs = await seedReview(
        demoShopOneId,
        sub: otherSub,
        rating: 5,
        comment: 'Reseña de otro usuario.',
      );

      await openShopDetail($, demoShopOneId);

      final theirCard = find.byKey(Key('shop_review_card_${theirs['id']}'));
      expect($(theirCard), findsOneWidget);
      expect(
        find.descendant(
          of: theirCard,
          matching: find.byKey(const Key('shop_review_edit_button')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: theirCard,
          matching: find.byKey(const Key('shop_review_delete_button')),
        ),
        findsNothing,
      );
    },
  );

  patrolWidgetTest(
    'REV-08: rating promedio visible en la ficha de la cafetería',
    ($) async {
      // Baseline REAL antes de sembrar nada — nunca asumir cafetería
      // "limpia" (ver hallazgo #2 de cabecera).
      final before = await fetchShopRatingSummary(demoShopTwoId, sub: mySub);

      await registerTestUser(sub: otherSub);
      await seedReview(
        demoShopTwoId,
        sub: otherSub,
        rating: 3,
        comment: withStamp('Rating medio, ajeno.'),
      );
      await seedReview(
        demoShopTwoId,
        sub: mySub,
        rating: 5,
        comment: withStamp('Rating alto, propio.'),
      );

      final expectedAvg =
          (before.avg * before.count + 3 + 5) / (before.count + 2);

      await openShopDetail($, demoShopTwoId);

      // Promedio esperado, calculado sobre el baseline real — viene
      // directo de shop.avgRating (GET /shops/{id} -> rating_average),
      // sin depender de que el panel de reseñas termine de cargar.
      expect(
        find.textContaining(expectedAvg.toStringAsFixed(1)),
        findsWidgets,
      );
    },
  );

  patrolWidgetTest(
    'REV-10 (regresivo del gap ya cerrado): reabrir la ficha en una '
    'sesión nueva SÍ reconoce una reseña propia sembrada por API',
    ($) async {
      await seedReview(
        demoShopOneId,
        sub: mySub,
        rating: 4,
        comment: withStamp('Reseña sembrada antes de abrir la ficha.'),
      );

      // Se abre directo (nunca se pasó por la UI en esta sesión) — antes
      // del fix del Backend esto NO hubiera reconocido la reseña como
      // propia (ver hallazgo #3 de la 2da pasada de la matriz).
      await openShopDetail($, demoShopOneId);

      expect($(const Key('shop_review_edit_button')), findsOneWidget);
      expect($(const Key('shop_review_delete_button')), findsOneWidget);
      expect($(const Key('shop_review_write_button')), findsNothing);
    },
  );

  // ---------------------------------------------------------------------
  // Grupo B: pasan por `_submit`/`_delete` de `ShopReviewsPanel` —
  // ejercitaban el bug real #1 de cabecera (ya arreglado por Mobile).
  // Se dejan al final por costumbre de la pasada anterior, ya no hace
  // falta (no corrompen el binding de tests siguientes).
  // ---------------------------------------------------------------------

  patrolWidgetTest(
    'REV-03: crear una reseña nueva desde el formulario real',
    ($) async {
      await openShopDetail($, demoShopOneId);

      final comment = withStamp('Excelente espresso, volvería.');
      await writeOwnReview($, stars: 5, comment: comment);

      expect(find.textContaining(comment), findsOneWidget);
      // Reconocida como propia (is_mine server-side) — expone
      // editar/borrar.
      expect($(const Key('shop_review_edit_button')), findsOneWidget);
      expect($(const Key('shop_review_delete_button')), findsOneWidget);
      // Ya no se ofrece "escribir" de nuevo mientras exista la propia.
      expect($(const Key('shop_review_write_button')), findsNothing);
    },
  );

  patrolWidgetTest(
    'REV-05: editar reseña propia',
    ($) async {
      await seedReview(
        demoShopOneId,
        sub: mySub,
        rating: 3,
        comment: withStamp('Café correcto, nada más.'),
      );
      await openShopDetail($, demoShopOneId);

      await $(const Key('shop_review_edit_button')).tap();
      await $.pumpAndSettle();
      final newComment =
          withStamp('Volví y mejoró mucho, ahora sí lo recomiendo.');
      await $(const Key('shop_review_comment_input')).enterText(newComment);
      await $(const Key('shop_review_submit_button')).tap();
      await $.pumpAndSettle();

      expect(find.textContaining(newComment), findsOneWidget);
      // Sigue habiendo una sola tarjeta propia, no un duplicado.
      expect($(const Key('shop_review_edit_button')), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'REV-06: borrar reseña propia',
    ($) async {
      final comment = withStamp('Para borrar en este caso.');
      await seedReview(
        demoShopOneId,
        sub: mySub,
        rating: 2,
        comment: comment,
      );
      await openShopDetail($, demoShopOneId);
      expect($(const Key('shop_review_delete_button')), findsOneWidget);

      await $(const Key('shop_review_delete_button')).tap();
      await $.pumpAndSettle();

      // No hay diálogo de confirmación en el código real.
      expect(find.textContaining(comment), findsNothing);
      expect($(const Key('shop_review_write_button')), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'REV-09: el promedio se recalcula tras editar la reseña propia',
    ($) async {
      final before = await fetchShopRatingSummary(demoShopTwoId, sub: mySub);

      await registerTestUser(sub: otherSub);
      await seedReview(
        demoShopTwoId,
        sub: otherSub,
        rating: 5,
        comment: withStamp('Rating alto, ajeno.'),
      );
      await seedReview(
        demoShopTwoId,
        sub: mySub,
        rating: 3,
        comment: withStamp('Rating a editar.'),
      );

      final initialAvg =
          (before.avg * before.count + 5 + 3) / (before.count + 2);

      await openShopDetail($, demoShopTwoId);
      expect(
        find.textContaining(initialAvg.toStringAsFixed(1)),
        findsWidgets,
      );

      await $(const Key('shop_review_edit_button')).tap();
      await $.pumpAndSettle();
      await $(const Key('shop_review_star_1')).tap();
      await $(const Key('shop_review_submit_button')).tap();
      await $.pumpAndSettle();

      // Mismo baseline, pero mi rating pasó de 3 a 1.
      final finalAvg =
          (before.avg * before.count + 5 + 1) / (before.count + 2);
      expect(
        find.textContaining(finalAvg.toStringAsFixed(1)),
        findsWidgets,
      );
    },
  );
}
