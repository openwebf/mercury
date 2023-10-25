/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The Mercury authors. All rights reserved.
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mercury/mercury.dart';

typedef OnControllerCreated = void Function(MercuryController controller);

class Mercury extends InheritedWidget {

  //  The initial bundle to load.
  final MercuryBundle? bundle;

  // A method channel for receiving messaged from JavaScript code and sending message to JavaScript.
  final MercuryMethodChannel? javaScriptChannel;

  // Trigger when webf controller once created.
  final OnControllerCreated? onControllerCreated;

  final LoadErrorHandler? onLoadError;

  final LoadHandler? onLoad;

  final JSErrorHandler? onJSError;

  // Open a service to support Chrome DevTools for debugging.
  final DevToolsService? devToolsService;

  final HttpClientInterceptor? httpClientInterceptor;

  final UriParser? uriParser;

  MercuryController? get controller {
    return MercuryController.getControllerOfName(shortHash(this));
  }

  Future<void> load(MercuryBundle bundle) async {
    await controller?.load(bundle);
  }

  Future<void> reload() async {
    await controller?.reload();
  }

  Mercury(
      {Key? key,
      this.bundle,
      this.onControllerCreated,
      this.onLoad,
      this.javaScriptChannel,
      this.devToolsService,
      // webf's http client interceptor.
      this.httpClientInterceptor,
      this.uriParser,
      // Callback functions when loading Javascript scripts failed.
      this.onLoadError,
      this.onJSError})
      : super(key: key); // TODO

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}
