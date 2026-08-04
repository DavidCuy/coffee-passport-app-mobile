import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/coffee.dart';
import '../../domain/repositories/coffee_repository.dart';
import '../screens/coffee_detail_screen.dart';
import 'coffee_list_tile.dart';

/// Contenido del sub-tab "Cafés" del Laboratorio — sección "Café del
/// mes" (`GET /coffees/featured`) seguida del catálogo completo (`GET
/// /coffees`), equivalente a `.lab-section[data-lab-panel="cafes"]`
/// del mock (`pasaporte-cafe-mock.html`).
///
/// Widget keys para QA:
/// - `Key('lab_coffee_catalog_view')` — raíz.
/// - `Key('lab_coffee_featured_section')` — sección "Café del mes",
///   sólo si `GET /coffees/featured` trae al menos uno.
/// - `Key('lab_coffee_list')` — lista del catálogo completo.
/// - `Key('lab_coffee_empty_state')` — si el catálogo está vacío.
/// - Ver `CoffeeListTile` para el key de cada item
///   (`lab_coffee_card_<id>`).
class CoffeeCatalogView extends StatefulWidget {
  const CoffeeCatalogView({super.key, required this.repository});

  final CoffeeRepository repository;

  @override
  State<CoffeeCatalogView> createState() => _CoffeeCatalogViewState();
}

class _CoffeeCatalogData {
  const _CoffeeCatalogData({required this.featured, required this.catalog});

  final List<Coffee> featured;
  final List<Coffee> catalog;
}

class _CoffeeCatalogViewState extends State<CoffeeCatalogView> {
  late Future<_CoffeeCatalogData> _future = _load();

  Future<_CoffeeCatalogData> _load() async {
    final results = await Future.wait([
      widget.repository.getFeaturedCoffees(),
      widget.repository.getCoffees(),
    ]);
    return _CoffeeCatalogData(
      featured: results[0],
      catalog: results[1],
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  void _openDetail(Coffee coffee) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CoffeeDetailScreen(
          repository: widget.repository,
          coffeeId: coffee.id,
          fallback: coffee,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CoffeeCatalogData>(
      key: const Key('lab_coffee_catalog_view'),
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error, onRetry: _refresh);
        }
        final data =
            snapshot.data ?? const _CoffeeCatalogData(featured: [], catalog: []);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (data.featured.isNotEmpty) ...[
                Padding(
                  key: const Key('lab_coffee_featured_section'),
                  padding: const EdgeInsets.only(bottom: 4),
                  child: const Text(
                    'CAFÉ DEL MES',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: PassportColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...data.featured.map(
                  (coffee) => CoffeeListTile(
                    coffee: coffee,
                    onTap: () => _openDetail(coffee),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'CATÁLOGO COMPLETO',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: PassportColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (data.catalog.isEmpty)
                Padding(
                  key: const Key('lab_coffee_empty_state'),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Todavía no hay cafés publicados en el catálogo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: PassportColors.textFaint),
                    ),
                  ),
                )
              else
                Column(
                  key: const Key('lab_coffee_list'),
                  children: data.catalog
                      .map(
                        (coffee) => CoffeeListTile(
                          coffee: coffee,
                          onTap: () => _openDetail(coffee),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No se pudo cargar el catálogo de café.\n$error',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
