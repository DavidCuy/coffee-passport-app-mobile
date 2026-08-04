import 'dart:async';

import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/recipe.dart';

/// Timer de receta guiada — Fase 1, sección 5 ("Contenido
/// interactivo: ... guías paso a paso"). Cuenta regresiva por paso
/// usando `recipe_steps.suggested_seconds`, avanza automáticamente al
/// siguiente paso al llegar a 0 — mismo comportamiento que
/// `brewTick()`/`loadBrewStep()` del mock (`pasaporte-cafe-mock.html`
/// → `#brewOverlay`), pantalla completa en vez de overlay (mismo
/// criterio de composición que el resto de las pantallas nuevas de
/// esta app: mejor encaje con `Navigator`/testing E2E por pantalla).
///
/// Requiere `recipe.steps.isNotEmpty` (verificado por
/// `RecipeDetailScreen` antes de navegar acá — el botón "Iniciar
/// receta guiada" queda deshabilitado si la receta no tiene pasos).
///
/// Widget keys para QA:
/// - `Key('brew_timer_screen')` — raíz.
/// - `Key('brew_timer_step_title')` — instrucción del paso actual.
/// - `Key('brew_timer_step_count')` — "Paso N de M".
/// - `Key('brew_timer_remaining_text')` — cuenta regresiva `mm:ss`.
/// - `Key('brew_timer_pause_button')` — pausa/reanuda.
/// - `Key('brew_timer_back_button')` — cierra el timer.
/// - `Key('brew_timer_done_text')` — mensaje final, sólo tras el
///   último paso.
class BrewTimerScreen extends StatefulWidget {
  const BrewTimerScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<BrewTimerScreen> createState() => _BrewTimerScreenState();
}

class _BrewTimerScreenState extends State<BrewTimerScreen> {
  late int _stepIndex;
  late int _remainingSeconds;
  int _elapsedSeconds = 0;
  bool _paused = false;
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _stepIndex = 0;
    _remainingSeconds = _currentStepSeconds;
    _startTicking();
  }

  int get _currentStepSeconds =>
      widget.recipe.steps.isEmpty
          ? 0
          : widget.recipe.steps[_stepIndex].suggestedSeconds;

  void _startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_paused || _done || !mounted) return;
    setState(() {
      _elapsedSeconds++;
      _remainingSeconds--;
      if (_remainingSeconds < 0) {
        if (_stepIndex < widget.recipe.steps.length - 1) {
          _stepIndex++;
          _remainingSeconds = _currentStepSeconds;
        } else {
          _done = true;
          _remainingSeconds = 0;
          _timer?.cancel();
        }
      }
    });
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.recipe.steps;
    final currentInstruction = _done
        ? '¡Listo! Disfruta tu café.'
        : steps[_stepIndex].instructionText;
    return Scaffold(
      key: const Key('brew_timer_screen'),
      backgroundColor: PassportColors.background,
      appBar: AppBar(
        backgroundColor: PassportColors.background,
        foregroundColor: PassportColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          key: const Key('brew_timer_back_button'),
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.recipe.name),
        actions: [
          if (!_done)
            IconButton(
              key: const Key('brew_timer_pause_button'),
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
              onPressed: _togglePause,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Text(
                currentInstruction,
                key: const Key('brew_timer_step_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: PassportColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: _done || _currentStepSeconds == 0
                            ? 0
                            : (_remainingSeconds / _currentStepSeconds).clamp(
                                0,
                                1,
                              ),
                        strokeWidth: 7,
                        backgroundColor: PassportColors.surface2,
                        valueColor: const AlwaysStoppedAnimation(
                          PassportColors.primary,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _fmt(_remainingSeconds),
                          key: const Key('brew_timer_remaining_text'),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: PassportColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'Restante',
                          style: TextStyle(
                            fontSize: 11,
                            color: PassportColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_done)
                const Text(
                  'Receta terminada',
                  key: Key('brew_timer_done_text'),
                  style: TextStyle(
                    color: PassportColors.textSecondary,
                    fontSize: 13,
                  ),
                )
              else
                Text(
                  'Paso ${_stepIndex + 1} de ${steps.length}',
                  key: const Key('brew_timer_step_count'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PassportColors.textSecondary,
                  ),
                ),
              const Spacer(),
              Text(
                'Tiempo total ${_fmt(_elapsedSeconds)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: PassportColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
