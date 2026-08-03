// Test de regresión del bug #6 (QA Mobile, 2026-07-30): `_stampFromJson`
// mapeaba `Stamp` contra un shape que nunca existió en el backend real
// (`json['is_unlocked']`/`json['shop_name']` planos). El shape real de
// `GET /passport` -- confirmado contra
// `coffee-passport-backend/src/functions/get_passport/function.py` y su
// `test_function.py` -- anida el nombre de la cafetería en `shop.name` y
// nunca manda un booleano "desbloqueado": la sola presencia del elemento
// en `stamps` ya significa desbloqueado.
//
// Este test fija ese contrato con un fixture literal calcado del backend
// (incluye campos reales como `id_shop`, `unlocked_at`, `shop.status`)
// para que un futuro cambio de shape rompa este test antes que llegue a
// QA.

import 'dart:convert';

import 'package:coffee_passport_app/core/auth/dev_auth_local_datasource.dart';
import 'package:coffee_passport_app/core/network/api_client.dart';
import 'package:coffee_passport_app/features/passport/data/repositories/passport_repository_impl.dart';
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

  PassportRepositoryImpl buildRepository(http.Client mockClient) {
    return PassportRepositoryImpl(
      apiClient: ApiClient(
        httpClient: mockClient,
        authDatasource: DevAuthLocalDatasource(),
      ),
    );
  }

  test(
    'getPassport trata todo elemento de "stamps" como desbloqueado y lee '
    'el nombre de la cafetería desde shop.name (shape real del backend)',
    () async {
      // Calcado literal de lo que `get_passport/function.py` arma con
      // `PassportStamp.to_dict(jsonEncoder=AlchemyRelationEncoder,
      // encoder_extras={"relationships": ["shop"]})` -- sin ningún campo
      // `unlocked`/`is_unlocked`/`shop_name` plano.
      final fixtureBody = jsonEncode({
        'stamps_count': 2,
        'current_level': {'level_name': 'Catador', 'min_stamps': 5},
        'next_level': {'level_name': 'Explorador', 'min_stamps': 10},
        'stamps': [
          {
            'id': 10,
            'id_user': 3,
            'id_shop': 1,
            'unlocked_at': '2026-07-29T10:00:00+00:00',
            'shop': {
              'id': 1,
              'qr_slug': 'cafe-luna',
              'name': 'Cafe Luna',
              'status': 'active',
            },
          },
          {
            'id': 11,
            'id_user': 3,
            'id_shop': 2,
            'unlocked_at': '2026-07-29T11:00:00+00:00',
            'shop': {
              'id': 2,
              'qr_slug': 'cafe-sol',
              'name': 'Cafe Sol',
              'status': 'active',
            },
          },
        ],
      });

      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/passport'));
        return http.Response(fixtureBody, 200);
      });

      final overview = await buildRepository(mockClient).getPassport();

      expect(overview.stamps, hasLength(2));
      expect(overview.stamps.every((s) => s.isUnlocked), isTrue);
      expect(overview.stamps.map((s) => s.shopName), [
        'Cafe Luna',
        'Cafe Sol',
      ]);
      expect(overview.stamps.map((s) => s.shopId), ['1', '2']);
      // Sin `total_shops`/`unlocked_count` planos en el body real, los
      // contadores caen al fallback derivado de `stamps` -- ver
      // `PassportRepositoryImpl.getPassport`.
      expect(overview.unlockedCount, 2);
      expect(overview.totalShops, 2);
    },
  );
}
