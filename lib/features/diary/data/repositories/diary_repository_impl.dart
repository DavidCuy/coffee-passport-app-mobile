import '../../../../core/network/api_client.dart';
import '../../domain/entities/brew_method.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/repositories/diary_repository.dart';

/// Implementación real de [DiaryRepository] contra `GET/POST /diary` y
/// `PATCH/DELETE /diary/{id}` de `coffee-passport-backend`.
///
/// **Construida en paralelo al backend/DB** (2026-08-03): al momento de
/// escribir esta clase, `/diary` y la tabla `diary_entries` todavía se
/// estaban implementando del lado de Backend/DB (mismo patrón que ya se
/// usó para Mapa/Directorio el 2026-08-02, ver `Fase 1 -
/// Funcionalidades.md`). El parseo es defensivo por eso — acepta
/// snake_case y camelCase, y el wrapper `{"data": [...]}` que ya
/// confirmó ser el patrón real de `core_http.BaseController` para
/// `/shops`/`/levels`/`/shops/{id}/reviews` — hasta que el Agente
/// Backend confirme el shape exacto de `/diary` (igual que se hizo con
/// `ShopRepositoryImpl`/`ShopReviewRepositoryImpl`). Revisar y
/// reconciliar este archivo cuando esté ese aviso.
class DiaryRepositoryImpl implements DiaryRepository {
  // Ver nota de `PassportRepositoryImpl`/`ShopRepositoryImpl` sobre por
  // qué no se usa `this._apiClient` como initializing formal aquí.
  DiaryRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient; // ignore: prefer_initializing_formals

  final ApiClient _apiClient;

  @override
  Future<List<DiaryEntry>> getEntries() async {
    final raw = await _apiClient.get('/diary');
    final List<dynamic> entriesJson;
    if (raw is List) {
      entriesJson = raw;
    } else if (raw is Map && raw['data'] is List) {
      // Mismo wrapper genérico que `GET /shops`/`GET /levels`/
      // `GET /shops/{id}/reviews` — ver `ShopRepositoryImpl`.
      entriesJson = raw['data'] as List<dynamic>;
    } else if (raw is Map && raw['entries'] is List) {
      entriesJson = raw['entries'] as List<dynamic>;
    } else {
      throw ApiException('Respuesta inesperada de GET /diary: $raw');
    }
    final entries = entriesJson
        .cast<Map<String, dynamic>>()
        .map(_entryFromJson)
        .toList();
    // El contrato documentado no garantiza orden — se ordena acá,
    // "más recientes primero" (Fase 1, sección 4), usando la fecha de
    // visita cuando está disponible y cayendo a la de creación si no.
    entries.sort((a, b) => _sortKey(b).compareTo(_sortKey(a)));
    return entries;
  }

  DateTime _sortKey(DiaryEntry entry) =>
      entry.visitedAt ?? entry.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<DiaryEntry> createEntry({
    required String shopId,
    required BrewMethod brewMethod,
    required int rating,
    String? note,
    DateTime? visitedAt,
  }) async {
    final response = await _apiClient.post(
      '/diary',
      body: _bodyFor(
        shopId: shopId,
        brewMethod: brewMethod,
        rating: rating,
        note: note,
        visitedAt: visitedAt,
        isUpdate: false,
      ),
    );
    if (!response.isSuccessStatus) {
      throw ApiException(
        'No se pudo guardar tu entrada del diario.',
        statusCode: response.statusCode,
      );
    }
    return _entryFromResponseOrFallback(
      response.body,
      shopId: shopId,
      brewMethod: brewMethod,
      rating: rating,
      note: note,
      visitedAt: visitedAt,
    );
  }

  @override
  Future<DiaryEntry> updateEntry({
    required String id,
    required String shopId,
    required BrewMethod brewMethod,
    required int rating,
    String? note,
    DateTime? visitedAt,
  }) async {
    final response = await _apiClient.patch(
      '/diary/$id',
      body: _bodyFor(
        shopId: shopId,
        brewMethod: brewMethod,
        rating: rating,
        note: note,
        visitedAt: visitedAt,
        isUpdate: true,
      ),
    );
    if (!response.isSuccessStatus) {
      throw ApiException(
        'No se pudo actualizar tu entrada del diario.',
        statusCode: response.statusCode,
      );
    }
    return _entryFromResponseOrFallback(
      response.body,
      id: id,
      shopId: shopId,
      brewMethod: brewMethod,
      rating: rating,
      note: note,
      visitedAt: visitedAt,
    );
  }

  @override
  Future<void> deleteEntry(String id) async {
    final response = await _apiClient.delete('/diary/$id');
    if (!response.isSuccessStatus) {
      throw ApiException(
        'No se pudo borrar tu entrada del diario.',
        statusCode: response.statusCode,
      );
    }
  }

  /// Body de `POST`/`PATCH /diary` — nombres de campo tal cual los
  /// documenta `API endpoints.md`: `id_shop`, `brew_method`, `rating`,
  /// `note`, `visited_at`. `id_shop` se manda como entero cuando
  /// [shopId] parsea a uno (probable PK serial de Postgres, mismo
  /// criterio que el resto de las tablas del backend); si no parsea
  /// (ej. un slug), se manda tal cual como respaldo defensivo.
  ///
  /// [isUpdate] distingue `PATCH` (edición) de `POST` (creación) para
  /// decidir qué hacer con `note` cuando el campo del formulario llega
  /// vacío (`null`, ya normalizado por
  /// `DiaryEntryFormScreen._submit()`):
  /// - `update_diary_entry/function.py` solo toca `note` si la key
  ///   está presente en el body (`"note" in body_in`) — omitirla y
  ///   mandar `null` explícito son comportamientos distintos del lado
  ///   del backend. Si el usuario vació una nota que ya existía, hay
  ///   que mandar `'note': null` a propósito para que se borre; si no,
  ///   la nota vieja sobrevive para siempre (bug DIARY-08).
  /// - `create_diary_entry/function.py` en cambio siempre lee
  ///   `body_in.get("note")` (default `None` si la key no está), así
  ///   que crear con la key omitida o con `'note': null` es
  ///   equivalente — se mantiene el comportamiento previo de omitirla
  ///   para no mandar payload de más.
  Map<String, dynamic> _bodyFor({
    required String shopId,
    required BrewMethod brewMethod,
    required int rating,
    String? note,
    DateTime? visitedAt,
    required bool isUpdate,
  }) {
    final trimmedNote = note?.trim();
    return {
      'id_shop': int.tryParse(shopId) ?? shopId,
      'brew_method': brewMethod.apiValue,
      'rating': rating,
      if (trimmedNote != null && trimmedNote.isNotEmpty)
        'note': trimmedNote
      else if (isUpdate)
        'note': null,
      // ignore: use_null_aware_elements
      if (visitedAt != null) 'visited_at': visitedAt.toIso8601String(),
    };
  }

  /// El body de respuesta de `POST`/`PATCH` puede venir vacío o sin
  /// `id` (contrato exacto todavía sin confirmar contra código real,
  /// igual que `ShopReviewRepositoryImpl._reviewFromResponseOrFallback`)
  /// — en ese caso se arma una [DiaryEntry] "optimista" con lo que el
  /// usuario acaba de enviar, usando [id] si ya se conocía (caso
  /// update) o un id local temporal (caso create, hasta el próximo
  /// `getEntries()`).
  DiaryEntry _entryFromResponseOrFallback(
    dynamic body, {
    String? id,
    required String shopId,
    required BrewMethod brewMethod,
    required int rating,
    String? note,
    DateTime? visitedAt,
  }) {
    if (body is Map) {
      final json = body.cast<String, dynamic>();
      final nested = json['entry'] ?? json['diary_entry'];
      final entryJson = nested is Map ? nested.cast<String, dynamic>() : json;
      if (entryJson['id'] != null) {
        return _entryFromJson(entryJson);
      }
    }
    return DiaryEntry(
      id: id ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
      shopId: shopId,
      brewMethod: brewMethod,
      rating: rating,
      note: note,
      visitedAt: visitedAt,
    );
  }

  /// Parseo defensivo de un item de `GET /diary` (o del body de
  /// `POST`/`PATCH` cuando trae la entrada completa) — snake_case y
  /// camelCase, más `shop` anidado si el backend lo resuelve así (mismo
  /// patrón que `Stamp` en `PassportRepositoryImpl`, ya que "resolver
  /// `id_shop` contra el nombre real" es el mismo problema en ambas
  /// features).
  DiaryEntry _entryFromJson(Map<String, dynamic> json) {
    final shopJson = json['shop'];
    final shopMap = shopJson is Map ? shopJson.cast<String, dynamic>() : null;
    final shopId =
        shopMap?['id'] ??
        json['id_shop'] ??
        json['shop_id'] ??
        json['shopId'];
    final shopName =
        shopMap?['name'] ?? json['shop_name'] ?? json['shopName'];
    final brewMethodRaw =
        (json['brew_method'] ?? json['brewMethod'])?.toString();
    return DiaryEntry(
      id: json['id'].toString(),
      shopId: shopId.toString(),
      shopName: shopName?.toString(),
      brewMethod: BrewMethod.fromApiValue(brewMethodRaw),
      rating: _asInt(json['rating']) ?? 0,
      note: json['note'] as String?,
      visitedAt: _asDate(json['visited_at'] ?? json['visitedAt']),
      createdAt: _asDate(json['created_at'] ?? json['createdAt']),
      updatedAt: _asDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
