// Fija el contrato real de `ShopReviewRepositoryImpl`, confirmado por
// el Agente Backend contra la Supabase real (2026-08-02, ver
// `API endpoints.md`): parseo del wrapper `{"data": [...]}`,
// `reviewer_display_name` como nombre del autor (no `author_name`/
// `user_name`) e `is_mine` calculado por el backend (siempre presente,
// sin heurística de `user_sub`/dev-sub del lado del cliente) — más el
// fallback "optimista" de create/update cuando el body de respuesta
// todavía no trae la reseña completa.

import 'dart:convert';

import 'package:coffee_passport_app/core/auth/dev_auth_local_datasource.dart';
import 'package:coffee_passport_app/core/network/api_client.dart';
import 'package:coffee_passport_app/features/shop_directory/data/repositories/shop_review_repository_impl.dart';
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

  ShopReviewRepositoryImpl buildRepository(http.Client mockClient) {
    return ShopReviewRepositoryImpl(
      apiClient: ApiClient(
        httpClient: mockClient,
        authDatasource: DevAuthLocalDatasource(),
      ),
    );
  }

  test(
    'getReviews desenvuelve {"data": [...]} y usa reviewer_display_name/'
    'is_mine tal cual los manda el backend',
    () async {
      final fixtureBody = jsonEncode({
        'data': [
          {
            'id': 10,
            'id_user': 5,
            'id_shop': 1,
            'rating': 5,
            'comment': 'Excelente cafe',
            'created_at': '2026-08-03T03:01:41.334834+00:00',
            'updated_at': '2026-08-03T03:01:41.334834+00:00',
            'reviewer_display_name': 'Dev Local',
            'is_mine': true,
          },
          {
            'id': 11,
            'id_user': 6,
            'id_shop': 1,
            'rating': 3,
            'comment': 'Regular',
            'created_at': '2026-08-01T10:00:00+00:00',
            'updated_at': '2026-08-01T10:00:00+00:00',
            'reviewer_display_name': 'Otro Visitante',
            'is_mine': false,
          },
        ],
      });
      final mockClient = MockClient((request) async {
        expect(request.url.path, contains('/shops/1/reviews'));
        return http.Response(fixtureBody, 200);
      });

      final reviews = await buildRepository(mockClient).getReviews('1');

      expect(reviews, hasLength(2));
      expect(reviews[0].isMine, isTrue);
      expect(reviews[0].rating, 5);
      expect(reviews[0].authorName, 'Dev Local');
      expect(reviews[1].isMine, isFalse);
      expect(reviews[1].rating, 3);
      expect(reviews[1].authorName, 'Otro Visitante');
    },
  );

  test(
    'getReviews respeta is_mine=false para todas cuando el backend no '
    'resuelve identidad (sin heurística de sub del lado del cliente)',
    () async {
      final fixtureBody = jsonEncode({
        'data': [
          {
            'id': 10,
            'id_user': 5,
            'id_shop': 1,
            'rating': 5,
            'comment': 'Excelente',
            'created_at': '2026-08-01T10:00:00+00:00',
            'updated_at': '2026-08-01T10:00:00+00:00',
            'reviewer_display_name': 'Dev Local',
            'is_mine': false,
          },
        ],
      });
      final mockClient = MockClient(
        (request) async => http.Response(fixtureBody, 200),
      );

      final reviews = await buildRepository(mockClient).getReviews('1');

      expect(reviews.single.isMine, isFalse);
    },
  );

  test(
    'createReview manda POST con rating/comment y arma un ShopReview '
    '"local" (sin forzar isMine) si el backend no devuelve id',
    () async {
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedMethod = request.method;
        capturedBody =
            jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('', 201);
      });

      final repository = buildRepository(mockClient);
      final review = await repository.createReview(
        shopId: '1',
        rating: 4,
        comment: 'Muy bueno',
      );

      expect(capturedMethod, 'POST');
      expect(capturedBody, {'rating': 4, 'comment': 'Muy bueno'});
      expect(review.rating, 4);
      expect(review.comment, 'Muy bueno');
    },
  );

  test(
    'createReview usa is_mine del body de respuesta cuando el backend '
    'sí devuelve la reseña completa',
    () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 20,
            'id_shop': 1,
            'rating': 4,
            'comment': 'Muy bueno',
            'reviewer_display_name': 'Dev Local',
            'is_mine': true,
          }),
          201,
        );
      });

      final repository = buildRepository(mockClient);
      final review = await repository.createReview(
        shopId: '1',
        rating: 4,
        comment: 'Muy bueno',
      );

      expect(review.id, '20');
      expect(review.isMine, isTrue);
      expect(review.authorName, 'Dev Local');
    },
  );

  test('createReview lanza ApiException si el backend responde error', () async {
    final mockClient = MockClient(
      (request) async => http.Response('{"message":"ya existe"}', 409),
    );

    final repository = buildRepository(mockClient);

    expect(
      () => repository.createReview(shopId: '1', rating: 5),
      throwsA(isA<ApiException>()),
    );
  });

  test('deleteMyReview hace DELETE /shops/{id}/reviews/mine', () async {
    String? capturedMethod;
    String? capturedPath;
    final mockClient = MockClient((request) async {
      capturedMethod = request.method;
      capturedPath = request.url.path;
      return http.Response('', 204);
    });

    final repository = buildRepository(mockClient);
    await repository.deleteMyReview('1');

    expect(capturedMethod, 'DELETE');
    expect(capturedPath, contains('/shops/1/reviews/mine'));
  });
}
