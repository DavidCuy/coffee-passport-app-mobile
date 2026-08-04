import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;

/// Una barra del "ADN del café" (cuerpo/acidez/dulzor/postgusto, 1-5)
/// — equivalente a `.dna-attr`/`.dna-track`/`.dna-fill` del mock
/// (`pasaporte-cafe-mock.html` → `#screen-lab`). Relleno sólido
/// `--primary` sobre pista `--surface-2`, **sin gradiente** (misma
/// regla anti-patrón "IA" que el resto de la app).
class DnaAttributeBar extends StatelessWidget {
  const DnaAttributeBar({
    super.key,
    required this.label,
    required this.score,
    this.maxScore = 5,
  });

  final String label;

  /// `null` si el backend no manda ese atributo — se muestra la barra
  /// vacía en vez de ocultar la fila, para que la ficha mantenga la
  /// misma estructura de 4 filas del mock.
  final int? score;
  final int maxScore;

  @override
  Widget build(BuildContext context) {
    final clamped = (score ?? 0).clamp(0, maxScore);
    final fraction = maxScore == 0 ? 0.0 : clamped / maxScore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: PassportColors.textPrimary,
              ),
            ),
            Text(
              score == null ? '—' : '$score/$maxScore',
              style: const TextStyle(
                fontSize: 12,
                color: PassportColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: PassportColors.surface2,
            valueColor: const AlwaysStoppedAnimation(PassportColors.primary),
          ),
        ),
      ],
    );
  }
}
