/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
import 'package:mercuryjs/bridge.dart';
import 'package:mercuryjs/src/global/event.dart';
import 'package:mercuryjs/src/global/event_target.dart';
import 'package:mercuryjs/foundation.dart';

const String GLOBAL = 'GLOBAL';

class Global extends EventTarget {
  Global(BindingContext? context)
      : super(context) {
    BindingBridge.listenEvent(this, 'load');
    BindingBridge.listenEvent(this, 'gcopen');
  }

  @override
  EventTarget? get parentEventTarget => null;

  @override
  void initializeMethods(Map<String, BindingObjectMethod> methods) {
  }

  @override
  void initializeProperties(Map<String, BindingObjectProperty> properties) {
  }

  @override
  Future<void> dispatchEvent(Event event) async {
    if (contextId != null && event.type == EVENT_LOAD || event.type == EVENT_ERROR) {
      flushIsolateCommandWithContextId(contextId!, pointer!);
    }
    return super.dispatchEvent(event);
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
