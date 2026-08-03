import 'package:flutter/material.dart';

import '../../domain/entities/stamp.dart';

/// Colores de marca tomados literalmente de `Diseño UI.md` (vault) —
/// se repiten como constantes locales en vez de un theme global porque
/// esta tarea sólo toca las pantallas de `passport`/`scan` (ver
/// `Agente Mobile.md`, restricciones: "no decide diseño visual nuevo
/// sin anclarlo al mock/notas ya aprobadas").
class PassportColors {
  const PassportColors._();

  static const primary = Color(0xFF75191A); // Burgundy / Tinto Café
  static const background = Color(0xFFFFF8E8); // Fondo principal
  static const surface = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF7EFE0); // Surface secundaria elevada
  static const textPrimary = Color(0xFF1C1917);
  static const textSecondary = Color(0xFF665E57);
  static const textFaint = Color(0xFFA89F91);
  static const border = Color(0xFFEADEC9);
}

/// Un sello individual en la grilla del pasaporte.
///
/// Regla explícita del proyecto (ver memoria de feedback del cliente y
/// `Diseño UI.md` → "Regla anti-patrón: nada de gradientes tipo IA"):
/// **sin `radial-gradient`/`linear-gradient` decorativo**. El sello
/// desbloqueado usa un relleno sólido (`--primary`) con un anillo
/// punteado (borde discontinuo, no blur) para leer como un sello de
/// tinta real sin caer en el look "glossy/bubbly" que el cliente
/// rechazó.
class StampTile extends StatelessWidget {
  const StampTile({super.key, required this.stamp, this.onTap});

  final Stamp stamp;
  final VoidCallback? onTap;

  String get _initials {
    final parts = stamp.shopName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = stamp.isUnlocked;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? PassportColors.primary : PassportColors.surface2,
              border: Border.all(
                color: unlocked ? PassportColors.primary : PassportColors.border,
                width: unlocked ? 1 : 2,
                style: BorderStyle.solid,
              ),
            ),
            alignment: Alignment.center,
            child: unlocked
                ? Text(
                    _initials,
                    style: const TextStyle(
                      color: PassportColors.surface,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  )
                : const Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: PassportColors.textFaint,
                  ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              stamp.shopName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: unlocked
                    ? PassportColors.textPrimary
                    : PassportColors.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
