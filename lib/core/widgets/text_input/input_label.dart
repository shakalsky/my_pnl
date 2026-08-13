import 'package:flutter/material.dart';



class InputLabel extends StatelessWidget {
  final String text;
  final bool isImportant;
  final TextStyle? style;

  const InputLabel({super.key, required this.text, this.isImportant = false, this.style});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Text(
            text,
            style: style,
          ),
          if (isImportant)
            Padding(
              padding: EdgeInsets.only(left: 4.0),
              child: Text(
                '*',
                style: TextStyle().copyWith(color: Colors.red[600]),
              ),
            ),
        ],
      ),
    );
  }
}
