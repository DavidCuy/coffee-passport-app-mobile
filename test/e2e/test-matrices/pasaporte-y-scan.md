# Matriz de pruebas E2E — Pasaporte (toggle grid/tarjeta) y Escáner QR

Agente QA Mobile · **sexta pasada (ejecutada) · 2026-08-02 — CERRADA 12/12**.
Historial resumido (detalle completo en "Bugs encontrados y resueltos
durante toda la sesión" al final): 1ra = matriz + tests con placeholders.
2da-5ta = ejecución real, ciclo iterativo de "arreglar → destapar el
siguiente bug" — en total se encontraron y resolvieron **8 bugs reales**
entre Mobile y Backend/DevOps, más 1 discrepancia de configuración de
entorno (puerto del backend). 6ta pasada (esta) = todo resuelto y
verificado. **Resultado final: Pasaporte 6/6 PASS, Escáner QR 6/6 PASS —
12/12, sin reservas, sin `--dart-define`, contra el backend real en
`http://localhost:8000/prod`.**

Keys acordados usados en esta matriz (finales, tras las iteraciones):
`passport_view_toggle_grid_button`, `passport_view_toggle_card_button`,
`passport_grid_view`, `passport_card_view`,
`passport_card_prev_button`/`passport_card_next_button`,
`scan_qr_manual_input`, `scan_submit_button`, `scan_result_banner`.

## Flujo 1 — Pasaporte: toggle grid ↔ tarjeta — **6/6 PASS**

Fuente de comportamiento esperado: [[Diseño UI]] sección "Componentes ya
prototipados" → "Vista de pasaporte (2 modos)": grid es el modo original/
default, tarjeta es el modo nuevo (un sello grande a pantalla completa,
nav prev/next + swipe, estado bloqueado/desbloqueado con copy distinto).

| ID | Caso | Precondición | Pasos | Resultado esperado | Estado |
|----|------|--------------|-------|---------------------|--------|
| PASS-01 | Vista por defecto al entrar al pasaporte | Usuario registrado + 2 sellos sembrados | 1. Navegar a la pantalla Pasaporte | `passport_grid_view` visible; `passport_card_view` no visible; los 2 botones de toggle visibles | **PASS** |
| PASS-02 | Tap en el botón "tarjeta" cambia de grilla a tarjeta | Igual que PASS-01 | 1. Tap en `passport_view_toggle_card_button` | `passport_card_view` visible; `passport_grid_view` deja de estar visible | **PASS** |
| PASS-03 | Tap en el botón "grid", estando en tarjeta, vuelve a la grilla | En modo tarjeta | 1. Tap en `passport_view_toggle_grid_button` | Vuelve a mostrarse `passport_grid_view` | **PASS** |
| PASS-04 | El índice de página de la tarjeta se mantiene al alternar de modo y volver | En modo tarjeta, en el sello 2/2 | 1. `passport_card_next_button` 2. Toggle a grid 3. Toggle a tarjeta | Sigue en "2 / 2" | **PASS** |
| PASS-05 | Copy de sello desbloqueado en tarjeta | 2 sellos sembrados con `unlocked_at` real | 1. Entrar en modo tarjeta | Texto "Visitado el DD/MM/YYYY." | **PASS** |
| PASS-06 | Grid muestra las cafeterías selladas | 2 sellos sembrados | 1. Entrar en modo grid | 2 `InkWell` dentro de `passport_grid_view` | **PASS** |

## Flujo 2 — Escáner QR (`POST /scan`, geofencing) — **6/6 PASS**

Fuente de comportamiento esperado: [[Deploy en producción]] → sección "QR +
Geofencing", orden de validación real del backend: auth → perfil
registrado → resuelve `qr_slug` a cafetería activa → verifica
versión+firma HMAC → valida lat/lng presentes → distancia haversine vs.
radio configurado (**409** con la distancia real si falla) → si el sello
ya existe, responde **éxito idempotente** (`already_stamped:true`, NO es
un error) → inserta sello.

| ID | Caso | Resultado esperado | Estado |
|----|------|---------------------|--------|
| SCAN-01 | Éxito — nuevo sello | Banner "¡Nuevo sello desbloqueado…" | **PASS** |
| SCAN-02 | `already_stamped` — mismo QR dos veces | Banner "Ya tenías el sello…" (200 idempotente) | **PASS** |
| SCAN-03 | Fuera de rango (`out_of_range`) | Banner "fuera de rango" (409 real) | **PASS** |
| SCAN-04 | Firma inválida | Banner "firma inválida" | **PASS** |
| SCAN-05 | Cafetería no encontrada | Banner "No encontramos ninguna cafetería…" | **PASS** |
| SCAN-06 | Input vacío / submit sin pegar QR | Banner de validación de cliente, sin llamar al backend | **PASS** |

## Resultados de ejecución (sexta pasada, 2026-08-02)

### Build/entorno probado
- App: `coffee_passport_app`, `pubspec.yaml` version `1.0.0+1`, working
  tree sobre commit `96d2d15`. `flutter analyze`: **No issues found!**
- Backend: puerto **confirmado 8000** (el "5000" de la 5ta pasada fue un
  error de comunicación — el proceso real de `fastapi dev
  src/api_local/main_server.py` siempre estuvo en 8000, su default real).
  `Env.apiBaseUrl` revertido a `http://localhost:8000/prod`;
  `patrol.yaml`/`test_fixtures.dart` (de este agente) alineados al mismo
  valor.
- Comando final, **sin `--dart-define`** (ya no hace falta, el default
  de la app es correcto):
  ```
  flutter test integration_test/passport_view_toggle_test.dart -d windows
  flutter test integration_test/scan_flow_test.dart -d windows
  ```
  Resultado: `All tests passed!` en ambos archivos (6/6 y 6/6).
- Automatización nativa de Patrol (`patrol test` en Android/iOS) sigue
  sin poder correr en este entorno (Android SDK instalado no cumple la
  versión mínima del Flutter instalado; único emulador disponible,
  `Pixel_Fold_API_35`). Se usó `patrolWidgetTest` de `patrol_finders` vía
  `flutter test -d windows` — suficiente para ambos flujos, ninguno
  necesita automatización nativa de permisos/diálogos del SO (GPS se
  fake vía inyección de `GeolocationDatasource`).

### Bugs encontrados y resueltos durante toda la sesión (8 en total)
Cada pasada de esta suite destapó exactamente el bug que la pasada
anterior enmascaraba — todos verificados end-to-end contra el backend
real, no sólo "dejó de verse el síntoma":

1. `ScanRepositoryImpl` mandaba `qr_payload` en vez de `qr` que espera el
   backend (dueño: Mobile).
2. El contenedor local servía un router desactualizado, sólo
   `/hello-world` (dueño: Backend/DevOps).
3. `users.email` NOT NULL sin validar — provocaba 500 en el alta
   automática de usuario; se resolvió exigiendo perfil ya registrado vía
   `POST /auth/register-profile` antes de `scan`/`passport` (dueño:
   Backend).
4. `Env.apiBaseUrl` no incluía el prefijo `/prod` bajo el cual el
   backend realmente sirve todas las rutas (dueño: Mobile).
5. `GET /levels`/`GET /shops` venían envueltos en `{"data": [...]}`
   (wrapper genérico de `BaseController.index()`) sin desenvolver en los
   repositorios del cliente (dueño: Mobile).
6. `Stamp.isUnlocked`/`shopName` no coincidían con el shape real de
   `GET /passport` (el nombre viene anidado en `shop.name`, y la sola
   presencia en `stamps` ya implica desbloqueado) (dueño: Mobile).
7. El key `passport_view_toggle` cubría 2 botones independientes de
   igual ancho — el tap en el centro geométrico siempre caía en el
   mismo botón, impidiendo automatizar un toggle real. Resuelto
   reemplazándolo por 2 keys dedicados,
   `passport_view_toggle_grid_button`/`_card_button` (dueño: Mobile).
8. El índice de página de la vista tarjeta no persistía al alternar a
   grid y volver — causa real: `PassportScreen` desmontaba la rama
   entera del `if/else` de `_mode` en cada cambio (no un key faltante en
   `StampCardView`, como se sospechaba inicialmente). Resuelto subiendo
   el índice al estado de `PassportScreen` (`_cardPageIndex`), pasado a
   `StampCardView` vía `initialIndex`/`onIndexChanged` (dueño: Mobile).

Más 1 discrepancia de configuración de entorno (no un bug de código):
el backend a mano se reportó primero en el puerto 5000, luego confirmado
que el puerto real siempre fue 8000 (default de `fastapi dev`) — resuelto
alineando `Env.apiBaseUrl`/`patrol.yaml`/`test_fixtures.dart` a 8000.

### Cierre
El flujo de estampas (Pasaporte + Escáner QR) queda **cerrado end-to-end,
12/12, verificado contra el backend real**, sin flags ni condiciones
especiales para correr. Cualquier regresión futura en estos 2 flujos se
detecta corriendo:
```
flutter test integration_test/ -d windows
```

## Referencias
- [[Diseño UI]]
- [[Deploy en producción]] — sección "QR + Geofencing"
- [[API endpoints]]
- [[Experiencia de usuario]]
- `ARCHITECTURE.md` (este repo)
- `mock-ui/pasaporte-cafe-mock.html`
