import 'package:flutter/material.dart';

class DisplayPanel extends StatelessWidget {
  final String text;
  final Function() onDeleteOne;
  final Function() onClearAll;

  const DisplayPanel({
    super.key,
    required this.text,
    required this.onDeleteOne,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // 🔥 full ngang
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// 🔤 TITLE + BUTTON
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recognized Output",
               
              ),

              /// ❌ DELETE BUTTON
              GestureDetector(
                onTap: onDeleteOne, // xóa 1 chữ
                onLongPress: onClearAll, // giữ để xóa hết
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.backspace,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          /// 🧠 TEXT OUTPUT
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Text(
                text.isEmpty ? "..." : text,
                style: const TextStyle(
                  fontSize: 32,
                  color: Colors.black,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}