import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {

  final client = MqttServerClient(
      'broker.emqx.io',
      'flutter_glove_client'
  );

  bool isConnected = false;

  Function(String)? onGesture;
  Function(String)? onTrain;
  Function(List<String>)? onTrainList;

  Future connect({
    required Function(String) onGesture,
    required Function(String) onTrain,
    Function(List<String>)? onTrainList,
  }) async {

    this.onGesture = onGesture;
    this.onTrain = onTrain;
    this.onTrainList = onTrainList;

    client.port = 1883;
    client.keepAlivePeriod = 20;

    final connMess = MqttConnectMessage()
        .withClientIdentifier('flutter_glove_${DateTime.now().millisecondsSinceEpoch}')
        .startClean();

    client.connectionMessage = connMess;

    print("MQTT CONNECTING...");

    await client.connect();

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      print("MQTT CONNECT FAIL");
      return;
    }

    print("MQTT CONNECTED");

    isConnected = true;

    /// LISTENER
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {

      final recMess = c[0].payload as MqttPublishMessage;

      final topic = c[0].topic;

      final msg = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message);

      print("MQTT RECEIVED [$topic] : $msg");

      /// gesture nhận dạng
      if(topic == "glove/gesture"){

        try{

          final data = jsonDecode(msg);

          String g = data["gesture"];

          if(g=="SPACE") g=" ";

          onGesture?.call(g);

        }catch(e){

          print("JSON ERROR");

        }

      }

      /// train xong
      else if(topic == "glove/trained"){

        onTrain?.call(msg.trim());

      }

      /// danh sách chữ đã train
      else if(topic == "glove/trained_list"){

        List<String> letters =
            msg.split(",")
               .map((e)=>e.trim())
               .where((e)=>e.isNotEmpty)
               .toList();

        print("TRAIN LIST FROM ESP: $letters");

        onTrainList?.call(letters);

      }

    });

    /// SUBSCRIBE
    client.subscribe("glove/gesture", MqttQos.atLeastOnce);
    client.subscribe("glove/trained", MqttQos.atLeastOnce);
    client.subscribe("glove/trained_list", MqttQos.atLeastOnce);

Future.delayed(const Duration(milliseconds:500),(){

    publish("glove/get_trained","1");

    print("REQUEST TRAIN LIST");

  });

  }

  void publish(String topic,String msg){

    if(!isConnected){
      print("MQTT chưa connect");
      return;
    }

    final builder = MqttClientPayloadBuilder();

    builder.addString(msg);

    client.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );

  }

  /// train chữ
  void train(String letter){

    publish("glove/train",letter);

  }

  /// clear chữ
  void clear(String letter){

    publish("glove/clear",letter);

  }

  /// clear all
  void clearAll(){

    publish("glove/clear","ALL");

  }

  /// nhận dạng
  void recognize(){

    publish("glove/recognize","1");

  }

}

