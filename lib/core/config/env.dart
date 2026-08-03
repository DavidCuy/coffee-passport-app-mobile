/// Configuración de entorno de la app.
///
/// `coffee-passport-backend` corre localmente vía `docker-compose.yml`
/// (repo hermano) mapeando el contenedor `coffeepassportbackend-api` al
/// puerto **8000** del host por defecto (mismo puerto que usa en
/// producción detrás de nginx, ver `Deploy en producción.md` en el
/// vault). Este valor es una constante de un solo lugar para poder
/// cambiarla fácilmente (emulador Android físico, dispositivo real en
/// la misma red, staging futuro, etc.) sin tener que tocar cada
/// feature.
///
/// ⚠️ Confirmado por el usuario (2026-08-02): el backend real corre en
/// el puerto **8000** (el 5000 usado brevemente antes fue una
/// confusión de un setup manual temporal). [apiBaseUrl] vuelve a
/// apuntar a `8000` por defecto.
///
/// ⚠️ Todas las rutas del backend (generado con spa-cli, modo
/// container) quedan servidas bajo el prefijo de stage `/prod` — así
/// en el contenedor local (confirmado por QA Mobile: `GET
/// http://localhost:8000/scan` → 404, `GET
/// http://localhost:8000/prod/scan` → 200) y así queda también en
/// producción por convención de API Gateway (ver `Deploy en
/// producción.md`). El valor por defecto de [apiBaseUrl] YA incluye
/// ese prefijo para que la app hable con el backend real sin tener que
/// pasar `--dart-define` a mano en el caso común.
///
/// Se puede sobreescribir sin recompilar el código fuente usando
/// `--dart-define=API_BASE_URL=http://<host>:<puerto>[/prefijo]`, por
/// ejemplo:
/// - Emulador Android (el host de la máquina se ve como `10.0.2.2`):
///   `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/prod`
/// - Dispositivo físico en la misma red Wi-Fi que el backend:
///   `flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000/prod`
/// - Alguien sirviendo el backend sin el prefijo `/prod` (ej. un
///   `main_server.py` local corrido a mano fuera del stage): pasar
///   `--dart-define=API_BASE_URL=http://localhost:8000` (sin sufijo)
///   para pisar este default.
class Env {
  const Env._();

  /// URL base de `coffee-passport-backend`, incluyendo el prefijo de
  /// stage `/prod` bajo el cual sirve todas sus rutas (tanto en el
  /// contenedor local como en producción). Por defecto apunta a
  /// `localhost:8000/prod` (ver comentario de arriba para overrides en
  /// otros targets).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/prod',
  );
}
