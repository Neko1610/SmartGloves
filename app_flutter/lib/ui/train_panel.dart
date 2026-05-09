import 'package:flutter/material.dart';

class TrainPanel extends StatelessWidget {
  final List<String> allLetters;
  final List<String> trainedLetters;
  final String trainingLetter;
  final Function(String) onTap;

  const TrainPanel({
    super.key,
    required this.allLetters,
    required this.trainedLetters,
    required this.onTap,
    required this.trainingLetter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "TRAIN",
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          "Đã train: ${trainedLetters.length}/26",
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: trainedLetters.length / 26,
          backgroundColor: Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation(Color(0xFF00F2FF)),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: allLetters.length,
          itemBuilder: (context, i) {
            String l = allLetters[i];
            bool trained = trainedLetters.contains(l);
            bool isTraining = trainingLetter == l;

            return InkWell(
              onTap: trained || isTraining ? null : () => onTap(l),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: trained
                      ? const Color(0xFF00F2FF).withOpacity(0.2)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: trained ? const Color(0xFF00F2FF) : Colors.black87,
                  ),
                ),
                child: isTraining
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00F2FF),
                        ),
                      )
                    : Text(
                        l,
                        style: TextStyle(
                          color:
                              trained ? const Color(0xFF00F2FF) : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }
}
