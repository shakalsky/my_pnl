import 'package:flutter/material.dart';


class InputError extends StatelessWidget {
  final String text;

  const InputError({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    // The scheme's own red rather than a fixed one: it is already the colour
    // every other failure in the app is reported in, and it is picked to read
    // against whichever surface the form is on.
    final error = Theme.of(context).colorScheme.error;

    return Padding(
      padding: EdgeInsets.only(top: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: 2.0),
            child: Icon(
              Icons.error_outline,
              size: 14.0,
              color: error,
            ),
          ),
          SizedBox(width: 4.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle().copyWith(color: error),
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
