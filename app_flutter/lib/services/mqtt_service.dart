import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {

  final client = MqttServerClient(
    'broker.emqx.io',
    'flutter_glove_client',
  );

  bool isConnected = false;

  /// CALLBACKS
  Function(String)? onGesture;

  Function(String)? onTrain;

  Function(List<String>)? onTrainList;

  Function(double,double)? onMpu;

  /// CONNECT
  Future<void> connect({

    required Function(String) onGesture,

    required Function(String) onTrain,

    Function(List<String>)? onTrainList,

    Function(double,double)? onMpu,

  }) async {

    this.onGesture = onGesture;

    this.onTrain = onTrain;

    this.onTrainList = onTrainList;

    this.onMpu = onMpu;

    client.port = 1883;

    client.keepAlivePeriod = 20;

    client.autoReconnect = true;

    client.logging(on: false);

    /// CONNECTED
    client.onConnected = () {

      print("✅ MQTT CONNECTED");

      isConnected = true;
    };

    /// DISCONNECTED
    client.onDisconnected = () {

      print("❌ MQTT DISCONNECTED");

      isConnected = false;
    };

    final connMess = MqttConnectMessage()

        .withClientIdentifier(
          'flutter_glove_${DateTime.now().millisecondsSinceEpoch}',
        )

        .startClean();

    client.connectionMessage = connMess;

    try {

      print("MQTT CONNECTING...");

      await client.connect();

    } catch (e) {

      print("MQTT ERROR: $e");

      client.disconnect();

      return;
    }

    if (client.connectionStatus?.state !=
        MqttConnectionState.connected) {

      print("MQTT CONNECT FAIL");

      return;
    }

    /// LISTENER
    client.updates!.listen(

      (List<MqttReceivedMessage<MqttMessage>> c) {

        final recMess =
            c[0].payload as MqttPublishMessage;

        final topic = c[0].topic;

        final msg =
            MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );

        print("📩 [$topic] : $msg");

        /// GESTURE
        if (topic == "glove/gesture") {

          try {

            final data = jsonDecode(msg);

            String g = data["gesture"];

            if (g == "SPACE") {
              g = " ";
            }

            /// MPU
            double pitch =
                (data["pitch"] ?? 0).toDouble();

            double roll =
                (data["roll"] ?? 0).toDouble();

            onGesture?.call(g);

            onMpu?.call(pitch, roll);

          } catch (e) {

            print("JSON ERROR: $e");
          }
        }

        /// TRAINED
        else if (topic == "glove/trained") {

          onTrain?.call(msg.trim());
        }

        /// TRAIN LIST
        else if (topic == "glove/trained_list") {

          List<String> letters =

              msg
                  .split(",")

                  .map((e) => e.trim())

                  .where((e) => e.isNotEmpty)

                  .toList();

          onTrainList?.call(letters);
        }
      },
    );

    /// SUBSCRIBE
    client.subscribe(
      "glove/gesture",
      MqttQos.atLeastOnce,
    );

    client.subscribe(
      "glove/trained",
      MqttQos.atLeastOnce,
    );

    client.subscribe(
      "glove/trained_list",
      MqttQos.atLeastOnce,
    );

    /// REQUEST TRAIN LIST
    Future.delayed(
      const Duration(milliseconds: 500),
      () {

        publish("glove/get_trained", "1");
      },
    );
  }

  /// PUBLISH
  void publish(
    String topic,
    String msg,
  ) {

    if (!isConnected) {

      print("MQTT chưa connect");

      return;
    }

    final builder =
        MqttClientPayloadBuilder();

    builder.addString(msg);

    client.publishMessage(

      topic,

      MqttQos.atLeastOnce,

      builder.payload!,
    );
  }

  /// TRAIN
  void train(String letter) {

    publish("glove/train", letter);
  }

  /// CLEAR ONE
  void clear(String letter) {

    publish("glove/clear", letter);
  }

  /// CLEAR ALL
  void clearAll() {

    publish("glove/clear", "ALL");
  }

  /// RECOGNIZE
  void recognize() {

    publish("glove/recognize", "1");
  }

  /// DISCONNECT
  void disconnect() {

    client.disconnect();
  }
}