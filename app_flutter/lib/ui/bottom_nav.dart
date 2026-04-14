import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: const Color(0xFF0A0E17),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          Icon(Icons.track_changes, color: Color(0xFF00F2FF)),
          Icon(Icons.model_training, color: Colors.grey),
          Icon(Icons.settings, color: Colors.grey),
        ],
      ),
    );
  }
}