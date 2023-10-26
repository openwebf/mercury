/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
import 'package:mercury/bridge.dart';
import 'package:mercury/src/global/event.dart';
import 'package:mercury/src/global/event_target.dart';
import 'package:mercury/foundation.dart';

const String GLOBAL = 'GLOBAL';

class Global extends EventTarget {
  Global(BindingContext? context)
      : super(context);

  @override
  EventTarget? get parentEventTarget => null;

  @override
  void initializeMethods(Map<String, BindingObjectMethod> methods) {
  }

  @override
  void initializeProperties(Map<String, BindingObjectProperty> properties) {
  }

  @override
  void dispatchEvent(Event event) {
    super.dispatchEvent(event);
  }

  @override
  void addEventListener(String eventType, EventHandler handler, {EventListenerOptions? addEventListenerOptions}) {
    super.addEventListener(eventType, handler, addEventListenerOptions: addEventListenerOptions);
  }

  @override
  void removeEventListener(String eventType, EventHandler handler, {bool isCapture = false}) {
    super.removeEventListener(eventType, handler, isCapture: isCapture);
  }
}
