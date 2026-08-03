/// Resultado posible de `POST /scan`, calcado 1:1 del enum Postgres
/// `scan_result` documentado en `Base de datos.md` del vault
/// (`success | already_stamped | out_of_range | invalid_signature |
/// rate_limited | shop_not_found`), más dos casos propios del cliente
/// para errores de transporte/parseo que no vienen del backend.
enum ScanResultType {
  /// Sello nuevo desbloqueado con éxito.
  success,

  /// Ya tenías el sello de esta cafetería — el backend responde éxito
  /// idempotente, no error (ver `Deploy en producción.md`, sección
  /// "QR + Geofencing").
  alreadyStamped,

  /// Estás fuera del radio de geofence configurado para la cafetería.
  outOfRange,

  /// La firma HMAC del QR no es válida (payload alterado o corrupto).
  invalidSignature,

  /// Límite de intentos de escaneo alcanzado.
  rateLimited,

  /// El `qr_slug` del payload no corresponde a ninguna cafetería activa.
  shopNotFound,

  /// El backend respondió pero con un status/cuerpo que no reconocemos.
  unknownError,

  /// No se pudo completar la solicitud (sin conexión, timeout, etc.).
  networkError,
}

/// Resultado de dominio de un intento de escaneo — lo que
/// [ScanRepository.submitScan] regresa a la capa `presentation`.
class ScanOutcome {
  const ScanOutcome({
    required this.type,
    this.shopName,
    this.distanceMeters,
    this.message,
  });

  final ScanResultType type;

  /// Nombre de la cafetería, cuando el backend lo incluye.
  final String? shopName;

  /// Distancia (en metros) al geofence, presente típicamente cuando
  /// [type] es [ScanResultType.outOfRange].
  final double? distanceMeters;

  /// Mensaje adicional del backend (si lo manda) o del cliente (en
  /// errores de red/parseo).
  final String? message;
}
