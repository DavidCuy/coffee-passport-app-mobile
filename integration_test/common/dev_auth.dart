// Helper para arrancar los tests E2E ya "logueados", usando el dev-login
// local del Agente Mobile
// (`lib/core/auth/dev_auth_local_datasource.dart`).
//
// Confirmado por el Agente Mobile (2026-07-30):
//   1. Clave real de almacenamiento: `dev_auth_user_sub`.
//   2. Mecanismo real: `DevAuthLocalDatasource` usa `SharedPreferencesAsync`
//      — hay que reemplazar `SharedPreferencesAsyncPlatform.instance` por
//      `InMemorySharedPreferencesAsync` (no alcanza el mock legacy
//      `SharedPreferences.setMockInitialValues`).
//   3. Sembrar esta clave alcanza para que la app arranque autenticada.
//
// Actualizado en la 3ra pasada (2026-07-30) tras el fix de Backend: `/scan`
// y `/passport` ya NO auto-crean el usuario (antes lo hacían y causaba un
// 500 real por `users.email` NOT NULL sin validar) — ahora exigen perfil
// ya registrado vía `POST /auth/register-profile`, si no existe responden
// 404 "Perfil no encontrado". Por eso `testUserSub` ahora es único por
// corrida (timestamp) — necesario para que SCAN-01 vea `success` de
// verdad y no `already_stamped` heredado de una corrida anterior de la
// suite contra la misma DB local persistente — y se agregó
// [registerTestUser]/[seedScan] para dejar al usuario de prueba en el
// estado que cada archivo de test necesita antes de arrancar la app.
//
// Actualizado de nuevo en la pasada de Mapa/Directorio (2026-08-02):
// [registerTestUser] usaba `ApiClient()` (default), que resuelve el
// header `X-Auth-User-Sub` leyendo el sub "activo" en
// `SharedPreferencesAsync` (el último `seedDevLogin()`) — el parámetro
// `sub` de este método sólo se usaba para el email del body, NUNCA para
// el header real. Bug latente sin síntoma mientras todos los llamadores
// pasaban (o heredaban) el mismo `sub` que el dev-login activo; quedó
// expuesto por `shop_reviews_flow_test.dart`, que necesita registrar a
// un "segundo usuario" (`otherSub`) sin cambiar el dev-login activo
// (`mySub`) — daba 404 "Perfil no encontrado" real al sembrar la reseña
// de `otherSub`, porque nunca se había registrado de verdad. Arreglado
// acá mandando el header explícito con `package:http` directo (mismo
// patrón que `shop_review_fixtures.dart`), sin depender del estado
// mutable de `ApiClient`/`DevAuthLocalDatasource` — comportamiento
// idéntico para todo llamador preexistente (siempre coincidía con el
// login activo), y ahora también correcto para "otro usuario".

import 'dart:convert';

import 'package:coffee_passport_app/core/config/env.dart';
import 'package:coffee_passport_app/core/network/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Sub de prueba único por corrida del proceso de test (no por test
/// individual dentro del archivo) — evita que una corrida anterior de la
/// suite contra la misma Postgres local persistente deje al usuario con
/// sellos ya desbloqueados, lo que rompería asserts que esperan `success`
/// (no `already_stamped`) en un escaneo "nuevo".
final String testUserSub =
    'qa-mobile-e2e-${DateTime.now().millisecondsSinceEpoch}';

/// Siembra el estado de "dev login" ANTES de `pumpWidgetAndSettle` para
/// que la app arranque autenticada, sin pasar por `DevLoginScreen`.
void seedDevLogin({String? sub}) {
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData(
    {'dev_auth_user_sub': sub ?? testUserSub},
  );
}

/// Da de alta el perfil de [testUserSub] contra el backend real vía
/// `POST /auth/register-profile` — requisito nuevo desde el fix de
/// Backend del 2026-07-30 (`/scan` y `/passport` ya no auto-crean el
/// usuario, responden 404 si no está registrado). Debe llamarse DESPUÉS
/// de `seedDevLogin()` (usa el mismo `ApiClient`/`X-Auth-User-Sub`) y
/// ANTES de pumpear cualquier pantalla que llame a `/passport` o `/scan`.
///
/// Manda el header `X-Auth-User-Sub` EXPLÍCITO de [resolvedSub] (ver
/// nota de cabecera del archivo sobre por qué no alcanza `ApiClient`
/// default) — así funciona tanto para el usuario "activo" del dev-login
/// como para un segundo usuario de prueba que todavía no lo es.
Future<void> registerTestUser({String? sub}) async {
  final resolvedSub = sub ?? testUserSub;
  final base = Uri.parse(Env.apiBaseUrl);
  final uri = base.replace(path: '${base.path}/auth/register-profile');
  await http.post(
    uri,
    headers: {
      'X-Auth-User-Sub': resolvedSub,
      'Content-Type': 'application/json',
    },
    body: jsonEncode({'email': '$resolvedSub@example.com'}),
  );
}

/// Escanea [qrPayload] directo contra `POST /scan` (bypasseando la UI)
/// para dejar un sello ya sembrado antes de un test que lo necesite como
/// precondición (ej. PASS-04/05/06, que necesitan sellos ya
/// desbloqueados para tener algo que mostrar en la grilla/tarjeta — ver
/// nota en `test/e2e/test-matrices/pasaporte-y-scan.md` sobre que
/// `GET /passport` sólo devuelve sellos YA desbloqueados, no cafeterías
/// bloqueadas como placeholder).
Future<void> seedScan(
  String qrPayload, {
  required double lat,
  required double lng,
}) async {
  final client = ApiClient();
  try {
    await client.post('/scan', body: {'qr': qrPayload, 'lat': lat, 'lng': lng});
  } finally {
    client.close();
  }
}
