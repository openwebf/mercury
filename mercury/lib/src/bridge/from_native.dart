/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mercury/bridge.dart';
import 'package:mercury/launcher.dart';

String uint16ToString(Pointer<Uint16> pointer, int length) {
  return String.fromCharCodes(pointer.asTypedList(length));
}

Pointer<Uint16> _stringToUint16(String string) {
  final units = string.codeUnits;
  final Pointer<Uint16> result = malloc.allocate<Uint16>(units.length * sizeOf<Uint16>());
  final Uint16List nativeString = result.asTypedList(units.length);
  nativeString.setAll(0, units);
  return result;
}

Pointer<NativeString> stringToNativeString(String string) {
  Pointer<NativeString> nativeString = malloc.allocate<NativeString>(sizeOf<NativeString>());
  nativeString.ref.string = _stringToUint16(string);
  nativeString.ref.length = string.length;
  return nativeString;
}

int doubleToUint64(double value) {
  var byteData = ByteData(8);
  byteData.setFloat64(0, value);
  return byteData.getUint64(0);
}

int doubleToInt64(double value) {
  var byteData = ByteData(8);
  byteData.setFloat64(0, value);
  return byteData.getInt64(0);
}

double uInt64ToDouble(int value) {
  var byteData = ByteData(8);
  byteData.setInt64(0, value);
  return byteData.getFloat64(0);
}

String nativeStringToString(Pointer<NativeString> pointer) {
  return uint16ToString(pointer.ref.string, pointer.ref.length);
}

void freeNativeString(Pointer<NativeString> pointer) {
  malloc.free(pointer.ref.string);
  malloc.free(pointer);
}

// Steps for using dart:ffi to call a Dart function from C:
// 1. Import dart:ffi.
// 2. Create a typedef with the FFI type signature of the Dart function.
// 3. Create a typedef for the variable that you’ll use when calling the
//    Dart function.
// 4. Open the dynamic library that register in the C.
// 5. Get a reference to the C function, and put it into a variable.
// 6. Call from C.

// Register InvokeModule
typedef NativeAsyncModuleCallback = Pointer<NativeValue> Function(
    Pointer<Void> callbackContext, Int32 contextId, Pointer<Utf8> errmsg, Pointer<NativeValue> ptr);
typedef DartAsyncModuleCallback = Pointer<NativeValue> Function(
    Pointer<Void> callbackContext, int contextId, Pointer<Utf8> errmsg, Pointer<NativeValue> ptr);

typedef NativeInvokeModule = Pointer<NativeValue> Function(
    Pointer<Void> callbackContext,
    Int32 contextId,
    Pointer<NativeString> module,
    Pointer<NativeString> method,
    Pointer<NativeValue> params,
    Pointer<NativeFunction<NativeAsyncModuleCallback>>);

dynamic invokeModule(Pointer<Void> callbackContext, MercuryController controller, String moduleName, String method, params,
    DartAsyncModuleCallback callback) {
  MercuryContextController currentView = controller.context;
  dynamic result;

  Stopwatch? stopwatch;
  if (isEnabledLog) {
    stopwatch = Stopwatch()..start();
  }

  try {
    Future<dynamic> invokeModuleCallback({String? error, data}) {
      Completer<dynamic> completer = Completer();
      // To make sure Promise then() and catch() executed before Promise callback called at JavaScript side.
      // We should make callback always async.
      Future.microtask(() {
        if (controller.context != currentView || currentView.disposed) return;
        Pointer<NativeValue> callbackResult = nullptr;
        if (error != null) {
          Pointer<Utf8> errmsgPtr = error.toNativeUtf8();
          callbackResult = callback(callbackContext, currentView.contextId, errmsgPtr, nullptr);
          malloc.free(errmsgPtr);
        } else {
          Pointer<NativeValue> dataPtr = malloc.allocate(sizeOf<NativeValue>());
          toNativeValue(dataPtr, data);
          callbackResult = callback(callbackContext, currentView.contextId, nullptr, dataPtr);
          malloc.free(dataPtr);
        }

        var returnValue = fromNativeValue(currentView, callbackResult);
        if (isEnabledLog) {
          print('Invoke module callback from(name: $moduleName method: $method, params: $params) return: $returnValue time: ${stopwatch!.elapsedMicroseconds}us');
        }

        malloc.free(callbackResult);
        completer.complete(returnValue);
      });
      return completer.future;
    }

    result = controller.module.moduleManager.invokeModule(
        moduleName, method, params, invokeModuleCallback);
  } catch (e, stack) {
    if (isEnabledLog) {
      print('Invoke module failed: $e\n$stack');
    }
    String error = '$e\n$stack';
    callback(callbackContext, currentView.contextId, error.toNativeUtf8(), nullptr);
  }

  if (isEnabledLog) {
    print('Invoke module name: $moduleName method: $method, params: $params return: $result time: ${stopwatch!.elapsedMicroseconds}us');
  }

  return result;
}

Pointer<NativeValue> _invokeModule(
    Pointer<Void> callbackContext,
    int contextId,
    Pointer<NativeString> module,
    Pointer<NativeString> method,
    Pointer<NativeValue> params,
    Pointer<NativeFunction<NativeAsyncModuleCallback>> callback) {
  MercuryController controller = MercuryController.getControllerOfJSContextId(contextId)!;
  dynamic result = invokeModule(callbackContext, controller, nativeStringToString(module), nativeStringToString(method),
      fromNativeValue(controller.context, params), callback.asFunction());
  Pointer<NativeValue> returnValue = malloc.allocate(sizeOf<NativeValue>());
  toNativeValue(returnValue, result);
  freeNativeString(module);
  freeNativeString(method);
  return returnValue;
}

final Pointer<NativeFunction<NativeInvokeModule>> _nativeInvokeModule = Pointer.fromFunction(_invokeModule);

// Register reloadApp
typedef NativeReloadApp = Void Function(Int32 contextId);

void _reloadApp(int contextId) async {
  MercuryController controller = MercuryController.getControllerOfJSContextId(contextId)!;

  try {
    await controller.reload();
  } catch (e, stack) {
    print('Dart Error: $e\n$stack');
  }
}

final Pointer<NativeFunction<NativeReloadApp>> _nativeReloadApp = Pointer.fromFunction(_reloadApp);

typedef NativeAsyncCallback = Void Function(Pointer<Void> callbackContext, Int32 contextId, Pointer<Utf8> errmsg);
typedef DartAsyncCallback = void Function(Pointer<Void> callbackContext, int contextId, Pointer<Utf8> errmsg);
typedef NativeRAFAsyncCallback = Void Function(
    Pointer<Void> callbackContext, Int32 contextId, Double data, Pointer<Utf8> errmsg);
typedef DartRAFAsyncCallback = void Function(Pointer<Void>, int contextId, double data, Pointer<Utf8> errmsg);

// Register setTimeout
typedef NativeSetTimeout = Int32 Function(
    Pointer<Void> callbackContext, Int32 contextId, Pointer<NativeFunction<NativeAsyncCallback>>, Int32);

int _setTimeout(
    Pointer<Void> callbackContext, int contextId, Pointer<NativeFunction<NativeAsyncCallback>> callback, int timeout) {
  MercuryController controller = MercuryController.getControllerOfJSContextId(contextId)!;
  MercuryContextController currentView = controller.context;

  return controller.module.setTimeout(timeout, () {
    DartAsyncCallback func = callback.asFunction();
    void _runCallback() {
      if (controller.context != currentView || currentView.disposed) return;

      try {
        func(callbackContext, contextId, nullptr);
      } catch (e, stack) {
        Pointer<Utf8> nativeErrorMessage = ('Error: $e\n$stack').toNativeUtf8();
        func(callbackContext, contextId, nativeErrorMessage);
        malloc.free(nativeErrorMessage);
      }
    }

    // Pause if mercury page paused.
    if (controller.paused) {
      controller.pushPendingCallbacks(_runCallback);
    } else {
      _runCallback();
    }
  });
}

const int SET_TIMEOUT_ERROR = -1;
final Pointer<NativeFunction<NativeSetTimeout>> _nativeSetTimeout =
    Pointer.fromFunction(_setTimeout, SET_TIMEOUT_ERROR);

// Register setInterval
typedef NativeSetInterval = Int32 Function(
    Pointer<Void> callbackContext, Int32 contextId, Pointer<NativeFunction<NativeAsyncCallback>>, Int32);

int _setInterval(
    Pointer<Void> callbackContext, int contextId, Pointer<NativeFunction<NativeAsyncCallback>> callback, int timeout) {
  MercuryController controller = MercuryController.getControllerOfJSContextId(contextId)!;
  MercuryContextController currentView = controller.context;
  return controller.module.setInterval(timeout, () {
    void _runCallbacks() {
      if (controller.context != currentView || currentView.disposed) return;

      DartAsyncCallback func = callback.asFunction();
      try {
        func(callbackContext, contextId, nullptr);
      } catch (e, stack) {
        Pointer<Utf8> nativeErrorMessage = ('Dart Error: $e\n$stack').toNativeUtf8();
        func(callbackContext, contextId, nativeErrorMessage);
        malloc.free(nativeErrorMessage);
      }
    }

    // Pause if mercury page paused.
    if (controller.paused) {
      controller.pushPendingCallbacks(_runCallbacks);
    } else {
      _runCallbacks();
    }
  });
}

const int SET_INTERVAL_ERROR = -1;
final Pointer<NativeFunction<NativeSetInterval>> _nativeSetInterval =
    Pointer.fromFunction(_setInterval, SET_INTERVAL_ERROR);

// Register clearTimeout
typedef NativeClearTimeout = Void Function(Int32 contextId, Int32);

void _clearTimeout(int contextId, int timerId) {
  MercuryController controller = MercuryController.getControllerOfJSContextId(contextId)!;
  return controller.module.clearTimeout(timerId);
}

final Pointer<NativeFunction<NativeClearTimeout>> _nativeClearTimeout = Pointer.fromFunction(_clearTimeout);

typedef NativeJSError = Void Function(Int32 contextId, Pointer<Utf8>);

void _onJSError(int contextId, Pointer<Utf8> charStr) {
  MercuryController? controller = MercuryController.getControllerOfJSContextId(contextId);
  JSErrorHandler? handler = controller?.onJSError;
  if (handler != null) {
    String msg = charStr.toDartString();
    handler(msg);
  }
}

final Pointer<NativeFunction<NativeJSError>> _nativeOnJsError = Pointer.fromFunction(_onJSError);

typedef NativeJSLog = Void Function(Int32 contextId, Int32 level, Pointer<Utf8>);

void _onJSLog(int contextId, int level, Pointer<Utf8> charStr) {
  String msg = charStr.toDartString();
  MercuryController? controller = MercuryController.getControllerOfJSContextId(contextId);
  if (controller != null) {
    JSLogHandler? jsLogHandler = controller.onJSLog;
    if (jsLogHandler != null) {
      jsLogHandler(level, msg);
    }
  }
}

final Pointer<NativeFunction<NativeJSLog>> _nativeOnJsLog = Pointer.fromFunction(_onJSLog);

final List<int> _dartNativeMethods = [
  _nativeInvokeModule.address,
  _nativeReloadApp.address,
  _nativeSetTimeout.address,
  _nativeSetInterval.address,
  _nativeClearTimeout.address,
  _nativeOnJsError.address,
  _nativeOnJsLog.address,
];

List<int> makeDartMethodsData() {
  return _dartNativeMethods;
}
