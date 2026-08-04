import '../../../../core/brew/brew_method.dart';
import '../entities/diary_entry.dart';

/// Contrato de dominio para el Diario de cata (`diary_entries`).
///
/// Ver `API endpoints.md` del vault: `GET /diary` / `POST /diary` /
/// `PATCH /diary/{id}` / `DELETE /diary/{id}` — CRUD autenticado
/// simple, sin geofencing ni firma (a diferencia de `POST /scan`).
abstract interface class DiaryRepository {
  /// Todas las entradas del usuario, más recientes primero (ver
  /// `DiaryRepositoryImpl` para el criterio de orden — el backend no
  /// garantiza orden en el contrato documentado).
  Future<List<DiaryEntry>> getEntries();

  /// Crea una entrada nueva. `visitedAt` es opcional — si se omite, el
  /// backend decide el valor por defecto (probablemente "ahora").
  Future<DiaryEntry> createEntry({
    required String shopId,
    required BrewMethod brewMethod,
    required int rating,
    String? note,
    DateTime? visitedAt,
  });

  /// Edita una entrada propia existente (`PATCH /diary/{id}`).
  Future<DiaryEntry> updateEntry({
    required String id,
    required String shopId,
    required BrewMethod brewMethod,
    required int rating,
    String? note,
    DateTime? visitedAt,
  });

  /// Borra (soft-delete del lado del backend) una entrada propia.
  Future<void> deleteEntry(String id);
}
