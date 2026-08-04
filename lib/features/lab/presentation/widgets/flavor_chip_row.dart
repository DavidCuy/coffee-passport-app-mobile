import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;

/// Fila de chips de solo lectura para las notas de cata de un café —
/// equivalente al `.chip-row`/`.flavor-chip` de la sección "Notas de
/// sabor" del mock (`pasaporte-cafe-mock.html` → `#screen-lab`, ficha
/// de café): pill con borde (`--border`/`--surface`), sin relleno
/// sólido (a diferencia de `BrewMethodChipRow`, acá no hay selección —
/// son etiquetas informativas).
///
/// Widget key para QA: `Key('coffee_detail_flavor_notes')` en el
/// `Wrap` contenedor.
class FlavorChipRow extends StatelessWidget {
  const FlavorChipRow({super.key, required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return const Text(
        'Sin notas de cata registradas todavía.',
        style: TextStyle(color: PassportColors.textFaint, fontSize: 12.5),
      );
    }
    return Wrap(
      key: const Key('coffee_detail_flavor_notes'),
      spacing: 8,
      runSpacing: 8,
      children: notes.map((note) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: PassportColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: PassportColors.border),
          ),
          child: Text(
            note,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PassportColors.textPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }
}
