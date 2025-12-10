import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:typed_data/typed_buffers.dart';
import 'dart:convert';
import 'dart:js' as js;   // <-- Thêm để TTS

void main() {
  runApp(const SmartGloveApp());
}

class SmartGloveApp extends StatefulWidget {
  const SmartGloveApp({super.key});

  @override
  State<SmartGloveApp> createState() => _SmartGloveAppState();
}

class _SmartGloveAppState extends State<SmartGloveApp> {
  final String broker = "ws://broker.hivemq.com:8000/mqtt";
  final String clientId = "flutter_glove_web_001";

  late MqttBrowserClient client;

  String connectionStatus = "Offline";
  String displayText = ""; 
  String selectedLetter = "A";

  List<String> dictionary = [];
  List<String> suggestions = [];

  List<String> letters = [
    "A","B","C","D","E","F","G","H","I","J","K","L","M",
    "N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
    "(space)"
  ];

  @override
  void initState() {
    super.initState();
    loadDictionary();
    _connectMqtt();
  }

  // LOAD DICTIONARY
  Future<void> loadDictionary() async {
    final text = await rootBundle.loadString("assets/dictionary.txt");
    dictionary = text
        .split("\n")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    setState(() {});
  }

  // UPDATE SUGGESTIONS
  void updateSuggestions() {
    if (displayText.isEmpty) {
      suggestions = [];
      setState(() {});
      return;
    }

    String lastWord = displayText.split(" ").last.toLowerCase();
    if (lastWord.isEmpty) {
      suggestions = [];
      setState(() {});
      return;
    }

    suggestions = dictionary
        .where((w) => w.startsWith(lastWord))
        .take(3)
        .toList();

    setState(() {});
  }

  // MQTT CONNECT
  Future<void> _connectMqtt() async {
    client = MqttBrowserClient(broker, clientId);
    client.port = 8000;
    client.websocketProtocols = MqttClientConstants.protocolsMultipleDefault;

    client.onConnected = () => setState(() => connectionStatus = "Online");
    client.onDisconnected = () => setState(() => connectionStatus = "Offline");

    final connMsg = MqttConnectMessage().withClientIdentifier(clientId).startClean();
    client.connectionMessage = connMsg;

    try {
      await client.connect();
      _subscribe();
    } catch (e) {
      print("MQTT ERROR: $e");
    }
  }

  // SUBSCRIBE
  void _subscribe() {
    client.subscribe("glove/recognize_result", MqttQos.atLeastOnce);
    client.subscribe("glove/train_result", MqttQos.atLeastOnce);

    client.updates!.listen((messages) {
      final msg = messages[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(msg.payload.message);

      try {
        final data = jsonDecode(payload);

        if (data["gesture"] != null) {
          String letter = data["gesture"];
          if (letter == "?") return;

          setState(() => displayText += letter);
          updateSuggestions();
        }
      } catch (_) {}
    });
  }

  // TRAIN
  void sendTrain() {
    String value = (selectedLetter == "(space)") ? " " : selectedLetter;
    final msg = Uint8Buffer()..addAll(value.codeUnits);
    client.publishMessage("glove/train", MqttQos.atLeastOnce, msg);
  }

  // RECOGNIZE
  void sendRecognize() {
    final msg = Uint8Buffer()..addAll("1".codeUnits);
    client.publishMessage("glove/recognize", MqttQos.atLeastOnce, msg);
  }

  // 🔊 TTS - GIỌNG NỮ GOOGLE (vi-VN)
  void speakText() {
    if (displayText.isEmpty) return;

    js.context.callMethod("eval", ["""
      var msg = new SpeechSynthesisUtterance("$displayText");
      msg.lang = "vi-VN";
      msg.voice = speechSynthesis.getVoices().find(v => v.lang === "vi-VN" && v.name.toLowerCase().includes("female"));
      msg.rate = 1;
      msg.pitch = 1;
      speechSynthesis.speak(msg);
    """]);
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF181818),

        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text("Smart Glove"),
          actions: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                connectionStatus,
                style: TextStyle(
                  color: connectionStatus == "Online" ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        ),

        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // DISPLAY + TTS + DELETE
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 120,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        displayText.isEmpty ? "-" : displayText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // 🔊 NÚT LOA — ĐỌC GIỌNG NỮ GOOGLE
                  IconButton(
                    onPressed: speakText,
                    icon: const Icon(Icons.volume_up, color: Colors.white, size: 34),
                  ),

                  const SizedBox(width: 5),

                  // ❌ XOÁ 1 KÝ TỰ hoặc XOÁ HẾT
                  GestureDetector(
                    onTap: () {
                      if (displayText.isNotEmpty) {
                        setState(() {
                          displayText = displayText.substring(0, displayText.length - 1);
                        });
                        updateSuggestions();
                      }
                    },
                    onLongPress: () {
                      setState(() {
                        displayText = "";
                        suggestions = [];
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.white, size: 30),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 3 GỢI Ý
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: suggestions.map((word) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ElevatedButton(
                      onPressed: () {
                        List<String> parts = displayText.split(" ");
                        parts.removeLast();
                        parts.add(word);
                        displayText = parts.join(" ") + " ";

                        setState(() {});
                        updateSuggestions();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                      ),
                      child: Text(word),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 25),

              _button("Nhận dạng", sendRecognize),

              const SizedBox(height: 25),

              // TRAIN SELECT
              DropdownButton<String>(
                value: selectedLetter,
                dropdownColor: Colors.black,
                style: const TextStyle(color: Colors.white, fontSize: 20),
                items: letters.map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: Text(e == "(space)" ? "␣ SPACE" : e),
                  );
                }).toList(),
                onChanged: (v) => setState(() => selectedLetter = v!),
              ),

              const SizedBox(height: 15),

              _button("Train ký tự: $selectedLetter", sendTrain),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(String label, VoidCallback action) {
    return ElevatedButton(
      onPressed: action,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 18)),
    );
  }
}
