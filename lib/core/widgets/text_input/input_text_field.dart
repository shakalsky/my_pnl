import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_pnl/core/theme/input_theme.dart';
import 'package:my_pnl/core/theme/semantic_colors.dart';
import 'package:my_pnl/core/widgets/text_input/input_error.dart';



class InputTextField extends StatefulWidget {

  const InputTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.borderRadius,
    this.borderSide,
    this.hintText,
    this.textStyle,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.autofillHints,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.enabled,
    this.textArea,
    this.keyboardType,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.inputFormatters,
    this.textCapitalization,
    this.textInputAction,
    this.onChanged,
    this.onFieldSubmitted,
    this.onUnfocus,
    this.obscureText = false,
    this.onTap,
    this.onClear,
    this.showClearButton = true,
    this.forceActive = false,
    this.readOnly = false,
  });
  /// Optional: when omitted the field owns and disposes its own controller,
  /// so callers that only listen via [onChanged] need not hold one.
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final String? hintText;
  final TextStyle? textStyle;
  final TextAlign textAlign;
  final bool autofocus;
  final Iterable<String>? autofillHints;
  final double? borderRadius;
  final BorderSide? borderSide;
  final Widget? prefixIcon;
  final String? prefixText;
  final Widget? suffixIcon;
  final bool? enabled;
  final bool? textArea;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autovalidateMode;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization? textCapitalization;
  final TextInputAction? textInputAction;
  final void Function(String value)? onChanged;
  final void Function(String value)? onFieldSubmitted;
  final void Function()? onUnfocus;
  final bool obscureText;
  final void Function()? onTap;
  final void Function()? onClear;
  final bool showClearButton;

  /// Если true, поле визуально отображается как активное (с обведением),
  /// даже если реальный фокус на нём отсутствует.
  final bool forceActive;
  final bool readOnly;

  @override
  State<InputTextField> createState() => _InputTextFieldState();
}

class _InputTextFieldState extends State<InputTextField> {
  final FocusNode _focusNode = FocusNode();
  TextEditingController? _ownedController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownedController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    (widget.focusNode ?? _focusNode).addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    // Only dispose the internally created FocusNode/controller. Caller-owned
    // ones must be disposed by the caller to avoid double-dispose when child
    // unmounts before parent.
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _ownedController?.dispose();
    super.dispose();
  }

  bool get _isActive => (widget.focusNode ?? _focusNode).hasFocus || widget.forceActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final semantics = AppSemanticColors.of(context);
    final enabled = widget.enabled ?? true;

    // What the field is drawn on, and so what everything inside it has to be
    // legible against. The focused field takes the plain surface and an idle
    // one a step off it — see [appInputDecoration], which is where the same
    // choice is made for the borders.
    final fill = _isActive
        ? colors.surface
        : enabled
        ? colors.surfaceContainerHighest
        : colors.surfaceContainerLow;

    // Placeholder, hint and the label all say the same thing about the field:
    // it is empty and this is what goes in it. Held at less than full strength
    // so they read as an invitation rather than as content already typed.
    final hintColor = colors.onSurfaceVariant.withValues(alpha: 0.7);

    // Everything sitting on the value's own line — the hint standing in for it
    // and the prefix in front of it — is sized off the value's style, so a
    // field given a larger [textStyle] does not read as one size of text with
    // another size bolted to its left.
    final valueStyle = widget.textStyle ?? theme.textTheme.bodyLarge;
    final inlineSize = valueStyle?.fontSize ?? 16.0;

    return Stack(
      children: [
        TextFormField(
          enabled: enabled,
          autofocus: widget.autofocus,
          autofillHints: widget.autofillHints,
          style: widget.textStyle,
          textAlign: widget.textAlign,
          readOnly: widget.readOnly,
          cursorColor: colors.onSurface,
          minLines: widget.textArea ?? false ? 2 : null,
          obscureText: widget.obscureText,
          keyboardType:
              widget.keyboardType ?? (widget.textArea ?? false ? TextInputType.multiline : null),
          maxLines: widget.textArea ?? false ? 2 : 1,
          focusNode: widget.focusNode ?? _focusNode,
          controller: _controller,
          onTap: widget.onTap,
          inputFormatters: [
            ...?widget.inputFormatters,
          ],
          onChanged: (text) {
            widget.onChanged?.call(text);
            setState(() {});
          },
          onFieldSubmitted: (text) {
            widget.onFieldSubmitted?.call(text);
            widget.onUnfocus?.call();
          },
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          autovalidateMode: widget.autovalidateMode,
          textCapitalization: widget.textCapitalization ?? TextCapitalization.none,
          onTapOutside: (event) => widget.onUnfocus?.call(),
          errorBuilder: (_, error) => InputError(text: error),
          decoration: appInputDecoration(context, enabled: enabled).copyWith(
            contentPadding: const EdgeInsets.only(
              top: 12,
              bottom:12,
              right:16,
            ),
            fillColor: fill,
            hintStyle: valueStyle?.copyWith(
              color: hintColor,
            ),
            labelStyle: theme.textTheme.bodyMedium?.copyWith(
              color: hintColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ??  8.0,
              ),
              borderSide:
                  widget.borderSide ?? const BorderSide(style: BorderStyle.none),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ??  8.0,
              ),
              borderSide:
                  widget.borderSide ??  BorderSide(color: colors.error),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ??  8.0,
              ),
              borderSide:
                  widget.borderSide ??
                  BorderSide(color: semantics.focus),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ??  8.0,
              ),
              borderSide: BorderSide(
                width: widget.borderSide?.width ?? 1.0,
                // Drawn in the fill when idle, which is to say not drawn at
                // all: what marks this field out is that it is lighter than
                // the ones around it, not that it is boxed.
                color:
                    widget.borderSide?.color ??
                    (_isActive ? semantics.focus : fill),
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ??  8.0,
              ),
              borderSide:
                  widget.borderSide ?? BorderSide(color: fill),
            ),
            hintText: widget.hintText,
            label: widget.placeholder == null
                ? const SizedBox(width: 16,)
                : Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      widget.placeholder!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle().copyWith(
                        color: hintColor,
                      ),
                    ),
                  ),
            prefixIconConstraints: BoxConstraints(
              maxHeight: math.max(24, inlineSize),
            ),
            prefixIcon: widget.prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: IconTheme.merge(
                      data: IconThemeData(size: inlineSize),
                      child: widget.prefixIcon!,
                    ),
                  )
                : null,
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showClearButton && _controller.value.text.isNotEmpty) GestureDetector(
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                          onTap: () {
                            if (widget.onClear != null) {
                              widget.onClear!();
                            } else {
                              _controller.clear();
                            }
                            widget.onChanged?.call(_controller.text);
                            setState(() {});
                          },
                        ) else const SizedBox.shrink(),
                  if (widget.suffixIcon != null) Padding(
                          padding: const EdgeInsets.only(left:8),
                          child: widget.suffixIcon,
                        ) else const SizedBox.shrink(),
                ],
              ),
            ),
            prefix: widget.prefixText == null
                ? const SizedBox(width: 16,)
                : Padding(
                    padding: const EdgeInsets.only(left:16),
                    child: Text(
                      widget.prefixText!,
                      style: valueStyle?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ),
          ),
        ),
        if (widget.textArea == true)
          Positioned(
            right: 1,
            bottom: 1,
            child: Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 6),
              child: Icon(
                Icons.south_east,
                size: 12,
                color: colors.outline,
              ),
            ),
          ),
      ],
    );
  }
}
