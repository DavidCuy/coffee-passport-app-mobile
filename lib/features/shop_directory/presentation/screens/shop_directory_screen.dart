import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/shop.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../../domain/repositories/shop_repository.dart';
import '../../domain/repositories/shop_review_repository.dart';
import '../widgets/shop_card.dart';
import '../widgets/shop_map_view.dart';
import 'favorite_shops_screen.dart';
import 'shop_detail_screen.dart';

enum ShopViewMode { list, map }

/// Pantalla real de "Mapa & Directorio de Barras" (Fase 1, sección 2
/// del vault): combina `GET /shops` (lista + mapa), `GET /favorites`
/// (corazones + acceso a `FavoriteShopsScreen`) y la ficha completa de
/// cafetería (`ShopDetailScreen`, con horario/perk/rating/reseñas).
///
/// Widget keys obligatorios para QA:
/// - `Key('shop_view_toggle_list_button')` / `Key('shop_view_toggle_map_button')`
///   — mismo patrón de 2 botones individuales que
///   `PassportScreen._ViewToggle` (ver bug #7 de QA Mobile: nunca un
///   único key envolviendo ambos botones).
/// - `Key('shop_favorites_action_button')` — ícono de corazón en el
///   `AppBar` que navega a `FavoriteShopsScreen`.
/// - `Key('shop_directory_list_view')` — `ListView` del modo lista.
/// - Ver `ShopCard`/`ShopMapView` para el resto de keys (dinámicos por
///   `shop.id` en el caso de `ShopCard`).
class ShopDirectoryScreen extends StatefulWidget {
  const ShopDirectoryScreen({
    super.key,
    required this.shopRepository,
    required this.favoriteRepository,
    required this.shopReviewRepository,
  });

  final ShopRepository shopRepository;
  final FavoriteRepository favoriteRepository;
  final ShopReviewRepository shopReviewRepository;

  @override
  State<ShopDirectoryScreen> createState() => _ShopDirectoryScreenState();
}

class _ShopDirectoryScreenState extends State<ShopDirectoryScreen> {
  ShopViewMode _mode = ShopViewMode.list;
  late Future<List<Shop>> _shopsFuture = _load();
  Set<String> _favoriteIds = {};
  bool _favoriteBusy = false;

  Future<List<Shop>> _load() async {
    final results = await Future.wait([
      widget.shopRepository.getShops(),
      widget.favoriteRepository.getFavoriteShopIds(),
    ]);
    final shops = results[0] as List<Shop>;
    _favoriteIds = results[1] as Set<String>;
    return shops
        .map((s) => s.copyWith(isFavorite: _favoriteIds.contains(s.id)))
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _shopsFuture = next;
    });
    await next;
  }

  Future<void> _toggleFavorite(Shop shop) async {
    if (_favoriteBusy) return;
    setState(() => _favoriteBusy = true);
    final wasFavorite = shop.isFavorite;
    try {
      if (wasFavorite) {
        await widget.favoriteRepository.removeFavorite(shop.id);
      } else {
        await widget.favoriteRepository.addFavorite(shop.id);
      }
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  void _openDetail(Shop shop) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ShopDetailScreen(
              shopId: shop.id,
              shopRepository: widget.shopRepository,
              favoriteRepository: widget.favoriteRepository,
              shopReviewRepository: widget.shopReviewRepository,
            ),
          ),
        )
        .then((_) => _refresh());
  }

  void _openFavorites() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => FavoriteShopsScreen(
              favoriteRepository: widget.favoriteRepository,
              shopRepository: widget.shopRepository,
              shopReviewRepository: widget.shopReviewRepository,
            ),
          ),
        )
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassportColors.background,
      appBar: AppBar(
        title: const Text('Cafeterías'),
        backgroundColor: PassportColors.background,
        foregroundColor: PassportColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            key: const Key('shop_favorites_action_button'),
            onPressed: _openFavorites,
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Tus favoritas',
          ),
          _ViewToggle(
            mode: _mode,
            onChanged: (mode) => setState(() => _mode = mode),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Shop>>(
          future: _shopsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No se pudo cargar el directorio.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final shops = snapshot.data ?? const [];
            if (shops.isEmpty) {
              return const Center(child: Text('Todavía no hay cafeterías.'));
            }
            if (_mode == ShopViewMode.map) {
              return ShopMapView(
                shops: shops,
                onShopTap: _openDetail,
                onToggleFavorite: _toggleFavorite,
              );
            }
            final favoriteCount = shops.where((s) => s.isFavorite).length;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                key: const Key('shop_directory_list_view'),
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  _DirectoryHero(
                    totalShops: shops.length,
                    favoriteCount: favoriteCount,
                  ),
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Mis cafeterías',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: PassportColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: PassportColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: PassportColors.textPrimary.withValues(
                            alpha: 0.06,
                          ),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < shops.length; i++) ...[
                          if (i != 0) const SizedBox(height: 10),
                          ShopCard(
                            shop: shops[i],
                            showBackground: false,
                            onTap: () => _openDetail(shops[i]),
                            onToggleFavorite: () => _toggleFavorite(shops[i]),
                          ),
                        ],
                      ],
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

/// Encabezado grande con el resumen del directorio (equivalente al
/// "balance" del mock de referencia dado por el cliente): fondo sólido
/// `--primary` (sin gradiente, ver regla anti-patrón del proyecto) con
/// el total de cafeterías en tipografía grande y el conteo de
/// favoritas debajo.
class _DirectoryHero extends StatelessWidget {
  const _DirectoryHero({required this.totalShops, required this.favoriteCount});

  final int totalShops;
  final int favoriteCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PassportColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Directorio',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$totalShops',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'cafeterías',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            favoriteCount == 0
                ? 'Ninguna en tus favoritas todavía'
                : '$favoriteCount en tus favoritas',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.mode, required this.onChanged});

  final ShopViewMode mode;
  final ValueChanged<ShopViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: PassportColors.surface2,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            key: const Key('shop_view_toggle_list_button'),
            icon: Icons.view_list_outlined,
            selected: mode == ShopViewMode.list,
            onTap: () => onChanged(ShopViewMode.list),
            semanticLabel: 'Vista de lista',
          ),
          _ToggleButton(
            key: const Key('shop_view_toggle_map_button'),
            icon: Icons.map_outlined,
            selected: mode == ShopViewMode.map,
            onTap: () => onChanged(ShopViewMode.map),
            semanticLabel: 'Vista de mapa',
          ),
        ],
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
            color: selected ? PassportColors.primary : PassportColors.textFaint,
          ),
        ),
      ),
    );
  }
}
