// Fake de GPS para los casos SCAN-01/02/03 de
// test/e2e/test-matrices/pasaporte-y-scan.md.
//
// Agente QA Mobile — segunda pasada, 2026-07-30. El Agente Mobile
// confirmó (ver nota anterior de este archivo en la primera pasada) que
// `ScanScreen` (lib/features/scan/presentation/screens/scan_screen.dart)
// ya acepta un `GeolocationDatasource?` opcional por constructor —
// exactamente la opción (a) que este agente prefería. Implementado acá
// extendiendo la clase concreta y sobreescribiendo `getCurrentPosition()`
// para regresar coordenadas fijas y determinísticas, sin tocar nada del
// SO/emulador ni requerir permisos reales.
//
// Límite conocido (documentado por el Agente Mobile, no resuelto):
// `CoffeePassportApp`/`_HomeTabs` (main.dart) arman `ScanScreen`
// internamente sin exponer este parámetro hacia afuera. Por eso los
// tests de escaneo (`scan_flow_test.dart`) pumpean `ScanScreen`
// directamente (con su propio `ScanRepositoryImpl` real apuntando al
// backend real) en vez de navegar ahí desde `CoffeePassportApp` — se
// pierde la cobertura del tab de navegación (`nav_scan_tab`), pero se
// gana determinismo total de GPS sin depender de un emulador/dispositivo
// real. El tab en sí ya está cubierto indirectamente:
// `test/widget_test.dart` (del Agente Mobile) navega a él y confirma que
// `scan_qr_manual_input`/`scan_submit_button` aparecen.

import 'package:coffee_passport_app/features/scan/data/datasources/geolocation_datasource.dart';
import 'package:geolocator/geolocator.dart';

/// [GeolocationDatasource] fake que siempre regresa la misma posición,
/// sin tocar permisos ni servicios de ubicación reales.
class FakeGeolocationDatasource extends GeolocationDatasource {
  FakeGeolocationDatasource({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  Future<Position> getCurrentPosition() async {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}
