import 'package:flutter/material.dart';


class InputPlaceholder extends StatelessWidget {

  const InputPlaceholder({required this.text, super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top:6),
      child: Text(
        text,
        style: const TextStyle().copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
