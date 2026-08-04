import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/repositories/coffee_repository.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../widgets/coffee_catalog_view.dart';
import '../widgets/ratio_calculator_view.dart';
import '../widgets/recipe_catalog_view.dart';

/// Pantalla real del Laboratorio (Fase 1, sección 5 del vault de
/// producto): "Ficha técnica del café, recetas por método de
/// extracción y contenido interactivo (calculadora de ratio, guías
/// paso a paso)". Dividida en 3 sub-tabs — equivalente a
/// `.seg.lab-tabs`/`#labTabs` del mock (`pasaporte-cafe-mock.html` →
/// `#screen-lab`): **Cafés**, **Recetas**, **Utilidades**.
///
/// Cada sub-tab mantiene su propio `State` vivo entre cambios (usa
/// `IndexedStack`, no reconstruye al volver) — mismo criterio que
/// evitó el bug #8 documentado en `Fase 1 - Funcionalidades.md`
/// (`PassportScreen`/`StampCardView`), aplicado acá desde el arranque
/// en vez de encontrarlo como bug después.
///
/// Widget keys para QA:
/// - `Key('lab_screen')` — raíz.
/// - `Key('lab_tab_cafes_button')` / `Key('lab_tab_recetas_button')` /
///   `Key('lab_tab_utilidades_button')` — selectores de sub-tab
///   (botones individuales, no un solo `Container` — mismo criterio
///   que ya fijó el fix del bug #7 de `PassportScreen._ViewToggle`:
///   un `Key` sobre un contenedor con más de un botón del mismo ancho
///   hace que `WidgetTester.tap()` siempre golpee el del centro/
///   derecha).
/// - Ver `CoffeeCatalogView`, `RecipeCatalogView`, `RatioCalculatorView`
///   para los keys del contenido de cada sub-tab.
class LabScreen extends StatefulWidget {
  const LabScreen({
    super.key,
    required this.coffeeRepository,
    required this.recipeRepository,
  });

  final CoffeeRepository coffeeRepository;
  final RecipeRepository recipeRepository;

  @override
  State<LabScreen> createState() => _LabScreenState();
}

enum _LabTab { cafes, recetas, utilidades }

class _LabScreenState extends State<LabScreen> {
  _LabTab _tab = _LabTab.cafes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('lab_screen'),
      backgroundColor: PassportColors.background,
      appBar: AppBar(
        title: const Text('Laboratorio'),
        backgroundColor: PassportColors.background,
        foregroundColor: PassportColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _LabTabSelector(
                value: _tab,
                onChanged: (tab) => setState(() => _tab = tab),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab.index,
                children: [
                  CoffeeCatalogView(repository: widget.coffeeRepository),
                  RecipeCatalogView(repository: widget.recipeRepository),
                  RatioCalculatorView(repository: widget.recipeRepository),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabTabSelector extends StatelessWidget {
  const _LabTabSelector({required this.value, required this.onChanged});

  final _LabTab value;
  final ValueChanged<_LabTab> onChanged;

  static const _labels = {
    _LabTab.cafes: 'Cafés',
    _LabTab.recetas: 'Recetas',
    _LabTab.utilidades: 'Utilidades',
  };

  static const _keys = {
    _LabTab.cafes: 'lab_tab_cafes_button',
    _LabTab.recetas: 'lab_tab_recetas_button',
    _LabTab.utilidades: 'lab_tab_utilidades_button',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PassportColors.surface2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _LabTab.values.map((tab) {
          final selected = tab == value;
          return Expanded(
            child: InkWell(
              key: Key(_keys[tab]!),
              onTap: () => onChanged(tab),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? PassportColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _labels[tab]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? PassportColors.primary
                        : PassportColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
