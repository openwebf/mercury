/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'dart:ffi';
import 'package:mercury_js/devtools.dart';
import 'package:mercury_js/launcher.dart';

class InspectOverlayModule extends UIInspectorModule {
  @override
  String get name => 'Overlay';

  MercuryContextController get view => devtoolsService.controller!.context;
  InspectOverlayModule(DevToolsService devtoolsService) : super(devtoolsService);

  @override
  void receiveFromFrontend(int? id, String method, Map<String, dynamic>? params) {
  }
}
