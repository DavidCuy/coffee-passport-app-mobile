import '../entities/scan_outcome.dart';

/// Contrato de dominio para la feature `scan`.
///
/// La implementación real llama `POST /scan` con el string del QR y la
/// posición GPS capturada al momento del envío (ver `API endpoints.md`
/// y `Deploy en producción.md` → "QR + Geofencing" en el vault).
abstract interface class ScanRepository {
  Future<ScanOutcome> submitScan({
    required String qrPayload,
    required double latitude,
    required double longitude,
  });
}
