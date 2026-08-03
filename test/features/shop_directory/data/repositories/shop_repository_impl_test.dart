// Cubre el parseo agregado a `ShopRepositoryImpl._shopFromJson` en la
// tarea "Mapa & Directorio — favoritos y reseñas" (2026-08-02): los
// campos reales de `core_db/models/shop.py` (`description`,
// `hours_json`, `active_perk_text`, `website_url`, etc.) y el rating
// agregado (`rating_average`/`review_count`), confirmados contra la
// Supabase real por el Agente Backend ese mismo día (ver
// `API endpoints.md` — nombres exactos, sin heurísticas).

import 'dart:convert';

import 'package:coffee_passport_app/core/auth/dev_auth_local_datasource.dart';
import 'package:coffee_passport_app/core/network/api_client.dart';
import 'package:coffee_passport_app/features/shop_directory/data/repositories/shop_repository_impl.dart';
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

  ShopRepositoryImpl buildRepository(http.Client mockClient) {
    return ShopRepositoryImpl(
      apiClient: ApiClient(
        httpClient: mockClient,
        authDatasource: DevAuthLocalDatasource(),
      ),
    );
  }

  test(
    'getShopById mapea los campos reales de core_db/models/shop.py '
    '(hours_json, active_perk_text, etc.)',
    () async {
      final fixtureBody = jsonEncode({
        'id': 1,
        'qr_slug': 'demo-cafe-uno',
        'name': 'Demo 1',
        'address': 'Chapinero',
        'lat': 4.6533,
        'lng': -74.0575,
        'description': 'Barra de especialidad.',
        'hours_json': {'mon': '08:00-18:00'},
        'active_perk_text': '10% con tu pasaporte',
        'website_url': 'https://example.com',
      });
      final mockClient = MockClient(
        (request) async => http.Response(fixtureBody, 200),
      );

      final shop = await buildRepository(mockClient).getShopById('1');

      expect(shop, isNotNull);
      expect(shop!.description, 'Barra de especialidad.');
      expect(shop.hoursRaw, {'mon': '08:00-18:00'});
      expect(shop.activePerkText, '10% con tu pasaporte');
      expect(shop.websiteUrl, 'https://example.com');
      // Sin `rating_average`/`review_count` en el body: cafetería sin
      // reseñas todavía, deben quedar `null` sin tronar.
      expect(shop.avgRating, isNull);
      expect(shop.reviewCount, isNull);
    },
  );

  test(
    'getShopById lee rating_average/review_count exactos (contrato '
    'confirmado 2026-08-02)',
    () async {
      final fixtureBody = jsonEncode({
        'id': 1,
        'name': 'Demo 1',
        'address': 'Chapinero',
        'lat': 4.6533,
        'lng': -74.0575,
        'rating_average': 4.5,
        'review_count': 12,
      });
      final mockClient = MockClient(
        (request) async => http.Response(fixtureBody, 200),
      );

      final shop = await buildRepository(mockClient).getShopById('1');

      expect(shop!.avgRating, 4.5);
      expect(shop.reviewCount, 12);
    },
  );

  test(
    'getShopById deja rating_average en null cuando el backend lo manda '
    'null explícito (sin reseñas, no 0.0)',
    () async {
      final fixtureBody = jsonEncode({
        'id': 1,
        'name': 'Demo 1',
        'address': 'Chapinero',
        'lat': 4.6533,
        'lng': -74.0575,
        'rating_average': null,
        'review_count': 0,
      });
      final mockClient = MockClient(
        (request) async => http.Response(fixtureBody, 200),
      );

      final shop = await buildRepository(mockClient).getShopById('1');

      expect(shop!.avgRating, isNull);
      expect(shop.reviewCount, 0);
    },
  );
}
