import 'package:flutter/material.dart';

class TrainedList extends StatelessWidget {

  final List<String> letters;
  final Function(String) onDelete;

  const TrainedList({
    super.key,
    required this.letters,
    required this.onDelete
  });

  @override
  Widget build(BuildContext context) {

    return Wrap(

      spacing:8,

      children:letters.map((l){

        return Chip(

          label:Text(l),

          deleteIcon:const Icon(Icons.close),

          onDeleted:(){

            onDelete(l);

          },

        );

      }).toList(),

    );

  }
}