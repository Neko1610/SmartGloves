import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();
}

class _SettingsScreenState
    extends State<SettingsScreen> {

  bool vibration = true;

  Future<void> testVibration() async {

    bool? hasVibrator =
        await Vibration.hasVibrator();

    if (hasVibrator == true) {

      Vibration.vibrate(
        duration: 120,
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(

        title: const Text(
          "Settings",
        ),

        centerTitle: true,

        backgroundColor: Colors.white,

        elevation: 0,
      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(20),

        child: Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            /// STATUS
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
                        "ESP32 + MQTT",

                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 10),

                      Row(
                        children: [

                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),

                          SizedBox(width: 8),

                          Text(
                            "ESP32 Connected",

                            style: TextStyle(
                              color: Colors.green,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 8),

                      Row(
                        children: [

                          Icon(
                            Icons.cloud_done,
                            color: Colors.green,
                            size: 18,
                          ),

                          SizedBox(width: 8),

                          Text(
                            "MQTT Connected",

                            style: TextStyle(
                              color: Colors.green,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  Container(

                    width: 16,
                    height: 16,

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

            /// VIBRATION
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

                    value: vibration,

                    activeColor: Colors.green,

                    contentPadding:
                        EdgeInsets.zero,

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

                      if (v) {

                        testVibration();
                      }
                    },
                  ),

                  const Divider(),

                  ListTile(

                    contentPadding:
                        EdgeInsets.zero,

                    leading: const Icon(
                      Icons.vibration,
                      color: Colors.green,
                    ),

                    title: const Text(
                      "Test Vibration",
                    ),

                    subtitle: const Text(
                      "Kiểm tra rung thiết bị",
                    ),

                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                    ),

                    onTap: () {

                      testVibration();
                    },
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

                  SizedBox(height: 14),

                  Row(
                    children: [

                      Icon(
                        Icons.smart_toy,
                        color: Colors.green,
                      ),

                      SizedBox(width: 10),

                      Text(
                        "Smart Glove v1.0",
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  Row(
                    children: [

                      Icon(
                        Icons.memory,
                        color: Colors.green,
                      ),

                      SizedBox(width: 10),

                      Text(
                        "ESP32 + MPU6050 + Flex Sensor",
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  Row(
                    children: [

                      Icon(
                        Icons.code,
                        color: Colors.green,
                      ),

                      SizedBox(width: 10),

                      Text(
                        "Flutter + MQTT + ESP-IDF",
                      ),
                    ],
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