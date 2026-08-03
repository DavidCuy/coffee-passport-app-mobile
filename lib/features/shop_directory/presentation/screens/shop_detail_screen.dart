import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/shop.dart';
import '../../domain/entities/shop_review.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../../domain/repositories/shop_repository.dart';
import '../../domain/repositories/shop_review_repository.dart';
import '../widgets/rating_stars.dart';
import '../widgets/shop_reviews_panel.dart';

/// Ficha completa de cafetería (Fase 1, sección 2 — "Directorio de
/// Barras", equivalente al "Café profile" full-screen sheet del mock
/// `pasaporte-cafe-mock.html`, aquí como pantalla normal en vez de
/// overlay porque esta app todavía no tiene un patrón de navegación
/// por sheets/overlays establecido — ver `ARCHITECTURE.md`).
///
/// Muestra: horario, beneficio activo, dirección, botón de favorito y
/// rating promedio + reseñas (`GET /shops/{id}/reviews`).
///
/// Widget keys para QA:
/// - `Key('shop_detail_screen')` — raíz (`Scaffold`).
/// - `Key('shop_detail_favorite_button')` — corazón en el AppBar.
/// - Ver `ShopReviewsPanel` para los keys de la sección de reseñas.
class ShopDetailScreen extends StatefulWidget {
  const ShopDetailScreen({
    super.key,
    required this.shopId,
    required this.shopRepository,
    required this.favoriteRepository,
    required this.shopReviewRepository,
  });

  final String shopId;
  final ShopRepository shopRepository;
  final FavoriteRepository favoriteRepository;
  final ShopReviewRepository shopReviewRepository;

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  late Future<_ShopDetailData> _future;
  bool _favoriteBusy = false;
  bool? _favoriteOverride;

  /// Promedio calculado del lado del cliente a partir de
  /// `GET /shops/{id}/reviews`, usado sólo si `shop.avgRating` no vino
  /// del backend (ver nota en `ShopRepositoryImpl._shopFromJson`).
  double? _clientAvgRating;
  int? _clientReviewCount;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<_ShopDetailData> _load() async {
    final results = await Future.wait([
      widget.shopRepository.getShopById(widget.shopId),
      widget.favoriteRepository.getFavoriteShopIds(),
    ]);
    final shop = results[0] as Shop?;
    if (shop == null) {
      throw ApiException('La cafetería no existe o ya no está disponible.');
    }
    final favoriteIds = results[1] as Set<String>;
    return _ShopDetailData(shop: shop, isFavorite: favoriteIds.contains(shop.id));
  }

  Future<void> _toggleFavorite(bool currentlyFavorite) async {
    setState(() {
      _favoriteBusy = true;
      _favoriteOverride = !currentlyFavorite;
    });
    try {
      if (currentlyFavorite) {
        await widget.favoriteRepository.removeFavorite(widget.shopId);
      } else {
        await widget.favoriteRepository.addFavorite(widget.shopId);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _favoriteOverride = currentlyFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _favoriteBusy = false);
    }
  }

  void _onReviewsChanged(List<ShopReview> reviews) {
    if (reviews.isEmpty) {
      setState(() {
        _clientAvgRating = null;
        _clientReviewCount = 0;
      });
      return;
    }
    final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) /
        reviews.length;
    setState(() {
      _clientAvgRating = avg;
      _clientReviewCount = reviews.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('shop_detail_screen'),
      backgroundColor: PassportColors.background,
      body: SafeArea(
        child: FutureBuilder<_ShopDetailData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  AppBar(
                    backgroundColor: PassportColors.background,
                    foregroundColor: PassportColors.textPrimary,
                    elevation: 0,
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No se pudo cargar la cafetería.\n${snapshot.error}',
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
                    ),
                  ),
                ],
              );
            }
            final data = snapshot.data!;
            final shop = data.shop;
            final isFavorite = _favoriteOverride ?? data.isFavorite;
            final avgRating = shop.avgRating ?? _clientAvgRating;
            final reviewCount = shop.reviewCount ?? _clientReviewCount;
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: PassportColors.background,
                  foregroundColor: PassportColors.textPrimary,
                  elevation: 0,
                  pinned: true,
                  title: Text(shop.name),
                  actions: [
                    IconButton(
                      key: const Key('shop_detail_favorite_button'),
                      onPressed: _favoriteBusy
                          ? null
                          : () => _toggleFavorite(isFavorite),
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite
                            ? PassportColors.primary
                            : PassportColors.textFaint,
                      ),
                      tooltip: isFavorite
                          ? 'Quitar de favoritos'
                          : 'Marcar como favorita',
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ShopHeader(shop: shop),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (avgRating != null) ...[
                            RatingStars(rating: avgRating),
                            const SizedBox(width: 6),
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: PassportColors.textPrimary,
                              ),
                            ),
                            if (reviewCount != null)
                              Text(
                                ' ($reviewCount reseñas)',
                                style: const TextStyle(
                                  color: PassportColors.textSecondary,
                                ),
                              ),
                          ] else
                            const Text(
                              'Sin reseñas todavía',
                              style: TextStyle(
                                color: PassportColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      if (shop.activePerkText != null &&
                          shop.activePerkText!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _PerkBanner(text: shop.activePerkText!),
                      ],
                      if (shop.description != null &&
                          shop.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          shop.description!,
                          style: const TextStyle(
                            color: PassportColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _ShopHoursSection(hoursRaw: shop.hoursRaw),
                      const SizedBox(height: 24),
                      const Divider(color: PassportColors.border),
                      const SizedBox(height: 16),
                      ShopReviewsPanel(
                        shopId: shop.id,
                        repository: widget.shopReviewRepository,
                        onReviewsChanged: _onReviewsChanged,
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ShopDetailData {
  const _ShopDetailData({required this.shop, required this.isFavorite});

  final Shop shop;
  final bool isFavorite;
}

class _ShopHeader extends StatelessWidget {
  const _ShopHeader({required this.shop});

  final Shop shop;

  String get _initials {
    final parts = shop.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: PassportColors.surface2,
            border: Border.all(color: PassportColors.border),
          ),
          alignment: Alignment.center,
          child: Text(
            _initials,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: PassportColors.primary,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shop.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: PassportColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 15,
                    color: PassportColors.textFaint,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      shop.address.isEmpty
                          ? 'Dirección no disponible'
                          : shop.address,
                      style: const TextStyle(
                        color: PassportColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PerkBanner extends StatelessWidget {
  const _PerkBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_offer_outlined,
              size: 16, color: Color(0xFF2D6A4F)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF2D6A4F),
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renderiza `Shop.hoursRaw` (JSON de forma libre, ver
/// `core_db/models/shop.py::hours_json`) de la mejor forma posible sin
/// asumir un shape fijo — un `Map` se muestra como lista `día: horario`
/// (orden de inserción del JSON, tal cual lo mande el backend); un
/// `String` se muestra literal; cualquier otro caso (incluido `null`)
/// cae en "Horario no disponible".
class _ShopHoursSection extends StatelessWidget {
  const _ShopHoursSection({required this.hoursRaw});

  final Object? hoursRaw;

  @override
  Widget build(BuildContext context) {
    final raw = hoursRaw;
    Widget body;
    if (raw is Map && raw.isNotEmpty) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: raw.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${e.key}: ${e.value}',
                  style: const TextStyle(color: PassportColors.textSecondary),
                ),
              ),
            )
            .toList(growable: false),
      );
    } else if (raw is String && raw.trim().isNotEmpty) {
      body = Text(raw, style: const TextStyle(color: PassportColors.textSecondary));
    } else {
      body = const Text(
        'Horario no disponible',
        style: TextStyle(color: PassportColors.textFaint),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.schedule_outlined, size: 16, color: PassportColors.textFaint),
            SizedBox(width: 6),
            Text(
              'Horario',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: PassportColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        body,
      ],
    );
  }
}
