import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../passport/presentation/widgets/stamp_tile.dart'
    show PassportColors;
import '../../domain/entities/shop_review.dart';
import '../../domain/repositories/shop_review_repository.dart';
import 'rating_stars.dart';
import 'shop_review_card.dart';

/// Panel autocontenido de reseñas de una cafetería: carga
/// `GET /shops/{id}/reviews`, muestra la lista, y ofrece el
/// formulario de "tu reseña" (crear si todavía no tiene una, editar/
/// borrar si ya la tiene).
///
/// Vive en `presentation/widgets` (no en `screens`) porque no es una
/// pantalla completa — se embebe dentro de `ShopDetailScreen`.
///
/// Widget keys para QA:
/// - `Key('shop_reviews_panel')` — raíz del panel.
/// - `Key('shop_review_write_button')` — abre el formulario cuando
///   todavía no hay reseña propia.
/// - `Key('shop_review_comment_input')` — campo de texto del
///   formulario (crear/editar).
/// - `Key('shop_review_submit_button')` — guarda (crear o editar,
///   según el modo).
/// - `Key('shop_review_cancel_button')` — cierra el formulario sin
///   guardar.
/// - `Key('shop_review_star_\$n')` (1 a 5) — ver `RatingSelector`.
/// - `Key('shop_review_edit_button')` / `Key('shop_review_delete_button')`
///   — ver `ShopReviewCard`.
/// - `Key('shop_reviews_empty_state')` — se muestra cuando no hay
///   ninguna reseña todavía.
class ShopReviewsPanel extends StatefulWidget {
  const ShopReviewsPanel({
    super.key,
    required this.shopId,
    required this.repository,
    this.onReviewsChanged,
  });

  final String shopId;
  final ShopReviewRepository repository;

  /// Notifica a quien embebe este panel (ej. `ShopDetailScreen`) cada
  /// vez que la lista de reseñas cambia, para que pueda recalcular el
  /// promedio mostrado en el encabezado si el backend no lo trae ya
  /// calculado (ver nota en `ShopRepositoryImpl._shopFromJson`).
  final ValueChanged<List<ShopReview>>? onReviewsChanged;

  @override
  State<ShopReviewsPanel> createState() => ShopReviewsPanelState();
}

/// Pública (no `_ShopReviewsPanelState`) para que `ShopDetailScreen` pueda
/// tipar un `GlobalKey<ShopReviewsPanelState>` y disparar [openWriteForm]
/// desde el botón "Calificar" de la fila de acciones — sin duplicar la
/// lógica del formulario de reseña acá.
class ShopReviewsPanelState extends State<ShopReviewsPanel> {
  late Future<List<ShopReview>> _future;
  bool _formOpen = false;
  bool _submitting = false;
  String? _error;
  int _formRating = 0;
  final _commentController = TextEditingController();
  ShopReview? _myReview;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<List<ShopReview>> _load() async {
    final reviews = await widget.repository.getReviews(widget.shopId);
    widget.onReviewsChanged?.call(reviews);
    final mine = reviews.where((r) => r.isMine).toList();
    if (mine.isNotEmpty) {
      _myReview = mine.first;
    }
    return reviews;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  /// Trigger público para que `ShopDetailScreen` abra el formulario desde
  /// el botón "Calificar" de la fila de acciones -- pre-llena con la
  /// reseña propia si ya existe (mismo criterio que el botón "Editar" de
  /// `ShopReviewCard`), o arranca en blanco si todavía no hay una.
  void openWriteForm() => _openForm(existing: _myReview);

  void _openForm({ShopReview? existing}) {
    setState(() {
      _formOpen = true;
      _error = null;
      _formRating = existing?.rating ?? 0;
      _commentController.text = existing?.comment ?? '';
    });
  }

  void _closeForm() {
    setState(() {
      _formOpen = false;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_formRating == 0) {
      setState(() => _error = 'Elige una calificación de 1 a 5 estrellas.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final comment = _commentController.text.trim();
      final review = _myReview == null
          ? await widget.repository.createReview(
              shopId: widget.shopId,
              rating: _formRating,
              comment: comment.isEmpty ? null : comment,
            )
          : await widget.repository.updateMyReview(
              shopId: widget.shopId,
              rating: _formRating,
              comment: comment.isEmpty ? null : comment,
            );
      if (!mounted) return;
      setState(() {
        _myReview = review;
        _formOpen = false;
      });
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _submitting = true);
    try {
      await widget.repository.deleteMyReview(widget.shopId);
      if (!mounted) return;
      setState(() {
        _myReview = null;
        _formOpen = false;
      });
      await _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('shop_reviews_panel'),
      child: FutureBuilder<List<ShopReview>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No se pudieron cargar las reseñas.\n${snapshot.error}',
                    style: const TextStyle(color: PassportColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          final reviews = snapshot.data ?? const [];
          final others = reviews.where((r) => !r.isMine).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MyReviewSection(
                myReview: _myReview,
                formOpen: _formOpen,
                submitting: _submitting,
                error: _error,
                rating: _formRating,
                commentController: _commentController,
                onWrite: () => _openForm(),
                onEdit: () => _openForm(existing: _myReview),
                onDelete: _delete,
                onCancel: _closeForm,
                onSubmit: _submit,
                onRatingChanged: (r) => setState(() => _formRating = r),
              ),
              const SizedBox(height: 16),
              Text(
                'Reseñas de la comunidad',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: PassportColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (others.isEmpty)
                Padding(
                  key: const Key('shop_reviews_empty_state'),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Todavía no hay reseñas de otros visitantes.',
                    style: const TextStyle(color: PassportColors.textFaint),
                  ),
                )
              else
                ...others.map((r) => ShopReviewCard(review: r)),
            ],
          );
        },
      ),
    );
  }
}

class _MyReviewSection extends StatelessWidget {
  const _MyReviewSection({
    required this.myReview,
    required this.formOpen,
    required this.submitting,
    required this.error,
    required this.rating,
    required this.commentController,
    required this.onWrite,
    required this.onEdit,
    required this.onDelete,
    required this.onCancel,
    required this.onSubmit,
    required this.onRatingChanged,
  });

  final ShopReview? myReview;
  final bool formOpen;
  final bool submitting;
  final String? error;
  final int rating;
  final TextEditingController commentController;
  final VoidCallback onWrite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final ValueChanged<int> onRatingChanged;

  @override
  Widget build(BuildContext context) {
    if (!formOpen) {
      if (myReview != null) {
        return ShopReviewCard(
          review: myReview!,
          onEdit: submitting ? null : onEdit,
          onDelete: submitting ? null : onDelete,
          deleting: submitting,
        );
      }
      return OutlinedButton.icon(
        key: const Key('shop_review_write_button'),
        onPressed: onWrite,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Escribir una reseña'),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PassportColors.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            myReview == null ? 'Tu reseña' : 'Editar tu reseña',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: PassportColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          RatingSelector(value: rating, onChanged: onRatingChanged),
          const SizedBox(height: 8),
          TextField(
            key: const Key('shop_review_comment_input'),
            controller: commentController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '¿Qué te pareció esta cafetería? (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                key: const Key('shop_review_cancel_button'),
                onPressed: submitting ? null : onCancel,
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('shop_review_submit_button'),
                onPressed: submitting ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: PassportColors.primary,
                ),
                child: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
