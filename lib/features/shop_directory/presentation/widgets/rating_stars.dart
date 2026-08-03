import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;

/// Color de "estrella llena" — mismo ámbar de advertencia/calificación
/// usado en el resto de la app (ver `Diseño UI.md`, `--warning`).
const Color _starFilled = Color(0xFFD97706);

/// Fila de estrellas de solo lectura (1-5). Usado para mostrar el
/// rating de una reseña ya guardada o el promedio de una cafetería.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 16});

  /// Puede ser fraccionario (ej. promedio `4.3`) — se redondea al
  /// entero más cercano sólo para decidir qué estrellas rellenar; no
  /// hay estrellas "a la mitad" en el look flat/editorial de esta app.
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final filled = rating.round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < filled ? Icons.star : Icons.star_border,
          size: size,
          color: i < filled ? _starFilled : PassportColors.textFaint,
        );
      }),
    );
  }
}

/// Selector de estrellas interactivo (1-5) para escribir/editar una
/// reseña propia — equivalente al `.star-row` del Diario de cata en el
/// mock (`pasaporte-cafe-mock.html` → `#diaryStars`), reutilizado acá
/// para reseñas de cafetería.
///
/// Widget keys para QA: `Key('shop_review_star_\$n')` por cada botón
/// (1 a 5).
class RatingSelector extends StatelessWidget {
  const RatingSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final n = i + 1;
        return IconButton(
          key: Key('shop_review_star_$n'),
          padding: const EdgeInsets.all(2),
          constraints: const BoxConstraints(),
          onPressed: () => onChanged(n),
          icon: Icon(
            n <= value ? Icons.star : Icons.star_border,
            size: 26,
            color: n <= value ? _starFilled : PassportColors.border,
          ),
        );
      }),
    );
  }
}
