import 'dart:convert';
import 'dart:io';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:wr_manager/login.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final txtServerAddr = TextEditingController();
  final txtPlantCode = TextEditingController();
  final txtDealerCode = TextEditingController();
  final txtWarehouseCode = TextEditingController();
  bool? chkEmployeeSelection = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    File('data/settings.json').create(recursive: true).then((File configFile) {
      try {
        final contents = configFile.readAsStringSync();
        final configObj = jsonDecode(contents);
        txtServerAddr.text = configObj['serverAddr'];
        txtDealerCode.text = configObj['dealerCode'];
        txtPlantCode.text = configObj['plantCode'];
        txtWarehouseCode.text = configObj['warehouseCode'];

        if (configObj['employeeSelection'] != null) {
          setState(() {
            try {
              chkEmployeeSelection = configObj['employeeSelection'];
            } catch (e) {}
          });
        }
      } catch (e) {
        log(e.toString());
      }
    });
  }

  void _saveSettings() async {
    try {
      Map<String, dynamic> configObj = <String, dynamic>{};
      configObj['serverAddr'] = txtServerAddr.text;
      configObj['dealerCode'] = txtDealerCode.text;
      configObj['plantCode'] = txtPlantCode.text;
      configObj['warehouseCode'] = txtWarehouseCode.text;

      try {
        configObj['employeeSelection'] = chkEmployeeSelection ?? false;
      } catch (eInner) {}

      final String configJson = jsonEncode(configObj);

      if (configJson.isNotEmpty) {
        final configFile = File('data/settings.json');
        if (!(await configFile.exists())) await configFile.create();
        var writer = configFile.openWrite();
        writer.write(configJson);
        //configFile.writeAsStringSync(configJson);
        await writer.flush();
        await writer.close();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage(title: '')),
      );
    } catch (e) {
      log(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    // WidgetsBinding.instance.addPostFrameCallback(_onLoad);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistem Erişim Ayarları'),
        centerTitle: true,
        actions: <Widget>[
          Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () {},
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Icon(
                    Icons.save,
                    size: 26.0,
                  ),
                ),
              )),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 400,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: TextFormField(
                      controller: txtServerAddr,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                        labelText: 'Sunucu adresi',
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 400,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: TextFormField(
                      controller: txtPlantCode,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                        labelText: 'Fabrika kodu',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 400,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: TextFormField(
                      controller: txtWarehouseCode,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                        labelText: 'Depo kodu',
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 400,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: TextFormField(
                      controller: txtDealerCode,
                      decoration: const InputDecoration(
                        border: UnderlineInputBorder(),
                        labelText: 'Bayi kodu',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 400,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('Personel Seçimi'),
                        Checkbox(
                          onChanged: (bool? value) {
                            setState(() {
                              chkEmployeeSelection = value;
                            });
                          },
                          value: chkEmployeeSelection,
                        ),
                      ],
                    ),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
