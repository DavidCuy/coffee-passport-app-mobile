// E2E — Pasaporte: toggle grid <-> tarjeta.
//
// Casos de test/e2e/test-matrices/pasaporte-y-scan.md, sección "Flujo 1".
// Agente QA Mobile — quinta pasada, 2026-08-02. Historial completo en la
// matriz. Esta pasada:
//   - Usa los 2 keys NUEVOS que reemplazan al contenedor ambiguo
//     `passport_view_toggle` (ELIMINADO por Mobile, bug #7 resuelto):
//     `passport_view_toggle_grid_button` (activa grid) y
//     `passport_view_toggle_card_button` (activa tarjeta) — cada tap va
//     directo al botón que corresponde, sin depender de dónde caiga el
//     centro geométrico de un contenedor compartido.
//   - `PassportRepositoryImpl` ya parsea `shop.name` anidado y marca
//     `isUnlocked = true` para todo elemento presente en `stamps` (bug
//     #6 resuelto).
//
// ⚠️ Discrepancia de entorno encontrada en esta pasada (ver
// `common/test_fixtures.dart`): el backend real está corriendo a mano
// (`fastapi dev src/api_local/main_server.py`) en el puerto **8000**
// (confirmado con `Get-CimInstance Win32_Process`), no 5000 como se
// indicó — no hay nada escuchando en 5000 (3 reintentos de curl). El
// default de `Env.apiBaseUrl` ya apunta a `:5000/prod`, así que esta
// pasada corrió con `--dart-define=API_BASE_URL=http://localhost:8000/prod`
// para poder validar contra el backend que de verdad está vivo. Ver el
// reporte de ejecución en la matriz para el detalle y la recomendación
// (confirmar el puerto real con el usuario antes de la próxima pasada).
//
// Precondición que se mantiene desde la 3ra pasada: `GET /passport` sólo
// devuelve sellos YA desbloqueados (no hay placeholders de "bloqueado"),
// así que este archivo siembra 2 sellos reales (`registerTestUser` +
// `seedScan` x2) antes de cada test.

import 'package:coffee_passport_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'common/dev_auth.dart';
import 'common/test_fixtures.dart';

void main() {
  setUp(() async {
    seedDevLogin();
    await registerTestUser();
    // Sellamos las 2 cafeterías demo para que la grilla/tarjeta tengan
    // contenido real que recorrer (ver nota de cabecera).
    await seedScan(validTestQrPrimary, lat: inRangeLat, lng: inRangeLng);
    await seedScan(
      validTestQrSecondary,
      lat: outOfRangeLat, // = coordenadas reales de demo-cafe-dos
      lng: outOfRangeLng,
    );
  });

  patrolWidgetTest('PASS-01: la vista por defecto del pasaporte es la grilla', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const CoffeePassportApp());

    // Pestaña "Pasaporte" ya es la seleccionada por default (índice 0 en
    // `_HomeTabs`), no hace falta tocar `nav_passport_tab`.
    expect($(const Key('passport_grid_view')), findsOneWidget);
    expect($(const Key('passport_card_view')), findsNothing);
    expect($(const Key('passport_view_toggle_grid_button')), findsOneWidget);
    expect($(const Key('passport_view_toggle_card_button')), findsOneWidget);
  });

  patrolWidgetTest('PASS-02: tap en el botón tarjeta cambia de grilla a tarjeta', (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const CoffeePassportApp());

    expect($(const Key('passport_grid_view')), findsOneWidget);

    await $(const Key('passport_view_toggle_card_button')).tap();
    await $.pumpAndSettle();

    expect($(const Key('passport_card_view')), findsOneWidget);
    expect($(const Key('passport_grid_view')), findsNothing);
  });

  patrolWidgetTest(
    'PASS-03: tap en el botón grid, estando en tarjeta, vuelve a la grilla',
    ($) async {
      await $.pumpWidgetAndSettle(const CoffeePassportApp());

      await $(const Key('passport_view_toggle_card_button')).tap();
      await $.pumpAndSettle();
      expect($(const Key('passport_card_view')), findsOneWidget);

      await $(const Key('passport_view_toggle_grid_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('passport_grid_view')), findsOneWidget);
      expect($(const Key('passport_card_view')), findsNothing);
    },
  );

  patrolWidgetTest(
    'PASS-04: la tarjeta enfocada se mantiene al alternar de modo y volver',
    ($) async {
      await $.pumpWidgetAndSettle(const CoffeePassportApp());

      await $(const Key('passport_view_toggle_card_button')).tap();
      await $.pumpAndSettle();

      // 2 sellos sembrados en `setUp` — hay una 2da página a la que
      // avanzar.
      await $(const Key('passport_card_next_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('passport_card_view')), findsOneWidget);
      expect(find.textContaining('2 / 2'), findsOneWidget);

      // Round-trip real ahora que hay un botón dedicado por modo.
      await $(const Key('passport_view_toggle_grid_button')).tap();
      await $.pumpAndSettle();
      expect($(const Key('passport_grid_view')), findsOneWidget);

      await $(const Key('passport_view_toggle_card_button')).tap();
      await $.pumpAndSettle();

      // Confirma que `_StampCardViewState._index` no se reinició al
      // alternar de modo (el estado vive en `StampCardView`, que se
      // reconstruye entero cada vez que `_mode` cambia en
      // `PassportScreen`, así que esto documenta el comportamiento real).
      expect(find.textContaining('2 / 2'), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'PASS-05: copy de sello desbloqueado en tarjeta',
    ($) async {
      await $.pumpWidgetAndSettle(const CoffeePassportApp());

      await $(const Key('passport_view_toggle_card_button')).tap();
      await $.pumpAndSettle();

      // Copy real confirmado leyendo `stamp_card_view.dart`
      // (`_PassportPage._visitSummary`): con `unlockedAt` presente
      // ("Visitado el DD/MM/YYYY.") o sin fecha ("Sello agregado a tu
      // pasaporte."). El backend sí manda `unlocked_at`
      // (`passport_stamps.unlocked_at`), así que se espera el primer
      // caso.
      expect(find.textContaining('Visitado el '), findsWidgets);
    },
  );

  patrolWidgetTest(
    'PASS-06: la grilla muestra las cafeterías selladas del pasaporte',
    ($) async {
      await $.pumpWidgetAndSettle(const CoffeePassportApp());

      // 2 sellos sembrados en `setUp`. `StampTile` no tiene key
      // individual por tile — se cuenta por tipo de widget dentro del
      // grid.
      final tiles = find.descendant(
        of: find.byKey(const Key('passport_grid_view')),
        matching: find.byType(InkWell),
      );
      expect(tiles, findsNWidgets(2));
    },
  );
}
