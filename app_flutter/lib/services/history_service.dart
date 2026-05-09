import 'package:shared_preferences/shared_preferences.dart';

class HistoryService {

  static const String key = "gesture_history";

  static Future<void> save(String value) async {

    final prefs = await SharedPreferences.getInstance();

    List<String> old =
        prefs.getStringList(key) ?? [];

    old.add(value);

    await prefs.setStringList(key, old);
  }

  static Future<List<String>> load() async {

    final prefs = await SharedPreferences.getInstance();

    return prefs.getStringList(key) ?? [];
  }
}