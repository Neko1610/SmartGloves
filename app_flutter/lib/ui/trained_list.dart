import 'package:flutter/material.dart';

class TrainedList extends StatelessWidget {
  final List<String> trainedLetters;

  const TrainedList({super.key, required this.trainedLetters});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(
          "Đã train: ${trainedLetters.length}/26",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),

        const SizedBox(height: 10),

        LinearProgressIndicator(
          value: trainedLetters.length / 26,
          backgroundColor: Colors.grey[800],
          valueColor: const AlwaysStoppedAnimation(Color(0xFF00F2FF)),
        ),

      ],
    );
  }
}