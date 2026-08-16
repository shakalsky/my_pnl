import 'package:flutter/material.dart';



class InputLabel extends StatelessWidget {

  const InputLabel({required this.text, super.key, this.isImportant = false, this.style});
  final String text;
  final bool isImportant;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            text,
            style: style,
          ),
          if (isImportant)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '*',
                style: const TextStyle().copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
