import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/shop.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../../domain/repositories/shop_repository.dart';
import '../../domain/repositories/shop_review_repository.dart';
import '../widgets/shop_card.dart';
import 'shop_detail_screen.dart';

/// Lista de cafeterías favoritas del usuario (`GET /favorites`).
///
/// Widget keys para QA:
/// - `Key('favorite_shops_screen')` — raíz.
/// - `Key('favorite_shops_empty_state')` — se muestra si no hay
///   ninguna favorita todavía.
/// - Ver `ShopCard` para los keys de cada tarjeta (`shop_card_<id>`,
///   `shop_card_favorite_<id>`).
class FavoriteShopsScreen extends StatefulWidget {
  const FavoriteShopsScreen({
    super.key,
    required this.favoriteRepository,
    required this.shopRepository,
    required this.shopReviewRepository,
  });

  final FavoriteRepository favoriteRepository;
  final ShopRepository shopRepository;
  final ShopReviewRepository shopReviewRepository;

  @override
  State<FavoriteShopsScreen> createState() => _FavoriteShopsScreenState();
}

class _FavoriteShopsScreenState extends State<FavoriteShopsScreen> {
  late Future<List<Shop>> _future = widget.favoriteRepository.getFavoriteShops();

  Future<void> _refresh() async {
    final next = widget.favoriteRepository.getFavoriteShops();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _toggleFavorite(Shop shop) async {
    // Siempre "quitar" acá — esta pantalla sólo lista favoritos.
    await widget.favoriteRepository.removeFavorite(shop.id);
    await _refresh();
  }

  void _openDetail(Shop shop) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopDetailScreen(
          shopId: shop.id,
          shopRepository: widget.shopRepository,
          favoriteRepository: widget.favoriteRepository,
          shopReviewRepository: widget.shopReviewRepository,
        ),
      ),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('favorite_shops_screen'),
      backgroundColor: PassportColors.background,
      appBar: AppBar(
        title: const Text('Tus favoritas'),
        backgroundColor: PassportColors.background,
        foregroundColor: PassportColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Shop>>(
          future: _future,
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
                        'No se pudieron cargar tus favoritas.\n${snapshot.error}',
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
              return Center(
                child: Padding(
                  key: const Key('favorite_shops_empty_state'),
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Todavía no marcaste ninguna cafetería como favorita.\n'
                    'Toca el corazón en el directorio para agregarla aquí.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: PassportColors.textSecondary),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                itemCount: shops.length,
                itemBuilder: (context, index) {
                  final shop = shops[index];
                  return ShopCard(
                    shop: shop,
                    onTap: () => _openDetail(shop),
                    onToggleFavorite: () => _toggleFavorite(shop),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
