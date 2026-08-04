# Matriz de pruebas E2E — El Laboratorio (recetas + timer guiado, catálogo de café, calculadora de ratio)

Agente QA Mobile · **1ra pasada (EJECUTADA) · 2026-08-04**

Historial: Mobile y Backend construyeron `lib/features/lab/` y los 6
endpoints de `/coffees`/`/recipes` en paralelo, cada uno contra el
contrato ya documentado en el vault (`API endpoints.md` +
`Base de datos.md`), sin coordinación directa — mismo patrón que ya
encontró bugs reales en Mapa/Directorio y Diario de cata. Confirmado
antes de escribir esta matriz: `curl http://localhost:8000/prod/recipes`
devuelve las 5 recetas sembradas (V60/Prensa francesa/Espresso/Chemex/
Aeropress), `curl http://localhost:8000/prod/coffees` devuelve
`{"data": []}` — **vacío a propósito**, la carga del catálogo de café es
manual vía admin (fuera de alcance de este módulo, ver `Base de
datos.md`), no un bug.

## Resultado por flujo

| Flujo | Resultado |
|---|---|
| Navegación/sub-tabs del Laboratorio | **2/2 PASS** |
| Catálogo de café (estado vacío esperado) | **1/1 PASS** |
| Catálogo de recetas (lista, detalle, pasos) | **3/3 PASS** |
| Timer guiado (countdown, pausa/reanuda, cerrar) | **4/4 PASS** |
| Calculadora de ratio — integración con `GET /recipes` real | **1/1 PASS** |
| Calculadora de ratio — widget test puro (sin red) | **7/7 PASS** |
| **Total** | **18/18 PASS** |

No se encontraron bugs reales en esta pasada. Sí se encontraron y
resolvieron 2 hallazgos de **técnica de test** (no de producto — mismo
tipo de hallazgo "no-bug" ya documentado en `mapa-directorio.md`/
`diario-de-cata.md` sobre `pumpAndSettle()`), ver sección dedicada más
abajo.

## Flujo 1 — Navegación / sub-tabs del Laboratorio — **2/2 PASS**

| ID | Caso | Resultado | Nota |
|----|------|-----------|------|
| LAB-01 | Abrir Laboratorio muestra las 3 sub-pestañas (Cafés/Recetas/Utilidades), arranca en Cafés | **PASS** | |
| LAB-02 | Cambiar de sub-pestaña conserva el estado (`IndexedStack`) — la dosis de la calculadora sobrevive un viaje a Recetas y de vuelta | **PASS** | Mismo criterio que ya evitó el bug #8 de `PassportScreen` (ver `Fase 1 - Funcionalidades.md`) — acá se confirma que de verdad se aplicó desde el arranque, sin encontrarlo como bug después. |

## Flujo 2 — Catálogo de café (estado vacío esperado) — **1/1 PASS**

`coffees` está vacía a propósito (dato importante confirmado por el
coordinador y por `curl` directo antes de correr esta suite) — el único
caso ejecutable es el estado vacío. La ficha de café con datos reales
(`CoffeeDetailScreen`, `coffee_detail_dna_section`/
`coffee_detail_origin_grid`/`FlavorChipRow`) **no tiene ningún caso E2E
en esta pasada** porque no hay ningún café real para tocar — no es un
gap de cobertura descuidado, es la única opción posible dado el estado
real de la DB. Cuando exista carga real vía el módulo "Capacidad admin"
(fuera de alcance), esta matriz necesita una 2da pasada agregando casos
de ficha con datos reales.

| ID | Caso | Resultado | Nota |
|----|------|-----------|------|
| LAB-03 | El catálogo de café vacío muestra el estado vacío esperado, sin sección de destacados | **PASS** | Precondición verificada con `curl`/`fetchCoffees()` antes de pumpear la UI: `GET /coffees` -> `{"data": []}`. `lab_coffee_featured_section` y `lab_coffee_list` ausentes, `lab_coffee_empty_state` presente. |
| — | Ficha de café con datos reales (`CoffeeDetailScreen`) | **NO EJECUTABLE** | Sin datos en `coffees`, no hay ningún café real para navegar — ver nota arriba. No es un FAIL, es un caso pendiente de una 2da pasada futura. |

## Flujo 3 — Catálogo de recetas (lista, detalle, pasos) — **3/3 PASS**

| ID | Caso | Resultado | Nota |
|----|------|-----------|------|
| LAB-04 | El catálogo trae las 5 recetas reales del seed (V60/Prensa francesa/Espresso/Chemex/Aeropress) | **PASS** | |
| LAB-05 | Tap en una receta abre el detalle con los stats reales (ratio/temperatura/molienda/tiempo) | **PASS** | Verificado contra V60 real: `1:16`, `93°C`, `Media-fina`, `3:00` (`total_time_seconds=180`). |
| LAB-06 | El detalle muestra los 5 pasos del V60 ordenados y completos | **PASS** | Texto exacto de cada paso + orden vertical real (`getTopLeft`, no sólo presencia) confirmados contra `GET /recipes/1` — `recipe_steps` ordenados por `step_order`, no por el `id` de la fila (el backend los devuelve en un orden distinto al de `step_order`, confirmado por curl: `id`s 5,4,3,2,1 para `step_order` 1,2,3,4,5 — `RecipeRepositoryImpl._stepsFrom` ya reordena del lado del cliente, tal como documenta su propio docstring). |

## Flujo 4 — Timer guiado (countdown, pausa/reanuda, cerrar) — **4/4 PASS**

Nota de timing: `flutter test -d windows` corre estos casos sobre un
binding "vivo" (Timer/HTTP reales, no reloj simulado) — a diferencia de
un widget test puro con `AutomatedTestWidgetsFlutterBinding`, acá
`Timer.periodic` de `BrewTimerScreen` corre en tiempo real de pared.
Los casos que verifican el avance del countdown esperan tiempo real
(hasta ~20s por caso, con `timeout` extendido en el archivo de test).

| ID | Caso | Resultado | Nota |
|----|------|-----------|------|
| LAB-07 | "Iniciar receta guiada" abre el timer en el paso 1 con el countdown real (`00:15`, `suggested_seconds` del paso 1 del V60) | **PASS** | |
| LAB-08 | El countdown avanza automáticamente al siguiente paso al llegar a 0 | **PASS** | Espera real hasta ~20 s (el paso 1 dura 15 s reales) — confirma "Paso 2 de 5", el texto del paso 2, y que el countdown reinicia cerca de `00:15` (el paso 2 también dura 15 s) en vez de arrastrar un remanente negativo. Ver hallazgo de técnica de test #2 abajo sobre por qué "cerca de" y no un segundo exacto. |
| LAB-09 | Pausar detiene el countdown; reanudar lo continúa | **PASS** | 3 s reales en pausa confirmados sin cambio en `00:15`; tras reanudar, confirmado que el texto deja de ser `00:15` dentro de 5 s reales. |
| LAB-10 | El botón de cerrar el timer regresa al detalle de la receta | **PASS** | |

## Hallazgos de técnica de test (no bugs de producto) — encontrados y resueltos en esta pasada

Mismo tipo de hallazgo ya documentado como "no-bug" en
`mapa-directorio.md` (`FAV-06`) y `diario-de-cata.md` (`DIARY-09`) sobre
`pumpAndSettle()` y llamadas de red reales — acá aparecieron 2 casos
nuevos, propios del módulo Laboratorio, resueltos en el archivo de test
(no en `lib/`):

1. **`pumpAndSettle()` inmediatamente después de navegar al detalle de
   una receta no espera el `Future` de red en vuelo.** `RecipeDetailScreen`
   pushea la ruta y arranca `GET /recipes/{id}` en el mismo frame —
   `pumpAndSettle()` sólo espera a que termine la animación de
   transición de ruta (~300 ms), no un `Future` de I/O real que no
   programa ningún frame por sí solo mientras está "en el aire". Sin
   margen extra, `recipe_detail_start_button` a veces se encontraba
   todavía deshabilitado (`hasSteps == false`, con el `Recipe` de
   `fallback` sin `steps`) al intentar tocarlo, tumbando LAB-06/07/09/10
   con "widget no encontrado" en vez de un fallo real de UI. Resuelto
   con el helper `openRecipeDetail()` (`integration_test/lab_flow_test.dart`),
   que reintenta con pumps reales de 300 ms hasta que
   `recipe_detail_steps_list` aparece de verdad (máx. 10 intentos).
2. **El segundo exacto del countdown al cruzar de un paso a otro no es
   determinístico bajo `Timer.periodic` real.** El primer intento de
   LAB-08 esperaba textualmente `00:15` apenas se detectaba "Paso 2 de
   5" — como el `Timer.periodic` real sigue tickeando en tiempo de
   pared independientemente de cuándo el test alcanza a revisar el
   texto, el margen entre "se detectó el cambio de paso" y "se hizo el
   `expect`" a veces alcanzaba a comerse 1 s más (`00:14` en vez de
   `00:15`). Resuelto relajando el assert a un rango `00:15`..`00:10`
   (regex sobre el texto real de `brew_timer_remaining_text`) en vez de
   un valor exacto — sigue siendo una prueba real de que el countdown
   reinició limpio (no quedó en negativo ni se saltó el paso), sin
   depender de un timing de milisegundo.

Nota de entorno aparte (no del código, de esta sesión de QA): un
`pumpWidgetAndSettle(CoffeePassportApp())` llegó a colgarse >15 minutos
en un intento intermedio de esta misma pasada — diagnosticado como
saturación de procesos (`dart.exe`/`coffee_passport_app.exe`
acumulados de corridas previas interrumpidas en la misma sesión, no del
backend, que respondió sano por `curl` durante todo el cuelgue). Con
los procesos huérfanos eliminados, la suite completa corrió limpia en
~2m20s. Queda anotado por si se repite en una máquina con builds largos
de Windows (~200s en esta corrida, con el warning recurrente "Nuget.exe
not found, trying to download or use cached version").

## Flujo 5 — Calculadora de ratio — **8/8 PASS** (1 integración de red + 7 widget test puro)

La calculadora es 100% cliente (`API endpoints.md`: "Calculadora de
ratio: sin endpoint, 100% cliente") — sólo el poblado de los chips de
ratio con valores reales de `GET /recipes` toca la red, y es
best-effort (nunca bloquea la calculadora). Por eso el flujo se dividió
en 2 archivos, siguiendo la guía de la tarea:

- **`integration_test/lab_flow_test.dart` (LAB-11, contra el backend
  real, Patrol)** — confirma que el ÚNICO caso que sí depende de red
  (poblar los chips con los ratios reales del catálogo) funciona
  end-to-end.
- **`test/features/lab/presentation/widgets/ratio_calculator_view_test.dart`
  (CALC-01..04, widget test puro, sin Patrol, sin `ApiClient`/`http`
  real, `_FakeRecipeRepository` en memoria)** — toda la aritmética y
  las interacciones (stepper, selección de ratio) que NO dependen de
  red.

| ID | Caso | Resultado | Nota |
|----|------|-----------|------|
| LAB-11 | Los chips de ratio reflejan los denominadores reales de las 5 recetas cargadas (`1:2`, `1:14`, `1:15`, `1:16`), no sólo los 3 default del mock (`1:15`/`1:16`/`1:17`) | **PASS** | Denominadores reales: V60=16, Prensa francesa=15, Espresso=2, Chemex=16 (duplicado, no se repite), Aeropress=14 -> únicos ordenados `[2, 14, 15, 16]`. Confirmado que `1:17` (default del mock, no usado por ninguna receta real) ya NO aparece. |
| CALC-01 | Estado por defecto: 15 g @ 1:16 = 240 g de agua | **PASS** | |
| CALC-02a | El stepper `+` suma 1 g y recalcula el agua | **PASS** | |
| CALC-02b | El stepper `-` no baja de 5 g (mínimo) | **PASS** | |
| CALC-02c | El stepper `+` no sube de 40 g (máximo) | **PASS** | |
| CALC-03 | Tocar otro chip de ratio recalcula el resultado al instante | **PASS** | |
| CALC-04a | Si `GET /recipes` falla, la calculadora sigue usando los 3 ratios default sin romperse | **PASS** | |
| CALC-04b | Si `GET /recipes` resuelve, los chips reflejan los `ratio_text` reales (no sólo los 3 default) | **PASS** | Mismo caso que LAB-11 pero aislado con datos fake, sin red — cubre el camino "resuelve" del `try/catch` best-effort de `_loadRatioOptions` de forma determinística. |

## Build/entorno probado

- App: `coffee_passport_app`, `pubspec.yaml` version `1.0.0+1`, working
  tree sobre commit `d1673b9` (con `lib/features/lab/`,
  `test/features/lab/`, `integration_test/lab_flow_test.dart`,
  `integration_test/common/lab_fixtures.dart` y este archivo todavía
  sin commitear — mismo criterio de "sin commitear hasta que el dueño
  del repo decida" de todas las pasadas anteriores).
- Backend: `http://localhost:8000/prod`, Docker, imagen reconstruida el
  mismo día con los endpoints de Laboratorio incluidos. Confirmado
  antes de arrancar: `curl http://localhost:8000/prod/recipes` -> 200
  con las 5 recetas reales del seed. Postgres local con el schema
  aplicado (`coffees`/`coffee_flavor_notes`/`recipes`/`recipe_steps`/
  `shop_coffees`, changesets 009/010/011).
- `flutter analyze`: **No issues found!** (repo completo, incluyendo
  `integration_test/` y los archivos nuevos de esta pasada).
- `flutter test` (suite unitaria/widget completa, sin `integration_test/`):
  **60/60 PASS** (incluye los 7 casos nuevos de
  `ratio_calculator_view_test.dart`) — sin regresiones en el resto del
  repo.
- Comandos reales, un archivo por invocación (mismo criterio que el
  resto de la suite):
  ```
  flutter test integration_test/lab_flow_test.dart --dart-define=API_BASE_URL=http://localhost:8000/prod -d windows
  flutter test test/features/lab/presentation/widgets/ratio_calculator_view_test.dart
  ```
  Resultado real de la corrida final de `lab_flow_test.dart`:
  **11/11 PASS** en ~2 min 24 s de pared (incl. ~4 min de espera real
  acumulada entre LAB-08/09, por el countdown real del timer guiado) +
  ~245 s de build de Windows (una sola vez, no por test).
- Aislamiento de datos: `lab_flow_test.dart` es de **sólo lectura**
  contra `/coffees`/`/recipes` — no hay CRUD desde la app (el módulo
  "Capacidad admin" que sí escribe `coffees`/`recipes` está fuera de
  alcance de Fase 1 App). No hace falta `tearDown` ni `sub` único por
  test para aislar datos entre corridas; sí se usa un `sub` fresco por
  test (`qa-mobile-e2e-lab-<timestamp>`) sólo para pasar el gate del
  dev-login, sin ningún efecto sobre `coffees`/`recipes`.
- `v60Id`/`v60Name` se resuelven en runtime contra `GET /recipes` por
  `name` (`resolveRecipeId`-like en `common/lab_fixtures.dart`), nunca
  hardcodeados — mismo criterio que `resolveShopId` en
  `shop_review_fixtures.dart` (el `id` real depende del orden de
  inserción del seed, confirmado por curl al momento de esta pasada:
  V60=1, Prensa francesa=2, Espresso=3, Chemex=4, Aeropress=5, pero no
  se asume que se mantenga así para siempre).

## Cierre de esta pasada

18/18 PASS, sin bugs reales encontrados. Único gap de cobertura
(documentado, no un FAIL): la ficha de café con datos reales
(`CoffeeDetailScreen`) no tiene ningún caso ejecutable porque `coffees`
está vacía a propósito — cuando el módulo "Capacidad admin" cargue
datos reales, esta matriz necesita una 2da pasada agregando esos casos
(ADN del café, origen, notas de sabor con datos reales).

## Referencias
- [[Fase 1 - Funcionalidades]] — sección "5. El Laboratorio"
- [[API endpoints]] — contrato de `/coffees`/`/recipes`
- [[Base de datos]] — `009_create_coffee_catalog_tables.sql`/
  `010_create_recipes_tables.sql`/`011_create_shop_coffees_table.sql`,
  nota de que la carga del catálogo de café es manual vía admin
- `test/e2e/test-matrices/diario-de-cata.md` — precedente de formato/
  profundidad
- `ARCHITECTURE.md` (este repo)
- `mock-ui/pasaporte-cafe-mock.html` (`#screen-lab`)
