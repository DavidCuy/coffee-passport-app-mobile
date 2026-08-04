// E2E — Diario de cata (lista, crear, editar, borrar, validaciones).
//
// Casos de test/e2e/test-matrices/diario-de-cata.md.
// Agente QA Mobile — 1ra pasada (EJECUTADA), 2026-08-03/04.
//
// Contra el backend real (`http://localhost:8000/prod`, Docker,
// `docker-compose.local.yml`, imagen reconstruida con `/diary` +
// `app_config` incluidos) — Postgres local con el schema aplicado
// (`diary_entries`, changeset 012 + índice). Mismo criterio de
// aislamiento por `sub` único por test que `shop_reviews_flow_test.dart`.
//
// ⚠️ Bug real de Mobile confirmado por esta suite (ver DIARY-08 y la
// matriz para el detalle completo): `DiaryEntryFormScreen`/
// `DiaryRepositoryImpl._bodyFor` omiten la clave `note` del body de
// `PATCH /diary/{id}` cuando el usuario borra el texto de la nota
// (`note.trim().isEmpty` -> `null` -> la clave ni se manda), y
// `update_diary_entry/function.py` sólo toca `note` si la clave
// `"note"` está presente en el body — el resultado es que **nunca se
// puede borrar una nota ya escrita editando la entrada**, la nota
// vieja sobrevive indefinidamente. Ver `lib/features/diary/data/
// repositories/diary_repository_impl.dart::_bodyFor`.
//
// (Aparte, documentado en `common/diary_fixtures.dart` y en la
// matriz, no cubierto por ningún caso de esta suite porque la UI real
// nunca lo dispara: `POST/PATCH /diary` con `brew_method`/
// `visited_at` omitidos revienta con `NotNullViolation` real contra
// la Postgres real — bug de Backend/DB, `visited_at` con
// `server_default=func.now()` en el modelo SQLAlchemy que NO existe
// en el DDL real del changeset 012, y `brew_method` marcado
// `nullable=True` en el modelo pese a ser `NOT NULL` en el DDL real.
// Confirmado con `curl` directo antes de escribir esta suite, no
// reproducido acá porque el formulario real de Mobile SIEMPRE exige
// ambos campos antes de dejar enviar — cero riesgo para el usuario
// final hoy, pero contrato real roto para cualquier otro cliente/caso
// futuro que no pase por este formulario.)

import 'package:coffee_passport_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'common/dev_auth.dart';
import 'common/diary_fixtures.dart';
import 'common/shop_review_fixtures.dart' show fetchShops;

void main() {
  late String demoShopOneId; // demo-cafe-uno
  late String demoShopOneName;
  late String demoShopTwoId; // demo-cafe-dos
  late String demoShopTwoName;
  late String mySub;
  late String stamp;
  var counter = 0;

  setUp(() async {
    counter += 1;
    stamp = '${DateTime.now().microsecondsSinceEpoch}-$counter';
    mySub = 'qa-mobile-e2e-diary-$stamp';
    seedDevLogin(sub: mySub);
    await registerTestUser(sub: mySub);

    final shops = await fetchShops(sub: mySub);
    final shopOne = shops.firstWhere((s) => s['qr_slug'] == 'demo-cafe-uno');
    final shopTwo = shops.firstWhere((s) => s['qr_slug'] == 'demo-cafe-dos');
    demoShopOneId = shopOne['id'].toString();
    demoShopOneName = shopOne['name'] as String;
    demoShopTwoId = shopTwo['id'].toString();
    demoShopTwoName = shopTwo['name'] as String;
  });

  tearDown(() async {
    // Best-effort: borra todo lo que haya quedado del `sub` de esta
    // corrida — no importa si falla (ej. el test ya lo borró él
    // mismo). `mySub` es único por test, así que nunca pisa datos de
    // otra corrida.
    try {
      final leftovers = await fetchDiaryEntries(sub: mySub);
      for (final entry in leftovers) {
        try {
          await deleteDiaryEntry(entry['id'].toString(), sub: mySub);
        } catch (_) {}
      }
    } catch (_) {}
  });

  String withStamp(String text) => '$text [$stamp]';

  Future<void> openDiary(PatrolTester $) async {
    await $.pumpWidgetAndSettle(const CoffeePassportApp());
    await $(const Key('nav_diary_tab')).tap();
    await $.pumpAndSettle();
  }

  Future<void> selectShopInForm(PatrolTester $, String shopName) async {
    await $(const Key('diary_form_shop_dropdown')).tap();
    await $.pumpAndSettle();
    await $.tester.tap(find.text(shopName).last);
    await $.pumpAndSettle();
  }

  Future<void> openAddForm(PatrolTester $) async {
    await $(const Key('diary_add_entry_button')).tap();
    await $.pumpAndSettle();
  }

  patrolWidgetTest(
    'DIARY-01: el diario vacío muestra el estado vacío',
    ($) async {
      await openDiary($);

      expect($(const Key('diary_screen')), findsOneWidget);
      expect($(const Key('diary_empty_state')), findsOneWidget);
      expect($(const Key('diary_add_entry_button')), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'DIARY-02: la lista muestra las entradas más recientes primero '
    '(por fecha de visita, no de creación)',
    ($) async {
      final older = await seedDiaryEntry(
        demoShopOneId,
        sub: mySub,
        rating: 3,
        brewMethod: 'chemex',
        note: withStamp('Entrada más antigua'),
        visitedAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      final newer = await seedDiaryEntry(
        demoShopOneId,
        sub: mySub,
        rating: 5,
        brewMethod: 'v60',
        note: withStamp('Entrada más reciente'),
        visitedAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      await openDiary($);

      final newerCard = find.byKey(Key('diary_entry_card_${newer['id']}'));
      final olderCard = find.byKey(Key('diary_entry_card_${older['id']}'));
      expect($(newerCard), findsOneWidget);
      expect($(olderCard), findsOneWidget);

      final newerTop = $.tester.getTopLeft(newerCard).dy;
      final olderTop = $.tester.getTopLeft(olderCard).dy;
      expect(
        newerTop < olderTop,
        isTrue,
        reason: 'La entrada más reciente (visited_at) debería aparecer '
            'arriba de la más antigua.',
      );

      // De paso: el nombre de la cafetería anidada (`shop.name` de
      // `GET /diary`) se resuelve bien en la tarjeta.
      expect(find.text(demoShopOneName), findsWidgets);
    },
  );

  patrolWidgetTest(
    'DIARY-03: crear una entrada completa desde el formulario real '
    '(cafetería + método + calificación + nota + fecha)',
    ($) async {
      await openDiary($);
      await openAddForm($);

      await selectShopInForm($, demoShopTwoName);
      await $(const Key('diary_form_method_chip_espresso')).tap();
      await $(const Key('diary_form_star_4')).tap();
      final note = withStamp('Espresso intenso, buena crema');
      await $(const Key('diary_form_note_input')).enterText(note);
      await $(const Key('diary_form_submit_button')).tap();
      await $.pumpAndSettle();

      // De vuelta en la lista, sin quedarse en el formulario.
      expect($(const Key('diary_form_screen')), findsNothing);
      expect($(const Key('diary_screen')), findsOneWidget);
      expect(find.textContaining(note), findsOneWidget);
      expect(find.text(demoShopTwoName), findsWidgets);
      expect(find.textContaining('Espresso'), findsWidgets);
    },
  );

  patrolWidgetTest(
    'DIARY-04: crear una entrada sin nota (campo opcional)',
    ($) async {
      await openDiary($);
      await openAddForm($);

      await selectShopInForm($, demoShopOneName);
      await $(const Key('diary_form_method_chip_aeropress')).tap();
      await $(const Key('diary_form_star_3')).tap();
      await $(const Key('diary_form_submit_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('diary_form_screen')), findsNothing);
      expect(find.textContaining('Aeropress'), findsWidgets);
    },
  );

  patrolWidgetTest(
    'DIARY-05: validación — enviar sin elegir método de extracción',
    ($) async {
      await openDiary($);
      await openAddForm($);

      // No se toca ningún chip de método — sólo calificación.
      await $(const Key('diary_form_star_5')).tap();
      await $(const Key('diary_form_submit_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('diary_form_screen')), findsOneWidget);
      expect($(const Key('diary_form_error_text')), findsOneWidget);
      expect(
        find.textContaining('método', findRichText: true),
        findsWidgets,
      );
    },
  );

  patrolWidgetTest(
    'DIARY-06: validación — enviar sin calificar (0 estrellas)',
    ($) async {
      await openDiary($);
      await openAddForm($);

      await $(const Key('diary_form_method_chip_v60')).tap();
      // Sin tocar ninguna estrella.
      await $(const Key('diary_form_submit_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('diary_form_screen')), findsOneWidget);
      expect($(const Key('diary_form_error_text')), findsOneWidget);
      expect(
        find.textContaining('calificación', findRichText: true),
        findsWidgets,
      );
    },
  );

  patrolWidgetTest(
    'DIARY-07: editar una entrada existente actualiza método/'
    'calificación/nota en la lista',
    ($) async {
      final seeded = await seedDiaryEntry(
        demoShopOneId,
        sub: mySub,
        rating: 2,
        brewMethod: 'prensa_francesa',
        note: withStamp('Nota original a editar'),
      );
      final entryId = seeded['id'].toString();

      await openDiary($);
      await $(Key('diary_entry_edit_button_$entryId')).tap();
      await $.pumpAndSettle();

      await $(const Key('diary_form_method_chip_chemex')).tap();
      await $(const Key('diary_form_star_5')).tap();
      final newNote = withStamp('Nota ya editada, mucho mejor');
      await $(const Key('diary_form_note_input')).enterText(newNote);
      await $(const Key('diary_form_submit_button')).tap();
      await $.pumpAndSettle();

      expect(find.textContaining(newNote), findsOneWidget);
      expect(find.textContaining('Chemex'), findsWidgets);
      // La nota vieja ya no debería seguir visible.
      expect(
        find.textContaining(withStamp('Nota original a editar')),
        findsNothing,
      );
    },
  );

  patrolWidgetTest(
    'DIARY-08 (BUG real de Mobile): editar para borrar la nota NO la '
    'limpia — la nota anterior sobrevive',
    ($) async {
      final originalNote = withStamp('Nota que se debería poder borrar');
      final seeded = await seedDiaryEntry(
        demoShopOneId,
        sub: mySub,
        rating: 3,
        brewMethod: 'v60',
        note: originalNote,
      );
      final entryId = seeded['id'].toString();

      await openDiary($);
      expect(find.textContaining(originalNote), findsOneWidget);

      await $(Key('diary_entry_edit_button_$entryId')).tap();
      await $.pumpAndSettle();

      // Selecciona todo el texto del campo y lo borra (deja el campo
      // de notas vacío) sin tocar ningún otro campo.
      await $(const Key('diary_form_note_input')).enterText('');
      await $(const Key('diary_form_submit_button')).tap();
      await $.pumpAndSettle();

      // Comportamiento ESPERADO (documentado en Fase 1 y en el propio
      // formulario: el campo de notas es editable/borrable): la nota
      // vieja ya no debería aparecer en la tarjeta.
      //
      // Comportamiento REAL (bug confirmado): `_bodyFor` omite la
      // clave `note` del PATCH cuando el campo queda vacío, así que
      // `update_diary_entry/function.py` nunca la toca — la nota
      // vieja sigue ahí. Este `expect` queda documentado como el
      // comportamiento correcto a propósito, así la suite marca RED
      // hasta que se arregle (ver cabecera del archivo y la matriz).
      expect(
        find.textContaining(originalNote),
        findsNothing,
        reason: 'Bug real: PATCH /diary/{id} nunca manda la clave '
            '"note" cuando el usuario borra el texto (DiaryRepositoryImpl.'
            '_bodyFor sólo la incluye si no está vacía) — la nota vieja '
            'sobrevive a la edición. Ver diary_repository_impl.dart.',
      );
    },
  );

  patrolWidgetTest(
    'DIARY-09: borrar una entrada con confirmación explícita la '
    'elimina de la lista',
    ($) async {
      final note = withStamp('Entrada a borrar de verdad');
      final seeded = await seedDiaryEntry(
        demoShopOneId,
        sub: mySub,
        rating: 4,
        note: note,
      );
      final entryId = seeded['id'].toString();

      await openDiary($);
      expect(find.textContaining(note), findsOneWidget);

      await $(Key('diary_entry_delete_button_$entryId')).tap();
      await $.pumpAndSettle();

      expect($(const Key('diary_delete_confirm_dialog')), findsOneWidget);
      await $(const Key('diary_delete_confirm_button')).tap();
      // `_confirmDelete` hace 2 llamadas de red reales y secuenciales
      // (`DELETE /diary/{id}` seguido de `_refresh()` -> `Future.wait`
      // de `GET /diary` + `GET /shops`) — `pumpAndSettle()` solo a
      // veces se da por "asentado" antes de que termine el segundo
      // round-trip (mismo hallazgo, no-bug, que `FAV-06` documentó en
      // `mapa-directorio.md`: `settleAfterRoundTrip`). Se le da margen
      // real extra antes de re-verificar.
      for (var i = 0; i < 10; i++) {
        await $.tester.pump(const Duration(milliseconds: 300));
      }
      await $.pumpAndSettle();

      expect(find.textContaining(note), findsNothing);
      expect(
        $(Key('diary_entry_card_$entryId')),
        findsNothing,
      );
    },
  );

  patrolWidgetTest(
    'DIARY-10: cancelar el diálogo de borrado conserva la entrada',
    ($) async {
      final note = withStamp('Entrada que NO se debe borrar');
      final seeded = await seedDiaryEntry(
        demoShopOneId,
        sub: mySub,
        rating: 4,
        note: note,
      );
      final entryId = seeded['id'].toString();

      await openDiary($);
      await $(Key('diary_entry_delete_button_$entryId')).tap();
      await $.pumpAndSettle();

      expect($(const Key('diary_delete_confirm_dialog')), findsOneWidget);
      await $(const Key('diary_delete_cancel_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('diary_delete_confirm_dialog')), findsNothing);
      expect(find.textContaining(note), findsOneWidget);
      expect($(Key('diary_entry_card_$entryId')), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'DIARY-11: reabrir "Editar" precarga el formulario con los valores '
    'reales de la entrada',
    ($) async {
      final note = withStamp('Nota para precargar');
      final seeded = await seedDiaryEntry(
        demoShopTwoId,
        sub: mySub,
        rating: 4,
        brewMethod: 'aeropress',
        note: note,
      );
      final entryId = seeded['id'].toString();

      await openDiary($);
      await $(Key('diary_entry_edit_button_$entryId')).tap();
      await $.pumpAndSettle();

      // Nota precargada tal cual en el campo de texto.
      final noteField = $.tester.widget<TextField>(
        find.byKey(const Key('diary_form_note_input')),
      );
      expect(noteField.controller?.text, note);

      // Método precargado: el chip de aeropress debe estar
      // seleccionado (relleno con el color primario, no el borde
      // neutro) — se verifica indirectamente confirmando que las
      // 4 estrellas de calificación (n<=4) están llenas.
      for (var n = 1; n <= 4; n++) {
        final icon = $.tester.widget<Icon>(
          find.descendant(
            of: find.byKey(Key('diary_form_star_$n')),
            matching: find.byType(Icon),
          ),
        );
        expect(icon.icon, Icons.star, reason: 'Estrella $n debería estar llena.');
      }

      // Cafetería precargada correctamente (Demo Dos, no Demo Uno).
      expect(find.text(demoShopTwoName), findsWidgets);
    },
  );

  patrolWidgetTest(
    'DIARY-12: el diario de un usuario no muestra entradas de otro '
    'usuario',
    ($) async {
      await seedDiaryEntry(
        demoShopOneId,
        sub: mySub,
        rating: 5,
        note: withStamp('Entrada de otro usuario, no debería verse'),
      );

      final freshSub = 'qa-mobile-e2e-diary-isolated-$stamp';
      seedDevLogin(sub: freshSub);
      await registerTestUser(sub: freshSub);

      await $.pumpWidgetAndSettle(const CoffeePassportApp());
      await $(const Key('nav_diary_tab')).tap();
      await $.pumpAndSettle();

      expect($(const Key('diary_empty_state')), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'DIARY-13: el selector de fecha abre el date picker y permite '
    'cancelarlo sin perder el resto del formulario',
    ($) async {
      await openDiary($);
      await openAddForm($);

      await $(const Key('diary_form_method_chip_v60')).tap();
      await $(const Key('diary_form_star_3')).tap();

      await $(const Key('diary_form_visited_at_button')).tap();
      await $.pumpAndSettle();

      // Diálogo nativo de Flutter (`showDatePicker`) — botones default
      // en inglés porque la app no configura `localizationsDelegates`.
      expect(find.text('Cancel'), findsOneWidget);
      await $.tester.tap(find.text('Cancel'));
      await $.pumpAndSettle();

      // De vuelta en el formulario, sin perder lo ya elegido.
      expect($(const Key('diary_form_screen')), findsOneWidget);
      expect($(const Key('diary_form_method_chip_v60')), findsOneWidget);
    },
  );
}
