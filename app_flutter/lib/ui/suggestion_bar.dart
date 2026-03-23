import 'package:flutter/material.dart';

class SuggestionBar extends StatelessWidget {

  final List<String> suggestions;
  final Function(String) onTap;

  const SuggestionBar({
    super.key,
    required this.suggestions,
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {

    if(suggestions.isEmpty) return const SizedBox();

    return Row(

      mainAxisAlignment:MainAxisAlignment.center,

      children:suggestions.map((word){

        return Padding(

          padding:const EdgeInsets.symmetric(horizontal:5),

          child:ElevatedButton(

            onPressed:(){

              onTap(word);

            },

            child:Text(word),

          ),

        );

      }).toList(),

    );
  }
}