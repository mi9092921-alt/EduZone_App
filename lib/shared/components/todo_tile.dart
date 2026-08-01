import 'package:flutter/material.dart';

class TodoTile extends StatelessWidget {
  final String title;
  final bool done;

  const TodoTile({super.key, required this.title, this.done = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: Checkbox(value: done, onChanged: null),
    );
  }
}
