import 'package:flutter/material.dart';
import 'package:wr_manager/login.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const WrApp());
}

class WrApp extends StatelessWidget {
  const WrApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MetaGanos Depo Yönetimi',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [
        Locale('tr', 'TR'), // Türkçe
      ],
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.deepOrange,
      ),
      home: const LoginPage(
          title: ''), //const MyHomePage(title: 'Depo Yönetim Paneli'),
    );
  }
}
