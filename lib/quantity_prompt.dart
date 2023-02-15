import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

var _promptedPassword = '';
var _selectionCallback = null;
var _dialogContext = null;
var _stateFunc = null;

Future<void> showQuantityPrompt(BuildContext context, Function callback) async {
  _dialogContext = context;
  _selectionCallback = callback;

  final txtPassword = TextEditingController();
  late FocusNode focusNodeOfPassword;

  return showDialog<void>(
    context: context,
    barrierDismissible: true, // user must tap button!
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          _stateFunc = setState;
          focusNodeOfPassword = FocusNode();
          return AlertDialog(
            title: const Text('Miktar Giriniz'),
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
                      child: TextFormField(
                        autofocus: true,
                        focusNode: focusNodeOfPassword,
                        controller: txtPassword,
                        decoration: const InputDecoration(
                          border: UnderlineInputBorder(),
                          labelText: 'Miktar',
                        ),
                        enableSuggestions: false,
                        autocorrect: false,
                      ),
                    ),
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
                child: const Text('TAMAM'),
                onPressed: () {
                  Navigator.of(context).pop();
                  callback(txtPassword.text);
                },
              ),
            ],
          );
        },
      );
    },
  );
}
