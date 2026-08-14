import 'package:flutter/material.dart';
import 'package:my_pnl/core/theme/semantic_colors.dart';

/// How every text field in the app is drawn.
///
/// Read off the theme rather than written down, because the same field has to
/// be a pale box on white and a raised one on near-black, and a fill written
/// down as a shade of grey can only ever be one of the two.
///
/// The mapping is the point:
///
/// * the field being typed into takes the plain surface, so it lifts off the
///   sheet in the light and sinks into it in the dark — either way it is the
///   one that reads as open;
/// * an idle field takes the highest container, a step away from the surface
///   in whichever direction that brightness has room for;
/// * a disabled one takes a lower step still, so it reads as backed off rather
///   than merely greyed.
///
/// The borders are drawn in the fill colour rather than left off, which keeps
/// the outline invisible until something has to be said with it — focus in
/// green, an error in the scheme's own red. A field that outlines itself at
/// rest would put a box around every row of a form.
InputDecoration appInputDecoration(
  BuildContext context, {
  required bool enabled,
}) {
  final colors = Theme.of(context).colorScheme;
  final semantics = AppSemanticColors.of(context);
  final fill = enabled
      ? colors.surfaceContainerHighest
      : colors.surfaceContainerLow;

  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );

  return InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    hintStyle: TextStyle(
      color: enabled
          ? colors.onSurfaceVariant
          // A hint on a field nobody can type into is a label for something
          // that is not going to happen, and reads as one.
          : colors.onSurfaceVariant.withValues(alpha: 0.5),
    ),
    floatingLabelBehavior: FloatingLabelBehavior.never,
    filled: true,
    fillColor: fill,
    enabledBorder: border(fill),
    errorBorder: border(colors.error),
    disabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide.none,
    ),
    focusedBorder: border(semantics.focus),
    border: border(fill),
    prefixIconConstraints: const BoxConstraints(maxHeight: 24),
    suffixIconConstraints: const BoxConstraints(maxHeight: 24),
  );
}
