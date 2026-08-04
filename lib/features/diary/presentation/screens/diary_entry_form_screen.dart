import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../../shop_directory/domain/entities/shop.dart';
import '../../../shop_directory/presentation/widgets/rating_stars.dart';
import '../../../../core/brew/brew_method.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/repositories/diary_repository.dart';
import '../widgets/brew_method_chip_row.dart';

/// Formulario de crear/editar una entrada del Diario de cata —
/// equivalente al `.diary-form`/`#diaryForm` del mock
/// (`pasaporte-cafe-mock.html`), como pantalla completa en vez de un
/// panel expandible inline (mejor encaje con `Navigator`/testing E2E
/// por pantalla, mismo criterio de composición que `ShopDetailScreen`
/// en vez de un modal).
///
/// Hace `Navigator.pop(true)` al guardar con éxito (para que
/// `DiaryScreen` sepa que debe refrescar), o `Navigator.pop()`/back sin
/// valor al cancelar.
///
/// Widget keys para QA:
/// - `Key('diary_form_screen')` — raíz (`Scaffold`).
/// - `Key('diary_form_shop_dropdown')` — selector de cafetería.
/// - Ver `BrewMethodChipRow` para los keys de método
///   (`diary_form_method_chip_<valor>`).
/// - Ver `RatingSelector` (reutilizado, `keyPrefix: 'diary_form_star'`)
///   para los keys de calificación (`diary_form_star_1`..`_5`).
/// - `Key('diary_form_visited_at_button')` — abre el date picker.
/// - `Key('diary_form_note_input')` — campo de notas de cata.
/// - `Key('diary_form_error_text')` — mensaje de validación/error de
///   red, cuando aplica.
/// - `Key('diary_form_cancel_button')` / `Key('diary_form_submit_button')`.
class DiaryEntryFormScreen extends StatefulWidget {
  const DiaryEntryFormScreen({
    super.key,
    required this.diaryRepository,
    required this.shops,
    this.existing,
  });

  final DiaryRepository diaryRepository;

  /// Cafeterías disponibles para el selector — `DiaryScreen` ya las
  /// tenía cargadas (`ShopRepository.getShops()`) para resolver los
  /// nombres de la lista, así que se reusan acá en vez de pedirlas de
  /// nuevo.
  final List<Shop> shops;

  /// `null` = modo "crear". No-`null` = modo "editar" (pre-llena el
  /// formulario).
  final DiaryEntry? existing;

  @override
  State<DiaryEntryFormScreen> createState() => _DiaryEntryFormScreenState();
}

class _DiaryEntryFormScreenState extends State<DiaryEntryFormScreen> {
  String? _shopId;
  BrewMethod? _method;
  int _rating = 0;
  late final TextEditingController _noteController;
  DateTime _visitedAt = DateTime.now();
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _shopId = existing?.shopId ?? (widget.shops.isNotEmpty ? widget.shops.first.id : null);
    _method = existing?.brewMethod;
    _rating = existing?.rating ?? 0;
    _noteController = TextEditingController(text: existing?.note ?? '');
    _visitedAt = existing?.visitedAt ?? existing?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _visitedAt = picked);
    }
  }

  Future<void> _submit() async {
    if (_shopId == null) {
      setState(() => _error = 'Elige una cafetería.');
      return;
    }
    if (_method == null) {
      setState(() => _error = 'Elige un método de extracción.');
      return;
    }
    if (_rating == 0) {
      setState(() => _error = 'Elige una calificación de 1 a 5 estrellas.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final note = _noteController.text.trim();
    try {
      if (_isEditing) {
        await widget.diaryRepository.updateEntry(
          id: widget.existing!.id,
          shopId: _shopId!,
          brewMethod: _method!,
          rating: _rating,
          note: note.isEmpty ? null : note,
          visitedAt: _visitedAt,
        );
      } else {
        await widget.diaryRepository.createEntry(
          shopId: _shopId!,
          brewMethod: _method!,
          rating: _rating,
          note: note.isEmpty ? null : note,
          visitedAt: _visitedAt,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String get _dateLabel {
    final d = _visitedAt;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('diary_form_screen'),
      backgroundColor: PassportColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar entrada' : 'Nueva entrada'),
        backgroundColor: PassportColors.background,
        foregroundColor: PassportColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel('Cafetería'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: const Key('diary_form_shop_dropdown'),
                initialValue: _shopId,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: widget.shops
                    .map(
                      (shop) => DropdownMenuItem(
                        value: shop.id,
                        child: Text(shop.name),
                      ),
                    )
                    .toList(),
                onChanged: widget.shops.isEmpty
                    ? null
                    : (value) => setState(() => _shopId = value),
              ),
              const SizedBox(height: 16),
              _FieldLabel('Método'),
              const SizedBox(height: 6),
              BrewMethodChipRow(
                value: _method,
                onChanged: (method) => setState(() => _method = method),
              ),
              const SizedBox(height: 16),
              _FieldLabel('Calificación'),
              const SizedBox(height: 6),
              RatingSelector(
                value: _rating,
                onChanged: (r) => setState(() => _rating = r),
                keyPrefix: 'diary_form_star',
              ),
              const SizedBox(height: 16),
              _FieldLabel('Fecha de la visita'),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                key: const Key('diary_form_visited_at_button'),
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(_dateLabel),
              ),
              const SizedBox(height: 16),
              _FieldLabel('Notas de cata'),
              const SizedBox(height: 6),
              TextField(
                key: const Key('diary_form_note_input'),
                controller: _noteController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '¿Qué notaste? Acidez, cuerpo, dulzor…',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    key: const Key('diary_form_error_text'),
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('diary_form_cancel_button'),
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('diary_form_submit_button'),
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: PassportColors.primary,
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEditing ? 'Guardar cambios' : 'Guardar entrada'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: PassportColors.textSecondary,
      ),
    );
  }
}
