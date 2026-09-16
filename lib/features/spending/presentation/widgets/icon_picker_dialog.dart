import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:my_pnl/features/spending/presentation/theme/category_style.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// The further icons behind the category form's "more icons" button.
///
/// Only [categoryMoreIcons]: the eleven on the form are still on the form
/// behind this dialog, and repeating them here would make the grid longer for
/// nothing.
class IconPickerDialog extends StatelessWidget {
  const IconPickerDialog({required this.selectedKey, super.key});

  /// The icon the form currently holds, ticked in the grid if it is one of
  /// these.
  final String selectedKey;

  /// Opens the picker and completes with the chosen icon key, or null if it
  /// was dismissed.
  static Future<String?> show(BuildContext context, String selectedKey) {
    return showDialog<String>(
      context: context,
      builder: (_) => IconPickerDialog(selectedKey: selectedKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.categoryForm.pickIcon),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      content: SizedBox(
        width: double.maxFinite,
        // Forty tiles are taller than a dialog on any phone, so the grid
        // scrolls rather than the dialog growing past the screen.
        child: SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const perRow = 5;
              const spacing = 10.0;
              // Each tile sits in a cell a fifth of the width, so five fill a
              // row exactly and a sixth cannot fit however wide the dialog
              // gets. Forty icons then make eight even rows.
              final cell =
                  (constraints.maxWidth - spacing * (perRow - 1)) / perRow;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final entry in categoryMoreIcons.entries)
                    SizedBox(
                      width: cell,
                      child: Center(
                        child: _IconOption(
                          iconKey: entry.key,
                          icon: entry.value,
                          // Never wider than the cell on a narrow phone, and
                          // never so wide it dwarfs the form's own tiles.
                          size: math.min(44, cell),
                          selected: entry.key == selectedKey,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
      ],
    );
  }
}

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.iconKey,
    required this.icon,
    required this.size,
    required this.selected,
  });

  final String iconKey;
  final IconData icon;

  /// Sized from the row rather than fixed, so five always fit across.
  final double size;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        // Picking an icon is the whole errand, so the tap both chooses and
        // closes — there is nothing left to confirm.
        onTap: () => Navigator.of(context).pop(iconKey),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
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
            icon,
            size: size / 2,
            color: selected
                ? colors.onSecondaryContainer
                : colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
