import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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
/// Header con foto de portada a pantalla completa (`shop.photoUrl`,
/// placeholder flat si no hay), nombre/dirección superpuestos, pill
/// "Abierto ahora"/"Cerrado" calculado del lado del cliente contra
/// `shop.hoursRaw` (ver `_computeOpenNow`), fila de acciones
/// Favorito/Calificar/Compartir, y debajo el resto de la ficha sin
/// cambios: rating, beneficio activo, descripción, horario y reseñas
/// (`GET /shops/{id}/reviews`).
///
/// Widget keys para QA:
/// - `Key('shop_detail_screen')` — raíz (`Scaffold`).
/// - `Key('shop_detail_favorite_button')` — corazón en la fila de
///   acciones (antes vivía en el AppBar -- se movió acá al quitar el
///   `SliverAppBar` por el header de foto).
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
  final _reviewsPanelKey = GlobalKey<ShopReviewsPanelState>();

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

  /// Handler del botón "Calificar" de la fila de acciones -- abre el
  /// formulario que ya vive dentro de `ShopReviewsPanel` (no duplica
  /// lógica de reseña acá) y lo hace visible en pantalla.
  void _openReviewForm() {
    _reviewsPanelKey.currentState?.openWriteForm();
    final panelContext = _reviewsPanelKey.currentContext;
    if (panelContext != null) {
      Scrollable.ensureVisible(
        panelContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Handler del botón/ícono "Compartir" -- sin link web/deep-link
  /// público por cafetería todavía (ver docstring de `pubspec.yaml`),
  /// comparte sólo texto plano.
  void _share(Shop shop) {
    SharePlus.instance.share(
      ShareParams(text: '${shop.name} — ${shop.address}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('shop_detail_screen'),
      backgroundColor: PassportColors.background,
      body: FutureBuilder<_ShopDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SafeArea(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return SafeArea(
              child: Column(
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
              ),
            );
          }
          final data = snapshot.data!;
          final shop = data.shop;
          final isFavorite = _favoriteOverride ?? data.isFavorite;
          // Prioriza el promedio recalculado en vivo por
          // `ShopReviewsPanel` (`_onReviewsChanged`, ver arriba) sobre
          // el de `shop.avgRating` (snapshot tomado cuando se abrió
          // la ficha, vía `_load()`): el panel se refresca solo tras
          // cada mutación (crear/editar/borrar reseña), pero esta
          // pantalla no vuelve a pedir `GET /shops/{id}` en ese
          // momento — con la prioridad al revés, el promedio quedaba
          // congelado en el valor inicial para siempre. Bug real
          // encontrado por QA Mobile (caso REV-09): "3 de cada 5" no
          // se actualizaba después de editar la calificación propia,
          // aunque el backend sí recalculaba bien.
          final avgRating = _clientAvgRating ?? shop.avgRating;
          final reviewCount = _clientReviewCount ?? shop.reviewCount;
          // `top: false` -- el header de foto sangra hasta el borde
          // superior de pantalla (por fuera del safe area) y maneja su
          // propio padding contra el notch/status bar (ver
          // `_ShopPhotoHeader`); el resto del contenido sí respeta el
          // safe area inferior normal (home indicator, etc).
          return SafeArea(
            top: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ShopPhotoHeader(shop: shop, onShare: () => _share(shop)),
                ),
                SliverToBoxAdapter(
                  child: _ShopActionButtons(
                    isFavorite: isFavorite,
                    favoriteBusy: _favoriteBusy,
                    onFavoriteTap: () => _toggleFavorite(isFavorite),
                    onRateTap: _openReviewForm,
                    onShareTap: () => _share(shop),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
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
                        key: _reviewsPanelKey,
                        shopId: shop.id,
                        repository: widget.shopReviewRepository,
                        onReviewsChanged: _onReviewsChanged,
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShopDetailData {
  const _ShopDetailData({required this.shop, required this.isFavorite});

  final Shop shop;
  final bool isFavorite;
}

/// Header de foto de portada a pantalla completa (~280px), sangrado hasta
/// el borde superior de pantalla (por eso lee `MediaQuery` a mano en vez
/// de depender de un `SafeArea` ancestro para el padding de la fila
/// back/compartir). Reemplaza al viejo `_ShopHeader` (avatar+nombre) --
/// nombre/dirección ahora se superponen sobre la foto.
class _ShopPhotoHeader extends StatelessWidget {
  const _ShopPhotoHeader({required this.shop, required this.onShare});

  final Shop shop;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final isOpen = _computeOpenNow(shop.hoursRaw);
    return SizedBox(
      height: 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (shop.photoUrl != null && shop.photoUrl!.trim().isNotEmpty)
            Image.network(
              shop.photoUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const _ShopPhotoPlaceholder(),
              errorBuilder: (context, error, stackTrace) =>
                  const _ShopPhotoPlaceholder(),
            )
          else
            const _ShopPhotoPlaceholder(),
          // Scrim funcional (no decorativo) para legibilidad del texto
          // superpuesto -- confinado al ~45% inferior, no un gradiente de
          // marca. Ver nota en el plan sobre la regla anti-gradiente.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.55, 1.0],
                colors: [Colors.transparent, Color(0xB3000000)],
              ),
            ),
          ),
          Positioned(
            top: topPadding + 8,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HeaderIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Volver',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                _HeaderIconButton(
                  icon: Icons.share_outlined,
                  tooltip: 'Compartir',
                  onTap: onShare,
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOpen != null) ...[
                  _OpenStatusPill(isOpen: isOpen),
                  const SizedBox(height: 8),
                ],
                Text(
                  shop.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 15, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        shop.address.isEmpty
                            ? 'Dirección no disponible'
                            : shop.address,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder flat cuando no hay `photoUrl` (o la imagen falla/expira) --
/// fondo sólido + ícono, mismo lenguaje visual que los avatares
/// circulares de `ShopCard`. Sin asset empaquetado a propósito (ver nota
/// del plan).
class _ShopPhotoPlaceholder extends StatelessWidget {
  const _ShopPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PassportColors.surface2,
      alignment: Alignment.center,
      child: const Icon(
        Icons.local_cafe_outlined,
        size: 56,
        color: PassportColors.textFaint,
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
      ),
    );
  }
}

class _OpenStatusPill extends StatelessWidget {
  const _OpenStatusPill({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFF2D6A4F) : const Color(0xFF7A7A7A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOpen ? 'Abierto ahora' : 'Cerrado',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Fila de acciones circulares (Favorito/Calificar/Compartir), mismo
/// lenguaje visual que los avatares circulares 44px de `ShopCard`.
class _ShopActionButtons extends StatelessWidget {
  const _ShopActionButtons({
    required this.isFavorite,
    required this.favoriteBusy,
    required this.onFavoriteTap,
    required this.onRateTap,
    required this.onShareTap,
  });

  final bool isFavorite;
  final bool favoriteBusy;
  final VoidCallback onFavoriteTap;
  final VoidCallback onRateTap;
  final VoidCallback onShareTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            buttonKey: const Key('shop_detail_favorite_button'),
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            label: 'Favorito',
            active: isFavorite,
            onTap: favoriteBusy ? null : onFavoriteTap,
          ),
          _ActionButton(
            icon: Icons.star_border,
            label: 'Calificar',
            active: false,
            onTap: onRateTap,
          ),
          _ActionButton(
            icon: Icons.share_outlined,
            label: 'Compartir',
            active: false,
            onTap: onShareTap,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    this.buttonKey,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  /// Key del `InkWell` tappable en sí -- **no** del `Column` completo
  /// (ícono + label). Un `WidgetTester.tap()` golpea el centro geométrico
  /// del widget encontrado por key; con label debajo, ese centro cae
  /// fuera del círculo tappable (mismo bug #7 ya documentado en
  /// `PassportScreen._ViewToggle`, no repetirlo acá).
  final Key? buttonKey;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          key: buttonKey,
          color: active ? PassportColors.primary : PassportColors.surface2,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                icon,
                size: 22,
                color: active ? Colors.white : PassportColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: PassportColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Calcula "abierto ahora" contra `shop.hoursRaw` (JSON de forma libre,
/// ver `_ShopHoursSection`) para el pill del header. Best-effort: sólo
/// entiende 2 formas conocidas de valor por día -- objeto
/// `{closed, open, close}` (shape que manda el dashboard, ver
/// `WeeklyHoursEditor`/`ShopProfileInput.hours` del portal) o string
/// `"HH:MM-HH:MM"`. Cualquier otra forma, o si no hay entrada para el día
/// actual, regresa `null` (desconocido) -- el pill se oculta en vez de
/// mostrar un estado adivinado.
bool? _computeOpenNow(Object? hoursRaw) {
  if (hoursRaw is! Map || hoursRaw.isEmpty) return null;

  const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  final todayKey = dayKeys[DateTime.now().weekday - 1];
  final entry = hoursRaw[todayKey];
  if (entry == null) return null;

  if (entry is Map) {
    if (entry['closed'] == true) return false;
    final openMinutes = _parseHm(entry['open']);
    final closeMinutes = _parseHm(entry['close']);
    if (openMinutes == null || closeMinutes == null) return null;
    return _minutesNowBetween(openMinutes, closeMinutes);
  }

  if (entry is String) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$')
        .firstMatch(entry.trim());
    if (match == null) return null;
    final openMinutes = int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
    final closeMinutes = int.parse(match.group(3)!) * 60 + int.parse(match.group(4)!);
    return _minutesNowBetween(openMinutes, closeMinutes);
  }

  return null;
}

int? _parseHm(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
}

bool _minutesNowBetween(int openMinutes, int closeMinutes) {
  if (closeMinutes <= openMinutes) return false; // rango inválido/overnight, no soportado
  final now = TimeOfDay.now();
  final nowMinutes = now.hour * 60 + now.minute;
  return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
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
