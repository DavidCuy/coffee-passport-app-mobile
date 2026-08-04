/// Lógica pura de la Calculadora de ratio café/agua (Fase 1, sección
/// 5 — "Contenido interactivo: calculadora de ratio café/agua"; ver
/// `API endpoints.md`: "Calculadora de ratio: sin endpoint, 100%
/// cliente").
///
/// **Sin dependencias de Flutter ni de red** a propósito — es la única
/// pieza de todo `lab` que no habla con el backend, y por eso es la
/// más fácil de cubrir con tests unitarios puros (sin mockear
/// `http.Client`). `RatioCalculatorTab` (presentation) es la única
/// consumidora.
class RatioCalculator {
  const RatioCalculator._();

  /// Ratios por defecto a ofrecer cuando todavía no hay recetas
  /// cargadas (o ninguna trae un `ratio_text` parseable) — mismos 3
  /// valores que el `#ratioSeg` del mock (`pasaporte-cafe-mock.html`):
  /// 1:15, 1:16 (preseleccionado), 1:17.
  static const List<int> defaultRatioDenominators = [15, 16, 17];

  /// Ratio preseleccionado por defecto, igual que el mock (`1:16`).
  static const int defaultRatioDenominator = 16;

  /// Dosis de café (g) por defecto, igual que el mock.
  static const int defaultDoseGrams = 15;

  /// Límites del stepper de dosis — mismos que el mock (`Math.max(5,
  /// ...)` / `Math.min(40, ...)`, ver `dosePlus`/`doseMinus`).
  static const int minDoseGrams = 5;
  static const int maxDoseGrams = 40;

  /// Parsea el denominador de un `ratio_text` tipo `"1:16"` → `16`.
  /// Acepta espacios sueltos (`"1 : 16"`) de forma defensiva. Devuelve
  /// `null` si el string no matchea el patrón `N:M` (ej. recetas de
  /// espresso con ratio `"1:2"` sí matchean — no hay un mínimo/máximo
  /// impuesto acá, cualquier receta real es válida como referencia).
  static int? parseRatioDenominator(String? ratioText) {
    if (ratioText == null) return null;
    final match = RegExp(r'^\s*1\s*:\s*(\d+(?:\.\d+)?)\s*$').firstMatch(ratioText);
    if (match == null) return null;
    return double.tryParse(match.group(1)!)?.round();
  }

  /// Agua (g/ml, 1 g de agua ≈ 1 ml) necesaria para [doseGrams] de
  /// café a un ratio `1:[ratioDenominator]`. Redondeado al gramo más
  /// cercano, igual que `Math.round(dose * ratio)` en el mock.
  static int waterForDose({
    required num doseGrams,
    required int ratioDenominator,
  }) {
    return (doseGrams * ratioDenominator).round();
  }

  /// Inverso de [waterForDose]: dosis de café necesaria para
  /// [waterGrams] de agua al mismo ratio. Redondeado al gramo más
  /// cercano.
  static int doseForWater({
    required num waterGrams,
    required int ratioDenominator,
  }) {
    if (ratioDenominator == 0) return 0;
    return (waterGrams / ratioDenominator).round();
  }

  /// Extrae y ordena los denominadores de ratio únicos de una lista de
  /// `ratio_text` (ej. de las recetas ya cargadas) — usados para
  /// poblar el selector de ratio de la calculadora con valores reales
  /// del catálogo en vez de sólo los 3 fijos del mock. Cae a
  /// [defaultRatioDenominators] si la lista queda vacía (sin recetas
  /// cargadas todavía, o ninguna con `ratio_text` parseable).
  static List<int> uniqueRatioDenominators(Iterable<String?> ratioTexts) {
    final parsed = <int>{};
    for (final raw in ratioTexts) {
      final denominator = parseRatioDenominator(raw);
      if (denominator != null) parsed.add(denominator);
    }
    if (parsed.isEmpty) return List.unmodifiable(defaultRatioDenominators);
    final sorted = parsed.toList()..sort();
    return List.unmodifiable(sorted);
  }
}
