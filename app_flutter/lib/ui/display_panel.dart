import 'package:flutter/material.dart';

class DisplayPanel extends StatelessWidget {

  final String text;
  final VoidCallback onDeleteOne;
  final VoidCallback onDeleteAll;

  const DisplayPanel({
    super.key,
    required this.text,
    required this.onDeleteOne,
    required this.onDeleteAll
  });

  @override
  Widget build(BuildContext context) {

    return Container(

      width:double.infinity,
      padding:const EdgeInsets.all(20),

      decoration:BoxDecoration(

        color:Colors.white,

        border:Border.all(
          color:Colors.black,
          width:2,
        ),

        borderRadius:BorderRadius.circular(10),

      ),

      child:Row(

        mainAxisAlignment:MainAxisAlignment.spaceBetween,

        children:[

          Expanded(

            child:Text(
              text,
              style:const TextStyle(
                fontSize:28,
                color:Colors.black,
              ),
            ),

          ),

          GestureDetector(

            onTap:onDeleteOne,
            onLongPress:onDeleteAll,

            child:Container(

              padding:const EdgeInsets.symmetric(
                horizontal:15,
                vertical:8,
              ),

              decoration:BoxDecoration(

                color:Colors.red,
                borderRadius:BorderRadius.circular(20),

              ),

              child:const Text(
                "Delete",
                style:TextStyle(color:Colors.white),
              ),

            ),

          )

        ],

      ),

    );

  }
}