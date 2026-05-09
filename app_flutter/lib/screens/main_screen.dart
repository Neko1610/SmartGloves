import 'package:flutter/material.dart';

import '../services/history_service.dart';

import '../ui/bottom_nav.dart';

import 'esp_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  /// HISTORY
  List<String> history = [];

  /// MPU
  List<double> pitchData = [];

  List<double> rollData = [];

  @override
  void initState() {
    super.initState();

    loadHistory();
  }

  /// LOAD LOCAL HISTORY
  Future<void> loadHistory() async {
    history = await HistoryService.load();

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      /// HOME
      ESPScreen(
        /// CHART DATA
        pitchData: pitchData,

        rollData: rollData,

        /// REALTIME HISTORY
        onHistory: (g) async {
          history.add(g);

          /// max 100
          if (history.length > 100) {
            history.removeAt(0);
          }

          /// SAVE LOCAL
          await HistoryService.save(g);

          setState(() {});
        },

        /// REALTIME MPU
        onMpu: (p, r) {
          pitchData.add(p);

          rollData.add(r);

          /// max chart points
          if (pitchData.length > 30) {
            pitchData.removeAt(0);
          }

          if (rollData.length > 30) {
            rollData.removeAt(0);
          }

          setState(() {});
        },
      ),

      /// HISTORY
      HistoryScreen(
        history: history,
      ),

      /// SETTINGS
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (i) {
          setState(() {
            _selectedIndex = i;
          });
        },
      ),
    );
  }
}
