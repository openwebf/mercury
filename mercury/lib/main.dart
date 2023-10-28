/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mercury_js/mercury_js.dart';

typedef OnControllerCreated = void Function(MercuryController controller);

class Mercury {

  //  The initial bundle to load.
  final MercuryBundle? bundle;

  // A method channel for receiving messaged from JavaScript code and sending message to JavaScript.
  final MercuryMethodChannel? javaScriptChannel;

  // Trigger when mercury controller once created.
  final OnControllerCreated? onControllerCreated;

  final LoadErrorHandler? onLoadError;

  final LoadHandler? onLoad;

  final JSErrorHandler? onJSError;

  // Open a service to support Chrome DevTools for debugging.
  final DevToolsService? devToolsService;

  final HttpClientInterceptor? httpClientInterceptor;

  final UriParser? uriParser;

  MercuryController? controller;

  Future<void> load(MercuryBundle bundle) async {
    await controller?.load(bundle);
  }

  Future<void> reload() async {
    await controller?.reload();
  }

  static void addEventTarget(String className, EventTargetCreator creator) {
    MercuryContextController.addEventTargetClass(className, creator);
  }

  Mercury({
      Key? key,
      this.bundle,
      this.onControllerCreated,
      this.onLoad,
      this.javaScriptChannel,
      this.devToolsService,
      // mercury's http client interceptor.
      this.httpClientInterceptor,
      this.uriParser,
      // Callback functions when loading Javascript scripts failed.
      this.onLoadError,
      this.onJSError
    }) {
      controller = MercuryController(shortHash(this),
        entrypoint: bundle,
        onLoad: onLoad,
        onLoadError: onLoadError,
        onJSError: onJSError,
        methodChannel: javaScriptChannel,
        devToolsService: devToolsService,
        httpClientInterceptor: httpClientInterceptor,
        uriParser: uriParser);

      if (onControllerCreated != null) {
        onControllerCreated!(controller!);
      }
  }
}
