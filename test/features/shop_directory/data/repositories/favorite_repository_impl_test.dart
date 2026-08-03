// Fija el contrato defensivo de `FavoriteRepositoryImpl` mientras el
// Agente Backend termina `POST/DELETE /shops/{id}/favorite` y
// `GET /favorites` en paralelo a esta tarea (ver docstring de la
// clase). Cubre los 2 shapes razonables de `GET /favorites`
// documentados ahí: favoritos ya resueltos con `shop` anidado, y el
// wrapper genérico `{"data": [...]}` de `core_http.BaseController`
// (mismo patrón ya confirmado para `/shops`/`/levels`).

import 'dart:convert';

import 'package:coffee_passport_app/core/auth/dev_auth_local_datasource.dart';
import 'package:coffee_passport_app/core/network/api_client.dart';
import 'package:coffee_passport_app/features/shop_directory/data/repositories/favorite_repository_impl.dart';
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

  FavoriteRepositoryImpl buildRepository(http.Client mockClient) {
    return FavoriteRepositoryImpl(
      apiClient: ApiClient(
        httpClient: mockClient,
        authDatasource: DevAuthLocalDatasource(),
      ),
    );
  }

  test(
    'getFavoriteShops desenvuelve el wrapper {"data": [...]} y arma Shop '
    'con isFavorite=true desde el objeto shop anidado',
    () async {
      final fixtureBody = jsonEncode({
        'data': [
          {
            'id_user': 3,
            'id_shop': 1,
            'shop': {
              'id': 1,
              'name': 'Cafe Luna',
              'address': 'Calle 1',
              'lat': 4.65,
              'lng': -74.05,
            },
          },
        ],
      });
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/favorites'));
        return http.Response(fixtureBody, 200);
      });

      final shops = await buildRepository(mockClient).getFavoriteShops();

      expect(shops, hasLength(1));
      expect(shops.single.id, '1');
      expect(shops.single.name, 'Cafe Luna');
      expect(shops.single.isFavorite, isTrue);
    },
  );

  test('getFavoriteShopIds regresa sólo los ids como Set', () async {
    final fixtureBody = jsonEncode({
      'data': [
        {
          'shop': {'id': 1, 'name': 'Cafe Luna'},
        },
        {
          'shop': {'id': 2, 'name': 'Cafe Sol'},
        },
      ],
    });
    final mockClient = MockClient(
      (request) async => http.Response(fixtureBody, 200),
    );

    final ids = await buildRepository(mockClient).getFavoriteShopIds();

    expect(ids, {'1', '2'});
  });

  test('addFavorite hace POST /shops/{id}/favorite', () async {
    String? capturedMethod;
    String? capturedPath;
    final mockClient = MockClient((request) async {
      capturedMethod = request.method;
      capturedPath = request.url.path;
      return http.Response('', 201);
    });

    await buildRepository(mockClient).addFavorite('7');

    expect(capturedMethod, 'POST');
    expect(capturedPath, contains('/shops/7/favorite'));
  });

  test('removeFavorite hace DELETE /shops/{id}/favorite', () async {
    String? capturedMethod;
    String? capturedPath;
    final mockClient = MockClient((request) async {
      capturedMethod = request.method;
      capturedPath = request.url.path;
      return http.Response('', 204);
    });

    await buildRepository(mockClient).removeFavorite('7');

    expect(capturedMethod, 'DELETE');
    expect(capturedPath, contains('/shops/7/favorite'));
  });

  test('removeFavorite lanza ApiException si el backend responde error', () async {
    final mockClient = MockClient(
      (request) async => http.Response('{"message":"nope"}', 404),
    );

    expect(
      () => buildRepository(mockClient).removeFavorite('7'),
      throwsA(isA<ApiException>()),
    );
  });
}
