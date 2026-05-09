import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {

  final List<String> history;

  const HistoryScreen({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text("Lịch sử nhận dạng"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,

        itemBuilder: (context, i){

          final item = history[history.length - 1 - i];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                )
              ],
            ),

            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                Text(
                  item,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  TimeOfDay.now().format(context),
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}