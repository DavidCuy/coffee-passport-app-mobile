import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../../../core/brew/brew_method.dart';

/// Fila de chips para elegir el método de extracción — equivalente al
/// `.chip-row`/`#diaryMethods` del mock (`pasaporte-cafe-mock.html`):
/// pill con borde (`--border`/`--surface-2`) cuando no está
/// seleccionado, relleno sólido `--primary` (sin gradiente, ver regla
/// anti-patrón "IA" del proyecto) cuando sí.
///
/// Widget keys para QA: `Key('diary_form_method_chip_\${method.apiValue}')`
/// por cada chip (`diary_form_method_chip_v60`,
/// `diary_form_method_chip_prensa_francesa`,
/// `diary_form_method_chip_espresso`, `diary_form_method_chip_chemex`,
/// `diary_form_method_chip_aeropress`).
class BrewMethodChipRow extends StatelessWidget {
  const BrewMethodChipRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final BrewMethod? value;
  final ValueChanged<BrewMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BrewMethod.values.map((method) {
        final selected = method == value;
        return InkWell(
          key: Key('diary_form_method_chip_${method.apiValue}'),
          onTap: () => onChanged(method),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? PassportColors.primary : PassportColors.surface2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? PassportColors.primary : PassportColors.border,
                width: 1.5,
              ),
            ),
            child: Text(
              method.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : PassportColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
