import 'package:flutter/material.dart';

import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../data/datasources/geolocation_datasource.dart';
import '../../domain/entities/scan_outcome.dart';
import '../../domain/repositories/scan_repository.dart';

/// Pantalla real de "Mecanismo de Sello" (Fase 1, sección 3 del vault).
///
/// Vía principal de prueba hoy: pegar manualmente el string del QR
/// (no hay QRs físicos impresos todavía, ver `Agente Mobile.md`). Al
/// enviar, captura GPS con `geolocator` y llama `POST /scan` con el
/// string + lat/lng.
///
/// Widget keys obligatorios para QA:
/// - `Key('scan_qr_manual_input')` — campo de texto del QR pegado.
/// - `Key('scan_submit_button')` — botón de envío.
/// - `Key('scan_result_banner')` — banner de resultado; el texto
///   visible distingue: éxito nuevo sello, `already_stamped`, fuera de
///   rango (con distancia si el backend la da), firma inválida,
///   cafetería no encontrada, rate-limit y errores de red/GPS.
class ScanScreen extends StatefulWidget {
  ScanScreen({super.key, required this.repository, GeolocationDatasource? geolocationDatasource})
    : geolocationDatasource = geolocationDatasource ?? GeolocationDatasource();

  final ScanRepository repository;
  final GeolocationDatasource geolocationDatasource;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  ScanOutcome? _lastOutcome;
  String? _clientError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qrPayload = _controller.text.trim();
    if (qrPayload.isEmpty) {
      setState(() {
        _clientError = 'Pega o escribe el contenido del QR antes de enviar.';
        _lastOutcome = null;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _clientError = null;
      _lastOutcome = null;
    });

    try {
      final position = await widget.geolocationDatasource
          .getCurrentPosition();
      final outcome = await widget.repository.submitScan(
        qrPayload: qrPayload,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() => _lastOutcome = outcome);
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() => _clientError = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PassportColors.background,
      appBar: AppBar(
        title: const Text('Sella tu visita'),
        backgroundColor: PassportColors.background,
        foregroundColor: PassportColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Actívalo solo cuando estés en el mostrador de la '
                'cafetería. Todavía no hay QRs físicos impresos: pega '
                'aquí el string del QR para probar el flujo.',
                style: TextStyle(color: PassportColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('scan_qr_manual_input'),
                controller: _controller,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Contenido del QR',
                  hintText: 'Pega aquí el string del código QR…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('scan_submit_button'),
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: PassportColors.primary,
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.qr_code_2),
                label: Text(_submitting ? 'Enviando…' : 'Escanear código'),
              ),
              const SizedBox(height: 20),
              if (_clientError != null)
                _ResultBanner.error(_clientError!)
              else if (_lastOutcome != null)
                _ResultBanner.fromOutcome(_lastOutcome!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner con el resultado del último intento de escaneo.
///
/// El texto visible es la fuente de verdad para QA — cada caso del
/// enum `scan_result` (más los errores de cliente) tiene una copia
/// distinta y reconocible.
class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.text,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  factory _ResultBanner.error(String message) => _ResultBanner(
    text: message,
    background: const Color(0xFFFEE2E2), // Error/Peligro (fondo)
    foreground: const Color(0xFFB91C1C), // Error/Peligro
    icon: Icons.error_outline,
  );

  factory _ResultBanner.fromOutcome(ScanOutcome outcome) {
    switch (outcome.type) {
      case ScanResultType.success:
        return _ResultBanner(
          text:
              '¡Nuevo sello desbloqueado${outcome.shopName != null ? ' en ${outcome.shopName}' : ''}! '
              'Se agregó a tu pasaporte.',
          background: const Color(0xFFE8F5E9), // Éxito (fondo)
          foreground: const Color(0xFF2D6A4F), // Éxito
          icon: Icons.check_circle_outline,
        );
      case ScanResultType.alreadyStamped:
        return _ResultBanner(
          text:
              'Ya tenías el sello de'
              '${outcome.shopName != null ? ' ${outcome.shopName}' : ' esta cafetería'}'
              ' — no se necesita volver a escanear.',
          background: const Color(0xFFEFF6FF), // Información (fondo)
          foreground: const Color(0xFF2563EB), // Información
          icon: Icons.info_outline,
        );
      case ScanResultType.outOfRange:
        final distance = outcome.distanceMeters;
        return _ResultBanner(
          text: distance != null
              ? 'Estás fuera de rango: a ${distance.round()} m de la '
                    'cafetería. Acércate e inténtalo de nuevo.'
              : 'Estás fuera del rango permitido de la cafetería. '
                    'Acércate e inténtalo de nuevo.',
          background: const Color(0xFFFEF3C7), // Advertencia (fondo)
          foreground: const Color(0xFFD97706), // Advertencia
          icon: Icons.location_off_outlined,
        );
      case ScanResultType.invalidSignature:
        return _ResultBanner(
          text:
              'El código QR no es válido (firma inválida). Puede estar '
              'dañado o alterado — pide un código nuevo.',
          background: const Color(0xFFFEE2E2),
          foreground: const Color(0xFFB91C1C),
          icon: Icons.gpp_bad_outlined,
        );
      case ScanResultType.shopNotFound:
        return _ResultBanner(
          text: 'No encontramos ninguna cafetería asociada a ese código QR.',
          background: const Color(0xFFFEE2E2),
          foreground: const Color(0xFFB91C1C),
          icon: Icons.storefront_outlined,
        );
      case ScanResultType.rateLimited:
        return _ResultBanner(
          text:
              'Hiciste demasiados intentos de escaneo en poco tiempo. '
              'Espera un momento y vuelve a intentarlo.',
          background: const Color(0xFFFEF3C7),
          foreground: const Color(0xFFD97706),
          icon: Icons.hourglass_empty,
        );
      case ScanResultType.networkError:
        return _ResultBanner(
          text:
              outcome.message ??
              'No se pudo conectar con el backend. Revisa tu conexión '
                  'e inténtalo de nuevo.',
          background: const Color(0xFFFEE2E2),
          foreground: const Color(0xFFB91C1C),
          icon: Icons.wifi_off,
        );
      case ScanResultType.unknownError:
        return _ResultBanner(
          text:
              outcome.message ??
              'Ocurrió un error inesperado al validar el escaneo.',
          background: const Color(0xFFFEE2E2),
          foreground: const Color(0xFFB91C1C),
          icon: Icons.error_outline,
        );
    }
  }

  final String text;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('scan_result_banner'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
