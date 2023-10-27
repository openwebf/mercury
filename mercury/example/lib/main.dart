/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mercury/mercury.dart';
import 'package:mercury/devtools.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized(); //imp line need to be added first
    FlutterError.onError = (FlutterErrorDetails details) {
    //this line prints the default flutter gesture caught exception in console
    //FlutterError.dumpErrorToConsole(details);
    print('Error From INSIDE FRAME_WORK');
    print('----------------------');
    print('Error :  ${details.exception}');
    print('StackTrace :  ${details.stack}');
    };

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kraken Browser',
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

  Mercury? mercury;

  String message = 'Loading...';

  @override
  Widget build(BuildContext context) {
    mercury ??= Mercury(
      devToolsService: ChromeDevToolsService(),
      bundle: MercuryBundle.fromUrl('assets:assets/bundle.js'),
      onControllerCreated: (controller) async {
        setState(() {
          message = 'Controller loading...';
        });
        controller.onLoad = (controller) {
          setState(() {
            message = 'Context loading...';
          });
          // controller.context.dispatcher.subscribe('example', (event) {
          //   setState(() {
          //     message = json.decode(event)['message'];
          //   });
          // });
          controller.context.evaluateJavaScripts('hello();');
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
