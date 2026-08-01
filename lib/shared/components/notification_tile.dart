import 'package:flutter/material.dart';

class NotificationTile extends StatelessWidget {
  final String title;
  final String body;

  const NotificationTile({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return ListTile(title: Text(title), subtitle: Text(body));
  }
}
