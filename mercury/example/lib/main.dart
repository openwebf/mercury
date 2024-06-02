/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'package:flutter/material.dart';
import 'package:mercuryjs/mercuryjs.dart';
import 'package:mercuryjs/devtools.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mercury Example',
      // theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: MyBrowser(),
    );
  }
}

class MyBrowser extends StatefulWidget {
  MyBrowser({Key? key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyBrowser> {
  OutlineInputBorder outlineBorder = OutlineInputBorder(
    borderSide: BorderSide(color: Colors.transparent, width: 0.0),
    borderRadius: const BorderRadius.all(
      Radius.circular(20.0),
    ),
  );

  Mercury? mercuryjs;

  String message = 'Loading...';

  @override
  Widget build(BuildContext context) {
    final javaScriptChannel = MercuryJavaScriptChannel();

    mercuryjs ??= Mercury(
      devToolsService: ChromeDevToolsService(),
      javaScriptChannel: javaScriptChannel,
      bundle: MercuryBundle.fromUrl('assets:assets/bundle.js'),
      onControllerCreated: (controller) {
        setState(() {
          message = 'Controller loading...';
        });
        controller.onLoad = (controller) {
          setState(() {
            message = 'Context loading...';
          });
          javaScriptChannel.invokeMethod('test', {'state': 'bar', 'test': 472 }).then((value) {
            print(value);
          });
          // controller.context.dispatcher?.subscribe('example', (args) {
          //   print('bar');
          //   setState(() {
          //     message = args[0]['message'];
          //   });
          // });
          // controller.context.evaluateJavaScripts('hello();');
        };
      }
    );
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black87,
          titleSpacing: 10.0,
          title: Container(
            height: 40.0,
            child: Text('Mercury Test')
          ),
        ),
        body: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: Column(
            children: [Text(message)],
          ),
        ));
  }
}
