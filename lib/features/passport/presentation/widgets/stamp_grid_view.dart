import 'package:flutter/material.dart';

import '../../domain/entities/stamp.dart';
import 'stamp_tile.dart';

/// Vista "cuadrícula condensada" del pasaporte — 4 columnas, réplica
/// funcional de `.stamp-grid` en `mock-ui/pasaporte-cafe-mock.html`.
///
/// Widget key obligatorio para QA: `Key('passport_grid_view')`.
class StampGridView extends StatelessWidget {
  const StampGridView({super.key, required this.stamps, this.onTapStamp});

  final List<Stamp> stamps;
  final ValueChanged<Stamp>? onTapStamp;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const Key('passport_grid_view'),
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
      ),
      itemCount: stamps.length,
      itemBuilder: (context, index) {
        final stamp = stamps[index];
        return StampTile(
          stamp: stamp,
          onTap: onTapStamp == null ? null : () => onTapStamp!(stamp),
        );
      },
    );
  }
}
