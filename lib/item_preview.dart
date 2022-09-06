import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

var _itemImage = '';

Uint8List getBytesOfItemImage() {
  // Image example. Put your data string
  if (_itemImage != null && _itemImage.toString().length > 0) {
    String base64Image = _itemImage;

    final UriData? data = Uri.parse(base64Image).data;

    Uint8List? myImage = data?.contentAsBytes();
    return myImage ?? Uint8List(0);
  }

  return Uint8List(0);
}

Future<void> showItemPreview(BuildContext context, var rawData) async {
  _itemImage = rawData;

  return showDialog<void>(
    context: context,
    barrierDismissible: true, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Ürün Resmi'),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                  width: MediaQuery.of(context).size.width * 0.7 - 100,
                  height: MediaQuery.of(context).size.height * 0.6 - 50,
                  child: Padding(
                      padding: const EdgeInsets.only(
                          top: 10, left: 5, right: 5, bottom: 5),
                      child: Image.memory(getBytesOfItemImage(),
                          width: MediaQuery.of(context).size.width * 0.7 - 120,
                          // cacheWidth: 100,
                          // cacheHeight: 100,
                          gaplessPlayback: true,
                          fit: BoxFit.fitWidth)))
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('KAPAT'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
