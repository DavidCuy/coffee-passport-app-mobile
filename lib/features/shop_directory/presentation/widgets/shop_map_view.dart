import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
/// `#screen-mapa` del mock (`pasaporte-cafe-mock.html`): un
/// `GoogleMap` con un pin por cafetería + una hoja inferior
/// arrastrable (`DraggableScrollableSheet`, aquí en vez del `.sheet`
/// con CSS custom del mock, pero mismo comportamiento: colapsada por
/// defecto, se puede arrastrar hacia arriba para ver el directorio
/// completo) que lista las mismas cafeterías.
///
/// No incluye lógica de negocio propia — recibe [shops] ya resueltos
/// y delega toque de tarjeta / favorito a los callbacks, igual que
/// `ShopCard`.
///
/// Widget keys para QA:
/// - `Key('shop_map_view')` — raíz del `GoogleMap`.
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

  LatLng? _myLocation;

  @override
  void initState() {
    super.initState();
    // Best-effort: si no hay permiso/GPS, el mapa igual se centra en
    // la primera cafetería (o el fallback) — nunca bloquea el render
    // del mapa por un fallo de ubicación (a diferencia de `scan`, acá
    // no es una validación de negocio, sólo comodidad de UX).
    unawaited(_loadMyLocation());
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
    final markers = <Marker>{
      for (final shop in widget.shops)
        Marker(
          markerId: MarkerId(shop.id),
          position: LatLng(shop.latitude, shop.longitude),
          infoWindow: InfoWindow(
            title: shop.name,
            snippet: shop.address,
            onTap: () => widget.onShopTap?.call(shop),
          ),
          onTap: () => widget.onShopTap?.call(shop),
        ),
      if (_myLocation != null)
        Marker(
          markerId: const MarkerId('__me__'),
          position: _myLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'Tu ubicación'),
        ),
    };

    return Stack(
      children: [
        GoogleMap(
          key: const Key('shop_map_view'),
          initialCameraPosition: CameraPosition(
            target: _initialCenter,
            zoom: 14,
          ),
          markers: markers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
        DraggableScrollableSheet(
          key: const Key('shop_map_sheet'),
          initialChildSize: 0.16,
          minChildSize: 0.12,
          maxChildSize: 0.82,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: PassportColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 12,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: PassportColors.border,
                      borderRadius: BorderRadius.circular(999),
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

