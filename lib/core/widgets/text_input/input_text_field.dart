import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_pnl/core/theme/input_theme.dart';
import 'package:my_pnl/core/widgets/text_input/input_error.dart';



class InputTextField extends StatefulWidget {
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
    return Stack(
      children: [
        TextFormField(
          enabled: widget.enabled ?? true,
          autofocus: widget.autofocus,
          autofillHints: widget.autofillHints,
          style: widget.textStyle,
          textAlign: widget.textAlign,
          readOnly: widget.readOnly,
          cursorColor:Colors.black,
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
          decoration: getWhiteAppInputDecorationTheme(context, widget.enabled ?? true).copyWith(
            contentPadding: EdgeInsets.only(
              top: 12.0,
              bottom:12.0,
              right:16.0,
            ),
            fillColor: _isActive
                ? Colors.white
                : widget.enabled ?? true
                ? const Color.fromARGB(255, 240, 240, 240)
                : Colors.grey[50],
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
            ),
            labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                (widget.borderRadius ??  8.0),
              ),
              borderSide:
                  widget.borderSide ?? const BorderSide(width: 1.0, style: BorderStyle.none),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                (widget.borderRadius ??  8.0),
              ),
              borderSide:
                  widget.borderSide ??  BorderSide(width: 1.0, color: Colors.red[600]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                (widget.borderRadius ??  8.0),
              ),
              borderSide:
                  widget.borderSide ??
                  BorderSide(width: 1.0, color: Colors.green[500]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                (widget.borderRadius ??  8.0),
              ),
              borderSide: BorderSide(
                width: widget.borderSide?.width ?? 1.0,
                color:
                    widget.borderSide?.color ??
                    (_isActive ? Colors.green[500]! : Colors.grey[50]!),
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                (widget.borderRadius ??  8.0),
              ),
              borderSide:
                  widget.borderSide ?? BorderSide(width: 1.0, color: Colors.grey[50]!),
            ),
            hintText: widget.hintText,
            label: widget.placeholder == null
                ? SizedBox(width: 16.0,)
                : Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: Text(
                      widget.placeholder!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle().copyWith(
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
            prefixIcon: widget.prefixIcon != null
                ? Padding(
                    padding: EdgeInsets.only(left: 12.0),
                    child: widget.prefixIcon!
                  )
                : null,
            suffixIcon: Padding(
              padding: EdgeInsets.only(right: 12.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.showClearButton && _controller.value.text.isNotEmpty
                      ? GestureDetector(
                          child: Icon(
                            Icons.close,
                            size: 18.0,
                            color: Colors.grey[500],
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
                        )
                      : const SizedBox.shrink(),
                  widget.suffixIcon != null
                      ? Padding(
                          padding: EdgeInsets.only(left:8.0),
                          child: widget.suffixIcon!,
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            ),
            prefix: widget.prefixText == null
                ? SizedBox(width: 16.0,)
                : Padding(
                    padding: EdgeInsets.only(left:16.0),
                    child: Text(
                      widget.prefixText!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
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
              padding: EdgeInsets.only(right: 6.0, bottom: 6.0),
              child: Icon(
                Icons.south_east,
                size: 12.0,
                color: Colors.grey[400],
              ),
            ),
          ),
      ],
    );
  }
}
