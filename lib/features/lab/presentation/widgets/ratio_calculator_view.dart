import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/ratio_calculator.dart';
import '../../domain/repositories/recipe_repository.dart';

/// Contenido del sub-tab "Utilidades" del Laboratorio — Calculadora de
/// ratio café/agua, **100% cliente** (ver `API endpoints.md`:
/// "Calculadora de ratio: sin endpoint, 100% cliente"). Toda la
/// aritmética vive en [RatioCalculator] (domain, sin Flutter) — este
/// widget sólo pinta el estado y llama a esos métodos puros.
/// Equivalente a `.calc-card` del mock (`pasaporte-cafe-mock.html` →
/// `#screen-lab`).
///
/// El único uso de red es opcional y best-effort: `GET /recipes` para
/// poblar el selector de ratio con los `ratio_text` reales del
/// catálogo (ej. "1:16", "1:2" de espresso) en vez de sólo los 3
/// valores fijos del mock — si la llamada falla o todavía no hay
/// recetas cargadas, la calculadora sigue siendo 100% usable con
/// [RatioCalculator.defaultRatioDenominators] (nunca bloquea el
/// render, mismo criterio que `ShopMapView` con la geolocalización).
///
/// Widget keys para QA:
/// - `Key('lab_ratio_calculator_view')` — raíz.
/// - `Key('lab_calc_dose_minus_button')` / `Key('lab_calc_dose_plus_button')`.
/// - `Key('lab_calc_dose_value')` — dosis actual en gramos.
/// - `Key('lab_calc_ratio_chip_<denominador>')` — uno por ratio
///   disponible (ej. `lab_calc_ratio_chip_16`).
/// - `Key('lab_calc_water_result')` — resultado calculado (agua en ml).
class RatioCalculatorView extends StatefulWidget {
  const RatioCalculatorView({super.key, required this.repository});

  final RecipeRepository repository;

  @override
  State<RatioCalculatorView> createState() => _RatioCalculatorViewState();
}

class _RatioCalculatorViewState extends State<RatioCalculatorView> {
  int _doseGrams = RatioCalculator.defaultDoseGrams;
  int _ratioDenominator = RatioCalculator.defaultRatioDenominator;
  List<int> _ratioOptions = RatioCalculator.defaultRatioDenominators;

  @override
  void initState() {
    super.initState();
    _loadRatioOptions();
  }

  Future<void> _loadRatioOptions() async {
    try {
      final recipes = await widget.repository.getRecipes();
      if (!mounted) return;
      final options = RatioCalculator.uniqueRatioDenominators(
        recipes.map((r) => r.ratioText),
      );
      setState(() {
        _ratioOptions = options;
        if (!_ratioOptions.contains(_ratioDenominator)) {
          _ratioDenominator = _ratioOptions.contains(
                RatioCalculator.defaultRatioDenominator,
              )
              ? RatioCalculator.defaultRatioDenominator
              : _ratioOptions.first;
        }
      });
    } on Exception {
      // Best-effort: la calculadora sigue funcionando con los ratios
      // por defecto si `GET /recipes` falla (ver docstring de arriba).
    }
  }

  void _decreaseDose() {
    setState(() {
      _doseGrams = (_doseGrams - 1).clamp(
        RatioCalculator.minDoseGrams,
        RatioCalculator.maxDoseGrams,
      );
    });
  }

  void _increaseDose() {
    setState(() {
      _doseGrams = (_doseGrams + 1).clamp(
        RatioCalculator.minDoseGrams,
        RatioCalculator.maxDoseGrams,
      );
    });
  }

  void _selectRatio(int denominator) {
    setState(() => _ratioDenominator = denominator);
  }

  @override
  Widget build(BuildContext context) {
    final water = RatioCalculator.waterForDose(
      doseGrams: _doseGrams,
      ratioDenominator: _ratioDenominator,
    );
    return SingleChildScrollView(
      key: const Key('lab_ratio_calculator_view'),
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PassportColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PassportColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CALCULADORA DE RATIO',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: PassportColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dosis de café',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PassportColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    _StepperButton(
                      key: const Key('lab_calc_dose_minus_button'),
                      icon: Icons.remove,
                      onPressed: _decreaseDose,
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        '$_doseGrams g',
                        key: const Key('lab_calc_dose_value'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: PassportColors.textPrimary,
                        ),
                      ),
                    ),
                    _StepperButton(
                      key: const Key('lab_calc_dose_plus_button'),
                      icon: Icons.add,
                      onPressed: _increaseDose,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Ratio',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PassportColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ratioOptions.map((denominator) {
                final selected = denominator == _ratioDenominator;
                return InkWell(
                  key: Key('lab_calc_ratio_chip_$denominator'),
                  onTap: () => _selectRatio(denominator),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? PassportColors.primary
                          : PassportColors.surface2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? PassportColors.primary
                            : PassportColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '1:$denominator',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : PassportColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PassportColors.surface2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text.rich(
                    key: const Key('lab_calc_water_result'),
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$water',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: PassportColors.primary,
                          ),
                        ),
                        const TextSpan(
                          text: ' g de agua',
                          style: TextStyle(
                            fontSize: 14,
                            color: PassportColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '≈ $water ml · vierte en pulsos',
                    style: const TextStyle(
                      fontSize: 12,
                      color: PassportColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: PassportColors.primary,
      style: IconButton.styleFrom(
        backgroundColor: PassportColors.surface2,
        shape: const CircleBorder(),
      ),
    );
  }
}
