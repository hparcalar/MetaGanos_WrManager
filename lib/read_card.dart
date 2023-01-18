import 'dart:developer';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:wr_manager/model/wr_session.dart';
import 'model/app_config.dart';
import 'package:http/http.dart';

var _promptedCardNo = '';
var _selectionCallback = null;
var _dialogContext = null;
var _stateFunc = null;

Future<void> showReadCardPrompt(BuildContext context, Function callback) async {
  _dialogContext = context;
  _selectionCallback = callback;

  final txtCardNo = TextEditingController();
  late FocusNode focusNodeOfCardNo;
  late FocusNode focusNodeOfKeyboard;

  return showDialog<void>(
    context: context,
    barrierDismissible: true, // user must tap button!
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          _stateFunc = setState;
          focusNodeOfCardNo = FocusNode();
          focusNodeOfKeyboard = FocusNode();

          var lastCardReadDate = DateTime.now();
          var cardTimeOutIsRunning = false;

          void _readCard() async {
            var cardNo = txtCardNo.text;
            AppConfig configManager = AppConfig();
            var configObj = configManager.getConfigObject();
            final loginResult =
                await post(configObj['serverAddr'] + 'User/LoginCard',
                    headers: {
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({
                      'login': cardNo,
                      'dealerCode': configObj['dealerCode'],
                      'plantCode': configObj['plantCode'],
                      'password': ''
                    }));

            if (loginResult.statusCode == 200 &&
                jsonDecode(loginResult.body)['result'] == true) {
              final loginBody = jsonDecode(loginResult.body);
              WrSession session = WrSession();
              session.apiToken = loginBody['token'];
              session.plantId = loginBody['employee']['plantId'];
              _promptedCardNo = cardNo;
              txtCardNo.text = '';
              Navigator.of(context).pop();
              callback(cardNo);
            } else {
              if (cardNo.isNotEmpty) {
                txtCardNo.text = '';
                var snackBar = SnackBar(
                  content: Text('OKUTULAN KART BİLGİLERİ GEÇERSİZ.'),
                );
                ScaffoldMessenger.of(context).showSnackBar(snackBar);
              }
            }
          }

          void _checkCardTimes() {
            var dtNow = DateTime.now();
            var diff = dtNow.difference(lastCardReadDate).inMilliseconds;
            if (diff >= 750 && diff >= 0) {
              _readCard();
            }
          }

          Future<void> _checkCardTimeout() async {
            if (cardTimeOutIsRunning == true) {
              return;
            }
            cardTimeOutIsRunning = true;
            Future.delayed(
                const Duration(milliseconds: 750), () => _checkCardTimes());
            cardTimeOutIsRunning = false;
          }

          return AlertDialog(
            title: const Text('Kart Okutunuz'),
            content: Container(
              width: MediaQuery.of(context).size.width * 0.2,
              height: MediaQuery.of(context).size.height * 0.2 - 10,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 400,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 15),
                        child: RawKeyboardListener(
                          focusNode: focusNodeOfKeyboard,
                          child: TextFormField(
                            autofocus: true,
                            focusNode: focusNodeOfCardNo,
                            controller: txtCardNo,
                            obscureText: true,
                            decoration: const InputDecoration(
                              border: UnderlineInputBorder(),
                              labelText: 'KART OKUTUNUZ',
                            ),
                          ),
                          onKey: (RawKeyEvent event) {
                            if (event.runtimeType == RawKeyUpEvent) {
                              lastCardReadDate = DateTime.now();
                              _checkCardTimeout();
                            }
                          },
                        )),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('VAZGEÇ'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('GİRİŞ'),
                onPressed: () {
                  Navigator.of(context).pop();
                  lastCardReadDate = DateTime.now();
                  _readCard();
                },
              ),
            ],
          );
        },
      );
    },
  );
}
