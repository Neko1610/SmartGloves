import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen> {

  bool autoRecognize = true;

  bool vibration = true;

  double threshold = 60;

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.white,

      appBar: AppBar(

        title: const Text(
          "Settings",
        ),

        backgroundColor: Colors.white,

        elevation: 0,
      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            /// CONNECTION
            Container(

              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(24),

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
                    MainAxisAlignment.spaceBetween,

                children: [

                  Column(

                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: const [

                      Text(
                        "ESP32 Status",

                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 6),

                      Text(
                        "Connected",
                        style: TextStyle(
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  Container(
                    width: 14,
                    height: 14,

                    decoration:
                        const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// AUTO RECOGNIZE
            Container(

              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(24),

                boxShadow: [

                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.05),

                    blurRadius: 10,
                  ),
                ],
              ),

              child: Column(

                children: [

                  SwitchListTile(

                    value: autoRecognize,

                    activeColor: Colors.green,

                    title: const Text(
                      "Auto Recognize",
                    ),

                    subtitle: const Text(
                      "Tự động nhận dạng cử chỉ",
                    ),

                    onChanged: (v){

                      setState(() {
                        autoRecognize = v;
                      });
                    },
                  ),

                  const Divider(),

                  SwitchListTile(

                    value: vibration,

                    activeColor: Colors.green,

                    title: const Text(
                      "Vibration",
                    ),

                    subtitle: const Text(
                      "Rung khi nhận dạng",
                    ),

                    onChanged: (v){

                      setState(() {
                        vibration = v;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// THRESHOLD
            Container(

              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(24),

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

                    "Recognition Threshold",

                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Slider(

                    value: threshold,

                    min: 0,

                    max: 100,

                    activeColor: Colors.green,

                    onChanged: (v){

                      setState(() {
                        threshold = v;
                      });
                    },
                  ),

                  Center(
                    child: Text(

                      "${threshold.toInt()}%",

                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight:
                            FontWeight.bold,

                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// ABOUT
            Container(

              padding: const EdgeInsets.all(20),

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(24),

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

                children: const [

                  Text(

                    "About",

                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 12),

                  Text(
                    "Smart Glove v1.0",
                  ),

                  SizedBox(height: 6),

                  Text(
                    "ESP32 + MPU6050 + Flex Sensor",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}