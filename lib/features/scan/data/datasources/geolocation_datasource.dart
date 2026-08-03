import 'package:geolocator/geolocator.dart';

/// Excepción de dominio para fallas al obtener la posición GPS —
/// separada de [ApiException] (`core/network`) porque no tiene nada
/// que ver con el backend, sino con permisos/hardware del dispositivo.
class LocationException implements Exception {
  LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Envoltorio delgado sobre `geolocator` para capturar la posición GPS
/// que exige `POST /scan` (lat/lng del dispositivo al momento del
/// escaneo, ver `API endpoints.md` del vault).
///
/// Vive en `data/datasources` de la feature `scan` (no en `core/`)
/// porque, por ahora, sólo esta feature necesita GPS — a diferencia
/// del cliente HTTP o el auth de dev-login, que sí son transversales.
/// Si el futuro "Mapa & Directorio" también lo necesita, es candidato
/// a subir a `core/` en ese momento (ver regla en `ARCHITECTURE.md`).
class GeolocationDatasource {
  /// Resuelve permisos y regresa la posición actual del dispositivo.
  ///
  /// Lanza [LocationException] con un mensaje ya listo para mostrar en
  /// UI si el servicio de ubicación está apagado o el permiso fue
  /// denegado (incluyendo "denegado para siempre").
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        'El GPS está desactivado. Actívalo para poder sellar tu visita.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException(
          'Se necesita permiso de ubicación para validar que estás en '
          'la cafetería.',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'El permiso de ubicación fue denegado permanentemente. '
        'Actívalo desde los ajustes del sistema.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on Exception catch (e) {
      throw LocationException('No se pudo obtener tu ubicación: $e');
    }
  }
}
