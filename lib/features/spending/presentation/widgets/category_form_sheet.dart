import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/core/widgets/text_input/app_input.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/usecases/create_category.dart';
import 'package:my_pnl/features/spending/domain/usecases/delete_category.dart';
import 'package:my_pnl/features/spending/domain/usecases/update_category.dart';
import 'package:my_pnl/features/spending/presentation/bloc/category_form/category_form_bloc.dart';
import 'package:my_pnl/features/spending/presentation/theme/category_style.dart';
import 'package:my_pnl/features/spending/presentation/widgets/color_palette_picker.dart';
import 'package:my_pnl/features/spending/presentation/widgets/icon_picker_dialog.dart';
import 'package:my_pnl/features/spending/presentation/widgets/transaction_history_sheet.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Modal form for creating or editing a category.
///
/// Owns a [CategoryFormBloc] for the life of the sheet. Closing is driven by
/// the bloc reaching [CategoryFormStatus.success], so the write completes
/// before the modal goes away.
class CategoryFormSheet extends StatelessWidget {
  const CategoryFormSheet({this.category, this.month, super.key});

  /// The category being edited, or null while creating one.
  ///
  /// Carried alongside the bloc rather than read out of its state: the only
  /// thing it is for is opening the history, which wants the saved category as
  /// it stands and not the half-edited form.
  final Category? category;

  /// Which month the history behind the button above is listed for. Null lists
  /// the category's whole history, and there is nothing to list while creating
  /// one.
  final CalendarMonth? month;

  /// Opens the modal with an empty form for a category of [kind].
  static Future<void> showCreate(
    BuildContext context, {
    CategoryKind kind = CategoryKind.expense,
  }) => _show(context, null, kind);

  /// Opens the modal seeded with [category].
  ///
  /// [month] is the month the grid behind is showing, which is what the history
  /// opened from here is scoped to — the same list the tile's own icon opens.
  static Future<void> showEdit(
    BuildContext context,
    Category category, {
    CalendarMonth? month,
  }) => _show(context, category, category.kind, month: month);

  static Future<void> _show(
    BuildContext context,
    Category? initial,
    CategoryKind kind, {
    CalendarMonth? month,
  }) {
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
          // From the quick set, so a new form opens with its icon highlighted
          // in the grid rather than tucked behind the button.
          defaultIconKey: categoryQuickIcons.keys.first,
          kind: kind,
          initial: initial,
        ),
        child: CategoryFormSheet(category: initial, month: month),
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
                SnackBar(content: Text(t.categoryForm.saveFailed)),
              );
            }
          case CategoryFormStatus.editing:
          case CategoryFormStatus.submitting:
          case CategoryFormStatus.deleting:
            break;
        }
      },
      child: _CategoryForm(category: category, month: month),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({this.category, this.month});

  final Category? category;

  /// The month the history button lists, carried down from the grid.
  final CalendarMonth? month;

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
                      (true, true) => t.categoryForm.editIncome,
                      (true, false) => t.categoryForm.editExpense,
                      (false, true) => t.categoryForm.newIncome,
                      (false, false) => t.categoryForm.newExpense,
                    },
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                // A category with no id has no entries to list, so the button
                // only exists on the editing form.
                if (widget.category case final category?)
                  IconButton(
                    onPressed: () => TransactionHistorySheet.show(
                      context,
                      category,
                      month: widget.month,
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                    tooltip: t.categoryForm.transactions,
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
                    label: t.common.name,
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
                title: Text(t.categoryForm.recurring),
                subtitle: Text(t.categoryForm.recurringSubtitle),
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
                        label: t.categoryForm.day,
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
                        label: t.common.amount,
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
                    t.categoryForm.recurringNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            Text(t.categoryForm.color, style: theme.textTheme.labelLarge),
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
                    // Fills the last cell of the second row. Shows the chosen
                    // colour when it came from the palette rather than the
                    // presets, so the form still says what is selected.
                    _MoreColorsButton(
                      size: size,
                      selectedArgb: state.colorArgb,
                      onPicked: (color) =>
                          bloc.add(CategoryFormColorSelected(color)),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text(t.categoryForm.icon, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final iconKey in categoryQuickIcons.keys)
                  _IconChoice(
                    iconKey: iconKey,
                    selected: iconKey == state.iconKey,
                    onTap: () => bloc.add(CategoryFormIconSelected(iconKey)),
                  ),
                // Twelfth tile, so the eleven above it and this make two even
                // rows. Wears the chosen icon when it came from the sheet
                // behind it, so the form still shows what is selected.
                _MoreIconsButton(
                  selectedKey: state.iconKey,
                  onPicked: (iconKey) =>
                      bloc.add(CategoryFormIconSelected(iconKey)),
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
                    : Text(state.isEditing ? t.common.save : t.common.create),
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
                      : Text(t.categoryForm.delete),
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
        title: Text(
          name.isEmpty
              ? t.categoryForm.deleteTitleUnnamed
              : t.categoryForm.deleteTitleNamed(name: name),
        ),
        content: Text(t.categoryForm.deleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(CategoryDeletion.keepTransactions),
            child: Text(t.categoryForm.keepEntries),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(CategoryDeletion.deleteTransactions),
            child: Text(t.categoryForm.deleteEntries),
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

/// The last cell of the colour grid: opens [ColorPalettePicker].
class _MoreColorsButton extends StatelessWidget {
  const _MoreColorsButton({
    required this.size,
    required this.selectedArgb,
    required this.onPicked,
  });

  /// Matches the swatches beside it, which size themselves to the row.
  final double size;

  /// The colour the form holds, shown here when it is not one of the presets.
  final int selectedArgb;

  final ValueChanged<int> onPicked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // A preset colour is already ticked in the grid, so the button stays
    // neutral; anything else came from the palette and belongs here.
    final custom = !categoryColors.contains(selectedArgb);

    return Semantics(
      selected: custom,
      button: true,
      label: t.categoryForm.customColor,
      child: Tooltip(
        message: t.categoryForm.customColor,
        child: InkWell(
          onTap: () async {
            final picked = await ColorPalettePicker.show(
              context,
              selectedArgb,
            );
            if (picked != null) onPicked(picked);
          },
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: custom
                  ? Color(selectedArgb)
                  : colors.surfaceContainerHighest,
              border: Border.all(
                color: custom ? colors.onSurface : colors.outlineVariant,
                width: custom ? 3 : 1,
              ),
            ),
            child: Icon(
              Icons.palette_outlined,
              size: size / 2,
              color: custom ? Colors.white : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The last tile of the icon grid: opens [IconPickerDialog].
class _MoreIconsButton extends StatelessWidget {
  const _MoreIconsButton({required this.selectedKey, required this.onPicked});

  /// The icon the form holds, shown here when it is not one of the eleven.
  final String selectedKey;

  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // A quick icon is already highlighted in the grid, so the button stays
    // neutral; anything else came from the sheet and belongs here.
    final fromSheet = !categoryQuickIcons.containsKey(selectedKey);

    return Semantics(
      selected: fromSheet,
      button: true,
      label: t.categoryForm.moreIcons,
      child: Tooltip(
        message: t.categoryForm.moreIcons,
        child: InkWell(
          onTap: () async {
            final picked = await IconPickerDialog.show(context, selectedKey);
            if (picked != null) onPicked(picked);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: fromSheet
                  ? colors.secondaryContainer
                  : colors.surfaceContainerHighest,
              border: Border.all(
                color: fromSheet ? colors.secondary : colors.outlineVariant,
                width: fromSheet ? 2 : 1,
              ),
            ),
            child: Icon(
              // The chosen icon when it lives behind the button, so the form
              // never shows an icon the grid cannot account for; otherwise the
              // plain "there are more" mark.
              fromSheet ? iconForKey(selectedKey) : Icons.more_horiz,
              size: 22,
              color: fromSheet
                  ? colors.onSecondaryContainer
                  : colors.onSurfaceVariant,
            ),
          ),
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
