import 'package:flutter/material.dart';

import '../../domain/entities/passport_level.dart';
import '../../domain/entities/passport_overview.dart';
import '../../domain/repositories/passport_repository.dart';
import '../widgets/stamp_card_view.dart';
import '../widgets/stamp_grid_view.dart';
import '../widgets/stamp_tile.dart' show PassportColors;

enum PassportViewMode { grid, card }

/// Pantalla real de "El Pasaporte" (Fase 1, sección 1 del vault).
///
/// Combina `GET /passport` y `GET /levels` (vía [PassportRepository])
/// y ofrece los 2 modos ya aprobados en `Diseño UI.md`: cuadrícula
/// condensada y tarjeta swipeable estilo pasaporte de papel.
///
/// Widget keys obligatorios para QA:
/// - `Key('passport_view_toggle_grid_button')` en el botón que activa el
///   modo grid.
/// - `Key('passport_view_toggle_card_button')` en el botón que activa el
///   modo tarjeta.
///   (Antes había un único `Key('passport_view_toggle')` en el
///   `Container` que envuelve ambos botones de igual ancho — bug #7
///   reportado por QA Mobile 2026-07-30: `WidgetTester.tap()` golpea el
///   centro geométrico del widget encontrado por key, que con 2 botones
///   de igual ancho cae siempre en el botón derecho ["tarjeta"],
///   haciendo imposible automatizar el round-trip grid→tarjeta→grid.
///   Se reemplazó por un key individual por botón.)
/// - `Key('passport_grid_view')` en la vista grid (ver `StampGridView`).
/// - `Key('passport_card_view')` en la vista tarjeta (ver
///   `StampCardView`).
class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key, required this.repository});

  final PassportRepository repository;

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> {
  PassportViewMode _mode = PassportViewMode.grid;
  late Future<_PassportData> _future;

  // Índice de la página enfocada en la vista tarjeta. Vive acá (y no en
  // `_StampCardViewState`) porque `StampCardView` se reconstruye entero
  // cada vez que se alterna grid↔tarjeta (ver nota en
  // `stamp_card_view.dart`, bug #8) — este `State` es el ancestro que
  // sobrevive al toggle, así que es el lugar correcto para persistirlo.
  int _cardPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PassportData> _load() async {
    final overview = await widget.repository.getPassport();
    final levels = await widget.repository.getLevels();
    return _PassportData(overview: overview, levels: levels);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassportColors.background,
      appBar: AppBar(
        title: const Text('Tu pasaporte'),
        backgroundColor: PassportColors.background,
        foregroundColor: PassportColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<_PassportData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: '${snapshot.error}',
                onRetry: _refresh,
              );
            }
            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _LevelHeader(overview: data.overview, levels: data.levels),
                  const SizedBox(height: 8),
                  _ViewToggle(
                    mode: _mode,
                    onChanged: (mode) => setState(() => _mode = mode),
                  ),
                  const SizedBox(height: 12),
                  if (_mode == PassportViewMode.grid)
                    StampGridView(stamps: data.overview.stamps)
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: StampCardView(
                        stamps: data.overview.stamps,
                        initialIndex: _cardPageIndex,
                        onIndexChanged: (i) =>
                            setState(() => _cardPageIndex = i),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PassportData {
  const _PassportData({required this.overview, required this.levels});

  final PassportOverview overview;
  final List<PassportLevel> levels;
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.overview, required this.levels});

  final PassportOverview overview;
  final List<PassportLevel> levels;

  @override
  Widget build(BuildContext context) {
    final currentLevel = levels.where((l) => l.isCurrent).firstOrNull;
    final progress = overview.totalShops == 0
        ? 0.0
        : (overview.unlockedCount / overview.totalShops).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentLevel != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: PassportColors.surface2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: PassportColors.border),
              ),
              child: Text(
                currentLevel.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: PassportColors.primary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '${overview.unlockedCount} de ${overview.totalShops} '
            'cafeterías completadas',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: PassportColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: PassportColors.surface2,
              valueColor: const AlwaysStoppedAnimation(PassportColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.mode, required this.onChanged});

  final PassportViewMode mode;
  final ValueChanged<PassportViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: PassportColors.surface2,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToggleButton(
                key: const Key('passport_view_toggle_grid_button'),
                icon: Icons.grid_view_rounded,
                selected: mode == PassportViewMode.grid,
                onTap: () => onChanged(PassportViewMode.grid),
                semanticLabel: 'Vista de cuadrícula',
              ),
              _ToggleButton(
                key: const Key('passport_view_toggle_card_button'),
                icon: Icons.badge_outlined,
                selected: mode == PassportViewMode.card,
                onTap: () => onChanged(PassportViewMode.card),
                semanticLabel: 'Vista de pasaporte',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    super.key,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 34,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? PassportColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected
                ? PassportColors.primary
                : PassportColors.textFaint,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: PassportColors.primary),
            const SizedBox(height: 8),
            Text(
              'No se pudo cargar tu pasaporte.\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: PassportColors.textSecondary),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
