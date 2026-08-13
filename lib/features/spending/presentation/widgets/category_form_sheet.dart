import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/core/widgets/text_input/app_input.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/usecases/create_category.dart';
import 'package:my_pnl/features/spending/domain/usecases/delete_category.dart';
import 'package:my_pnl/features/spending/domain/usecases/update_category.dart';
import 'package:my_pnl/features/spending/presentation/bloc/category_form/category_form_bloc.dart';
import 'package:my_pnl/features/spending/presentation/theme/category_style.dart';
import 'package:my_pnl/features/spending/presentation/widgets/transaction_history_sheet.dart';

/// Modal form for creating or editing a category.
///
/// Owns a [CategoryFormBloc] for the life of the sheet. Closing is driven by
/// the bloc reaching [CategoryFormStatus.success], so the write completes
/// before the modal goes away.
class CategoryFormSheet extends StatelessWidget {
  const CategoryFormSheet({this.category, super.key});

  /// The category being edited, or null while creating one.
  ///
  /// Carried alongside the bloc rather than read out of its state: the only
  /// thing it is for is opening the history, which wants the saved category as
  /// it stands and not the half-edited form.
  final Category? category;

  /// Opens the modal with an empty form for a category of [kind].
  static Future<void> showCreate(
    BuildContext context, {
    CategoryKind kind = CategoryKind.expense,
  }) => _show(context, null, kind);

  /// Opens the modal seeded with [category].
  static Future<void> showEdit(BuildContext context, Category category) =>
      _show(context, category, category.kind);

  static Future<void> _show(
    BuildContext context,
    Category? initial,
    CategoryKind kind,
  ) {
    final repository = context.read<CategoryRepository>();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // The income form is the tall one — a recurring schedule on top of the
      // colour and icon grids — and left alone it fills the screen. Capped
      // short of the top so the page behind stays in view and the sheet still
      // reads as a sheet; the form scrolls for whatever does not fit.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (_) => BlocProvider(
        create: (_) => CategoryFormBloc(
          createCategory: CreateCategory(repository),
          updateCategory: UpdateCategory(repository),
          deleteCategory: DeleteCategory(repository),
          defaultColorArgb: categoryColors.first,
          defaultIconKey: categoryIcons.keys.first,
          kind: kind,
          initial: initial,
        ),
        child: CategoryFormSheet(category: initial),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CategoryFormBloc, CategoryFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        switch (state.status) {
          case CategoryFormStatus.success:
            Navigator.of(context).pop();
          case CategoryFormStatus.failure:
            // A named reason is shown inline against the field it concerns;
            // only the generic case needs a snack bar.
            if (state.errorMessage == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not save the category')),
              );
            }
          case CategoryFormStatus.editing:
          case CategoryFormStatus.submitting:
          case CategoryFormStatus.deleting:
            break;
        }
      },
      child: _CategoryForm(category: category),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({this.category});

  final Category? category;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final TextEditingController _name;
  late final TextEditingController _recurringDay;
  late final TextEditingController _recurringAmount;

  @override
  void initState() {
    super.initState();
    // Seeded once from the bloc's initial state so editing opens with the
    // current values already in the fields.
    final state = context.read<CategoryFormBloc>().state;
    _name = TextEditingController(text: state.name);
    _recurringDay = TextEditingController(text: state.recurringDay);
    _recurringAmount = TextEditingController(text: state.recurringAmount);
  }

  @override
  void dispose() {
    _name.dispose();
    _recurringDay.dispose();
    _recurringAmount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<CategoryFormBloc>();
    final state = context.watch<CategoryFormBloc>().state;

    return GestureDetector(
      // Taps that miss a control dismiss the keyboard. Opaque so empty space
      // in the sheet counts as "outside"; taps that land on the swatches or
      // the button still reach them, since a child wins the gesture arena.
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        // Deliberately ignores MediaQuery.viewInsets: the sheet keeps the same
        // size when the keyboard opens. The form scrolls instead, so anything
        // the keyboard covers can still be reached.
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        // Dragging the form away from the field dismisses it too.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    switch ((state.isEditing, state.isIncome)) {
                      (true, true) => 'Edit income',
                      (true, false) => 'Edit category',
                      (false, true) => 'New income',
                      (false, false) => 'New category',
                    },
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                // A category with no id has no entries to list, so the button
                // only exists on the editing form.
                if (widget.category case final category?)
                  IconButton(
                    onPressed: () =>
                        TransactionHistorySheet.show(context, category),
                    icon: const Icon(Icons.receipt_long_outlined),
                    tooltip: 'Transactions',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(state.colorArgb),
                  ),
                  child: Icon(
                    iconForKey(state.iconKey),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppInput.white(
                    controller: _name,
                    label: 'Name',
                    errorText: state.errorMessage,
                    // No autofocus: the sheet opens showing the colour and icon
                    // choices rather than with half of itself behind a keyboard.
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) =>
                        bloc.add(CategoryFormNameChanged(value)),
                    onFieldSubmitted: (_) =>
                        bloc.add(const CategoryFormSubmitted()),
                  ),
                ),
              ],
            ),
            if (state.showsRecurring) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                value: state.isRecurring,
                onChanged: (value) => bloc.add(
                  CategoryFormRecurringToggled(isRecurring: value ?? false),
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Recurring'),
                subtitle: const Text('Book this income once a month'),
              ),
              // The schedule only appears once the box is ticked: an empty day
              // and amount would otherwise read as required fields.
              if (state.isRecurring)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: AppInput.white(
                        controller: _recurringDay,
                        label: 'Day',
                        inputHintText: '1',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        // Too narrow to give up room to a clear button.
                        showClearButton: false,
                        onChanged: (value) =>
                            bloc.add(CategoryFormRecurringDayChanged(value)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppInput.white(
                        controller: _recurringAmount,
                        label: 'Amount',
                        prefixText: '$baseCurrencySymbol ',
                        inputHintText: '0.00',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*[.,]?\d{0,2}'),
                          ),
                        ],
                        onChanged: (value) =>
                            bloc.add(CategoryFormRecurringAmountChanged(value)),
                      ),
                    ),
                  ],
                ),
              if (state.isRecurring)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    // Says what a short month does, because the 31st is the
                    // case people expect to silently misbehave.
                    'Months shorter than the chosen day use their last day. '
                    'Missed months are booked the next time you open the app.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            Text('Color', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            // Sized from the available width rather than fixed, so the row
            // always holds exactly eight swatches even on narrow phones.
            LayoutBuilder(
              builder: (context, constraints) {
                const perRow = 8;
                const spacing = 10.0;
                final size = math.min<double>(
                  36,
                  (constraints.maxWidth - spacing * (perRow - 1)) / perRow,
                );
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    for (final color in categoryColors)
                      _ColorSwatch(
                        colorArgb: color,
                        size: size,
                        selected: color == state.colorArgb,
                        onTap: () => bloc.add(CategoryFormColorSelected(color)),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text('Icon', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final iconKey in categoryIcons.keys)
                  _IconChoice(
                    iconKey: iconKey,
                    selected: iconKey == state.iconKey,
                    onTap: () => bloc.add(CategoryFormIconSelected(iconKey)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.isValid && !state.isBusy
                    ? () => bloc.add(const CategoryFormSubmitted())
                    : null,
                child: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(state.isEditing ? 'Save' : 'Create'),
              ),
            ),
            // Only when there is something to delete.
            if (state.isEditing) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: state.isBusy
                      ? null
                      : () => _confirmDelete(context, bloc),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: state.isDeleting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Delete category'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CategoryFormBloc bloc,
  ) async {
    final name = bloc.state.name.trim();

    // Three ways out rather than a checkbox: the two outcomes differ in
    // whether money leaves your totals, which is too big a difference to hang
    // off a box someone can miss.
    final mode = await showDialog<CategoryDeletion>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${name.isEmpty ? 'this category' : name}?'),
        content: const Text(
          'What should happen to the amounts recorded against it?\n\n'
          'Keep them and the money stays in your totals, without a category. '
          'Delete them and it leaves your totals too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(CategoryDeletion.keepTransactions),
            child: const Text('Keep entries'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(CategoryDeletion.deleteTransactions),
            child: const Text('Delete entries'),
          ),
        ],
      ),
    );

    if (mode != null) bloc.add(CategoryFormDeleted(mode));
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.colorArgb,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final int colorArgb;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(colorArgb),
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 3,
                  )
                : null,
          ),
          child: selected
              ? Icon(Icons.check, color: Colors.white, size: size / 2)
              : null,
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.iconKey,
    required this.selected,
    required this.onTap,
  });

  final String iconKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? colors.secondaryContainer
                : colors.surfaceContainerHighest,
            border: selected
                ? Border.all(color: colors.secondary, width: 2)
                : null,
          ),
          child: Icon(
            iconForKey(iconKey),
            size: 22,
            color: selected
                ? colors.onSecondaryContainer
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
