import 'dart:ffi';

class WrSession {
  static final WrSession _singleton = WrSession._internal();
  late String apiToken = '';
  late String userName = '';
  late int plantId = 0;
  late int userId = 0;
  late String readCardNo = '';
  late bool isLoggedByCard = false;

  factory WrSession() {
    return _singleton;
  }

  WrSession._internal();
}
