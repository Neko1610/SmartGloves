import 'package:flutter/material.dart';

import 'screens/main_screen.dart';

void main() {

  runApp(
    const MyApp(),
  );
}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(

      debugShowCheckedModeBanner: false,

      title: 'Smart Glove',

      theme: ThemeData(

        scaffoldBackgroundColor:
            Colors.white,

        fontFamily: 'Roboto',

        appBarTheme: const AppBarTheme(

          backgroundColor: Colors.white,

          foregroundColor: Colors.black,

          elevation: 0,
        ),
      ),

      home: const MainScreen(),
    );
  }
}