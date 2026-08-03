import '../entities/passport_level.dart';
import '../entities/passport_overview.dart';

/// Contrato de dominio para la feature `passport`.
///
/// La implementación real (`PassportRepositoryImpl`, capa `data`) llama
/// `GET /passport` y `GET /levels` en `coffee-passport-backend` (ver
/// `API endpoints.md` del vault). `presentation` sólo conoce esta
/// interfaz.
abstract interface class PassportRepository {
  /// `GET /passport` — grilla de sellos bloqueados/desbloqueados por
  /// cafetería, más los contadores para la barra de progreso.
  Future<PassportOverview> getPassport();

  /// `GET /levels` — niveles de gamificación (para el pill "Nivel
  /// Catador" y la barra de progreso hacia el siguiente nivel).
  Future<List<PassportLevel>> getLevels();
}
