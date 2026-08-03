import '../../../../core/network/api_client.dart';
import '../../domain/entities/passport_level.dart';
import '../../domain/entities/passport_overview.dart';
import '../../domain/entities/stamp.dart';
import '../../domain/repositories/passport_repository.dart';

/// Implementación real de [PassportRepository] contra
/// `coffee-passport-backend`.
///
/// Shape real confirmado 2026-07-30 contra
/// `coffee-passport-backend/src/functions/get_passport/function.py` (y su
/// `test_function.py`) tras el bug #6 reportado por QA Mobile:
/// `GET /passport` sólo devuelve, en `stamps`, los sellos que el usuario
/// YA tiene (join `passport_stamps` + `shops` filtrado por `id_user`) —
/// no hay placeholders de cafeterías "bloqueadas" en ese array ni ningún
/// booleano `unlocked`/`is_unlocked`. La sola presencia de un elemento en
/// `stamps` YA significa desbloqueado. El nombre de la cafetería viaja
/// anidado en `shop.name` (relationship `shop` serializada completa), no
/// en un campo plano `shop_name`/`shopName`. El parseo de abajo sigue
/// siendo defensivo con variantes snake_case/camelCase donde el backend
/// no impone una forma única (ids, fechas), pero ya no asume un booleano
/// de "desbloqueado" que el backend nunca manda.
class PassportRepositoryImpl implements PassportRepository {
  // Nota: no se usa `this._apiClient` como initializing formal a
  // propósito — sería un parámetro nombrado required cuyo nombre
  // público quedaría `_apiClient` (privado), inutilizable desde los
  // callers de otra librería (ej. `main.dart`).
  PassportRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient; // ignore: prefer_initializing_formals

  final ApiClient _apiClient;

  @override
  Future<PassportOverview> getPassport() async {
    final raw = await _apiClient.get('/passport');
    if (raw is! Map) {
      throw ApiException('Respuesta inesperada de GET /passport: $raw');
    }
    final json = raw.cast<String, dynamic>();
    final stampsJson =
        (json['stamps'] ?? json['sellos'] ?? const []) as List<dynamic>;
    final stamps = stampsJson
        .cast<Map<String, dynamic>>()
        .map(_stampFromJson)
        .toList(growable: false);
    final unlockedCount =
        (json['unlocked_count'] ?? json['unlockedCount']) as int? ??
        stamps.where((s) => s.isUnlocked).length;
    final totalShops =
        (json['total_shops'] ?? json['totalShops']) as int? ?? stamps.length;
    return PassportOverview(
      stamps: stamps,
      unlockedCount: unlockedCount,
      totalShops: totalShops,
    );
  }

  @override
  Future<List<PassportLevel>> getLevels() async {
    final raw = await _apiClient.get('/levels');
    final List<dynamic> levelsJson;
    if (raw is List) {
      levelsJson = raw;
    } else if (raw is Map && raw['data'] is List) {
      // `GET /levels` real (core_http.BaseController genérico del
      // backend) envuelve toda lista en `{"data": [...]}` — ver
      // `list_levels/function.py`.
      levelsJson = raw['data'] as List<dynamic>;
    } else if (raw is Map && raw['levels'] is List) {
      levelsJson = raw['levels'] as List<dynamic>;
    } else {
      throw ApiException('Respuesta inesperada de GET /levels: $raw');
    }
    return levelsJson
        .cast<Map<String, dynamic>>()
        .map(_levelFromJson)
        .toList(growable: false);
  }

  Stamp _stampFromJson(Map<String, dynamic> json) {
    final unlockedAtRaw =
        (json['unlocked_at'] ?? json['unlockedAt']) as String?;
    // `shop` viaja como objeto anidado (relationship completa del
    // backend), no como campo plano `shop_name`/`shopId` — ver nota de
    // shape real arriba de esta clase.
    final shopJson = json['shop'];
    final shopMap = shopJson is Map ? shopJson.cast<String, dynamic>() : null;
    final shopId =
        shopMap?['id'] ??
        json['shop_id'] ??
        json['shopId'] ??
        json['id_shop'];
    final shopName =
        (shopMap?['name'] ?? json['shop_name'] ?? json['shopName'] ?? '')
            .toString();
    return Stamp(
      shopId: shopId.toString(),
      shopName: shopName,
      // GET /passport sólo incluye en `stamps` los sellos que el usuario
      // YA tiene; no existe un booleano "desbloqueado" en el contrato
      // real ni sellos "bloqueados" en el array — la presencia del
      // elemento ya es la señal. Ver bug #6 (QA Mobile, 2026-07-30).
      isUnlocked: true,
      unlockedAt: unlockedAtRaw == null
          ? null
          : DateTime.tryParse(unlockedAtRaw),
    );
  }

  PassportLevel _levelFromJson(Map<String, dynamic> json) {
    final order = (json['level_order'] ?? json['levelOrder'] ?? json['order'])
        as int;
    final name = (json['level_name'] ?? json['levelName'] ?? json['name'])
        .toString();
    final minStamps = (json['min_stamps'] ?? json['minStamps'] ?? 0) as int;
    final badgeIconUrl =
        (json['badge_icon_url'] ?? json['badgeIconUrl']) as String?;
    final isCurrent =
        (json['is_current'] ?? json['isCurrent'] ?? json['current']) == true;
    return PassportLevel(
      order: order,
      name: name,
      minStamps: minStamps,
      badgeIconUrl: badgeIconUrl,
      isCurrent: isCurrent,
    );
  }
}
