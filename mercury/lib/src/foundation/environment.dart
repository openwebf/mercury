/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

String? _mercuryTemporaryPath;
Future<String> getMercuryTemporaryPath() async {
  if (_mercuryTemporaryPath == null) {
    String? temporaryDirectory = await getMercuryMethodChannel().invokeMethod<String>('getTemporaryDirectory');
    if (temporaryDirectory == null) {
      throw FlutterError('Can\'t get temporary directory from native side.');
    }
    _mercuryTemporaryPath = temporaryDirectory;
  }
  return _mercuryTemporaryPath!;
}

MethodChannel _methodChannel = const MethodChannel('mercury');
MethodChannel getMercuryMethodChannel() {
  return _methodChannel;
}
