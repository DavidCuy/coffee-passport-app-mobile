// E2E — Escáner QR (`POST /scan`, geofencing).
//
// Casos de test/e2e/test-matrices/pasaporte-y-scan.md, sección "Flujo 2".
// Agente QA Mobile — tercera pasada, 2026-07-30. Corre contra
// `coffee-passport-backend` real (imagen reconstruida, migraciones
// aplicadas) usando `ScanScreen` con su `ScanRepositoryImpl` real (mismo
// `ApiClient`/`http` que usa la app en producción) y un
// `FakeGeolocationDatasource` (ver `common/mock_location.dart`) para GPS
// determinístico — no navega desde `CoffeePassportApp` completa porque
// `main.dart` no expone un punto de inyección de ubicación hacia afuera
// (confirmado por el Agente Mobile, ver ese archivo).
//
// Usa `patrolWidgetTest` (`patrol_finders`), no `patrolTest` (`patrol`):
// no hace falta automatización nativa acá (sin diálogos de permisos,
// gracias al fake de arriba), y así corre bajo `flutter test` sin
// depender de un emulador/dispositivo (no disponible en este entorno,
// ver reporte de ejecución).
//
// Historial de bugs encontrados en pasadas anteriores (ver
// `common/test_fixtures.dart` para el detalle) — LOS 3 YA FUERON
// ARREGLADOS Y VERIFICADOS por sus dueños antes de esta pasada:
//   1. (Mobile) `ScanRepositoryImpl` mandaba `qr_payload` en vez de
//      `qr` — corregido.
//   2. (Backend/DevOps) el contenedor local servía un router
//      desactualizado (sólo `/hello-world`) — reconstruido con
//      `spa project build --api-build-mode container --yes`, los 8
//      endpoints reales responden.
//   3. (Backend, encontrado de paso al arreglar #2) `users.email`
//      NOT NULL sin validar causaba 500 en el alta automática de
//      usuario — ahora `/scan`/`/passport` YA NO auto-crean el
//      usuario, exigen `POST /auth/register-profile` primero (404 si
//      no existe). Por eso `setUp` de abajo llama
//      `registerTestUser()` antes de cada test — sin esto, TODO test
//      de este archivo fallaría con el banner de "cafetería no
//      encontrada" (la app mapea el 404 de perfil al mismo
//      `ScanResultType.shopNotFound` que un 404 de ruta, por el
//      fallback de `_typeFromResult` en `ScanRepositoryImpl` — un
//      false-negativo a tener en cuenta si un test falla así de nuevo:
//      revisar si es de verdad "cafetería no encontrada" o "perfil no
//      registrado" antes de asumir que es el mismo bug de antes).

import 'package:coffee_passport_app/core/network/api_client.dart';
import 'package:coffee_passport_app/features/scan/data/repositories/scan_repository_impl.dart';
import 'package:coffee_passport_app/features/scan/domain/repositories/scan_repository.dart';
import 'package:coffee_passport_app/features/scan/presentation/screens/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'common/dev_auth.dart';
import 'common/mock_location.dart';
import 'common/test_fixtures.dart';

void main() {
  late ApiClient apiClient;
  late ScanRepository scanRepository;

  setUp(() async {
    seedDevLogin();
    await registerTestUser();
    apiClient = ApiClient();
    scanRepository = ScanRepositoryImpl(apiClient: apiClient);
  });

  tearDown(() => apiClient.close());

  Widget pumpableScanScreen({required double lat, required double lng}) {
    return MaterialApp(
      home: ScanScreen(
        repository: scanRepository,
        geolocationDatasource: FakeGeolocationDatasource(
          latitude: lat,
          longitude: lng,
        ),
      ),
    );
  }

  patrolWidgetTest(
    'SCAN-01: escanear un QR nuevo desbloquea el sello (éxito)',
    ($) async {
      await $.pumpWidgetAndSettle(
        pumpableScanScreen(lat: inRangeLat, lng: inRangeLng),
      );

      await $(const Key('scan_qr_manual_input')).enterText(
        validTestQrPrimary,
      );
      await $(const Key('scan_submit_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('scan_result_banner')), findsOneWidget);
      expect(
        find.textContaining('¡Nuevo sello desbloqueado'),
        findsOneWidget,
      );
    },
  );

  patrolWidgetTest(
    'SCAN-02: reenviar el mismo QR responde already_stamped sin duplicar',
    ($) async {
      // Precondición real: este QR ya escaneado antes (repetimos SCAN-01
      // inline en vez de depender del orden de ejecución de los tests —
      // cada `patrolWidgetTest` debe ser independiente).
      await $.pumpWidgetAndSettle(
        pumpableScanScreen(lat: inRangeLat, lng: inRangeLng),
      );
      await $(const Key('scan_qr_manual_input')).enterText(
        validTestQrPrimary,
      );
      await $(const Key('scan_submit_button')).tap();
      await $.pumpAndSettle();

      // Segundo intento, mismo QR, misma pantalla (mismo estado que un
      // usuario reescaneando el mismo sticker).
      await $(const Key('scan_qr_manual_input')).enterText(
        validTestQrPrimary,
      );
      await $(const Key('scan_submit_button')).tap();
      await $.pumpAndSettle();

      // Importante (ver `Deploy en producción.md`): already_stamped es
      // éxito idempotente, no error.
      expect($(const Key('scan_result_banner')), findsOneWidget);
      expect(find.textContaining('Ya tenías el sello'), findsOneWidget);
    },
  );

  patrolWidgetTest(
    'SCAN-03: fuera de rango responde error (out_of_range / 409)',
    ($) async {
      await $.pumpWidgetAndSettle(
        pumpableScanScreen(lat: outOfRangeLat, lng: outOfRangeLng),
      );

      await $(const Key('scan_qr_manual_input')).enterText(
        validTestQrPrimary,
      );
      await $(const Key('scan_submit_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('scan_result_banner')), findsOneWidget);
      expect(find.textContaining('fuera de rango'), findsOneWidget);
    },
  );

  patrolWidgetTest('SCAN-04: QR con firma inválida es rechazado', ($) async {
    await $.pumpWidgetAndSettle(
      pumpableScanScreen(lat: inRangeLat, lng: inRangeLng),
    );

    // QR con estructura válida pero firma corrupta: reusamos el payload
    // válido y mutamos la parte de la firma (después del último '.').
    final parts = validTestQrPrimary.split('.');
    final tamperedSignature =
        '${parts[0]}.${parts[1].split('').reversed.join()}';

    await $(const Key('scan_qr_manual_input')).enterText(tamperedSignature);
    await $(const Key('scan_submit_button')).tap();
    await $.pumpAndSettle();

    expect($(const Key('scan_result_banner')), findsOneWidget);
    expect(find.textContaining('firma inválida'), findsOneWidget);
  });

  patrolWidgetTest(
    'SCAN-05: QR de cafetería inexistente/no encontrada es rechazado',
    ($) async {
      await $.pumpWidgetAndSettle(
        pumpableScanScreen(lat: inRangeLat, lng: inRangeLng),
      );

      // Payload con estructura válida (`shop`/`v` presentes) pero
      // `qr_slug` inexistente — la firma no importa para este caso
      // porque el backend resuelve `shop_not_found` ANTES de validar
      // firma (ver `scan_qr/function.py`, paso 2 antes que el paso 3).
      const unknownShopQr =
          'eyJpYXQiOjE3Njk3ODg4MDAsInNob3AiOiJjYWZldGVyaWEtaW5leGlzdGVudGUtOTk5IiwidiI6MX0.'
          'firma-no-importa-para-este-caso';

      await $(const Key('scan_qr_manual_input')).enterText(unknownShopQr);
      await $(const Key('scan_submit_button')).tap();
      await $.pumpAndSettle();

      expect($(const Key('scan_result_banner')), findsOneWidget);
      expect(
        find.textContaining('No encontramos ninguna cafetería'),
        findsOneWidget,
      );
    },
  );

  patrolWidgetTest(
    'SCAN-06: submit con el input vacío no dispara la llamada al backend',
    ($) async {
      await $.pumpWidgetAndSettle(
        pumpableScanScreen(lat: inRangeLat, lng: inRangeLng),
      );

      await $(const Key('scan_submit_button')).tap();
      await $.pumpAndSettle();

      // Validación de cliente (`_ScanScreenState._submit`): banner de
      // error sin llamar a la red.
      expect($(const Key('scan_result_banner')), findsOneWidget);
      expect(
        find.textContaining('Pega o escribe el contenido del QR'),
        findsOneWidget,
      );
    },
  );
}
