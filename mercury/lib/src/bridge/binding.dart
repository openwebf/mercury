/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

// Bind the JavaScript side object,
// provide interface such as property setter/getter, call a property as function.
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:mercuryjs/bridge.dart';
import 'package:mercuryjs/src/global/event.dart';
import 'package:mercuryjs/src/global/event_target.dart';
import 'package:mercuryjs/foundation.dart';
import 'package:mercuryjs/launcher.dart';

// We have some integrated built-in behavior starting with string prefix reuse the callNativeMethod implements.
enum BindingMethodCallOperations {
  GetProperty,
  SetProperty,
  GetAllPropertyNames,
  AnonymousFunctionCall,
  AsyncAnonymousFunction,
}

typedef NativeAsyncAnonymousFunctionCallback = Void Function(
    Pointer<Void> callbackContext, Pointer<NativeValue> nativeValue, Int32 contextId, Pointer<Utf8> errmsg);
typedef DartAsyncAnonymousFunctionCallback = void Function(
    Pointer<Void> callbackContext, Pointer<NativeValue> nativeValue, int contextId, Pointer<Utf8> errmsg);

typedef BindingCallFunc = dynamic Function(BindingObject bindingObject, List<dynamic> args);

List<BindingCallFunc> bindingCallMethodDispatchTable = [
  getterBindingCall,
  setterBindingCall,
  getPropertyNamesBindingCall,
  invokeBindingMethodSync,
  invokeBindingMethodAsync
];

// Dispatch the event to the binding side.
void _dispatchNomalEventToNative(Event event) {
  _dispatchEventToNative(event, false);
}
void _dispatchCaptureEventToNative(Event event) {
  _dispatchEventToNative(event, true);
}
void _dispatchEventToNative(Event event, bool isCapture) {
  Pointer<NativeBindingObject>? pointer = event.currentTarget?.pointer;
  int? contextId = event.target?.contextId;
  MercuryController controller = MercuryController.getControllerOfJSContextId(contextId)!;
  if (contextId != null && pointer != null && pointer.ref.invokeBindingMethodFromDart != nullptr) {
    BindingObject bindingObject = controller.context.getBindingObject(pointer);
    // Call methods implements at C++ side.
    DartInvokeBindingMethodsFromDart f = pointer.ref.invokeBindingMethodFromDart.asFunction();

    Pointer<RawEvent> rawEvent = event.toRaw().cast<RawEvent>();
    List<dynamic> dispatchEventArguments = [event.type, rawEvent, isCapture];

    Stopwatch? stopwatch;
    if (isEnabledLog) {
      stopwatch = Stopwatch()..start();
    }

    Pointer<NativeValue> method = malloc.allocate(sizeOf<NativeValue>());
    toNativeValue(method, 'dispatchEvent');
    Pointer<NativeValue> allocatedNativeArguments = makeNativeValueArguments(bindingObject, dispatchEventArguments);

    Pointer<NativeValue> returnValue = malloc.allocate(sizeOf<NativeValue>());
    f(pointer, returnValue, method, dispatchEventArguments.length, allocatedNativeArguments, event);
    Pointer<EventDispatchResult> dispatchResult = fromNativeValue(controller.context, returnValue).cast<EventDispatchResult>();
    event.cancelable = dispatchResult.ref.canceled;
    event.propagationStopped = dispatchResult.ref.propagationStopped;

    event.sharedJSProps = Pointer.fromAddress(rawEvent.ref.bytes.elementAt(8).value);
    event.propLen = rawEvent.ref.bytes.elementAt(9).value;
    event.allocateLen = rawEvent.ref.bytes.elementAt(10).value;

    if (isEnabledLog) {
      print('dispatch event to native side: target: ${event.target} arguments: $dispatchEventArguments time: ${stopwatch!.elapsedMicroseconds}us');
    }

    // Free the allocated arguments.
    malloc.free(rawEvent);
    malloc.free(method);
    malloc.free(allocatedNativeArguments);
    malloc.free(dispatchResult);
    malloc.free(returnValue);
  }
}

class DummyObject extends BindingObject {
  DummyObject(BindingContext context): super(context);

  @override
  void initializeMethods(Map<String, BindingObjectMethod> methods) {
  }

  @override
  void initializeProperties(Map<String, BindingObjectProperty> properties) {
  }
}

enum CreateBindingObjectType {
  createDummyObject
}

abstract class BindingBridge {
  static final Pointer<NativeFunction<InvokeBindingsMethodsFromNative>> _invokeBindingMethodFromNative =
      Pointer.fromFunction(invokeBindingMethodFromNativeImpl);

  static Pointer<NativeFunction<InvokeBindingsMethodsFromNative>> get nativeInvokeBindingMethod =>
      _invokeBindingMethodFromNative;

  static void createBindingObject(int contextId, Pointer<NativeBindingObject> pointer, CreateBindingObjectType type, Pointer<NativeValue> args, int argc) {
    MercuryController controller = MercuryController.getControllerOfJSContextId(contextId)!;
    switch(type) {
      case CreateBindingObjectType.createDummyObject: {
        DummyObject dummyObject = DummyObject(BindingContext(controller.context, contextId, pointer));
        controller.context.setBindingObject(pointer, dummyObject);
        return;
      }
    }
  }

  // For compatible requirement, we set the MercuryContextController to nullable due to the historical reason.
  // exp: We can not break the types for WidgetElement which will break all the codes for Users.
  static void _bindObject(MercuryContextController? context, BindingObject object) {
    Pointer<NativeBindingObject>? nativeBindingObject = object.pointer;
    if (nativeBindingObject != null) {
      if (context != null) {
        context.setBindingObject(nativeBindingObject, object);
      }

      if (!nativeBindingObject.ref.disposed) {
        nativeBindingObject.ref.invokeBindingMethodFromNative = _invokeBindingMethodFromNative;
      }
    }
  }

  // For compatible requirement, we set the MercuryContextController to nullable due to the historical reason.
  // exp: We can not break the types for WidgetElement which will break all the codes for Users.
  static void _unbindObject(MercuryContextController? context, BindingObject object) {
    Pointer<NativeBindingObject>? nativeBindingObject = object.pointer;
    if (nativeBindingObject != null) {
      nativeBindingObject.ref.invokeBindingMethodFromNative = nullptr;
    }
  }

  static void setup() {
    BindingObject.bind = _bindObject;
    BindingObject.unbind = _unbindObject;
  }

  static void teardown() {
    BindingObject.bind = null;
    BindingObject.unbind = null;
  }

  static void listenEvent(EventTarget target, String type, {Pointer<AddEventListenerOptions>? addEventListenerOptions}) {
    bool isCapture = addEventListenerOptions != null ? addEventListenerOptions.ref.capture : false;
    if (!hasListener(target, type, isCapture: isCapture)) {
      EventListenerOptions? eventListenerOptions;
      if (addEventListenerOptions != null && addEventListenerOptions.ref.capture) {
        eventListenerOptions = EventListenerOptions(addEventListenerOptions.ref.capture, addEventListenerOptions.ref.passive, addEventListenerOptions.ref.once);
        target.addEventListener(type, _dispatchCaptureEventToNative, addEventListenerOptions: eventListenerOptions);
      } else
        target.addEventListener(type, _dispatchNomalEventToNative, addEventListenerOptions: eventListenerOptions);
    }
  }

  static void unlistenEvent(EventTarget target, String type, {bool isCapture = false}) {
    if (isCapture)
      target.removeEventListener(type, _dispatchCaptureEventToNative, isCapture: isCapture);
    else
      target.removeEventListener(type, _dispatchNomalEventToNative, isCapture: isCapture);

  }

  static bool hasListener(EventTarget target, String type, {bool isCapture = false}) {
    Map<String, List<EventHandler>> eventHandlers = isCapture ? target.getCaptureEventHandlers() : target.getEventHandlers();
    List<EventHandler>? handlers = eventHandlers[type];
    if (handlers != null) {
      return isCapture ? handlers.contains(_dispatchCaptureEventToNative) : handlers.contains(_dispatchNomalEventToNative);
    }
    return false;
  }
}
