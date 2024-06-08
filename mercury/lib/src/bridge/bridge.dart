/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'dart:async';
import 'dart:ffi';
import 'package:mercuryjs/launcher.dart';

import 'binding.dart';
import 'from_native.dart';
import 'to_native.dart';
import 'multiple_thread.dart';

class DartContext {
  DartContext() : pointer = allocateNewMercuryIsolateSync(makeDartMethodsData()) {
    initDartDynamicLinking();
    registerDartContextFinalizer(this);
  }
  final Pointer<Void> pointer;
}

DartContext? dartContext;

bool isJSRunningInDedicatedThread(double contextId) {
  return contextId >= 0;
}

/// Init bridge
FutureOr<double> initBridge(MercuryContextController view, MercuryThread runningThread) async {
  dartContext ??= DartContext();

  // Setup binding bridge.
  BindingBridge.setup();

  double newContextId = runningThread.identity();
  await allocateNewIsolate(runningThread is FlutterIsolateThread, newContextId, runningThread.syncBufferSize());

  return newContextId;
}
