import 'dart:convert';
import 'dart:io';

class AppConfig {
  getConfigObject() {
    final configFile = File('data/settings.json');

    try {
      final contents = configFile.readAsStringSync();
      final configObj = jsonDecode(contents);

      return configObj;
    } catch (e) {}

    return null;
  }
}
