import 'package:shared_preferences/shared_preferences.dart';

/// ⚠️ TEMPORAL / SOLO DESARROLLO ⚠️
///
/// `coffee-passport-backend` todavía no tiene un gateway de auth real
/// delante (Cognito + servicio que resuelva el JWT y reenvíe la
/// identidad por headers — ver `Deploy en producción.md` en el vault,
/// sección "Auth"). Mientras eso no exista, el backend confía en que
/// quien le pega ya le manda la identidad resuelta vía headers HTTP:
/// - `X-Auth-User-Sub` (obligatorio en toda ruta autenticada).
/// - `X-Auth-User-Email` / `X-Auth-User-Groups` (opcionales).
///
/// Esta clase es el reemplazo de bolsillo de ese gateway del lado del
/// cliente: el usuario escribe una sola vez un `sub` de prueba en texto
/// libre (ej. `dev-user-local`), se guarda en `shared_preferences`, y
/// [ApiClient] (ver `lib/core/network/api_client.dart`) lo manda como
/// `X-Auth-User-Sub` en cada request.
///
/// **A reemplazar por completo cuando exista login real (Cognito +
/// gateway)** — en ese momento esta clase y la pantalla de dev-login
/// (`dev_login_screen.dart`) deben borrarse, no extenderse.
class DevAuthLocalDatasource {
  DevAuthLocalDatasource({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const String _devSubKey = 'dev_auth_user_sub';

  final SharedPreferencesAsync _preferences;

  /// Regresa el `sub` de prueba guardado, o `null` si el usuario todavía
  /// no completó el "dev login" una sola vez.
  Future<String?> getDevSub() async {
    final value = await _preferences.getString(_devSubKey);
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  /// Guarda el `sub` de prueba en texto libre elegido por el usuario.
  Future<void> saveDevSub(String sub) async {
    final trimmed = sub.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('El sub de dev-login no puede estar vacío.');
    }
    await _preferences.setString(_devSubKey, trimmed);
  }

  /// Borra el `sub` guardado (permite volver a mostrar el dev-login).
  Future<void> clearDevSub() async {
    await _preferences.remove(_devSubKey);
  }
}
