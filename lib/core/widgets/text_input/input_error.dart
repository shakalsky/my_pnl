import 'package:flutter/material.dart';


class InputError extends StatelessWidget {
  final String text;

  const InputError({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
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
              color: Colors.red[600],
            ),
          ),
          SizedBox(width: 4.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle().copyWith(color: Colors.red[600]),
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
