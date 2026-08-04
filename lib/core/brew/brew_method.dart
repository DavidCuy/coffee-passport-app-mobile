/// Método de extracción — usado tanto por una entrada del Diario de
/// cata (`diary.brewMethod`) como por una receta del Laboratorio
/// (`Recipe.brewMethod`, ver `Fase 1 - Funcionalidades.md`, sección 5).
///
/// Enum fijo (V60, prensa francesa, espresso, chemex, aeropress).
/// Vivió originalmente en `features/diary/domain/entities/` (único
/// consumidor cuando se escribió, 2026-08-03) con una nota explícita
/// de que debía subir a `core/` en cuanto una segunda feature lo
/// necesitara — exactamente lo que pasó al arrancar `lab` (2026-08-04,
/// recetas por método de extracción), así que se movió acá siguiendo
/// la regla de `ARCHITECTURE.md` en vez de duplicar el concepto.
enum BrewMethod {
  v60,
  prensaFrancesa,
  espresso,
  chemex,
  aeropress;

  /// Valor exacto que espera/manda el backend en el campo `brew_method`
  /// de `POST`/`PATCH /diary` (ver `API endpoints.md` del vault).
  String get apiValue {
    switch (this) {
      case BrewMethod.v60:
        return 'v60';
      case BrewMethod.prensaFrancesa:
        return 'prensa_francesa';
      case BrewMethod.espresso:
        return 'espresso';
      case BrewMethod.chemex:
        return 'chemex';
      case BrewMethod.aeropress:
        return 'aeropress';
    }
  }

  /// Etiqueta a mostrar en la UI — mismo texto que el `chip-row` del
  /// Diario en el mock (`pasaporte-cafe-mock.html` → `#diaryMethods`).
  String get label {
    switch (this) {
      case BrewMethod.v60:
        return 'V60';
      case BrewMethod.prensaFrancesa:
        return 'Prensa francesa';
      case BrewMethod.espresso:
        return 'Espresso';
      case BrewMethod.chemex:
        return 'Chemex';
      case BrewMethod.aeropress:
        return 'Aeropress';
    }
  }

  /// Parseo defensivo desde el string que manda el backend — acepta el
  /// valor exacto (`v60`, `prensa_francesa`, ...) y, por si acaso,
  /// variantes con espacios/guiones (`"Prensa Francesa"`,
  /// `"prensa-francesa"`). Regresa `null` si no matchea nada del enum
  /// fijo, en vez de fallar — `DiaryRepositoryImpl`/la UI deciden qué
  /// mostrar en ese caso ("Sin especificar", igual que hace el mock
  /// cuando no se elige método).
  static BrewMethod? fromApiValue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');
    for (final method in BrewMethod.values) {
      if (method.apiValue == normalized) return method;
    }
    return null;
  }
}
