import 'package:flutter/material.dart';

import 'dev_auth_local_datasource.dart';

/// ⚠️ TEMPORAL / SOLO DESARROLLO ⚠️
///
/// Pantalla mínima de "dev login": mientras no exista login real
/// (Cognito + gateway, ver `Deploy en producción.md` en el vault), el
/// usuario escribe aquí un `sub` de prueba en texto libre (ej.
/// `dev-user-local`) una sola vez. Se guarda localmente vía
/// [DevAuthLocalDatasource] y de ahí en adelante viaja como header
/// `X-Auth-User-Sub` en cada request al backend (ver
/// `lib/core/network/api_client.dart`).
///
/// A reemplazar por completo cuando exista el login real — no es una
/// pantalla de producto, es un atajo de desarrollo explícitamente
/// marcado como tal en el nombre del archivo y en este comentario.
class DevLoginScreen extends StatefulWidget {
  const DevLoginScreen({
    super.key,
    required this.datasource,
    required this.onLoggedIn,
  });

  final DevAuthLocalDatasource datasource;

  /// Se invoca con el `sub` guardado en cuanto el usuario confirma.
  final ValueChanged<String> onLoggedIn;

  @override
  State<DevLoginScreen> createState() => _DevLoginScreenState();
}

class _DevLoginScreenState extends State<DevLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController(text: 'dev-user-local');
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final sub = _controller.text.trim();
    await widget.datasource.saveDevSub(sub);
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onLoggedIn(sub);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dev login (temporal)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Todavía no hay login real (Cognito + gateway). '
                  'Escribe un identificador de prueba (sub) — se manda '
                  'como header X-Auth-User-Sub en cada request al '
                  'backend mientras dure el desarrollo.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('dev_login_sub_input'),
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Sub de prueba',
                    hintText: 'dev-user-local',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa un identificador de prueba.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('dev_login_submit_button'),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continuar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
