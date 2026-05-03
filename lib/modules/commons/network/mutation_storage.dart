import 'package:shared_preferences/shared_preferences.dart';

import 'package:drivio_driver/modules/commons/network/mutation.dart';

class MutationStorage {
  static const String _key = 'drivio_mutation_queue';

  Future<List<Mutation>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_key) ?? <String>[];
    return raw.map((String s) => Mutation.decode(s)).toList();
  }

  Future<void> save(List<Mutation> mutations) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = mutations
        .where((Mutation m) => m.status != MutationStatus.completed)
        .map((Mutation m) => m.encode())
        .toList();
    await prefs.setStringList(_key, raw);
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
