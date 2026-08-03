// Fixtures/constantes compartidas por los tests E2E de Pasaporte y Escáner
// QR (ver ../../test/e2e/test-matrices/pasaporte-y-scan.md).
//
// Agente QA Mobile — tercera pasada, 2026-07-30. Valores reales de
// Backend (QR de prueba, coordenadas). Historial (ver la matriz para el
// detalle completo): la 2da pasada encontró 2 bugs reales (campo
// `qr_payload` vs `qr` en `ScanRepositoryImpl`, y el router local
// desactualizado sirviendo sólo `/hello-world`) — YA ARREGLADOS y
// verificados por Mobile/Backend antes de esta pasada. De paso, Backend
// encontró y arregló un 3er bug (`users.email` NOT NULL sin validar) que
// cambió el contrato: `/scan` y `/passport` ya no auto-crean el usuario,
// exigen `POST /auth/register-profile` primero — ver
// `common/dev_auth.dart` (`registerTestUser`).

/// URL base del backend contra el que corren los tests E2E.
///
/// Confirmado (6ta pasada, 2026-08-02): el "5000" de la 5ta pasada fue un
/// error — el puerto real del backend a mano (`fastapi dev
/// src/api_local/main_server.py`) es **8000** (su default real).
/// `Env.apiBaseUrl` (`lib/core/config/env.dart`) fue revertido a
/// `http://localhost:8000/prod`, alineado acá.
const String testApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000/prod',
);

/// QR string válido de "Demo 1" (Chapinero, `qr_slug=demo-cafe-uno`),
/// `qr_secret_version=1`. Generado por el Agente Backend con
/// `scripts/generate_test_qr.py` usando el `MASTER_SECRET` de su `.env`
/// local (gitignored) — sólo válido contra un backend que corra con ESE
/// mismo `.env` (ver nota del vault, `API endpoints.md`, si se regenera
/// el `.env` estos strings dejan de servir).
const String validTestQrPrimary =
    'eyJpYXQiOjE3Njk3ODg4MDAsInNob3AiOiJkZW1vLWNhZmUtdW5vIiwidiI6MX0.'
    'f0qmrMgilxcCc2M9X0S-jlktOezfMLXnF3EKbH93b4o';

/// Segundo QR válido, "Demo 2" (Usaquén, `qr_slug=demo-cafe-dos`),
/// `qr_secret_version=1` — cafetería distinta a [validTestQrPrimary],
/// para no reusar el mismo estado de sello entre SCAN-01/02 y otros
/// casos que necesiten "una cafetería sin sellar todavía".
const String validTestQrSecondary =
    'eyJpYXQiOjE3Njk3ODg4MDAsInNob3AiOiJkZW1vLWNhZmUtZG9zIiwidiI6MX0.'
    'HZD2XXvfU2TApm84pfA8dObXQzTNMYVVZIAOnvwmUgo';

/// Coordenadas exactas de la cafetería Demo 1 (Chapinero,
/// `demo-cafe-uno`) — usarlas tal cual como "GPS del dispositivo" cae
/// dentro de cualquier radio de geofence razonable (default backend:
/// 150m hardcodeado en `scan_qr/function.py`, `shops.geofence_radius_meters`
/// es NULL para las 2 cafeterías demo del seed).
const double inRangeLat = 4.6533;
const double inRangeLng = -74.0575;

/// Coordenadas de la cafetería Demo 2 (Usaquén, `demo-cafe-dos`) —
/// reusadas como punto "fuera de rango" para SCAN-03 al escanear el QR
/// de Demo 1 ([validTestQrPrimary]): Chapinero-Usaquén son ~6.5km entre
/// sí, muy por encima del radio de 150m default. Confirmado por la nota
/// del vault ("Uso para Mobile/QA" en `API endpoints.md`): "para probar
/// out_of_range, mandar cualquier coordenada alejada (ej. la de la otra
/// cafetería demo)".
const double outOfRangeLat = 4.6946;
const double outOfRangeLng = -74.0313;
