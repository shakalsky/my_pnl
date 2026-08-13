import 'package:flutter/material.dart';



InputDecoration getWhiteAppInputDecorationTheme(BuildContext context, bool enabled) =>
    InputDecoration(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 12.0,
      ),
      hintStyle:TextStyle().copyWith(
        color: enabled ?Colors.grey[500] : Colors.grey[400],
      ),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      filled: true,
      fillColor: enabled ? const Color.fromARGB(255, 240, 240, 240) : Colors.grey[50],
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular( 8.0),
        borderSide: BorderSide(width: 1, color: Colors.grey[50]!),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular( 8.0),
        borderSide: const BorderSide(width: 1, color: Colors.red),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular( 8.0),
        borderSide: const BorderSide(width: 0, style: BorderStyle.none),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular( 8.0),
        borderSide: BorderSide(width: 1, color: Colors.green[500]!),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide(width: 1, color: Colors.grey[50]!),
      ),
      prefixIconConstraints: BoxConstraints(maxHeight:24.0),
      suffixIconConstraints: BoxConstraints(maxHeight: 24.0),
    );
