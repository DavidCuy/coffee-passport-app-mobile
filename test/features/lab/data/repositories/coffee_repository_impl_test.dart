// Fija el contrato defensivo de `CoffeeRepositoryImpl` mientras el
// Agente Backend/DB terminan `/coffees`/`coffees`/`coffee_flavor_notes`
// en paralelo a esta tarea (ver docstring de la clase). Cubre: el
// wrapper genérico `{"data": [...]}` (mismo patrón ya confirmado para
// `/shops`/`/levels`/`/diary`), la lista plana de respaldo, el parseo
// snake_case/camelCase de las columnas de `coffees`, y las 2 formas
// aceptadas de `coffee_flavor_notes` (lista de objetos con
// `note_label`, o lista plana de strings).

import 'dart:convert';

import 'package:coffee_passport_app/core/auth/dev_auth_local_datasource.dart';
import 'package:coffee_passport_app/core/network/api_client.dart';
import 'package:coffee_passport_app/features/lab/data/repositories/coffee_repository_impl.dart';
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

  CoffeeRepositoryImpl buildRepository(http.Client mockClient) {
    return CoffeeRepositoryImpl(
      apiClient: ApiClient(
        httpClient: mockClient,
        authDatasource: DevAuthLocalDatasource(),
      ),
    );
  }

  test(
    'getCoffees desenvuelve {"data": [...]} y parsea las columnas '
    'snake_case reales de `coffees`',
    () async {
      final fixtureBody = jsonEncode({
        'data': [
          {
            'id': 1,
            'name': 'Finca Argovia',
            'roaster_name': 'Raíz Tostadores',
            'origin_locality': 'Tapachula, Chiapas',
            'altitude_masl': 1200,
            'process': 'Lavado',
            'variety': 'Bourbon, Typica',
            'producer': 'Coop. Sierra Madre',
            'sca_score': 87,
            'body_score': 4,
            'acidity_score': 3,
            'sweetness_score': 4,
            'aftertaste_score': 3,
            'story_text': 'Cosecha de altura...',
            'is_featured': true,
          },
        ],
      });
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/coffees'));
        return http.Response(fixtureBody, 200);
      });

      final coffees = await buildRepository(mockClient).getCoffees();

      expect(coffees, hasLength(1));
      final coffee = coffees.single;
      expect(coffee.id, '1');
      expect(coffee.name, 'Finca Argovia');
      expect(coffee.roasterName, 'Raíz Tostadores');
      expect(coffee.originLocality, 'Tapachula, Chiapas');
      expect(coffee.altitudeMasl, 1200);
      expect(coffee.process, 'Lavado');
      expect(coffee.variety, 'Bourbon, Typica');
      expect(coffee.producer, 'Coop. Sierra Madre');
      expect(coffee.scaScore, 87);
      expect(coffee.bodyScore, 4);
      expect(coffee.acidityScore, 3);
      expect(coffee.sweetnessScore, 4);
      expect(coffee.aftertasteScore, 3);
      expect(coffee.isFeatured, isTrue);
      expect(coffee.flavorNotes, isEmpty);
    },
  );

  test('getCoffees acepta una lista plana (sin wrapper)', () async {
    final fixtureBody = jsonEncode([
      {'id': 2, 'name': 'Café Sol'},
    ]);
    final mockClient = MockClient(
      (request) async => http.Response(fixtureBody, 200),
    );

    final coffees = await buildRepository(mockClient).getCoffees();

    expect(coffees.single.id, '2');
    expect(coffees.single.name, 'Café Sol');
  });

  test('getFeaturedCoffees hace GET /coffees/featured', () async {
    String? capturedPath;
    final mockClient = MockClient((request) async {
      capturedPath = request.url.path;
      return http.Response(jsonEncode({'data': []}), 200);
    });

    await buildRepository(mockClient).getFeaturedCoffees();

    expect(capturedPath, contains('/coffees/featured'));
  });

  test(
    'getCoffeeById parsea coffee_flavor_notes como lista de objetos '
    'con note_label, ordenados por sort_order',
    () async {
      final fixtureBody = jsonEncode({
        'id': 1,
        'name': 'Finca Argovia',
        'coffee_flavor_notes': [
          {'note_label': 'Panela', 'sort_order': 2},
          {'note_label': 'Chocolate', 'sort_order': 1},
        ],
      });
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/coffees/1'));
        return http.Response(fixtureBody, 200);
      });

      final coffee = await buildRepository(mockClient).getCoffeeById('1');

      expect(coffee.flavorNotes, ['Chocolate', 'Panela']);
    },
  );

  test(
    'getCoffeeById acepta coffee_flavor_notes como lista plana de '
    'strings (respaldo defensivo)',
    () async {
      final fixtureBody = jsonEncode({
        'id': 1,
        'name': 'Finca Argovia',
        'coffee_flavor_notes': ['Chocolate', 'Cítrico'],
      });
      final mockClient = MockClient(
        (request) async => http.Response(fixtureBody, 200),
      );

      final coffee = await buildRepository(mockClient).getCoffeeById('1');

      expect(coffee.flavorNotes, ['Chocolate', 'Cítrico']);
    },
  );

  test('getCoffeeById lanza ApiException si el backend responde error', () async {
    final mockClient = MockClient(
      (request) async => http.Response('{"message":"not found"}', 404),
    );

    expect(
      () => buildRepository(mockClient).getCoffeeById('99'),
      throwsA(isA<ApiException>()),
    );
  });
}
