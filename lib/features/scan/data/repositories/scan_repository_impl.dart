import '../../../../core/network/api_client.dart';
import '../../domain/entities/scan_outcome.dart';
import '../../domain/repositories/scan_repository.dart';

/// Implementación real de [ScanRepository] contra `POST /scan` de
/// `coffee-passport-backend`.
///
/// ⚠️ Mismo aviso que `PassportRepositoryImpl`: `/scan` hoy sólo existe
/// documentado (`API endpoints.md` + `Deploy en producción.md` →
/// "QR + Geofencing" del vault), el backend real todavía no lo
/// implementa (sólo trae el scaffold `hello_world`). El mapeo de abajo
/// sigue el enum Postgres `scan_result` documentado en
/// `Base de datos.md` y el orden de validación descrito ahí
/// (auth → firma → geofence → rate-limit), incluyendo el `409` con
/// distancia para `out_of_range`. Ajustar junto con el Agente Backend
/// si el contrato final difiere.
class ScanRepositoryImpl implements ScanRepository {
  // Ver nota de PassportRepositoryImpl sobre por qué no se usa
  // `this._apiClient` como initializing formal aquí.
  ScanRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient; // ignore: prefer_initializing_formals

  final ApiClient _apiClient;

  @override
  Future<ScanOutcome> submitScan({
    required String qrPayload,
    required double latitude,
    required double longitude,
  }) async {
    final ApiResponse response;
    try {
      response = await _apiClient.post(
        '/scan',
        body: {'qr': qrPayload, 'lat': latitude, 'lng': longitude},
      );
    } on ApiException catch (e) {
      return ScanOutcome(type: ScanResultType.networkError, message: e.message);
    }

    final body = response.body;
    final json = body is Map ? body.cast<String, dynamic>() : <String, dynamic>{};

    final resultRaw =
        (json['result'] ?? json['scan_result'] ?? json['status']) as String?;
    final type = _typeFromResult(resultRaw, response.statusCode);

    final distanceRaw = json['distance_meters'] ?? json['distanceMeters'];
    final distance = distanceRaw is num ? distanceRaw.toDouble() : null;

    return ScanOutcome(
      type: type,
      shopName: (json['shop_name'] ?? json['shopName']) as String?,
      distanceMeters: distance,
      message: (json['message'] ?? json['detail']) as String?,
    );
  }

  ScanResultType _typeFromResult(String? result, int statusCode) {
    switch (result) {
      case 'success':
        return ScanResultType.success;
      case 'already_stamped':
        return ScanResultType.alreadyStamped;
      case 'out_of_range':
        return ScanResultType.outOfRange;
      case 'invalid_signature':
        return ScanResultType.invalidSignature;
      case 'rate_limited':
        return ScanResultType.rateLimited;
      case 'shop_not_found':
        return ScanResultType.shopNotFound;
    }
    // El backend no mandó un `result` reconocible en el body — cae de
    // vuelta al status code HTTP (ver `Deploy en producción.md`: 409
    // para fuera de rango es lo único con código explícito anotado).
    switch (statusCode) {
      case 200:
      case 201:
        return ScanResultType.success;
      case 404:
        return ScanResultType.shopNotFound;
      case 409:
        return ScanResultType.outOfRange;
      case 401:
      case 403:
        return ScanResultType.invalidSignature;
      case 429:
        return ScanResultType.rateLimited;
      default:
        return ScanResultType.unknownError;
    }
  }
}
