// Fija el contrato defensivo de `DiaryRepositoryImpl` mientras el
// Agente Backend/DB terminan `/diary`/`diary_entries` en paralelo a
// esta tarea (ver docstring de la clase). Cubre: el wrapper genérico
// `{"data": [...]}` (mismo patrón ya confirmado para
// `/shops`/`/levels`/`/shops/{id}/reviews`), el orden "más recientes
// primero" calculado del lado del cliente, el parseo defensivo
// snake_case/camelCase (incluido `shop` anidado para resolver el
// nombre de la cafetería), el enum fijo `BrewMethod` y el body exacto
// (`id_shop`/`brew_method`/`rating`/`note`/`visited_at`) de
// `POST`/`PATCH /diary`.

import 'dart:convert';

import 'package:coffee_passport_app/core/auth/dev_auth_local_datasource.dart';
import 'package:coffee_passport_app/core/network/api_client.dart';
import 'package:coffee_passport_app/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:coffee_passport_app/core/brew/brew_method.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  DiaryRepositoryImpl buildRepository(http.Client mockClient) {
    return DiaryRepositoryImpl(
      apiClient: ApiClient(
        httpClient: mockClient,
        authDatasource: DevAuthLocalDatasource(),
      ),
    );
  }

  test(
    'getEntries desenvuelve {"data": [...]}, parsea brew_method/shop '
    'anidado y ordena más recientes primero por visited_at',
    () async {
      final fixtureBody = jsonEncode({
        'data': [
          {
            'id': 1,
            'id_shop': 3,
            'shop': {'id': 3, 'name': 'Cafe Luna'},
            'brew_method': 'v60',
            'rating': 4,
            'note': 'Notas cítricas',
            'visited_at': '2026-08-01T10:00:00+00:00',
            'created_at': '2026-08-01T10:00:00+00:00',
          },
          {
            'id': 2,
            'id_shop': 5,
            'shop': {'id': 5, 'name': 'Cafe Sol'},
            'brew_method': 'prensa_francesa',
            'rating': 5,
            'note': null,
            'visited_at': '2026-08-02T09:00:00+00:00',
            'created_at': '2026-08-02T09:00:00+00:00',
          },
        ],
      });
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/diary'));
        return http.Response(fixtureBody, 200);
      });

      final entries = await buildRepository(mockClient).getEntries();

      expect(entries, hasLength(2));
      // Más reciente primero: entrada 2 (2026-08-02) antes que la 1
      // (2026-08-01), a pesar de venir en el orden contrario del JSON.
      expect(entries[0].id, '2');
      expect(entries[0].shopId, '5');
      expect(entries[0].shopName, 'Cafe Sol');
      expect(entries[0].brewMethod, BrewMethod.prensaFrancesa);
      expect(entries[0].rating, 5);
      expect(entries[1].id, '1');
      expect(entries[1].brewMethod, BrewMethod.v60);
      expect(entries[1].note, 'Notas cítricas');
    },
  );

  test(
    'getEntries acepta una lista plana (sin wrapper) como respaldo '
    'defensivo',
    () async {
      final fixtureBody = jsonEncode([
        {
          'id': 1,
          'id_shop': 3,
          'brew_method': 'espresso',
          'rating': 3,
        },
      ]);
      final mockClient = MockClient(
        (request) async => http.Response(fixtureBody, 200),
      );

      final entries = await buildRepository(mockClient).getEntries();

      expect(entries.single.brewMethod, BrewMethod.espresso);
    },
  );

  test(
    'getEntries deja brewMethod en null si el valor del backend no '
    'matchea ninguno de los 5 métodos fijos',
    () async {
      final fixtureBody = jsonEncode({
        'data': [
          {'id': 1, 'id_shop': 3, 'brew_method': 'moka', 'rating': 3},
        ],
      });
      final mockClient = MockClient(
        (request) async => http.Response(fixtureBody, 200),
      );

      final entries = await buildRepository(mockClient).getEntries();

      expect(entries.single.brewMethod, isNull);
    },
  );

  test(
    'createEntry manda POST /diary con id_shop/brew_method/rating/note/'
    'visited_at',
    () async {
      String? capturedMethod;
      String? capturedPath;
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedMethod = request.method;
        capturedPath = request.url.path;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('', 201);
      });

      final visitedAt = DateTime(2026, 8, 1);
      final entry = await buildRepository(mockClient).createEntry(
        shopId: '3',
        brewMethod: BrewMethod.chemex,
        rating: 4,
        note: 'Muy bueno',
        visitedAt: visitedAt,
      );

      expect(capturedMethod, 'POST');
      expect(capturedPath, contains('/diary'));
      expect(capturedBody, {
        'id_shop': 3,
        'brew_method': 'chemex',
        'rating': 4,
        'note': 'Muy bueno',
        'visited_at': visitedAt.toIso8601String(),
      });
      expect(entry.rating, 4);
      expect(entry.brewMethod, BrewMethod.chemex);
    },
  );

  test(
    'createEntry usa la entrada completa del body de respuesta cuando '
    'el backend la devuelve',
    () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 42,
            'id_shop': 3,
            'brew_method': 'aeropress',
            'rating': 5,
          }),
          201,
        );
      });

      final entry = await buildRepository(mockClient).createEntry(
        shopId: '3',
        brewMethod: BrewMethod.aeropress,
        rating: 5,
      );

      expect(entry.id, '42');
      expect(entry.brewMethod, BrewMethod.aeropress);
    },
  );

  test('createEntry lanza ApiException si el backend responde error', () async {
    final mockClient = MockClient(
      (request) async => http.Response('{"message":"nope"}', 422),
    );

    expect(
      () => buildRepository(mockClient).createEntry(
        shopId: '3',
        brewMethod: BrewMethod.v60,
        rating: 4,
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('updateEntry hace PATCH /diary/{id}', () async {
    String? capturedMethod;
    String? capturedPath;
    final mockClient = MockClient((request) async {
      capturedMethod = request.method;
      capturedPath = request.url.path;
      return http.Response('', 200);
    });

    await buildRepository(mockClient).updateEntry(
      id: '9',
      shopId: '3',
      brewMethod: BrewMethod.espresso,
      rating: 2,
    );

    expect(capturedMethod, 'PATCH');
    expect(capturedPath, contains('/diary/9'));
  });

  test(
    // Regresión DIARY-08: al vaciar la nota en el formulario de edición,
    // el body de PATCH tiene que mandar `'note': null` explícito -- no
    // omitir la key -- porque `update_diary_entry/function.py` solo
    // toca `note` cuando `"note" in body_in`. Omitirla deja la nota
    // vieja para siempre.
    'updateEntry manda "note": null explícito cuando el usuario vació '
    'la nota (para poder borrarla, no solo omitirla)',
    () async {
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('', 200);
      });

      await buildRepository(mockClient).updateEntry(
        id: '9',
        shopId: '3',
        brewMethod: BrewMethod.espresso,
        rating: 2,
        note: null,
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!.containsKey('note'), isTrue);
      expect(capturedBody!['note'], isNull);
    },
  );

  test(
    'createEntry omite la key "note" (no manda null) cuando no hay '
    'nota -- create_diary_entry/function.py trata la key ausente igual '
    'que null, así que no hace falta el payload de más',
    () async {
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('', 201);
      });

      await buildRepository(mockClient).createEntry(
        shopId: '3',
        brewMethod: BrewMethod.espresso,
        rating: 2,
      );

      expect(capturedBody, isNotNull);
      expect(capturedBody!.containsKey('note'), isFalse);
    },
  );

  test('deleteEntry hace DELETE /diary/{id}', () async {
    String? capturedMethod;
    String? capturedPath;
    final mockClient = MockClient((request) async {
      capturedMethod = request.method;
      capturedPath = request.url.path;
      return http.Response('', 204);
    });

    await buildRepository(mockClient).deleteEntry('9');

    expect(capturedMethod, 'DELETE');
    expect(capturedPath, contains('/diary/9'));
  });

  test('deleteEntry lanza ApiException si el backend responde error', () async {
    final mockClient = MockClient(
      (request) async => http.Response('{"message":"nope"}', 404),
    );

    expect(
      () => buildRepository(mockClient).deleteEntry('9'),
      throwsA(isA<ApiException>()),
    );
  });
}
