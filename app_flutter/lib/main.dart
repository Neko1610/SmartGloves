import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mqtt/mqtt_service.dart';
import 'ui/display_panel.dart';
import 'ui/suggestion_bar.dart';

void main() {
  runApp(const SmartGloveApp());
}

class SmartGloveApp extends StatefulWidget {
  const SmartGloveApp({super.key});

  @override
  State<SmartGloveApp> createState() => _SmartGloveAppState();
}

class _SmartGloveAppState extends State<SmartGloveApp> {

  final mqtt = MqttService();

  String text = "";
  String lastGesture = "";

  List<String> suggestions = [];
  List<String> dictionary = [];

  /// chữ đã train
  List<String> trainedLetters = [];

  /// chữ đang train
  Set<String> training = {};

  List<String> allLetters =
      List.generate(26,(i)=>String.fromCharCode(65+i));

  @override
  void initState() {
    super.initState();

    loadDictionary();

    mqtt.connect(

      /// nhận gesture
      onGesture: (g) {

        if(g == lastGesture) return;

        lastGesture = g;

        setState(() {

          text += (g == "SPACE") ? " " : g;

          updateSuggestions();

        });

      },

      /// train xong
      onTrain: (letter) {

        setState(() {

          training.remove(letter);

          if(!trainedLetters.contains(letter)){
            trainedLetters.add(letter);
          }

        });

      },
      onTrainList: (letters) {
        setState((){
          trainedLetters =letters;
        });
      },
    );
   
  }

  /// load dictionary
  Future loadDictionary() async {

    final data = await rootBundle.loadString("assets/dictionary.txt");

    dictionary = data
        .split("\n")
        .map((e)=>e.trim().toLowerCase())
        .toList();

  }

  /// suggestion
  void updateSuggestions(){

    String lastWord = text.trim().split(" ").last.toLowerCase();

    if(lastWord.isEmpty){
      suggestions=[];
      return;
    }

    suggestions = dictionary
        .where((w)=>w.startsWith(lastWord))
        .take(3)
        .toList();

  }

  /// nhận dạng
  void recognize(){

    mqtt.publish("glove/recognize","1");

  }

  /// train
  void train(String letter){

    setState(() {
      training.add(letter);
    });

    mqtt.train(letter);

  }

  /// delete 1
  void deleteOne(){

    if(text.isEmpty) return;

    setState(() {
      text = text.substring(0,text.length-1);
    });

  }

  /// delete all
  void deleteAll(){

    setState(() {
      text="";
      suggestions=[];
    });

  }

  /// chọn suggestion
  void applySuggestion(String word){

    List parts=text.split(" ");

    parts.removeLast();
    parts.add(word);

    setState(() {

      text=parts.join(" ")+" ";

      suggestions=[];

    });

  }

  @override
  Widget build(BuildContext context) {

    List<String> untrained =
        allLetters.where((l)=>!trainedLetters.contains(l)).toList();

    return MaterialApp(

      debugShowCheckedModeBanner:false,

      home:Scaffold(

        backgroundColor:Colors.white,

        appBar:AppBar(

          backgroundColor:Colors.white,
          elevation:1,

          title:const Text(
            "Smart Glove",
            style:TextStyle(color:Colors.black),
          ),

        ),

        body:Padding(

          padding:const EdgeInsets.all(20),

          child:SingleChildScrollView(

            child:Column(

              crossAxisAlignment:CrossAxisAlignment.start,

              children:[

                /// display
                DisplayPanel(
                  text:text,
                  onDeleteOne:deleteOne,
                  onDeleteAll:deleteAll,
                ),

                const SizedBox(height:10),

                /// suggestion
                SuggestionBar(
                  suggestions:suggestions,
                  onTap:applySuggestion,
                ),

                const SizedBox(height:20),

                /// recognize
                ElevatedButton(

                  style:ElevatedButton.styleFrom(
                    backgroundColor:Colors.blue,
                    padding:const EdgeInsets.symmetric(
                      horizontal:40,
                      vertical:15,
                    ),
                  ),

                  onPressed:recognize,

                  child:const Text(
                    "NHẬN DẠNG",
                    style:TextStyle(fontSize:18),
                  ),

                ),

                const SizedBox(height:25),

                /// CHƯA TRAIN
                const Text(
                  "CHƯA TRAIN",
                  style:TextStyle(
                    fontSize:16,
                    fontWeight:FontWeight.bold,
                  ),
                ),

                const SizedBox(height:10),

                Wrap(

                  spacing:8,
                  runSpacing:8,

                  children:untrained.map((l){

                    bool loading = training.contains(l);

                    return ElevatedButton(

                      style:ElevatedButton.styleFrom(
                        backgroundColor:Colors.grey,
                      ),

                      onPressed:(){
                        if(!loading){
                          train(l);
                        }
                      },

                      child:loading
                          ? const SizedBox(
                              width:16,
                              height:16,
                              child:CircularProgressIndicator(
                                strokeWidth:2,
                                color:Colors.white,
                              ),
                            )
                          : Text(l),

                    );

                  }).toList(),

                ),

                const SizedBox(height:15),

                /// SPACE
                if(!trainedLetters.contains("SPACE"))
                ElevatedButton(
                  style:ElevatedButton.styleFrom(
                    backgroundColor:Colors.orange,
                  ),
                  onPressed:(){
                    train("SPACE");
                  },
                  child:const Text("SPACE"),
                ),

                const SizedBox(height:25),

                /// ĐÃ TRAIN
                const Text(
                  "ĐÃ TRAIN",
                  style:TextStyle(
                    fontSize:16,
                    fontWeight:FontWeight.bold,
                  ),
                ),

                const SizedBox(height:10),

                Wrap(

                  spacing:8,

                  children:trainedLetters.map((l){

                    return AnimatedContainer(

                      duration:const Duration(milliseconds:300),

                      child:Chip(

                       label:Text(l),

                        backgroundColor:Colors.green,

                      ),

                    );

                  }).toList(),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}
