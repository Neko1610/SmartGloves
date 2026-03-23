import 'package:flutter/material.dart';

class TrainPanel extends StatelessWidget {

  final List<String> trainedLetters;
  final Function(String) onTrain;

  const TrainPanel({
    super.key,
    required this.trainedLetters,
    required this.onTrain
  });

  @override
  Widget build(BuildContext context) {

    return Wrap(

      spacing:8,
      runSpacing:8,

      children:List.generate(26,(i){

        String letter=String.fromCharCode(65+i);

        bool trained=trainedLetters.contains(letter);

        return ElevatedButton(

          style:ElevatedButton.styleFrom(

            backgroundColor:
            trained?Colors.green:Colors.orange,

          ),

          onPressed:(){

            if(!trained){

              onTrain(letter);

            }

          },

          child:Text(letter),

        );

      }),

    );

  }
}