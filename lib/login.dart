import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:wr_manager/main.dart';
import 'package:wr_manager/model/wr_session.dart';
import 'package:wr_manager/settings.dart';
import 'package:wr_manager/model/app_config.dart';
import 'package:wr_manager/ui/wr_alerts.dart';
// ignore: import_of_legacy_library_into_null_safe
import 'package:http/http.dart';
import 'package:wr_manager/warehouse.dart';
import 'dart:io';
import 'package:wr_manager/settings_pwd.dart';
import 'package:wr_manager/read_card.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final txtLogin = TextEditingController();
  final txtPassword = TextEditingController();
  bool? chkRemindMe = false;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    File('data/settings.json').create(recursive: true).then((File configFile) {
      try {
        final contents = configFile.readAsStringSync();
        final configObj = jsonDecode(contents);
        if (configObj['remindedLogin'] != null &&
            configObj['remindedPwd'] != null) {
          setState(() {
            txtLogin.text = configObj['remindedLogin'];
            txtPassword.text = configObj['remindedPwd'];
            chkRemindMe = true;
          });
        }
      } catch (e) {}
    });
  }

  void _tryLogin() async {
    AppConfig configManager = AppConfig();
    var configObj = configManager.getConfigObject();
    final loginResult =
        await post(configObj['serverAddr'] + 'User/LoginPanelUser',
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'login': txtLogin.text,
              'dealerCode': configObj['dealerCode'],
              'plantCode': configObj['plantCode'],
              'password': txtPassword.text
            }));

    if (loginResult.statusCode == 200) {
      final loginBody = jsonDecode(loginResult.body);
      WrSession session = WrSession();
      session.apiToken = loginBody['Token'];
      session.userName = loginBody['Username'];
      session.userId = loginBody['UserId'];
      session.plantId = loginBody['FactoryId'];
      session.isLoggedByCard = false;

      // save if remind me checked
      if (chkRemindMe == true) {
        File('data/settings.json')
            .create(recursive: true)
            .then((File configFile) {
          try {
            final contents = configFile.readAsStringSync();
            final configObj = jsonDecode(contents);
            configObj['remindedLogin'] = txtLogin.text;
            configObj['remindedPwd'] = txtPassword.text;

            // final String configJson = jsonEncode(configObj);

            // configFile.openWrite();
            // configFile.writeAsStringSync(configJson);
          } catch (e) {}
        });
      } else {
        File('data/settings.json')
            .create(recursive: true)
            .then((File configFile) {
          try {
            final contents = configFile.readAsStringSync();
            final configObj = jsonDecode(contents);
            configObj['remindedLogin'] = null;
            configObj['remindedPwd'] = null;

            // final String configJson = jsonEncode(configObj);

            // configFile.openWrite();
            // configFile.writeAsStringSync(configJson);
          } catch (e) {}
        });
      }

      // ignore: use_build_context_synchronously
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                const WarehousePage(title: 'MetaGanos Depo Yönetimi')),
      );
    } else {
      // ignore: use_build_context_synchronously
      await showWrAlert(context, 'UYARI', 'Hatalı giriş yaptınız.');
    }
  }

  void _showCardLogin() {
    showReadCardPrompt(context, _onCardRead);
  }

  void _onCardRead(String cardNo) async {
    if (cardNo != null && cardNo.length > 0) {
      WrSession session = WrSession();
      session.readCardNo = cardNo;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) =>
                const WarehousePage(title: 'MetaGanos Depo Yönetimi')),
      );
    }
  }

  void _goSettings() {
    showPasswordPrompt(context, _openSettings);
  }

  void _openSettings(String password) {
    if (password == "mg123") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage(title: '')),
      );
    } else {
      showWrAlert(context, 'Hata', 'Hatalı parola girdiniz');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Image.asset(
              'image/asset/appicon.png',
              height: 60,
              fit: BoxFit.fitHeight,
            ),
          ),
          const Text('Depo Yönetimi'),
        ]),
        centerTitle: true,
        actions: <Widget>[
          Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () {},
                child: ElevatedButton(
                  onPressed: _goSettings,
                  child: const Icon(
                    Icons.settings,
                    size: 26.0,
                  ),
                ),
              )),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("image/asset/login_bg.png"),
            fit: BoxFit.fill,
          ),
        ),
        child: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'image/asset/appicon.png',
              width: 400,
              fit: BoxFit.fitWidth,
            ),
            Container(
              color: Color.fromARGB(200, 255, 255, 255),
              width: 400,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: TextFormField(
                  controller: txtLogin,
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    labelText: 'Kullanıcı kodu',
                  ),
                ),
              ),
            ),
            Container(
              color: Color.fromARGB(200, 255, 255, 255),
              width: 400,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
                child: TextFormField(
                  controller: txtPassword,
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    labelText: 'Parola',
                  ),
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                ),
              ),
            ),
            Container(
              color: Color.fromARGB(200, 255, 255, 255),
              width: 400,
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    // children: [
                    //   const Text('Beni hatırla'),
                    //   Checkbox(
                    //     onChanged: (bool? value) {
                    //       setState(() {
                    //         chkRemindMe = value;
                    //       });
                    //     },
                    //     value: chkRemindMe,
                    //   ),
                    // ],
                  )),
            ),
            SizedBox(
                width: 400,
                height: 100,
                child: Row(
                  children: [
                    SizedBox(
                      width: 200,
                      height: 100,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 20),
                        child: ElevatedButton(
                          onPressed: _tryLogin,
                          child: const Text(
                            'Giriş',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      height: 100,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 20),
                        child: ElevatedButton(
                          style: ButtonStyle(
                              backgroundColor:
                                  MaterialStateProperty.all(Colors.black54),
                              foregroundColor:
                                  MaterialStateProperty.all(Colors.white)),
                          onPressed: _showCardLogin,
                          child: const Text(
                            'Kartla Giriş',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                      ),
                    )
                  ],
                )),
          ],
        )),
      ),
    );
  }
}
