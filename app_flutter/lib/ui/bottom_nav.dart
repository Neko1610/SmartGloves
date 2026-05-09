import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {

  final int currentIndex;

  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        boxShadow: [

          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),

      child: BottomNavigationBar(

        currentIndex: currentIndex,

        onTap: onTap,

        backgroundColor: Colors.white,

        selectedItemColor:
            const Color(0xFF4CAF50),

        unselectedItemColor: Colors.grey,

        type: BottomNavigationBarType.fixed,

        elevation: 0,

        items: const [

          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "History",
          ),

        
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}