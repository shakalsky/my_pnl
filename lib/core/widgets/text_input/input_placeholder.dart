import 'package:flutter/material.dart';


class InputPlaceholder extends StatelessWidget {
  final String text;

  const InputPlaceholder({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top:6.0),
      child: Text(
        text,
        style: TextStyle().copyWith(color: Colors.grey[600]),
      ),
    );
  }
}
