import 'package:flutter/material.dart';

import '../../domain/entities/stamp.dart';
import 'stamp_tile.dart';

/// Vista "tarjeta" del pasaporte: un sello grande a pantalla completa
/// por vez, estilo página de pasaporte de papel — nav prev/next +
/// swipe, réplica funcional de `.stamp-card-view`/`.passport-card` en
/// `mock-ui/pasaporte-cafe-mock.html`.
///
/// El índice de página enfocada NO se guarda dentro de este widget:
/// `PassportScreen` reconstruye este árbol entero cada vez que se
/// alterna grid↔tarjeta (`_mode` en un `if/else` dentro del `build`),
/// así que `State`/`PageController` de este widget se destruyen en
/// cada toggle sin importar qué `key` se le ponga a este `Stateful`
/// (bug #8 reportado por QA Mobile 2026-08-02: "2/2" volvía a "1/2" al
/// hacer round-trip tarjeta→grid→tarjeta). El fix real es que el
/// índice viva en el ancestro que sí sobrevive (`_PassportScreenState`)
/// y se le pase a este widget como [initialIndex], notificando cambios
/// vía [onIndexChanged].
///
/// Widget key obligatorio para QA: `Key('passport_card_view')`.
class StampCardView extends StatefulWidget {
  const StampCardView({
    super.key,
    required this.stamps,
    this.initialIndex = 0,
    this.onIndexChanged,
  });

  final List<Stamp> stamps;

  /// Página con la que debe arrancar el `PageView` — normalmente el
  /// último índice enfocado antes de que se haya desmontado este
  /// widget (ver nota de clase).
  final int initialIndex;

  /// Notificado en cada cambio de página (swipe o botones prev/next)
  /// para que el ancestro pueda persistirlo.
  final ValueChanged<int>? onIndexChanged;

  @override
  State<StampCardView> createState() => _StampCardViewState();
}

class _StampCardViewState extends State<StampCardView> {
  late int _index = _clampedInitialIndex();
  late final PageController _controller = PageController(
    initialPage: _index,
  );

  int _clampedInitialIndex() {
    if (widget.stamps.isEmpty) return 0;
    return widget.initialIndex.clamp(0, widget.stamps.length - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    widget.onIndexChanged?.call(i);
  }

  void _goTo(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.stamps.length) return;
    _controller.animateToPage(
      newIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stamps.isEmpty) {
      return const Center(
        key: Key('passport_card_view'),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Todavía no hay cafeterías en el pasaporte.'),
        ),
      );
    }
    return Column(
      key: const Key('passport_card_view'),
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.stamps.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final stamp = widget.stamps[index];
              return _PassportPage(stamp: stamp);
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const Key('passport_card_prev_button'),
              onPressed: _index == 0 ? null : () => _goTo(_index - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            SizedBox(
              width: 64,
              child: Text(
                '${_index + 1} / ${widget.stamps.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: PassportColors.textSecondary,
                ),
              ),
            ),
            IconButton(
              key: const Key('passport_card_next_button'),
              onPressed: _index == widget.stamps.length - 1
                  ? null
                  : () => _goTo(_index + 1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

class _PassportPage extends StatelessWidget {
  const _PassportPage({required this.stamp});

  final Stamp stamp;

  @override
  Widget build(BuildContext context) {
    final unlocked = stamp.isUnlocked;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: unlocked ? PassportColors.primary : PassportColors.surface,
            border: unlocked
                ? null
                : Border.all(color: PassportColors.border, width: 3),
          ),
          alignment: Alignment.center,
          child: unlocked
              ? Text(
                  _initials(stamp.shopName),
                  style: const TextStyle(
                    color: PassportColors.surface,
                    fontWeight: FontWeight.w800,
                    fontSize: 32,
                  ),
                )
              : const Icon(
                  Icons.lock_outline,
                  size: 34,
                  color: PassportColors.textFaint,
                ),
        ),
        const SizedBox(height: 16),
        Text(
          stamp.shopName,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: PassportColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            unlocked
                ? _visitSummary(stamp)
                : 'Aún no visitas esta cafetería — usa el escáner para '
                      'desbloquearla.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: PassportColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  String _visitSummary(Stamp stamp) {
    final unlockedAt = stamp.unlockedAt;
    if (unlockedAt == null) return 'Sello agregado a tu pasaporte.';
    final formatted =
        '${unlockedAt.day.toString().padLeft(2, '0')}/'
        '${unlockedAt.month.toString().padLeft(2, '0')}/'
        '${unlockedAt.year}';
    return 'Visitado el $formatted.';
  }
}
