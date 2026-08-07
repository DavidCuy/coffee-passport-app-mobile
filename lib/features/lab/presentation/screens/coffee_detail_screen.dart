import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/coffee.dart';
import '../../domain/repositories/coffee_repository.dart';
import '../widgets/dna_attribute_bar.dart';
import '../widgets/flavor_chip_row.dart';

/// Ficha técnica completa de un [Coffee] — `GET /coffees/{id}` (trae
/// `coffee_flavor_notes`, a diferencia de la lista/destacados que
/// pueden no incluirlas). Equivalente a `.coffee-card` del mock
/// (`pasaporte-cafe-mock.html` → `#screen-lab`): origen (altitud,
/// proceso, variedad, productor), "ADN del café" (cuerpo/acidez/
/// dulzor/postgusto), historia y notas de sabor.
///
/// [fallback] es el [Coffee] ya cargado desde la lista (sin
/// `coffee_flavor_notes` todavía) — se muestra de inmediato mientras
/// se resuelve la ficha completa, para que la pantalla no arranque en
/// blanco (mismo criterio de "no bloquear el render" que
/// `ShopMapView`).
///
/// Widget keys para QA:
/// - `Key('coffee_detail_screen')` — raíz.
/// - `Key('coffee_detail_origin_grid')` — sección de origen.
/// - `Key('coffee_detail_dna_section')` — sección "ADN del café".
/// - Ver `FlavorChipRow` para `Key('coffee_detail_flavor_notes')`.
class CoffeeDetailScreen extends StatefulWidget {
  const CoffeeDetailScreen({
    super.key,
    required this.repository,
    required this.coffeeId,
    this.fallback,
  });

  final CoffeeRepository repository;
  final String coffeeId;
  final Coffee? fallback;

  @override
  State<CoffeeDetailScreen> createState() => _CoffeeDetailScreenState();
}

class _CoffeeDetailScreenState extends State<CoffeeDetailScreen> {
  late final Future<Coffee> _future = widget.repository.getCoffeeById(
    widget.coffeeId,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('coffee_detail_screen'),
      backgroundColor: PassportColors.background,
      appBar: AppBar(
        title: Text(widget.fallback?.name ?? 'Ficha del café'),
        backgroundColor: PassportColors.background,
        foregroundColor: PassportColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<Coffee>(
          future: _future,
          builder: (context, snapshot) {
            final coffee = snapshot.data ?? widget.fallback;
            if (coffee == null) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No se pudo cargar este café.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coffee.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: PassportColors.textPrimary,
                    ),
                  ),
                  if (coffee.roasterName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        coffee.roasterName!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PassportColors.textSecondary,
                        ),
                      ),
                    ),
                  if (coffee.scaScore != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: PassportColors.surface2,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: PassportColors.primary,
                              width: 3,
                            ),
                          ),
                          child: Text(
                            '${coffee.scaScore}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: PassportColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Puntaje de cata (SCA)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: PassportColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (coffee.storyText != null &&
                      coffee.storyText!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      coffee.storyText!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: PassportColors.textPrimary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _SectionTitle('ADN del café'),
                  const SizedBox(height: 10),
                  Column(
                    key: const Key('coffee_detail_dna_section'),
                    children: [
                      DnaAttributeBar(label: 'Cuerpo', score: coffee.bodyScore),
                      const SizedBox(height: 12),
                      DnaAttributeBar(
                        label: 'Acidez',
                        score: coffee.acidityScore,
                      ),
                      const SizedBox(height: 12),
                      DnaAttributeBar(
                        label: 'Dulzor',
                        score: coffee.sweetnessScore,
                      ),
                      const SizedBox(height: 12),
                      DnaAttributeBar(
                        label: 'Postgusto',
                        score: coffee.aftertasteScore,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle('Origen'),
                  const SizedBox(height: 10),
                  _OriginGrid(coffee: coffee),
                  const SizedBox(height: 20),
                  _SectionTitle('Notas de sabor'),
                  const SizedBox(height: 10),
                  FlavorChipRow(notes: coffee.flavorNotes),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: PassportColors.textSecondary,
      ),
    );
  }
}

class _OriginGrid extends StatelessWidget {
  const _OriginGrid({required this.coffee});

  final Coffee coffee;

  @override
  Widget build(BuildContext context) {
    final tiles = <_OriginTile>[
      _OriginTile(
        icon: Icons.terrain_outlined,
        label: 'Altitud',
        value: coffee.altitudeMasl != null
            ? '${coffee.altitudeMasl} msnm'
            : null,
      ),
      _OriginTile(
        icon: Icons.water_drop_outlined,
        label: 'Proceso',
        value: coffee.process,
      ),
      _OriginTile(
        icon: Icons.eco_outlined,
        label: 'Variedad',
        value: coffee.variety,
      ),
      _OriginTile(
        icon: Icons.person_outline,
        label: 'Productor',
        value: coffee.producer,
      ),
    ];
    return Wrap(
      key: const Key('coffee_detail_origin_grid'),
      spacing: 10,
      runSpacing: 10,
      children: tiles.map((tile) => SizedBox(width: 160, child: tile)).toList(),
    );
  }
}

class _OriginTile extends StatelessWidget {
  const _OriginTile({required this.icon, required this.label, this.value});

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PassportColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: PassportColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: PassportColors.textSecondary,
                  ),
                ),
                Text(
                  value ?? '—',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: PassportColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
