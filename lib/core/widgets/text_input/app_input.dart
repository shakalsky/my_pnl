import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_pnl/core/widgets/text_input/input_error.dart';
import 'package:my_pnl/core/widgets/text_input/input_label.dart';
import 'package:my_pnl/core/widgets/text_input/input_placeholder.dart';
import 'package:my_pnl/core/widgets/text_input/input_text_field.dart';


enum AppInputColorType { white, gray }

class AppInput extends StatelessWidget {

  const AppInput({
    required this.colorType, super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.labelStyle,
    this.textStyle,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.autofillHints,
    this.borderRadius,
    this.borderSide,
    this.labelHint,
    this.placeholder,
    this.inputHintText,
    this.errorText,
    this.suffixIcon,
    this.prefixIcon,
    this.prefixText,
    this.hint,
    this.enabled,
    this.textArea,
    this.isImportant = false,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.inputFormatters,
    this.keyboardType,
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

  factory AppInput.white({
    TextEditingController? controller,
    FocusNode? focusNode,
    String? label,
    TextStyle? labelStyle,
    TextStyle? textStyle,
    TextAlign textAlign = TextAlign.start,
    bool autofocus = false,
    Iterable<String>? autofillHints,
    double? borderRadius,
    BorderSide? borderSide,
    String? labelHint,
    String? placeholder,
    String? inputHintText,
    String? errorText,
    Widget? suffixIcon,
    Widget? prefixIcon,
    String? prefixText,
    String? hint,
    bool? enabled,
    bool? textArea,
    bool isImportant = false,
    FormFieldValidator<String>? validator,
    AutovalidateMode autovalidateMode = AutovalidateMode.onUserInteraction,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    TextCapitalization? textCapitalization,
    TextInputAction? textInputAction,
    void Function(String value)? onChanged,
    void Function(String value)? onFieldSubmitted,
    void Function()? onUnfocus,
    bool obscureText = false,
    void Function()? onTap,
    void Function()? onClear,
    bool showClearButton = true,
    bool forceActive = false,
    bool readOnly = false,
  }) => AppInput(
    controller: controller,
    focusNode: focusNode,
    label: label,
    labelStyle: labelStyle,
    textStyle: textStyle,
    textAlign: textAlign,
    autofocus: autofocus,
    autofillHints: autofillHints,
    borderRadius: borderRadius,
    borderSide: borderSide,
    labelHint: labelHint,
    placeholder: placeholder,
    inputHintText: inputHintText,
    errorText: errorText,
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
    prefixText: prefixText,
    hint: hint,
    enabled: enabled,
    textArea: textArea,
    isImportant: isImportant,
    colorType: AppInputColorType.white,
    onClear: onClear,
    showClearButton: showClearButton,
    forceActive: forceActive,
    validator: validator,
    autovalidateMode: autovalidateMode,
    inputFormatters: inputFormatters,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    textInputAction: textInputAction,
    onChanged: onChanged,
    onFieldSubmitted: onFieldSubmitted,
    onUnfocus: onUnfocus,
    obscureText: obscureText,
    onTap: onTap,
    readOnly: readOnly,
  );

  factory AppInput.gray({
    Key? key,
    TextEditingController? controller,
    FocusNode? focusNode,
    String? label,
    TextStyle? labelStyle,
    TextStyle? textStyle,
    TextAlign textAlign = TextAlign.start,
    bool autofocus = false,
    Iterable<String>? autofillHints,
    double? borderRadius,
    BorderSide? borderSide,
    String? labelHint,
    String? placeholder,
    String? inputHintText,
    String? errorText,
    Widget? suffixIcon,
    Widget? prefixIcon,
    String? prefixText,
    String? hint,
    bool? enabled,
    bool? textArea,
    bool isImportant = false,
    FormFieldValidator<String>? validator,
    AutovalidateMode autovalidateMode = AutovalidateMode.onUserInteraction,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    TextCapitalization? textCapitalization,
    TextInputAction? textInputAction,
    void Function(String value)? onChanged,
    void Function(String value)? onFieldSubmitted,
    void Function()? onUnfocus,
    bool obscureText = false,
    void Function()? onTap,
    void Function()? onClear,
    bool showClearButton = true,
    bool forceActive = false,
    bool readOnly = false,
  }) => AppInput(
    key: key,
    controller: controller,
    focusNode: focusNode,
    label: label,
    labelStyle: labelStyle,
    textStyle: textStyle,
    textAlign: textAlign,
    autofocus: autofocus,
    autofillHints: autofillHints,
    borderRadius: borderRadius,
    borderSide: borderSide,
    labelHint: labelHint,
    placeholder: placeholder,
    inputHintText: inputHintText,
    errorText: errorText,
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
    prefixText: prefixText,
    hint: hint,
    enabled: enabled,
    textArea: textArea,
    isImportant: isImportant,
    colorType: AppInputColorType.gray,
    onClear: onClear,
    showClearButton: showClearButton,
    forceActive: forceActive,
    validator: validator,
    autovalidateMode: autovalidateMode,
    inputFormatters: inputFormatters,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    textInputAction: textInputAction,
    onChanged: onChanged,
    onFieldSubmitted: onFieldSubmitted,
    onUnfocus: onUnfocus,
    obscureText: obscureText,
    onTap: onTap,
    readOnly: readOnly,
  );
  /// Optional: when omitted the field owns its own controller, so callers that
  /// only listen via [onChanged] need not hold one.
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final TextStyle? labelStyle;

  /// Style of the text typed into the field itself.
  final TextStyle? textStyle;
  final TextAlign textAlign;
  final bool autofocus;
  final Iterable<String>? autofillHints;
  final double? borderRadius;

  /// Optional outline border customization for the inner text field.
  final BorderSide? borderSide;
  final String? inputHintText;
  final String? hint;
  final String? labelHint;
  final String? placeholder;
  final String? errorText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? prefixText;
  final bool? enabled;
  final bool readOnly;
  final bool? textArea;
  final bool isImportant;
  final AppInputColorType colorType;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode autovalidateMode;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final TextCapitalization? textCapitalization;
  final TextInputAction? textInputAction;
  final void Function(String value)? onChanged;
  final void Function(String value)? onFieldSubmitted;
  final void Function()? onUnfocus;
  final bool obscureText;
  final void Function()? onTap;
  final void Function()? onClear;
  final bool showClearButton;
  final bool forceActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null && label!.isNotEmpty)
          Tooltip(
            message: labelHint ?? '',
            triggerMode: TooltipTriggerMode.tap,
            padding: const EdgeInsets.symmetric(
              vertical: 4,
              horizontal: 8,
            ),
            showDuration: const Duration(seconds: 3),
            verticalOffset: 8,
            child: InputLabel(text: label!, isImportant: isImportant, style: labelStyle),
          ),
        InputTextField(
          onTap: onTap,
          controller: controller,
          focusNode: focusNode,
          textStyle: textStyle,
          textAlign: textAlign,
          autofocus: autofocus,
          autofillHints: autofillHints,
          placeholder: placeholder,
          borderRadius: borderRadius,
          borderSide: borderSide,
          hintText: inputHintText,
          prefixIcon: prefixIcon,
          prefixText: prefixText,
          suffixIcon: suffixIcon,
          enabled: enabled,
          textArea: textArea,
          validator: validator,
          autovalidateMode: autovalidateMode,
          inputFormatters: inputFormatters,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          onUnfocus: onUnfocus,
          onClear: onClear,
          showClearButton: showClearButton,
          forceActive: forceActive,
          obscureText: obscureText,
          readOnly: readOnly,
        ),
        if (hint != null && hint!.isNotEmpty && errorText == null) InputPlaceholder(text: hint!),
        if (errorText != null && errorText!.isNotEmpty) InputError(text: errorText!),
      ],
    );
  }
}
