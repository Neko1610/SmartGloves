import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mqtt/mqtt_service.dart';

import 'ui/top_bar.dart';
import 'ui/display_panel.dart';
import 'ui/action_button.dart';
import 'ui/train_panel.dart';
import 'ui/trained_list.dart';
import 'ui/bottom_nav.dart';
import 'ui/suggestion_bar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// MQTT
  late MqttService mqtt;

  /// TEXT HIỂN THỊ
  String text = "";
  String trainingLetter = "";

  /// DICTIONARY + SUGGESTIONS
  List<String> dictionary = [];
  List<String> suggestions = [];

  /// DANH SÁCH
  List<String> allLetters =
      List.generate(26, (i) => String.fromCharCode(65 + i));

  List<String> trainedLetters = [];

  /// LOAD DICTIONARY
  Future<void> loadDictionary() async {
    final data = await rootBundle.loadString('assets/dictionary.txt');

    dictionary = data
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    print("DICTIONARY LOADED: ${dictionary.length} words");
  }

  /// HÀM GỢI Ý
  List<String> getSuggestions(String input) {
    if (input.isEmpty) return [];

    /// lấy từ cuối
    String lastWord = input.split(" ").last;

    return dictionary
        .where((word) => word.toLowerCase().startsWith(lastWord.toLowerCase()))
        .take(5)
        .toList();
  }

  @override
  void initState() {
    super.initState();

    loadDictionary();

    mqtt = MqttService();

    mqtt.connect(
      /// nhận gesture realtime
      onGesture: (g) {
        setState(() {
          text += g;

          /// cập nhật gợi ý
          suggestions = getSuggestions(text);

          /// giới hạn text
          if (text.length > 30) {
            text = text.substring(text.length - 30);
          }
        });
      },

      /// train xong 1 chữ
      onTrain: (letter) {
        setState(() {
          trainingLetter = ""; 

          if (!trainedLetters.contains(letter)) {
            trainedLetters.add(letter);
          }
        });
      },

      /// nhận full list từ ESP
      onTrainList: (list) {
        setState(() {
          trainedLetters = list;
        });
      },
    );
  }

  @override
  void dispose() {
    mqtt.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F131C),
      body: SafeArea(
        child: Column(
          children: [
            /// TOP BAR
            const TopBar(),

            /// CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 🧠 OUTPUT
                    DisplayPanel(
                      text: text,
                      onDeleteOne: () {
                        setState(() {
                          if (text.isNotEmpty) {
                            text = text.substring(0, text.length - 1);
                          }
                        });
                      },
                      onClearAll: () {
                        setState(() {
                          text = "";
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    /// SUGGESTION BAR (NEW)
                    SuggestionBar(
                      suggestions: suggestions,
                      onSelect: (word) {
                        setState(() {
                          List<String> words = text.split(" ");
                          words[words.length - 1] = word;
                          text = words.join(" ");

                          suggestions.clear();
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    /// BUTTON NHẬN DẠNG
                    ActionButton(
                      onPressed: () {
                        mqtt.recognize();
                      },
                    ),

                    const SizedBox(height: 32),

                    /// TRAIN PANEL
                    TrainPanel(
                      allLetters: allLetters,
                      trainedLetters: trainedLetters,
                      trainingLetter: trainingLetter, 
                      onTap: (l) {
                        setState(() {
                          trainingLetter = l; 
                        });

                        mqtt.train(l);
                      },
                    ),

                    const SizedBox(height: 32),

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),

            /// BOTTOM NAV
            const BottomNavBar(),
          ],
        ),
      ),
    );
  }
}
