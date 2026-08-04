// Smoke test de la app real (post dev-login).
//
// Cubre el flujo mínimo que no depende de tener `coffee-passport-backend`
// corriendo: completar el "dev login" temporal (ver
// `lib/core/auth/dev_auth_local_datasource.dart`) y navegar entre las 3
// pantallas reales (Pasaporte / Escanear / Cafeterías) verificando que
// los widget keys que QA necesita están presentes. Las pantallas que sí
// llaman al backend (Pasaporte, Cafeterías) no deben tronar cuando la
// llamada falla (no hay servidor en el entorno de test) — deben caer en
// su estado de error, no crashear.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:coffee_passport_app/main.dart';

void main() {
  setUp(() {
    // Reemplaza el backend real de shared_preferences por uno en
    // memoria, vacío en cada test, para que el "dev login" siempre
    // arranque sin `sub` guardado.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('pide dev login y luego navega a Escanear', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CoffeePassportApp());
    await tester.pumpAndSettle();

    // Sin `sub` guardado, debe mostrar el dev-login temporal primero.
    expect(find.text('Dev login (temporal)'), findsOneWidget);
    expect(find.byKey(const Key('dev_login_sub_input')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dev_login_submit_button')));
    await tester.pumpAndSettle();

    // Ya logueado (modo dev), debe mostrar la navegación de las 3
    // pantallas reales con la pestaña "Pasaporte" activa por defecto.
    expect(find.text('Dev login (temporal)'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);

    // Navega a "Escanear" y verifica los widget keys obligatorios de
    // la feature `scan` (no dependen del backend hasta que se envíe).
    await tester.tap(find.text('Escanear'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scan_qr_manual_input')), findsOneWidget);
    expect(find.byKey(const Key('scan_submit_button')), findsOneWidget);

    // Enviar sin texto no debe intentar red — debe mostrar el banner
    // de resultado como validación de cliente.
    await tester.tap(find.byKey(const Key('scan_submit_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scan_result_banner')), findsOneWidget);
  });

  testWidgets('la pantalla de Pasaporte no truena sin backend disponible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CoffeePassportApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dev_login_submit_button')));
    await tester.pumpAndSettle();

    // Sin `coffee-passport-backend` corriendo en el entorno de test,
    // GET /passport falla — la pantalla debe caer en su estado de
    // error explícito (no un unhandled exception).
    expect(find.textContaining('No se pudo cargar tu pasaporte'), findsOneWidget);
  });

  testWidgets(
    'la pantalla de Laboratorio muestra sus 3 sub-tabs y no truena sin '
    'backend disponible',
    (WidgetTester tester) async {
      await tester.pumpWidget(const CoffeePassportApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dev_login_submit_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('nav_lab_tab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lab_screen')), findsOneWidget);
      expect(find.byKey(const Key('lab_tab_cafes_button')), findsOneWidget);
      expect(find.byKey(const Key('lab_tab_recetas_button')), findsOneWidget);
      expect(
        find.byKey(const Key('lab_tab_utilidades_button')),
        findsOneWidget,
      );

      // La Calculadora de ratio es 100% cliente — debe funcionar sin
      // depender de que `GET /coffees`/`GET /recipes` respondan.
      await tester.tap(find.byKey(const Key('lab_tab_utilidades_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('lab_ratio_calculator_view')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('lab_calc_water_result')), findsOneWidget);

      await tester.tap(find.byKey(const Key('lab_calc_dose_plus_button')));
      await tester.pump();
      expect(find.text('16 g'), findsOneWidget);
    },
  );
}
