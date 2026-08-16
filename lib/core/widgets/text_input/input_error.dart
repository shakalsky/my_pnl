import 'package:flutter/material.dart';


class InputError extends StatelessWidget {

  const InputError({required this.text, super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    // The scheme's own red rather than a fixed one: it is already the colour
    // every other failure in the app is reported in, and it is picked to read
    // against whichever surface the form is on.
    final error = Theme.of(context).colorScheme.error;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.error_outline,
              size: 14,
              color: error,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: const TextStyle().copyWith(color: error),
              softWrap: true,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
