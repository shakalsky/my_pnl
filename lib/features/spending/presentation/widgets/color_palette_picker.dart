import 'package:flutter/material.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Corner rounding shared by the gradient field and the hue track.
const _trackRadius = BorderRadius.all(Radius.circular(12));

/// The hue track, left to right. Ends on red again so the ramp wraps the way
/// the colour wheel does.
final _hueStops = <Color>[
  for (var degrees = 0; degrees <= 360; degrees += 60)
    HSVColor.fromAHSV(1, degrees % 360, 1, 1).toColor(),
];

/// A full colour picker: a hue track and the saturation/value gradient for the
/// chosen hue, so any colour at all can be landed on.
///
/// Works in HSV rather than on a list of swatches — dragging around a gradient
/// is how people expect to hunt for a shade, and it leaves nothing out.
class ColorPalettePicker extends StatefulWidget {
  const ColorPalettePicker({required this.selectedArgb, super.key});

  /// The colour the form currently holds; the picker opens on it.
  final int selectedArgb;

  /// Opens the picker and completes with the chosen colour as packed ARGB, or
  /// null if it was dismissed.
  static Future<int?> show(BuildContext context, int selectedArgb) {
    return showDialog<int>(
      context: context,
      builder: (_) => ColorPalettePicker(selectedArgb: selectedArgb),
    );
  }

  @override
  State<ColorPalettePicker> createState() => _ColorPalettePickerState();
}

class _ColorPalettePickerState extends State<ColorPalettePicker> {
  /// Held as HSV, not as a packed int: round-tripping through ARGB on every
  /// drag would lose the hue as soon as a drag reached white or black, and the
  /// gradient would jump under the finger.
  late HSVColor _color = HSVColor.fromColor(Color(widget.selectedArgb));

  int get _argb => _color.toColor().toARGB32();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(t.categoryForm.pickColor),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      content: SizedBox(
        // Fills the dialog rather than picking a width: the gradient wants all
        // the room there is, and the dialog is already inset from the screen.
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 180,
              child: _SaturationValueField(
                key: const ValueKey('saturation-value-field'),
                color: _color,
                onChanged: (color) => setState(() => _color = color),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 24,
              child: _HueTrack(
                key: const ValueKey('hue-track'),
                color: _color,
                onChanged: (color) => setState(() => _color = color),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(_argb),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  // The colour as a hex code, both to confirm the pick and to
                  // give something to copy down for anyone matching a shade.
                  '#${_argb.toRadixString(16).substring(2).toUpperCase()}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_argb),
          child: Text(t.common.select),
        ),
      ],
    );
  }
}

/// The big gradient: saturation left to right, value top to bottom, at the
/// hue the track below is set to.
class _SaturationValueField extends StatelessWidget {
  const _SaturationValueField({
    required this.color,
    required this.onChanged,
    super.key,
  });

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        void pick(Offset position) {
          onChanged(
            color
                .withSaturation((position.dx / width).clamp(0, 1))
                .withValue(1 - (position.dy / height).clamp(0, 1)),
          );
        }

        return GestureDetector(
          // onPanDown as well as onPanUpdate so a plain tap lands a colour
          // instead of needing a drag to register.
          onPanDown: (details) => pick(details.localPosition),
          onPanUpdate: (details) => pick(details.localPosition),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // White to the pure hue across, then black down over the top of
              // it: the two together are the standard saturation/value square.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _trackRadius,
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _trackRadius,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: color.saturation * width - _PickerThumb.radius,
                top: (1 - color.value) * height - _PickerThumb.radius,
                child: _PickerThumb(color: color.toColor()),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The hue ramp under the gradient field.
class _HueTrack extends StatelessWidget {
  const _HueTrack({required this.color, required this.onChanged, super.key});

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        void pick(Offset position) {
          onChanged(color.withHue((position.dx / width).clamp(0, 1) * 360));
        }

        return GestureDetector(
          onPanDown: (details) => pick(details.localPosition),
          onPanUpdate: (details) => pick(details.localPosition),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _trackRadius,
                    gradient: LinearGradient(colors: _hueStops),
                  ),
                ),
              ),
              Positioned(
                left: color.hue / 360 * width - _PickerThumb.radius,
                // Centred on a track shorter than the thumb, so it overhangs
                // top and bottom — which is why the stack does not clip.
                top: (constraints.maxHeight - _PickerThumb.radius * 2) / 2,
                child: _PickerThumb(
                  color: HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The ring that marks the current spot on a gradient.
class _PickerThumb extends StatelessWidget {
  const _PickerThumb({required this.color});

  static const radius = 12.0;

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          // White ring with a dark halo: readable against both ends of the
          // gradient, where a single-colour outline would vanish into one.
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}
