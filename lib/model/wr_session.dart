import 'dart:ffi';

class WrSession {
  static final WrSession _singleton = WrSession._internal();
  late String apiToken = '';
  late String userName = '';
  late int plantId = 0;
  late int userId = 0;

  factory WrSession() {
    return _singleton;
  }

  WrSession._internal();
}
