# Matriz de pruebas E2E — Mapa/Directorio (lista + mapa, favoritos, reseñas)

Agente QA Mobile · **tercera pasada (EJECUTADA) · 2026-08-02 — 18/24 PASS,
6 FAIL (los 6 atribuibles a 1 sólo bug real repetido 3 veces en Mobile,
detalle abajo).**

Historial: 1ra pasada = matriz + tests con `Key(...)` propuesto a ciegas
(la UI todavía no existía). 2da pasada (mismo día) = matriz + tests
reescritos contra el código real de Mobile/Backend, que habían avanzado
mucho más rápido de lo esperado — sin ejecutar todavía, a la espera de
la señal explícita del coordinador. 3ra pasada (esta) = el coordinador
confirmó que Backend y Mobile cerraron y reconciliaron el contrato real
contra la Supabase migrada, con `flutter analyze` limpio y `flutter
test` 17/17 de su lado — se sacaron los `skip: true`, se corrió la suite
completa contra el backend real (`http://localhost:8000/prod`, `spa
project run-api` sin Docker) y se reporta el resultado real acá.

## Resultado por flujo

| Flujo | Resultado |
|---|---|
| 1 — Directorio: lista y mapa | **6/7 PASS** (DIR-07 nuevo, agregado en esta pasada) |
| 2 — Favoritos | **6/7 PASS** |
| 3 — Reseñas (CRUD) + rating promedio | **6/10 PASS** |
| **Total** | **18/24 PASS** |

## Bug real encontrado (1 causa raíz, 3 ocurrencias, responsable de las 6 fallas)

`setState(() => _future = next)` — la forma flecha de Dart hace que el
closure "devuelva" el valor de la asignación, que es el propio `Future`
recién asignado. Flutter rechaza esto en tiempo de test/debug con
`"setState() callback argument returned a Future."` (el assert real
sigue activo en debug; en release queda deshabilitado — el bug es
funcionalmente silencioso para el usuario final pero rompe cualquier
automatización/debugging, y es una violación real del contrato de
`setState()`). Encontrado por lectura de código
(`grep -rn "setState\(\(\) => .+ = .+\);" lib/`) y **confirmado con un
test real en las 3 ocurrencias**:

1. `lib/features/shop_directory/presentation/screens/favorite_shops_screen.dart:41`
   (`_FavoriteShopsScreenState._refresh`, llamado desde `_toggleFavorite`)
   — rompe **FAV-06**.
2. `lib/features/shop_directory/presentation/widgets/shop_reviews_panel.dart:88`
   (`_ShopReviewsPanelState._refresh`, llamado desde `_submit` Y `_delete`)
   — rompe **REV-03, REV-05, REV-06, REV-09** (las 4 mutaciones reales:
   crear, editar x2, borrar).
3. `lib/features/shop_directory/presentation/screens/shop_detail_screen.dart:64`
   (`_ShopDetailScreenState._refresh`, llamado desde el botón
   "Reintentar" del estado de error) — rompe **DIR-07** (caso agregado
   en esta pasada específicamente para confirmar esta 3ra ocurrencia con
   un test real, no sólo lectura de código).

**El patrón correcto ya existe en el mismo repo** —
`ShopDirectoryScreen._refresh()` usa la forma de bloque
(`setState(() { _shopsFuture = next; });`), que NO tiene este problema.
Fix sugerido: la misma forma de bloque en los 3 sitios de arriba.

En los 3 casos el síntoma visible es el mismo: la acción de fondo (crear/
editar/borrar reseña, quitar favorito, reintentar) **sí llega a
ejecutarse contra el backend real** (confirmado con `curl` directo — ver
nota de hallazgo #2 más abajo), pero la UI no se termina de actualizar
porque `_refresh()` revienta a mitad de camino — datos correctos, vista
desincronizada.

## Flujo 1 — Directorio: lista y mapa — **6/7 PASS**

Riesgo documentado antes de correr (`google_maps_flutter` sin soporte
oficial de Windows desktop): **no se materializó**. El `GoogleMap` monta
igual bajo `flutter test -d windows` (sin key real de Google Maps
configurada, ver `pubspec.yaml` — probablemente en blanco/"for
development purposes only", pero el widget tree y sus `Key(...)` quedan
intactos, que es lo único que necesita esta suite).

| ID | Caso | Resultado | Nota |
|----|------|-----------|------|
| DIR-01 | Vista por defecto es la lista | **PASS** | |
| DIR-02 | Toggle a mapa oculta la lista y muestra el mapa | **PASS** | Riesgo de plataforma no se materializó |
| DIR-03 | Toggle de vuelta a lista desde mapa | **PASS** | |
| DIR-04 | La lista trae las 2 cafeterías reales de `GET /shops` | **PASS** | |
| DIR-05 | Tap en una cafetería de la lista abre la ficha completa | **PASS** | |
| DIR-06 | Tap en una cafetería dentro de la hoja del mapa abre la ficha completa | **PASS** | Encontrado en esta pasada: la hoja arranca colapsada (`initialChildSize: 0.16`), hay que expandirla primero con un `fling` sobre su `ListView` interno antes de poder tocar un `ShopCard` — no es bug, es un paso de interacción real que el test no tenía. Un `drag()` simple sobre el contenedor no alcanza (`DraggableScrollableSheet` sólo responde a gestos sobre su scrollable interno). |
| DIR-07 (nuevo, agregado esta pasada) | "Reintentar" en la ficha tras un error de red no vuelve a mostrar el error correctamente | **FAIL** | 3ra ocurrencia del bug real de arriba (`ShopDetailScreen._refresh`) |

## Flujo 2 — Favoritos — **6/7 PASS**

| ID | Caso | Resultado | Nota |
|----|------|-----------|------|
| FAV-01 | Marcar favorita desde la ficha completa | **PASS** | |
| FAV-02 | Marcar/quitar favorita desde la card de la lista, sin navegar | **PASS** | |
| FAV-03 | Quitar de favoritos una ya marcada | **PASS** | |
| FAV-04 | El estado favorito persiste al salir y volver a entrar | **PASS** | |
| FAV-05 | La pantalla de favoritos muestra sólo las cafeterías marcadas | **PASS** | |
| FAV-06 | Quitar el favorito desde `FavoriteShopsScreen` la saca de esa lista | **FAIL** | Bug real de arriba (`FavoriteShopsScreen._refresh`) — el `DELETE /shops/{id}/favorite` sí se ejecuta (verificado), la card sólo no desaparece de la UI |
| FAV-07 | Pantalla de favoritos vacía muestra el estado vacío | **PASS** | |

## Flujo 3 — Reseñas (CRUD) + rating promedio — **6/10 PASS**

⚠️ Nota de higiene de datos encontrada en esta pasada: `shop_reviews` es
una tabla real de la Supabase migrada, sin reset entre corridas de esta
suite. La cafetería `demo-cafe-uno` acumuló reseñas de las 3 corridas de
diagnóstico de esta misma pasada — los casos que necesitan un promedio/
estado vacío **exacto** (REV-02, REV-08, REV-09) usan `demo-cafe-dos` en
su lugar (sin tocar hasta esta pasada) para tener una base determinística.
Se agregó además un `tearDown` best-effort que borra la reseña propia de
la corrida en ambas cafeterías demo, para no seguir ensuciando corridas
futuras. Aparte, `otherSub`/`mySub` ahora se generan **por test** (no una
sola vez por archivo) — `shop_reviews` tiene `unique(id_user, id_shop)`
real, así que reusar el mismo `sub` en 2 tests seguidos contra la misma
cafetería daba 409 real.

Los 4 casos que mutan (crear/editar/borrar) van al final del archivo a
propósito: la excepción no manejada del bug real corrompe el binding de
`flutter_test` y arrastra al test que le sigue si hay uno después
(confirmado reordenando) — así que sus fallas quedan aisladas entre sí
sin ensuciar los 6 casos que sí pasan.

| ID | Caso | Resultado | Nota |
|----|------|-----------|------|
| REV-01 | Ver una reseña ajena existente | **PASS** | |
| REV-02 | Cafetería sin reseñas ajenas muestra el estado vacío | **PASS** | Sobre `demo-cafe-dos` (ver nota de higiene) |
| REV-03 | Crear una reseña nueva desde el formulario real | **FAIL** | Bug real de arriba (`ShopReviewsPanel._refresh`, vía `_submit`) |
| REV-04 | Reabrir el formulario de la reseña propia la precarga | **PASS** | No pasa por `_submit`/`_delete`, no dispara el bug |
| REV-05 | Editar reseña propia | **FAIL** | Mismo bug, vía `_submit` |
| REV-06 | Borrar reseña propia | **FAIL** | Mismo bug, vía `_delete` — el `DELETE .../reviews/mine` sí se ejecuta (verificado), la tarjeta sólo no desaparece de la UI |
| REV-07 | Reseña ajena no expone editar/borrar | **PASS** | |
| REV-08 | Rating promedio visible en la ficha | **PASS** | Sobre `demo-cafe-dos`; confirma además que el hallazgo #1 de la 2da pasada (mismatch `rating_average`) quedó resuelto — el valor sale directo de `shop.avgRating`, sin necesitar el fallback del cliente |
| REV-09 | El promedio se recalcula tras editar la reseña propia | **FAIL** | Mismo bug, vía `_submit` de edición |
| REV-10 | Reload frío SÍ reconoce una reseña propia sembrada por API (regresivo del gap ya cerrado) | **PASS** | Confirma que el hallazgo #3 de la 2da pasada (`is_mine` no sobrevivía un reload frío) quedó CERRADO de verdad — `GET /shops/{id}/reviews` ya calcula `is_mine` server-side contra `X-Auth-User-Sub` |

## 2 bugs propios de este agente, encontrados y arreglados durante esta pasada (no de Mobile/Backend)

1. **Aislamiento de datos entre tests de un mismo archivo.** La 2da
   pasada reusaba `testUserSub`/`otherReviewerSub` (constantes de
   `common/`, generadas una sola vez por proceso) para sembrar reseñas
   **propias** repetidas veces contra la misma cafetería dentro del
   mismo archivo — `shop_reviews` tiene `unique(id_user, id_shop)` real,
   así que el 2do intento daba 409. Arreglado generando `mySub`/`otherSub`
   frescos en el `setUp` de `shop_reviews_flow_test.dart` (que corre
   antes de CADA test, no una vez por archivo).
2. **`common/dev_auth.dart::registerTestUser(sub: ...)` no mandaba el
   `sub` pedido como header real.** Usaba `ApiClient()` default, que
   resuelve `X-Auth-User-Sub` leyendo el sub "activo" en
   `SharedPreferencesAsync` (el último `seedDevLogin()`) — el parámetro
   `sub` de ese método sólo se usaba para el email del body, nunca para
   el header. Bug latente sin síntoma mientras todo el mundo pasaba (o
   heredaba) el mismo `sub` que el dev-login activo; quedó expuesto por
   el nuevo patrón de "segundo usuario" (`otherSub`) que necesita
   registrarse sin cambiar el dev-login activo de la app. Arreglado
   mandando el header explícito con `package:http` directo (mismo patrón
   que `shop_review_fixtures.dart`). **Verificado sin regresión**:
   `passport_view_toggle_test.dart` (6/6) y `scan_flow_test.dart` (6/6)
   se re-corrieron completos después del fix y siguen en verde — el
   flujo ya aprobado de `pasaporte-y-scan.md` no cambió de matriz ni de
   resultado, sólo se re-validó tras tocar un helper compartido.

## Build/entorno probado

- App: `coffee_passport_app`, `pubspec.yaml` version `1.0.0+1`, working
  tree sobre commit `96d2d15` (mismo commit base que la pasada de
  Pasaporte/Escáner — todo el trabajo de Mapa/Directorio sigue sin
  commitear, a la espera de que el dueño del repo decida).
- Backend: `http://localhost:8000/prod`, corrido a mano con `spa project
  run-api` (sin Docker, tal como pidió el coordinador para este módulo)
  contra la Supabase real ya migrada (`favorites`/`shop_reviews`
  existen). Confirmado con `curl` antes de correr: `GET /prod/shops` →
  200 con las 2 cafeterías demo reales (`id=1` Chapinero, `id=2`
  Usaquén).
- `flutter analyze`: **No issues found!** en todas las pasadas de esta
  sesión (antes y después de cada fix).
- Comandos reales, un archivo por invocación (mismo criterio que
  `pasaporte-y-scan.md` — evita el reuso de un proceso/ventana Windows
  entre archivos, que dio un "Error waiting for a debug connection" real
  al probarlo combinado):
  ```
  flutter test integration_test/shop_directory_flow_test.dart -d windows
  flutter test integration_test/favorites_flow_test.dart -d windows
  flutter test integration_test/shop_reviews_flow_test.dart -d windows
  ```
- Una corrida tuvo un `Out of memory` real del VM de Dart en medio de una
  re-validación de `passport_view_toggle_test.dart` — descartado como
  regresión al reintentar inmediatamente después (6/6 limpio); atribuido
  a presión de memoria acumulada por las múltiples compilaciones Windows
  Debug de la sesión, no a ningún cambio de código.

## Cierre de esta pasada

18/24 PASS. Las 6 fallas restantes están **100% explicadas y
reproducidas** por una única causa raíz repetida 3 veces
(`setState(() => x = someFuture)` en `favorite_shops_screen.dart`,
`shop_reviews_panel.dart` y `shop_detail_screen.dart`) — mismo fix en
los 3 sitios (cambiar a la forma de bloque `setState(() { x = value; })`,
patrón ya usado correctamente en `ShopDirectoryScreen._refresh()` del
mismo repo). Reportado al coordinador para que Mobile lo arregle y se
re-corran exactamente los 6 casos rojos (`FAV-06`, `REV-03`, `REV-05`,
`REV-06`, `REV-09`, `DIR-07`) — no hace falta re-correr los 18 que ya
pasaron, sólo estos 6 una vez aplicado el fix.

## Referencias
- [[Diseño UI]] — sección "Mapa", "Ficha de cafetería (full-screen sheet)"
- [[Experiencia de usuario]] — "Encontrar y conocer una cafetería"
- [[Fase 1 - Funcionalidades]] — sección "2. Mapa & Directorio de Barras"
- [[API endpoints]]
- `test/e2e/test-matrices/pasaporte-y-scan.md` — precedente de formato,
  lección "un botón = un key dedicado", y gotcha de sincronización
  `build/` → `src/api_local/` del backend.
- `ARCHITECTURE.md` (este repo)
- `mock-ui/pasaporte-cafe-mock.html`
