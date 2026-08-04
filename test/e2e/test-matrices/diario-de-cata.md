# Matriz de pruebas E2E — Diario de cata (lista, crear, editar, borrar, validaciones)

Agente QA Mobile · **1ra pasada (EJECUTADA) · 2026-08-03/04 — 12/13
PASS, 1 FAIL (bug real de Mobile, root cause documentada abajo) + 2
gaps de contrato Backend/DB encontrados por lectura de código y
confirmados con `curl` directo (no cubiertos por Patrol porque la UI
real nunca los dispara — ver sección de hallazgos de contrato).**

Historial: Mobile y Backend/DB construyeron `lib/features/diary/` y
`/diary` en paralelo, sin coordinación directa, cada uno contra el
contrato ya documentado en el vault (`API endpoints.md`) — mismo
patrón que ya encontró 3 bugs reales en el módulo Mapa/Directorio
(`mapa-directorio.md`). Esta es la 1ra pasada de Diario: matriz + tests
Patrol escritos y ejecutados en la misma sesión, una vez confirmado que
el backend local (Docker, `docker-compose.local.yml`, imagen
reconstruida con `/diary` + `app_config`) respondía real.

## Resultado por flujo

| Flujo | Resultado |
|---|---|
| Diario de cata (lista, crear, editar, borrar, validaciones) | **12/13 PASS** |

## Bug real encontrado — Mobile (responsable del único FAIL)

**Editar una entrada para borrar la nota nunca la limpia** — la nota
vieja sobrevive indefinidamente a la edición, sin importar cuántas
veces se guarde el formulario con el campo vacío.

- **Síntoma**: `DIARY-08` — se siembra una entrada con nota, se edita
  la entrada, se borra el texto completo del campo de notas (queda
  vacío), se guarda. La tarjeta en la lista sigue mostrando la nota
  vieja.
- **Causa raíz** (Mobile,
  `lib/features/diary/data/repositories/diary_repository_impl.dart`,
  método `_bodyFor`, ~línea 155-158):
  ```dart
  // ignore: use_null_aware_elements
  if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
  ```
  Cuando el usuario borra el campo de notas,
  `DiaryEntryFormScreen._submit()` (línea ~117) ya convierte el string
  vacío a `null` antes de llamar `updateEntry` (`note.isEmpty ? null :
  note`). `_bodyFor` entonces omite la clave `'note'` por completo del
  body de `PATCH /diary/{id}` — no manda `"note": ""` ni `"note":
  null`, directamente no incluye la clave. Del lado del backend,
  `update_diary_entry/function.py` (línea 114-115) es explícito y
  correcto sobre este contrato: **sólo** toca `note` si la clave
  `"note"` está presente en el body (`if "note" in body_in:
  update_fields["note"] = body_in["note"]`) — comportamiento
  intencional para permitir un `PATCH` parcial que no toque campos no
  mencionados. El resultado de combinar ambos lados: no existe ninguna
  forma de que la app le diga al backend "quiero borrar la nota", sólo
  "no me refiero a la nota" — que el backend interpreta correctamente
  como "no la toques".
- **Confirmado con `curl` directo** (fuera de Patrol, para aislar si
  era un problema de UI o de contrato): `PATCH /diary/{id}` con
  `{"rating": 5}` (sin la clave `note`) sobre una entrada con
  `note: "Nota original"` devuelve la entrada con la nota intacta —
  comportamiento correcto del backend dado el contrato que implementa.
  El bug es 100% de Mobile, en cómo arma el body.
- **Fix sugerido** (no aplicado por este agente — ver "Alcance de este
  agente" abajo): `_bodyFor` (o sus llamadores) necesitan distinguir
  "no toqué este campo" (`create`: se puede seguir omitiendo, el
  backend no tiene nada que borrar) de "el usuario lo dejó
  intencionalmente vacío" (`update`: hay que mandar `"note": ""`
  explícito). La forma más simple: en `updateEntry`, mandar siempre la
  clave `'note'` (con el valor tal cual, incluyendo `''`), y sólo
  aplicar el criterio de "omitir si está vacío" en `createEntry` (que
  hoy comparte el mismo `_bodyFor` con `updateEntry` — hay que separar
  el criterio entre los dos casos, o agregar un parámetro explícito
  tipo `isUpdate`/`clearNote`).

## Alcance de este agente (por qué no se arregló directamente)

El bug de arriba vive en código de producción de la feature Diario
(`lib/features/diary/data/`), no en código de test — mismo criterio ya
seguido en todas las pasadas anteriores de este repo (`mapa-
directorio.md`, `pasaporte-y-scan.md`): esta pasada documenta la causa
raíz exacta (archivo + líneas + por qué) para que el Agente Mobile lo
aplique, en vez de que QA edite `lib/` directamente. No es un fix de
una sola línea aislada (como si lo fue el bug de `setState(() => x =
future)` que si arregló Mobile en la pasada de Mapa/Directorio) —
requiere decidir el criterio correcto para diferenciar `create` de
`update` en `_bodyFor`, una decisión de diseño del contrato cliente que
le corresponde a quien es dueño de esa clase.

## Hallazgos de contrato Backend/DB — NO cubiertos por Patrol (la UI real nunca los dispara)

Durante la exploración de contrato con `curl` directo (antes de
escribir la suite, para no reproducir a ciegas), aparecieron 2 gaps
reales entre lo que documenta `API endpoints.md`/`create_diary_entry/
function.py` ("brew_method`/`note`/`visited_at` opcionales") y lo que
la Postgres real (changeset `012_create_diary_entries_table.sql`)
permite. **Ninguno de los 2 se reproduce vía la app real** porque
`DiaryEntryFormScreen._submit()` exige explícitamente elegir método
(`_method == null` → error) y siempre calcula `_visitedAt` con un
default (`DateTime.now()`, nunca `null`) — así que la app siempre manda
ambos campos. Documentados igual porque son un contrato roto real para
cualquier otro cliente (o si el formulario de Mobile relaja esa
validación en el futuro):

1. **`brew_method` es `NOT NULL` en la Postgres real, pero el modelo
   SQLAlchemy y los validadores del backend lo tratan como
   opcional.** Changeset real:
   `${flowSchema}.brew_method NOT NULL` (`012_create_diary_entries_table.sql:9`).
   Modelo: `core_db/models/diary_entry.py:50`,
   `brew_method = Column(BrewMethodEnum, nullable=True)`.
   `create_diary_entry/function.py::_validate_brew_method` regresa
   `None` si no viene el campo, sin error. Confirmado con `curl`:
   `POST /diary` con `{"id_shop":1,"rating":3}` (sin `brew_method`)
   responde `422 {"message":"No se pudo crear la entrada del diario"}`
   — un `NotNullViolation` real de Postgres expuesto como mensaje
   genérico, en vez de la validación 400 clara que sí existe para
   `rating`/`id_shop`.
2. **`visited_at` es `NOT NULL` en la Postgres real y SIN default a
   nivel de columna, pero el modelo SQLAlchemy declara
   `server_default=func.now()` (que no existe en el DDL real).**
   Changeset real: `visited_at TIMESTAMPTZ NOT NULL` — **sin**
   `DEFAULT` (a diferencia de `created_at`/`updated_at`, que sí tienen
   `DEFAULT now()`), `012_create_diary_entries_table.sql:12-14`.
   Modelo: `core_db/models/diary_entry.py:53`,
   `visited_at = Column(DateTime(timezone=True), nullable=False,
   server_default=func.now())`. Como el modelo cree que hay un default
   de servidor, SQLAlchemy omite la columna del `INSERT` (confiando en
   que Postgres la va a rellenar sola) — pero como el DDL real no
   tiene ningún `DEFAULT`, Postgres inserta `NULL` y revienta el mismo
   `NOT NULL` constraint. Confirmado con `curl`: `POST /diary` con
   `{"id_shop":1,"brew_method":"v60","rating":3}` (sin `visited_at`)
   responde el mismo `422` genérico, con
   `psycopg2.errors.NotNullViolation: null value in column
   "visited_at"` en el log real del contenedor
   (`docker logs coffeepassportbackend-api-local`).

Reportado al coordinador para que lo enrute al Agente Backend — no se
tocó `coffee-passport-backend` (fuera del workspace de este agente).
`integration_test/common/diary_fixtures.dart` documenta el mismo
hallazgo inline y **siempre** manda ambos campos al sembrar datos
justamente para no toparse con este bug al armar fixtures.

## Diario de cata — 12/13 PASS

| ID | Caso | Resultado | Nota |
|----|------|-----------|------|
| DIARY-01 | El diario vacío muestra el estado vacío | **PASS** | |
| DIARY-02 | La lista ordena las entradas más recientes primero (por `visited_at`, no `created_at`) | **PASS** | Verificado comparando posición vertical real de las tarjetas (`getTopLeft`), no sólo presencia. De paso confirma que `shop.name` anidado de `GET /diary` se resuelve bien en la tarjeta. |
| DIARY-03 | Crear una entrada completa desde el formulario real (cafetería + método + calificación + nota + fecha) | **PASS** | |
| DIARY-04 | Crear una entrada sin nota (campo opcional) | **PASS** | |
| DIARY-05 | Validación — enviar sin elegir método de extracción | **PASS** | |
| DIARY-06 | Validación — enviar sin calificar (0 estrellas) | **PASS** | |
| DIARY-07 | Editar una entrada existente actualiza método/calificación/nota en la lista | **PASS** | Editar SÍ funciona cuando la nota nueva no está vacía — el bug de abajo es específico de dejarla vacía. |
| DIARY-08 | Editar para borrar la nota (dejarla vacía) debería limpiarla | **FAIL** | Bug real de Mobile, ver detalle arriba |
| DIARY-09 | Borrar una entrada con confirmación explícita la elimina de la lista | **PASS** | Encontrado en esta pasada: `_confirmDelete` hace 2 llamadas de red reales secuenciales (`DELETE` + `_refresh()` → `GET /diary` + `GET /shops`) — `pumpAndSettle()` a veces se da por "asentado" antes de que termine el 2do round-trip. **No es bug** (mismo hallazgo no-bug que `FAV-06` documentó en `mapa-directorio.md`, `DiaryScreen._refresh` ya usa la forma de bloque correcta de `setState`) — se agregó el mismo margen extra (`settleAfterRoundTrip`-like) que ya usa `favorites_flow_test.dart`, y con eso pasa consistente. |
| DIARY-10 | Cancelar el diálogo de borrado conserva la entrada | **PASS** | |
| DIARY-11 | Reabrir "Editar" precarga el formulario con los valores reales de la entrada | **PASS** | Nota, calificación (estrellas llenas) y cafetería seleccionada verificadas contra los valores sembrados por API |
| DIARY-12 | El diario de un usuario no muestra entradas de otro usuario | **PASS** | Aislamiento por `id_user` confirmado end-to-end (no sólo lectura de código) |
| DIARY-13 | El selector de fecha abre el date picker nativo y permite cancelarlo sin perder el resto del formulario | **PASS** | Botones en inglés (`Cancel`/`OK`) porque la app no configura `localizationsDelegates` — no es bug, sólo nota de la suite |

## Build/entorno probado

- App: `coffee_passport_app`, `pubspec.yaml` version `1.0.0+1`, working
  tree sobre commit `5420232` (con `lib/features/diary/`,
  `test/features/diary/`, cambios de `lib/main.dart` (wiring del nuevo
  tab) y `lib/features/shop_directory/presentation/widgets/
  rating_stars.dart` (parámetro `keyPrefix` de `RatingSelector`)
  todavía sin commitear — mismo criterio de "sin commitear hasta que
  el dueño del repo decida" de todas las pasadas anteriores).
- Backend: `http://localhost:8000/prod`, Docker
  (`docker-compose.local.yml`, contenedor
  `coffeepassportbackend-api-local`), imagen reconstruida el mismo día
  con `/diary` + `app_config` incluidos (confirmado antes de arrancar:
  `curl http://localhost:8000/prod/shops` → 200). Postgres local
  (`coffeepassportbackend-postgres-local`) con el schema aplicado
  (`diary_entries`, changeset 012 + índice).
- `flutter analyze` sobre los 2 archivos nuevos de esta pasada
  (`integration_test/diary_flow_test.dart`,
  `integration_test/common/diary_fixtures.dart`): **No issues found!**
  (1 aviso `info` de `use_null_aware_elements` corregido con el mismo
  `// ignore:` que ya usa `diary_repository_impl.dart` para el mismo
  patrón intencional de `if (x != null) 'k': x`).
- Comando real, un archivo por invocación (mismo criterio que el resto
  de la suite — evita reuso de proceso/ventana Windows entre
  archivos):
  ```
  flutter test integration_test/diary_flow_test.dart --dart-define=API_BASE_URL=http://localhost:8000/prod -d windows
  ```
- Aislamiento de datos: `mySub` único por test (timestamp +
  contador), igual que `shop_reviews_flow_test.dart` — `diary_entries`
  no tiene `unique(id_user, id_shop)`, así que no había riesgo de 409
  por reuso, pero sí de que una corrida anterior against la misma
  Postgres local ensuciara los asserts de texto/orden — todos los
  textos de nota van sufijados con un `stamp` único por test
  (`withStamp`), y `tearDown` borra best-effort todo lo sembrado por
  `mySub` en cada test.

## Cierre de esta pasada

12/13 PASS. El único FAIL (`DIARY-08`) es un bug real y reproducible
de Mobile, con causa raíz exacta documentada arriba — reportado al
coordinador para que el Agente Mobile lo arregle y se re-corra
`DIARY-08` (no hace falta re-correr los 12 que ya pasaron). Aparte, 2
gaps de contrato reales entre Backend y DB (`brew_method`/`visited_at`
`NOT NULL` en la Postgres real vs. tratados como opcionales en el
modelo/validadores) quedaron documentados para el Agente Backend —
no bloquean ningún caso de esta matriz porque la UI real de Mobile
nunca omite esos campos, pero sí romperían a cualquier otro
consumidor de `/diary` que confíe en la documentación tal cual está
hoy.

## Referencias
- [[Fase 1 - Funcionalidades]] — sección "4. Diario de Cata / Ficha de Notas"
- [[API endpoints]] — contrato de `/diary`
- [[Base de datos]] — `012_create_diary_entries_table.sql`
- `test/e2e/test-matrices/mapa-directorio.md` — precedente de formato/profundidad, y el hallazgo no-bug de `pumpAndSettle` tras un round-trip real (`FAV-06`)
- `ARCHITECTURE.md` (este repo)
- `mock-ui/pasaporte-cafe-mock.html` (`#screen-diario`)
