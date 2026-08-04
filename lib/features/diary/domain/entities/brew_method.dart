/// Método de extracción usado en una entrada del Diario de cata.
///
/// Enum fijo (Fase 1, sección 4 y sección 5 del vault de producto —
/// mismo set de métodos que usa el Laboratorio para sus recetas:
/// V60, prensa francesa, espresso, chemex, aeropress). No hay
/// referencia a un enum equivalente ya escrito en el repo (la feature
/// `lab`/recetas todavía no existe), así que este es el primero y vive
/// acá — si más adelante `lab` necesita el mismo concepto, debería
/// moverse a `core/` en vez de duplicarse (ver regla de
/// `ARCHITECTURE.md`).
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
