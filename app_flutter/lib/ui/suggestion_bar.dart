import 'package:flutter/material.dart';

class SuggestionBar extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onSelect;

  const SuggestionBar({
    super.key,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox();

    return Wrap(
      spacing: 8,
      children: suggestions.map((word) {
        return GestureDetector(
          onTap: () => onSelect(word),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00F2FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              word,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}