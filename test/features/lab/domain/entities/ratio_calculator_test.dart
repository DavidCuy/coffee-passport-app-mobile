// Cubre `RatioCalculator` — la única pieza de `lab` sin dependencias
// de red/Flutter (ver docstring de la clase). Fija el contrato de la
// calculadora del mock (`pasaporte-cafe-mock.html` → `#screen-lab`,
// `updateCalc()`): dosis por defecto 15 g, ratio por defecto 1:16,
// `water = round(dose * ratio)`.

import 'package:coffee_passport_app/features/lab/domain/entities/ratio_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRatioDenominator', () {
    test('parsea "1:16" -> 16', () {
      expect(RatioCalculator.parseRatioDenominator('1:16'), 16);
    });

    test('parsea "1:2" (espresso) -> 2', () {
      expect(RatioCalculator.parseRatioDenominator('1:2'), 2);
    });

    test('acepta espacios sueltos alrededor de los dos puntos', () {
      expect(RatioCalculator.parseRatioDenominator('1 : 16'), 16);
    });

    test('devuelve null para un string que no matchea "1:N"', () {
      expect(RatioCalculator.parseRatioDenominator('a lot'), isNull);
      expect(RatioCalculator.parseRatioDenominator('2:16'), isNull);
      expect(RatioCalculator.parseRatioDenominator(''), isNull);
    });

    test('devuelve null si el argumento es null', () {
      expect(RatioCalculator.parseRatioDenominator(null), isNull);
    });
  });

  group('waterForDose', () {
    test('mismo default del mock: 15 g @ 1:16 -> 240 g de agua', () {
      expect(
        RatioCalculator.waterForDose(doseGrams: 15, ratioDenominator: 16),
        240,
      );
    });

    test('redondea al gramo más cercano', () {
      expect(
        RatioCalculator.waterForDose(doseGrams: 15.4, ratioDenominator: 15),
        231, // 15.4 * 15 = 231.0
      );
      expect(
        RatioCalculator.waterForDose(doseGrams: 15.7, ratioDenominator: 15),
        236, // 15.7 * 15 = 235.5 -> redondea a 236
      );
    });

    test('ratio de espresso 1:2', () {
      expect(
        RatioCalculator.waterForDose(doseGrams: 18, ratioDenominator: 2),
        36,
      );
    });
  });

  group('doseForWater', () {
    test('inverso exacto de waterForDose', () {
      final water = RatioCalculator.waterForDose(
        doseGrams: 20,
        ratioDenominator: 15,
      );
      expect(
        RatioCalculator.doseForWater(
          waterGrams: water,
          ratioDenominator: 15,
        ),
        20,
      );
    });

    test('devuelve 0 en vez de dividir por cero si el ratio es 0', () {
      expect(
        RatioCalculator.doseForWater(waterGrams: 240, ratioDenominator: 0),
        0,
      );
    });
  });

  group('uniqueRatioDenominators', () {
    test('extrae y ordena los denominadores únicos de varios ratio_text', () {
      final result = RatioCalculator.uniqueRatioDenominators([
        '1:16',
        '1:15',
        '1:2',
        '1:16', // duplicado, no debe repetirse
        'sin ratio',
        null,
      ]);
      expect(result, [2, 15, 16]);
    });

    test(
      'cae a defaultRatioDenominators si ningún ratio_text es parseable',
      () {
        final result = RatioCalculator.uniqueRatioDenominators([
          null,
          'n/a',
        ]);
        expect(result, RatioCalculator.defaultRatioDenominators);
      },
    );

    test('cae a defaultRatioDenominators con lista vacía', () {
      expect(
        RatioCalculator.uniqueRatioDenominators(const []),
        RatioCalculator.defaultRatioDenominators,
      );
    });
  });
}
