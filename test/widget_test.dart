// Smoke test mínimo para el esqueleto de Clean Architecture.
//
// Verifica únicamente que la app arranca y que el flujo ilustrativo
// domain -> data -> presentation (ShopRepositoryImpl -> ShopCard) resuelve
// y pinta datos. No cubre pantallas reales todavía (eso llega junto con
// cada feature de la Fase 1).

import 'package:flutter_test/flutter_test.dart';

import 'package:coffee_passport_app/main.dart';

void main() {
  testWidgets('CoffeePassportApp muestra el directorio de ejemplo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CoffeePassportApp());

    // El repositorio stub resuelve de forma async: hay que asentar el
    // FutureBuilder antes de buscar el contenido.
    await tester.pumpAndSettle();

    expect(find.text('Pasaporte Café — esqueleto'), findsOneWidget);
    expect(find.text('Café Tinto'), findsOneWidget);
    expect(find.text('La Fisgona Café'), findsOneWidget);
  });
}
