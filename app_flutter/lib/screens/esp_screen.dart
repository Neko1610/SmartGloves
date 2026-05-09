import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/mqtt_service.dart';

import '../ui/action_button.dart';
import '../ui/display_panel.dart';
import '../ui/suggestion_bar.dart';
import '../ui/top_bar.dart';
import '../ui/train_panel.dart';

class ESPScreen extends StatefulWidget {

  final Function(String) onHistory;

  final Function(double,double) onMpu;

  final List<double> pitchData;

  final List<double> rollData;

  const ESPScreen({
    super.key,
    required this.onHistory,
    required this.onMpu,
    required this.pitchData,
    required this.rollData,
  });

  @override
  State<ESPScreen> createState() =>
      _ESPScreenState();
}

class _ESPScreenState
    extends State<ESPScreen> {

  late MqttService mqtt;

  String text = "";

  String trainingLetter = "";

  /// MPU
  double pitch = 0;

  double roll = 0;

  /// DICTIONARY
  List<String> dictionary = [];

  List<String> suggestions = [];

  /// LETTERS
  List<String> allLetters =
      List.generate(
        26,
        (i) => String.fromCharCode(65 + i),
      );

  List<String> trainedLetters = [];

  /// LOAD DICTIONARY
  Future<void> loadDictionary() async {

    final data =
        await rootBundle.loadString(
      'assets/dictionary.txt',
    );

    dictionary = data
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    print(
      "DICTIONARY LOADED: ${dictionary.length}",
    );
  }

  /// SUGGESTION
  List<String> getSuggestions(
    String input,
  ) {

    if (input.isEmpty) return [];

    String lastWord =
        input.split(" ").last;

    return dictionary

        .where(

          (word) =>

              word.toLowerCase().startsWith(
                    lastWord.toLowerCase(),
                  ),
        )

        .take(5)

        .toList();
  }

  @override
  void initState() {

    super.initState();

    loadDictionary();

    mqtt = MqttService();

    mqtt.connect(

      /// GESTURE
      onGesture: (g) {

        setState(() {

          text += g;

          /// CALLBACK
          widget.onHistory(g);

          /// SUGGESTIONS
          suggestions =
              getSuggestions(text);

          /// MAX TEXT
          if (text.length > 30) {

            text =
                text.substring(
                  text.length - 30,
                );
          }
        });
      },

      /// TRAIN
      onTrain: (letter) {

        setState(() {

          trainingLetter = "";

          if (!trainedLetters.contains(letter)) {

            trainedLetters.add(letter);
          }
        });
      },

      /// TRAIN LIST
      onTrainList: (list) {

        setState(() {

          trainedLetters = list;
        });
      },

      /// MPU
      onMpu: (p, r) {

        /// CALLBACK
        widget.onMpu(p, r);

        setState(() {

          pitch = p;

          roll = r;
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

      backgroundColor: Colors.white,

      body: SafeArea(

        child: Column(

          children: [

            const TopBar(),

            Expanded(

              child: SingleChildScrollView(

                padding:
                    const EdgeInsets.all(16),

                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    /// DISPLAY
                    DisplayPanel(

                      text: text,

                      onDeleteOne: () {

                        setState(() {

                          if (text.isNotEmpty) {

                            text =
                                text.substring(
                              0,
                              text.length - 1,
                            );
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

                    /// SUGGESTION
                    SuggestionBar(

                      suggestions:
                          suggestions,

                      onSelect: (word) {

                        setState(() {

                          List<String> words =
                              text.split(" ");

                          words[
                              words.length - 1] = word;

                          text =
                              words.join(" ");

                          suggestions.clear();
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    /// MPU CARD
                    Container(

                      padding:
                          const EdgeInsets.all(16),

                      decoration: BoxDecoration(

                        color: Colors.white,

                        borderRadius:
                            BorderRadius.circular(
                          24,
                        ),

                        boxShadow: [

                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.05),

                            blurRadius: 10,
                          ),
                        ],
                      ),

                      child: Row(

                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceAround,

                        children: [

                          /// PITCH
                          Column(

                            children: [

                              const Text(

                                "Pitch",

                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),

                              AnimatedSwitcher(

                                duration:
                                    const Duration(
                                  milliseconds: 200,
                                ),

                                child: Text(

                                  pitch
                                      .toStringAsFixed(
                                    1,
                                  ),

                                  key: ValueKey(
                                    pitch,
                                  ),

                                  style:
                                      const TextStyle(
                                    fontSize: 28,

                                    fontWeight:
                                        FontWeight.bold,

                                    color:
                                        Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          /// ROLL
                          Column(

                            children: [

                              const Text(

                                "Roll",

                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),

                              AnimatedSwitcher(

                                duration:
                                    const Duration(
                                  milliseconds: 200,
                                ),

                                child: Text(

                                  roll
                                      .toStringAsFixed(
                                    1,
                                  ),

                                  key: ValueKey(
                                    roll,
                                  ),

                                  style:
                                      const TextStyle(
                                    fontSize: 28,

                                    fontWeight:
                                        FontWeight.bold,

                                    color:
                                        Colors.blue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// REALTIME CHART
                    Container(

                      height: 320,

                      padding:
                          const EdgeInsets.all(16),

                      decoration: BoxDecoration(

                        color: Colors.white,

                        borderRadius:
                            BorderRadius.circular(
                          24,
                        ),

                        boxShadow: [

                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.05),

                            blurRadius: 10,
                          ),
                        ],
                      ),

                      child: Column(

                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [

                          const Text(

                            "Realtime MPU6050",

                            style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 20),

                          Expanded(

                            child: LineChart(

                              LineChartData(

                                minY: -180,
                                maxY: 180,

                                gridData:
                                    FlGridData(
                                  show: true,
                                ),

                                borderData:
                                    FlBorderData(
                                  show: false,
                                ),

                                titlesData:
                                    FlTitlesData(

                                  topTitles:
                                      AxisTitles(
                                    sideTitles:
                                        SideTitles(
                                      showTitles:
                                          false,
                                    ),
                                  ),

                                  rightTitles:
                                      AxisTitles(
                                    sideTitles:
                                        SideTitles(
                                      showTitles:
                                          false,
                                    ),
                                  ),
                                ),

                                lineBarsData: [

                                  /// PITCH
                                  LineChartBarData(

                                    spots:
                                        List.generate(

                                      widget
                                          .pitchData
                                          .length,

                                      (i) => FlSpot(
                                        i.toDouble(),

                                        widget
                                            .pitchData[i],
                                      ),
                                    ),

                                    color:
                                        Colors.green,

                                    isCurved: true,

                                    barWidth: 4,

                                    dotData:
                                        FlDotData(
                                      show: false,
                                    ),
                                  ),

                                  /// ROLL
                                  LineChartBarData(

                                    spots:
                                        List.generate(

                                      widget
                                          .rollData
                                          .length,

                                      (i) => FlSpot(
                                        i.toDouble(),

                                        widget
                                            .rollData[i],
                                      ),
                                    ),

                                    color:
                                        Colors.blue,

                                    isCurved: true,

                                    barWidth: 4,

                                    dotData:
                                        FlDotData(
                                      show: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(

                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceEvenly,

                            children: [

                              Row(
                                children: [

                                  Container(
                                    width: 14,
                                    height: 14,
                                    color:
                                        Colors.green,
                                  ),

                                  const SizedBox(
                                      width: 8),

                                  const Text(
                                      "Pitch"),
                                ],
                              ),

                              Row(
                                children: [

                                  Container(
                                    width: 14,
                                    height: 14,
                                    color:
                                        Colors.blue,
                                  ),

                                  const SizedBox(
                                      width: 8),

                                  const Text(
                                      "Roll"),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// BUTTON
                    ActionButton(

                      onPressed: () {

                        mqtt.recognize();
                      },
                    ),

                    const SizedBox(height: 32),

                    /// TRAIN PANEL
                    TrainPanel(

                      allLetters:
                          allLetters,

                      trainedLetters:
                          trainedLetters,

                      trainingLetter:
                          trainingLetter,

                      onTap: (l) {

                        setState(() {

                          trainingLetter = l;
                        });

                        mqtt.train(l);
                      },
                    ),

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}