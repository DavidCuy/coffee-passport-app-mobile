import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../../shop_directory/domain/entities/shop.dart';
import '../../../shop_directory/domain/repositories/shop_repository.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/repositories/diary_repository.dart';
import '../widgets/diary_entry_card.dart';
import 'diary_entry_form_screen.dart';

/// Pantalla real del Diario de cata (Fase 1, sección 4 del vault de
/// producto): lista de entradas del usuario, más recientes primero
/// (`GET /diary`, ver `DiaryRepositoryImpl` para el criterio de orden),
/// con acceso a crear/editar (`DiaryEntryFormScreen`) y borrar
/// (`DELETE /diary/{id}`, con confirmación explícita).
///
/// Cruza `id_shop` contra `ShopRepository.getShops()` de
/// `shop_directory` para resolver el nombre de la cafetería cuando el
/// backend no lo trae ya anidado (`DiaryEntry.shopName`) — import
/// cruzado explícito entre features, caso contemplado por
/// `ARCHITECTURE.md`. También se usa esa misma lista para poblar el
/// selector de cafetería del formulario, sin pedirla dos veces.
///
/// Widget keys para QA:
/// - `Key('diary_screen')` — raíz.
/// - `Key('diary_add_entry_button')` — abre el formulario en modo
///   "crear" (equivalente al `#diaryToggle` del mock).
/// - `Key('diary_empty_state')` — se muestra si no hay ninguna entrada.
/// - Ver `DiaryEntryCard` para los keys de cada tarjeta
///   (`diary_entry_card_<id>`, `diary_entry_edit_button_<id>`,
///   `diary_entry_delete_button_<id>`).
/// - `Key('diary_delete_confirm_dialog')` — diálogo de confirmación de
///   borrado, con `Key('diary_delete_confirm_button')` /
///   `Key('diary_delete_cancel_button')`.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({
    super.key,
    required this.diaryRepository,
    required this.shopRepository,
  });

  final DiaryRepository diaryRepository;
  final ShopRepository shopRepository;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryData {
  const _DiaryData({required this.entries, required this.shops});

  final List<DiaryEntry> entries;
  final List<Shop> shops;
}

class _DiaryScreenState extends State<DiaryScreen> {
  late Future<_DiaryData> _future = _load();

  Future<_DiaryData> _load() async {
    final results = await Future.wait([
      widget.diaryRepository.getEntries(),
      widget.shopRepository.getShops(),
    ]);
    return _DiaryData(
      entries: results[0] as List<DiaryEntry>,
      shops: results[1] as List<Shop>,
    );
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _openForm({DiaryEntry? existing, required List<Shop> shops}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DiaryEntryFormScreen(
          diaryRepository: widget.diaryRepository,
          shops: shops,
          existing: existing,
        ),
      ),
    );
    if (saved == true) {
      await _refresh();
    }
  }

  Future<void> _confirmDelete(DiaryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('diary_delete_confirm_dialog'),
        title: const Text('Borrar entrada'),
        content: const Text(
          '¿Seguro que quieres borrar esta entrada del diario? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            key: const Key('diary_delete_cancel_button'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const Key('diary_delete_confirm_button'),
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB91C1C),
            ),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.diaryRepository.deleteEntry(entry.id);
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  String _shopName(DiaryEntry entry, Map<String, Shop> shopsById) {
    if (entry.shopName != null && entry.shopName!.trim().isNotEmpty) {
      return entry.shopName!;
    }
    return shopsById[entry.shopId]?.name ?? 'Cafetería #${entry.shopId}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('diary_screen'),
      backgroundColor: PassportColors.background,
      appBar: AppBar(
        title: const Text('Diario de cata'),
        backgroundColor: PassportColors.background,
        foregroundColor: PassportColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<_DiaryData>(
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
                        'No se pudo cargar tu diario.\n${snapshot.error}',
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
            final data = snapshot.data ?? const _DiaryData(entries: [], shops: []);
            final shopsById = {for (final s in data.shops) s.id: s};
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Registra qué tomaste, cómo lo preparaste y qué te pareció.',
                    style: const TextStyle(color: PassportColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('diary_add_entry_button'),
                      onPressed: () => _openForm(shops: data.shops),
                      style: FilledButton.styleFrom(
                        backgroundColor: PassportColors.primary,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Nueva entrada'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (data.entries.isEmpty)
                    Padding(
                      key: const Key('diary_empty_state'),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Todavía no tienes entradas en tu diario.\n'
                          'Registra tu primer café con "Nueva entrada".',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: PassportColors.textFaint),
                        ),
                      ),
                    )
                  else
                    ...data.entries.map(
                      (entry) => DiaryEntryCard(
                        entry: entry,
                        shopName: _shopName(entry, shopsById),
                        onEdit: () => _openForm(existing: entry, shops: data.shops),
                        onDelete: () => _confirmDelete(entry),
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
