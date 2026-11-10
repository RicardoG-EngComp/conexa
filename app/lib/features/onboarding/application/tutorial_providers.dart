import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const tutorialSeenKey = 'tutorial_seen_v1';

final tutorialSeenProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(tutorialSeenKey) ?? false;
});

Future<void> setTutorialSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(tutorialSeenKey, true);
}
