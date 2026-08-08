import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Import cruzado explícito hacia la feature `scan` — ver el comentario
// de `geolocator` en `pubspec.yaml`: `GeolocationDatasource` sigue
// viviendo en `features/scan/data/datasources/` (no se subió a
// `core/` para no romper el import literal ya usado por
// `integration_test/common/mock_location.dart`, del Agente QA
// Mobile). La regla de dependencias de `ARCHITECTURE.md` permite
// justo este caso: "el acoplamiento cruzado queda explícito porque
// requiere un import entre features (o pasar por `core/`)".
import '../../../scan/data/datasources/geolocation_datasource.dart';
import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/shop.dart';
import 'shop_card.dart';

/// Vista de mapa del directorio (Fase 1, sección 2) — equivalente a
/// `#screen-mapa` del mock (`pasaporte-cafe-mock.html`): un mapa con
/// un pin por cafetería + una hoja inferior arrastrable
/// (`DraggableScrollableSheet`, aquí en vez del `.sheet` con CSS
/// custom del mock, pero mismo comportamiento: colapsada por defecto,
/// se puede arrastrar hacia arriba para ver el directorio completo)
/// que lista las mismas cafeterías.
///
/// Usa `flutter_map` + teselas de OpenStreetMap en vez de
/// `google_maps_flutter` (hasta 2026-08-08) — esta prueba de concepto
/// no quiere depender de una API key de Google Maps (ver comentario
/// de `flutter_map` en `pubspec.yaml`). Sin key, sin config nativa
/// (Android/iOS/web), sin costo.
///
/// No incluye lógica de negocio propia — recibe [shops] ya resueltos
/// y delega toque de tarjeta / favorito a los callbacks, igual que
/// `ShopCard`.
///
/// Widget keys para QA:
/// - `Key('shop_map_view')` — raíz del `FlutterMap`.
/// - `Key('shop_map_sheet')` — hoja inferior con el directorio.
class ShopMapView extends StatefulWidget {
  const ShopMapView({
    super.key,
    required this.shops,
    this.onShopTap,
    this.onToggleFavorite,
    this.geolocationDatasource,
  });

  final List<Shop> shops;
  final ValueChanged<Shop>? onShopTap;
  final ValueChanged<Shop>? onToggleFavorite;
  final GeolocationDatasource? geolocationDatasource;

  @override
  State<ShopMapView> createState() => _ShopMapViewState();
}

class _ShopMapViewState extends State<ShopMapView> {
  static const LatLng _fallbackCenter = LatLng(4.6533, -74.0575); // Demo 1 (Chapinero)

  // Mismos valores que `initialChildSize`/`maxChildSize` del
  // `DraggableScrollableSheet` de abajo — el handle sólo alterna entre
  // esos 2 extremos (colapsada/expandida), no arrastra libre.
  static const double _sheetCollapsedSize = 0.16;
  static const double _sheetExpandedSize = 0.82;

  LatLng? _myLocation;
  final _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    // Best-effort: si no hay permiso/GPS, el mapa igual se centra en
    // la primera cafetería (o el fallback) — nunca bloquea el render
    // del mapa por un fallo de ubicación (a diferencia de `scan`, acá
    // no es una validación de negocio, sólo comodidad de UX).
    unawaited(_loadMyLocation());
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  /// El `DraggableScrollableSheet` sólo responde a gestos de arrastre
  /// (sobre su `ListView` interno) — un simple tap en la rayita del
  /// handle no hacía nada. Con el `controller` sí podemos animarla
  /// programáticamente: tap alterna entre colapsada y expandida.
  void _toggleSheet() {
    final expanded = _sheetController.size > _sheetCollapsedSize + 0.05;
    _sheetController.animateTo(
      expanded ? _sheetCollapsedSize : _sheetExpandedSize,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadMyLocation() async {
    try {
      final position = await (widget.geolocationDatasource ??
              GeolocationDatasource())
          .getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _myLocation = LatLng(position.latitude, position.longitude);
      });
    } on LocationException {
      // Silencioso a propósito — ver docstring de la clase.
    }
  }

  LatLng get _initialCenter {
    if (_myLocation != null) return _myLocation!;
    if (widget.shops.isNotEmpty) {
      final first = widget.shops.first;
      return LatLng(first.latitude, first.longitude);
    }
    return _fallbackCenter;
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[
      for (final shop in widget.shops)
        Marker(
          point: LatLng(shop.latitude, shop.longitude),
          width: 40,
          height: 40,
          child: _ShopPin(
            onTap: () => widget.onShopTap?.call(shop),
            tooltip: shop.name,
          ),
        ),
      if (_myLocation != null)
        Marker(
          point: _myLocation!,
          width: 20,
          height: 20,
          child: const _MyLocationDot(),
        ),
    ];

    return Stack(
      children: [
        FlutterMap(
          key: const Key('shop_map_view'),
          options: MapOptions(
            initialCenter: _initialCenter,
            initialZoom: 14,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // Requerido por la política de uso de tiles de OSM --
              // identifica la app que hace las requests, no una key.
              userAgentPackageName: 'com.pasaportecafe.coffee_passport_app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        DraggableScrollableSheet(
          key: const Key('shop_map_sheet'),
          controller: _sheetController,
          initialChildSize: _sheetCollapsedSize,
          minChildSize: 0.12,
          maxChildSize: _sheetExpandedSize,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: PassportColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: PassportColors.border, width: 1.5),
                ),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    key: const Key('shop_map_sheet_handle'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleSheet,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PassportColors.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Directorio',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: PassportColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${widget.shops.length} cafeterías',
                          style: const TextStyle(
                            color: PassportColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: widget.shops.length,
                      itemBuilder: (context, index) {
                        final shop = widget.shops[index];
                        return ShopCard(
                          shop: shop,
                          onTap: () => widget.onShopTap?.call(shop),
                          onToggleFavorite: widget.onToggleFavorite == null
                              ? null
                              : () => widget.onToggleFavorite!(shop),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Pin de cafetería sobre el mapa -- reemplaza al `Marker`/`InfoWindow`
/// nativo de Google Maps (`flutter_map` no trae InfoWindow, sólo un
/// `child` posicionado; el tap se maneja acá mismo).
class _ShopPin extends StatelessWidget {
  const _ShopPin({required this.onTap, required this.tooltip});

  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: const Icon(
          Icons.location_on,
          color: PassportColors.primary,
          size: 40,
        ),
      ),
    );
  }
}

/// Punto de "tu ubicación" -- equivalente al marcador azul default de
/// Google Maps.
class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A73E8),
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
