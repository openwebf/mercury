/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The Mercury authors. All rights reserved.
 */

import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:mercuryjs/src/global/event.dart';
import 'package:mercuryjs/mercuryjs.dart';

// Steps for using dart:ffi to call a C function from Dart:
// 1. Import dart:ffi.
// 2. Create a typedef with the FFI type signature of the C function.
// 3. Create a typedef for the variable that you’ll use when calling the C function.
// 4. Open the dynamic library that contains the C function.
// 5. Get a reference to the C function, and put it into a variable.
// 6. Call the C function.

class MercuryInfo {
  final Pointer<NativeMercuryInfo> _nativeMercuryInfo;

  MercuryInfo(Pointer<NativeMercuryInfo> info) : _nativeMercuryInfo = info;

  String get appName {
    if (_nativeMercuryInfo.ref.app_name == nullptr) return '';
    return _nativeMercuryInfo.ref.app_name.toDartString();
  }

  String get appVersion {
    if (_nativeMercuryInfo.ref.app_version == nullptr) return '';
    return _nativeMercuryInfo.ref.app_version.toDartString();
  }

  String get appRevision {
    if (_nativeMercuryInfo.ref.app_revision == nullptr) return '';
    return _nativeMercuryInfo.ref.app_revision.toDartString();
  }

  String get systemName {
    if (_nativeMercuryInfo.ref.system_name == nullptr) return '';
    return _nativeMercuryInfo.ref.system_name.toDartString();
  }
}


// Register Native Callback Port
final interactiveCppRequests = RawReceivePort((message) {
  requestExecuteCallback(message);
});

final int nativePort = interactiveCppRequests.sendPort.nativePort;

class NativeWork extends Opaque {}

final _executeNativeCallback = MercuryDynamicLibrary.ref
    .lookupFunction<Void Function(Pointer<NativeWork>), void Function(Pointer<NativeWork>)>('executeNativeCallback');

Completer? _working_completer;

FutureOr<void> waitingSyncTaskComplete(double contextId) async {
  if (_working_completer != null) {
    return _working_completer!.future;
  }
}

void requestExecuteCallback(message) {
  try {
    final List<dynamic> data = message;
    final bool isSync = data[0] == 1;
    if (isSync) {
      _working_completer = Completer();
    }

    final int workAddress = data[1];
    final work = Pointer<NativeWork>.fromAddress(workAddress);
    _executeNativeCallback(work);
    _working_completer?.complete();
    _working_completer = null;
  } catch (e, stack) {
    print('requestExecuteCallback error: $e\n$stack');
  }
}

// Register invokeEventListener
typedef NativeInvokeEventListener = Void Function(
    Pointer<Void>,
    Pointer<NativeString>,
    Pointer<Utf8> eventType,
    Pointer<Void> nativeEvent,
    Pointer<NativeValue>,
    Handle object,
    Pointer<NativeFunction<NativeInvokeModuleCallback>> returnCallback);
typedef DartInvokeEventListener = void Function(
    Pointer<Void>,
    Pointer<NativeString>,
    Pointer<Utf8> eventType,
    Pointer<Void> nativeEvent,
    Pointer<NativeValue>,
    Object object,
    Pointer<NativeFunction<NativeInvokeModuleCallback>> returnCallback);
typedef NativeInvokeModuleCallback = Void Function(Handle object, Pointer<NativeValue> result);

final DartInvokeEventListener _invokeModuleEvent =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeInvokeEventListener>>('invokeModuleEvent').asFunction();

void _invokeModuleCallback(_InvokeModuleCallbackContext context, Pointer<NativeValue> dispatchResult) {
  dynamic result = fromNativeValue(context.controller.context, dispatchResult);
  malloc.free(dispatchResult);
  malloc.free(context.extraData);
  context.completer.complete(result);
}

class _InvokeModuleCallbackContext {
  Completer completer;
  MercuryController controller;
  Pointer<NativeValue> extraData;

  _InvokeModuleCallbackContext(this.completer, this.controller, this.extraData);
}

dynamic invokeModuleEvent(double contextId, String moduleName, Event? event, extra) {
  if (MercuryController.getControllerOfJSContextId(contextId) == null) {
    return null;
  }
  Completer<dynamic> completer = Completer();
  MercuryController controller = MercuryController.getControllerOfJSContextId(contextId)!;

  if (controller.context.disposed) return null;

  Pointer<NativeString> nativeModuleName = stringToNativeString(moduleName);
  Pointer<Void> rawEvent = event == null ? nullptr : event.toRaw().cast<Void>();
  Pointer<NativeValue> extraData = malloc.allocate(sizeOf<NativeValue>());
  toNativeValue(extraData, extra);
  assert(_allocatedMercuryIsolates.containsKey(contextId));

  Pointer<NativeFunction<NativeInvokeModuleCallback>> callback =
      Pointer.fromFunction<NativeInvokeModuleCallback>(_invokeModuleCallback);

  _InvokeModuleCallbackContext callbackContext = _InvokeModuleCallbackContext(completer, controller, extraData);

  scheduleMicrotask(() {
    if (controller.context.disposed) {
      callbackContext.completer.complete(null);
      return;
    }

    _invokeModuleEvent(_allocatedMercuryIsolates[contextId]!, nativeModuleName,
        event == null ? nullptr : event.type.toNativeUtf8(), rawEvent, extraData, callbackContext, callback);
  });

  return completer.future;
}

typedef DartDispatchEvent = int Function(double contextId, Pointer<NativeBindingObject> nativeBindingObject,
    Pointer<NativeString> eventType, Pointer<Void> nativeEvent, int isCustomEvent);

dynamic emitModuleEvent(double contextId, String moduleName, Event? event, extra) {
  return invokeModuleEvent(contextId, moduleName, event, extra);
}

// Register createScreen
typedef NativeCreateScreen = Pointer<Void> Function(Double, Double);
typedef DartCreateScreen = Pointer<Void> Function(double, double);

final DartCreateScreen _createScreen =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeCreateScreen>>('createScreen').asFunction();

Pointer<Void> createScreen(double width, double height) {
  return _createScreen(width, height);
}

// Register evaluateScripts
typedef NativeEvaluateScripts = Void Function(
    Pointer<Void>,
    Pointer<Uint8> code,
    Uint64 code_len,
    Pointer<Pointer<Uint8>> parsedBytecodes,
    Pointer<Uint64> bytecodeLen,
    Pointer<Utf8> url,
    Int32 startLine,
    // prof: Int64 profileId,
    Handle object,
    Pointer<NativeFunction<NativeEvaluateJavaScriptCallback>> resultCallback);
typedef DartEvaluateScripts = void Function(
    Pointer<Void>,
    Pointer<Uint8> code,
    int code_len,
    Pointer<Pointer<Uint8>> parsedBytecodes,
    Pointer<Uint64> bytecodeLen,
    Pointer<Utf8> url,
    int startLine,
    // prof: int profileId,
    Object object,
    Pointer<NativeFunction<NativeEvaluateJavaScriptCallback>> resultCallback);

typedef NativeEvaluateJavaScriptCallback = Void Function(Handle object, Int8 result);

final DartEvaluateScripts _evaluateScripts =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeEvaluateScripts>>('evaluateScripts').asFunction();

int _anonymousScriptEvaluationId = 0;

class ScriptByteCode {
  ScriptByteCode();

  late Uint8List bytes;
}

class _EvaluateScriptsContext {
  Completer completer;
  String? cacheKey;
  Pointer<Uint8> codePtr;
  Pointer<Utf8> url;
  Pointer<Pointer<Uint8>>? bytecodes;
  Pointer<Uint64>? bytecodeLen;
  Uint8List originalCodeBytes;

  _EvaluateScriptsContext(this.completer, this.originalCodeBytes, this.codePtr, this.url, this.cacheKey);
}

void handleEvaluateScriptsResult(_EvaluateScriptsContext context, int result) {
  if (context.bytecodes != null) {
    Uint8List bytes = context.bytecodes!.value.asTypedList(context.bytecodeLen!.value);
    // Save to disk cache
    QuickJSByteCodeCache.putObject(context.originalCodeBytes, bytes, cacheKey: context.cacheKey).then((_) {
      malloc.free(context.codePtr);
      malloc.free(context.url);
      context.completer.complete(result == 1);
    });
  } else {
    malloc.free(context.codePtr);
    malloc.free(context.url);
    context.completer.complete(result == 1);
  }
}

// prof:
Future<bool> evaluateScripts(double contextId, Uint8List codeBytes, {String? url, String? cacheKey, int line = 0 }) async { // EvaluateOpItem? profileOp
  if (MercuryController.getControllerOfJSContextId(contextId) == null) {
    return false;
  }
  // Assign `vm://$id` for no url (anonymous scripts).
  if (url == null) {
    url = 'vm://$_anonymousScriptEvaluationId';
    _anonymousScriptEvaluationId++;
  }

  QuickJSByteCodeCacheObject cacheObject = await QuickJSByteCodeCache.getCacheObject(codeBytes, cacheKey: cacheKey);
  if (QuickJSByteCodeCacheObject.cacheMode == ByteCodeCacheMode.DEFAULT &&
      cacheObject.valid &&
      cacheObject.bytes != null) {
    // prof:
    bool result = await evaluateQuickjsByteCode(contextId, cacheObject.bytes!); // profileOp: profileOp
    // If the bytecode evaluate failed, remove the cached file and fallback to raw javascript mode.
    if (!result) {
      await cacheObject.remove();
    }

    return result;
  } else {
    Pointer<Utf8> _url = url.toNativeUtf8();
    Pointer<Uint8> codePtr = uint8ListToPointer(codeBytes);
    Completer<bool> completer = Completer();

    _EvaluateScriptsContext context = _EvaluateScriptsContext(completer, codeBytes, codePtr, _url, cacheKey);
    Pointer<NativeFunction<NativeEvaluateJavaScriptCallback>> resultCallback =
        Pointer.fromFunction(handleEvaluateScriptsResult);

    try {
      assert(_allocatedMercuryIsolates.containsKey(contextId));
      if (QuickJSByteCodeCache.isCodeNeedCache(codeBytes)) {
        // Export the bytecode from scripts
        Pointer<Pointer<Uint8>> bytecodes = malloc.allocate(sizeOf<Pointer<Uint8>>());
        Pointer<Uint64> bytecodeLen = malloc.allocate(sizeOf<Uint64>());

        context.bytecodes = bytecodes;
        context.bytecodeLen = bytecodeLen;

        // prof:
        _evaluateScripts(_allocatedMercuryIsolates[contextId]!, codePtr, codeBytes.length, bytecodes, bytecodeLen, _url, line, context, resultCallback); // profileOp?.hashCode ?? 0
      } else {
        // prof:
        _evaluateScripts(_allocatedMercuryIsolates[contextId]!, codePtr, codeBytes.length, nullptr, nullptr, _url, line, context, resultCallback); // profileOp?.hashCode ?? 0
      }
      return completer.future;
    } catch (e, stack) {
      print('$e\n$stack');
    }

    return completer.future;
  }
}

// prof:
typedef NativeEvaluateQuickjsByteCode = Void Function(Pointer<Void>, Pointer<Uint8> bytes, Int32 byteLen, Handle object, // Int64 profileId
    Pointer<NativeFunction<NativeEvaluateQuickjsByteCodeCallback>> callback);
typedef DartEvaluateQuickjsByteCode = void Function(Pointer<Void>, Pointer<Uint8> bytes, int byteLen, Object object, // Int64 profileId
    Pointer<NativeFunction<NativeEvaluateQuickjsByteCodeCallback>> callback);

typedef NativeEvaluateQuickjsByteCodeCallback = Void Function(Handle object, Int8 result);

final DartEvaluateQuickjsByteCode _evaluateQuickjsByteCode = MercuryDynamicLibrary.ref
    .lookup<NativeFunction<NativeEvaluateQuickjsByteCode>>('evaluateQuickjsByteCode')
    .asFunction();

class _EvaluateQuickjsByteCodeContext {
  Completer<bool> completer;
  Pointer<Uint8> bytes;

  _EvaluateQuickjsByteCodeContext(this.completer, this.bytes);
}

void handleEvaluateQuickjsByteCodeResult(_EvaluateQuickjsByteCodeContext context, int result) {
  malloc.free(context.bytes);
  context.completer.complete(result == 1);
}

// prof:
Future<bool> evaluateQuickjsByteCode(double contextId, Uint8List bytes) async { // { EvaluateOpItem? profileOp }
  if (MercuryController.getControllerOfJSContextId(contextId) == null) {
    return false;
  }
  Completer<bool> completer = Completer();
  Pointer<Uint8> byteData = malloc.allocate(sizeOf<Uint8>() * bytes.length);
  byteData.asTypedList(bytes.length).setAll(0, bytes);
  assert(_allocatedMercuryIsolates.containsKey(contextId));

  _EvaluateQuickjsByteCodeContext context = _EvaluateQuickjsByteCodeContext(completer, byteData);

  Pointer<NativeFunction<NativeEvaluateQuickjsByteCodeCallback>> nativeCallback =
      Pointer.fromFunction(handleEvaluateQuickjsByteCodeResult);

  // prof:
  _evaluateQuickjsByteCode(_allocatedMercuryIsolates[contextId]!, byteData, bytes.length, context, nativeCallback); // profileOp?.hashCode ?? 0

  return completer.future;
}

typedef NativeDumpQuickjsByteCodeResultCallback = Void Function(Handle object);

typedef NativeDumpQuickjsByteCode = Void Function(
    Pointer<Void>,
    // prof: Int64 profileId,
    Pointer<Uint8> code,
    Int32 code_len,
    Pointer<Pointer<Uint8>> parsedBytecodes,
    Pointer<Uint64> bytecodeLen,
    Pointer<Utf8> url,
    Handle context,
    Pointer<NativeFunction<NativeDumpQuickjsByteCodeResultCallback>> resultCallback);
typedef DartDumpQuickjsByteCode = void Function(
    Pointer<Void>,
    // prof: int profileId,
    Pointer<Uint8> code,
    int code_len,
    Pointer<Pointer<Uint8>> parsedBytecodes,
    Pointer<Uint64> bytecodeLen,
    Pointer<Utf8> url,
    Object context,
    Pointer<NativeFunction<NativeDumpQuickjsByteCodeResultCallback>> resultCallback);

final DartDumpQuickjsByteCode _dumpQuickjsByteCode =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeDumpQuickjsByteCode>>('dumpQuickjsByteCode').asFunction();

class _DumpQuickjsByteCodeContext {
  Completer<Uint8List> completer;
  Pointer<Pointer<Uint8>> bytecodes;
  Pointer<Uint64> bytecodeLen;

  _DumpQuickjsByteCodeContext(this.completer, this.bytecodes, this.bytecodeLen);
}

void _handleQuickjsByteCodeResults(_DumpQuickjsByteCodeContext context) {
  Uint8List bytes = context.bytecodes.value.asTypedList(context.bytecodeLen.value);
  context.completer.complete(bytes);
}

Future<Uint8List> dumpQuickjsByteCode(double contextId, Uint8List code, {String? url, EvaluateOpItem? profileOp}) async {
  Completer<Uint8List> completer = Completer();
  // Assign `vm://$id` for no url (anonymous scripts).
  if (url == null) {
    url = 'vm://$_anonymousScriptEvaluationId';
    _anonymousScriptEvaluationId++;
  }

  Pointer<Uint8> codePtr = uint8ListToPointer(code);

  Pointer<Utf8> _url = url.toNativeUtf8();
  // Export the bytecode from scripts
  Pointer<Pointer<Uint8>> bytecodes = malloc.allocate(sizeOf<Pointer<Uint8>>());
  Pointer<Uint64> bytecodeLen = malloc.allocate(sizeOf<Uint64>());

  _DumpQuickjsByteCodeContext context = _DumpQuickjsByteCodeContext(completer, bytecodes, bytecodeLen);
  Pointer<NativeFunction<NativeDumpQuickjsByteCodeResultCallback>> resultCallback =
      Pointer.fromFunction(_handleQuickjsByteCodeResults);

  // prof:
  _dumpQuickjsByteCode(
      _allocatedMercuryIsolates[contextId]!, codePtr, code.length, bytecodes, bytecodeLen, _url, context, resultCallback); // profileOp?.hashCode ?? 0

  // return bytes;
  return completer.future;
}

// Register initJsEngine
// prof:
typedef NativeInitDartIsolateContext = Pointer<Void> Function(
    Int64 sendPort, Pointer<Uint64> dartMethods, Int32 methodsLength); // , Int8 enableProfile
typedef DartInitDartIsolateContext = Pointer<Void> Function(
    int sendPort, Pointer<Uint64> dartMethods, int methodsLength); // , Int8 enableProfile

final DartInitDartIsolateContext _initDartIsolateContext = MercuryDynamicLibrary.ref
    .lookup<NativeFunction<NativeInitDartIsolateContext>>('initDartIsolateContextSync')
    .asFunction();

Pointer<Void> initDartIsolateContext(List<int> dartMethods) {
  Pointer<Uint64> bytes = malloc.allocate<Uint64>(sizeOf<Uint64>() * dartMethods.length);
  Uint64List nativeMethodList = bytes.asTypedList(dartMethods.length);
  nativeMethodList.setAll(0, dartMethods); // prof:
  return _initDartIsolateContext(nativePort, bytes, dartMethods.length); // , enableMercuryProfileTracking ? 1 : 0
}

typedef HandleDisposeMercuryIsolateResult = Void Function(Handle context);
typedef NativeDisposeMercuryIsolate = Void Function(Double contextId, Pointer<Void>, Pointer<Void> mercury_isolate, Handle context,
    Pointer<NativeFunction<HandleDisposeMercuryIsolateResult>> resultCallback);
typedef DartDisposeMercuryIsolate = void Function(double, Pointer<Void>, Pointer<Void> mercury_isolate, Object context,
    Pointer<NativeFunction<HandleDisposeMercuryIsolateResult>> resultCallback);

final DartDisposeMercuryIsolate _disposeMercuryIsolate =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeDisposeMercuryIsolate>>('disposeMercuryIsolate').asFunction();

typedef NativeDisposeMercuryIsolateSync = Void Function(Double contextId, Pointer<Void>, Pointer<Void> mercury_isolate);
typedef DartDisposeMercuryIsolateSync = void Function(double, Pointer<Void>, Pointer<Void> mercury_isolate);

final DartDisposeMercuryIsolateSync _disposeMercuryIsolateSync =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeDisposeMercuryIsolateSync>>('disposeMercuryIsolateSync').asFunction();

void _handleDisposeMercuryIsolateResult(_DisposeMercuryIsolateContext context) {
  context.completer.complete();
}

class _DisposeMercuryIsolateContext {
  Completer<void> completer;

  _DisposeMercuryIsolateContext(this.completer);
}

FutureOr<void> disposeMercuryIsolate(bool isSync, double contextId) async {
  Pointer<Void> mercury_isolate = _allocatedMercuryIsolates[contextId]!;

  if (isSync) {
    _disposeMercuryIsolateSync(contextId, dartContext!.pointer, mercury_isolate);
    _allocatedMercuryIsolates.remove(contextId);
  } else {
    Completer<void> completer = Completer();
    _DisposeMercuryIsolateContext context = _DisposeMercuryIsolateContext(completer);
    Pointer<NativeFunction<HandleDisposeMercuryIsolateResult>> f = Pointer.fromFunction(_handleDisposeMercuryIsolateResult);
    _disposeMercuryIsolate(contextId, dartContext!.pointer, mercury_isolate, context, f);
    return completer.future;
  }
}

typedef NativeNewMercuryIsolateId = Int64 Function();
typedef DartNewMercuryIsolateId = int Function();

final DartNewMercuryIsolateId _newMercuryIsolateId =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeNewMercuryIsolateId>>('newMercuryIsolateIdSync').asFunction();

int newMercuryIsolateId() {
  return _newMercuryIsolateId();
}

typedef NativeAllocateNewMercuryIsolateSync = Pointer<Void> Function(Double, Pointer<Void>);
typedef DartAllocateNewMercuryIsolateSync = Pointer<Void> Function(double, Pointer<Void>);
typedef HandleAllocateNewMercuryIsolateResult = Void Function(Handle object, Pointer<Void> mercury_isolate);
typedef NativeAllocateNewMercuryIsolate = Void Function(
    Double, Int32, Pointer<Void>, Handle object, Pointer<NativeFunction<HandleAllocateNewMercuryIsolateResult>> handle_result);
typedef DartAllocateNewMercuryIsolate = void Function(
    double, int, Pointer<Void>, Object object, Pointer<NativeFunction<HandleAllocateNewMercuryIsolateResult>> handle_result);

final DartAllocateNewMercuryIsolateSync _allocateNewMercuryIsolateSync =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeAllocateNewMercuryIsolateSync>>('allocateNewMercuryIsolateSync').asFunction();

final DartAllocateNewMercuryIsolate _allocateNewMercuryIsolate =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeAllocateNewMercuryIsolate>>('allocateNewMercuryIsolate').asFunction();

void _handleAllocateNewMercuryIsolateResult(_AllocateNewMercuryIsolateContext context, Pointer<Void> mercury_isolate) {
  assert(!_allocatedMercuryIsolates.containsKey(context.contextId));
  _allocatedMercuryIsolates[context.contextId] = mercury_isolate;
  context.completer.complete();
}

class _AllocateNewMercuryIsolateContext {
  Completer<void> completer;
  double contextId;

  _AllocateNewMercuryIsolateContext(this.completer, this.contextId);
}

Future<void> allocateNewMercuryIsolate(bool sync, double newContextId, int syncBufferSize) async {
  await waitingSyncTaskComplete(newContextId);

  if (!sync) {
    Completer<void> completer = Completer();
    _AllocateNewMercuryIsolateContext context = _AllocateNewMercuryIsolateContext(completer, newContextId);
    Pointer<NativeFunction<HandleAllocateNewMercuryIsolateResult>> f = Pointer.fromFunction(_handleAllocateNewMercuryIsolateResult);
    _allocateNewMercuryIsolate(newContextId, syncBufferSize, dartContext!.pointer, context, f);
    return completer.future;
  } else {
    Pointer<Void> mercury_isolate = _allocateNewMercuryIsolateSync(newContextId, dartContext!.pointer);
    assert(!_allocatedMercuryIsolates.containsKey(newContextId));
    _allocatedMercuryIsolates[newContextId] = mercury_isolate;
  }
}

typedef NativeInitDartDynamicLinking = Void Function(Pointer<Void> data);
typedef DartInitDartDynamicLinking = void Function(Pointer<Void> data);

final DartInitDartDynamicLinking _initDartDynamicLinking = MercuryDynamicLibrary.ref
    .lookup<NativeFunction<NativeInitDartDynamicLinking>>('init_dart_dynamic_linking')
    .asFunction();

void initDartDynamicLinking() {
  _initDartDynamicLinking(NativeApi.initializeApiDLData);
}

typedef NativeRegisterDartContextFinalizer = Void Function(Handle object, Pointer<Void> dart_context);
typedef DartRegisterDartContextFinalizer = void Function(Object object, Pointer<Void> dart_context);

final DartRegisterDartContextFinalizer _registerDartContextFinalizer = MercuryDynamicLibrary.ref
    .lookup<NativeFunction<NativeRegisterDartContextFinalizer>>('register_dart_context_finalizer')
    .asFunction();

void registerDartContextFinalizer(DartContext dartContext) {
  _registerDartContextFinalizer(dartContext, dartContext.pointer);
}

typedef NativeRegisterPluginByteCode = Void Function(Pointer<Uint8> bytes, Int32 length, Pointer<Utf8> pluginName);
typedef DartRegisterPluginByteCode = void Function(Pointer<Uint8> bytes, int length, Pointer<Utf8> pluginName);

final DartRegisterPluginByteCode _registerPluginByteCode =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeRegisterPluginByteCode>>('registerPluginByteCode').asFunction();

void registerPluginByteCode(Uint8List bytecode, String name) {
  Pointer<Uint8> bytes = malloc.allocate(sizeOf<Uint8>() * bytecode.length);
  bytes.asTypedList(bytecode.length).setAll(0, bytecode);
  _registerPluginByteCode(bytes, bytecode.length, name.toNativeUtf8());
}

typedef NativeCollectNativeProfileData = Void Function(
    Pointer<Void> mercury_isolatePtr, Pointer<Pointer<Utf8>> data, Pointer<Uint32> len);
typedef DartCollectNativeProfileData = void Function(
    Pointer<Void> mercury_isolatePtr, Pointer<Pointer<Utf8>> data, Pointer<Uint32> len);

final DartCollectNativeProfileData _collectNativeProfileData = MercuryDynamicLibrary.ref
    .lookup<NativeFunction<NativeCollectNativeProfileData>>('collectNativeProfileData')
    .asFunction();

String collectNativeProfileData() {
  Pointer<Pointer<Utf8>> string = malloc.allocate(sizeOf<Pointer>());
  Pointer<Uint32> len = malloc.allocate(sizeOf<Pointer>());

  _collectNativeProfileData(dartContext!.pointer, string, len);

  return string.value.toDartString(length: len.value);
}

typedef NativeClearNativeProfileData = Void Function(Pointer<Void> mercury_isolatePtr);
typedef DartClearNativeProfileData = void Function(Pointer<Void> mercury_isolatePtr);

final DartClearNativeProfileData _clearNativeProfileData = MercuryDynamicLibrary.ref
    .lookup<NativeFunction<NativeClearNativeProfileData>>('clearNativeProfileData')
    .asFunction();

void clearNativeProfileData() {
  _clearNativeProfileData(dartContext!.pointer);
}

enum IsolateCommandType {
  // prof: startRecordingCommand,
  createGlobal,
  disposeBindingObject,
  addEvent,
  removeEvent,
  // perf optimize
  // prof: finishRecordingCommand,
}

class IsolateCommandItem extends Struct {
  @Int64()
  external int type;

  external Pointer<Pointer<NativeString>> args;

  @Int64()
  external int id;

  @Int64()
  external int length;

  external Pointer nativePtr;
}

typedef NativeGetIsolateCommandItems = Pointer<Uint64> Function(Pointer<Void>);
typedef DartGetIsolateCommandItems = Pointer<Uint64> Function(Pointer<Void>);

final DartGetIsolateCommandItems _getIsolateCommandItems =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeGetIsolateCommandItems>>('getIsolateCommandItems').asFunction();

typedef NativeGetIsolateCommandKindFlags = Uint32 Function(Pointer<Void>);
typedef DartGetIsolateCommandKindFlags = int Function(Pointer<Void>);

final DartGetIsolateCommandKindFlags _getIsolateCommandKindFlags =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeGetIsolateCommandKindFlags>>('getIsolateCommandKindFlag').asFunction();

typedef NativeGetIsolateCommandItemSize = Int64 Function(Pointer<Void>);
typedef DartGetIsolateCommandItemSize = int Function(Pointer<Void>);

final DartGetIsolateCommandItemSize _getIsolateCommandItemSize =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeGetIsolateCommandItemSize>>('getIsolateCommandItemSize').asFunction();

typedef NativeClearIsolateCommandItems = Void Function(Pointer<Void>);
typedef DartClearIsolateCommandItems = void Function(Pointer<Void>);

final DartClearIsolateCommandItems _clearIsolateCommandItems =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeClearIsolateCommandItems>>('clearIsolateCommandItems').asFunction();

typedef NativeIsJSThreadBlocked = Int8 Function(Pointer<Void>, Double);
typedef DartIsJSThreadBlocked = int Function(Pointer<Void>, double);

final DartIsJSThreadBlocked _isJSThreadBlocked =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeIsJSThreadBlocked>>('isJSThreadBlocked').asFunction();

bool isJSThreadBlocked(double contextId) {
  return _isJSThreadBlocked(dartContext!.pointer, contextId) == 1;
}

void clearIsolateCommand(double contextId) {
  assert(_allocatedMercuryIsolates.containsKey(contextId));

  _clearIsolateCommandItems(_allocatedMercuryIsolates[contextId]!);
}

void flushIsolateCommandWithContextId(double contextId, Pointer<NativeBindingObject> selfPointer) {
  MercuryController? controller = MercuryController.getControllerOfJSContextId(contextId);
  if (controller != null) {
    flushIsolateCommand(controller.context, selfPointer);
  }
}

class _NativeCommandData {
  static _NativeCommandData empty() {
    return _NativeCommandData(0, 0, []);
  }

  int length;
  int kindFlag;
  List<int> rawMemory;

  _NativeCommandData(this.kindFlag, this.length, this.rawMemory);
}

_NativeCommandData readNativeIsolateCommandMemory(double contextId) {
  Pointer<Uint64> nativeCommandItemPointer = _getIsolateCommandItems(_allocatedMercuryIsolates[contextId]!);
  int flag = _getIsolateCommandKindFlags(_allocatedMercuryIsolates[contextId]!);
  int commandLength = _getIsolateCommandItemSize(_allocatedMercuryIsolates[contextId]!);

  if (commandLength == 0 || nativeCommandItemPointer == nullptr) {
    return _NativeCommandData.empty();
  }

  List<int> rawMemory =
      nativeCommandItemPointer.cast<Int64>().asTypedList((commandLength) * nativeCommandSize).toList(growable: false);
  _clearIsolateCommandItems(_allocatedMercuryIsolates[contextId]!);

  return _NativeCommandData(flag, commandLength, rawMemory);
}

void flushIsolateCommand(MercuryContextController context, Pointer<NativeBindingObject> selfPointer) {
  assert(_allocatedMercuryIsolates.containsKey(context.contextId));
  if (context.disposed) return;

  // if (enableMercuryProfileTracking) {
  //   MercuryProfiler.instance.startTrackIsolateCommand();
  //   MercuryProfiler.instance.startTrackIsolateCommandStep('readNativeIsolateCommandMemory');
  // }

  _NativeCommandData rawCommands = readNativeIsolateCommandMemory(context.contextId);

  // prof:
  // if (enableMercuryProfileTracking) {
  //   MercuryProfiler.instance.finishTrackIsolateCommandStep();
  // }

  List<IsolateCommand>? commands;
  if (rawCommands.rawMemory.isNotEmpty) {
    // prof:
    // if (enableMercuryProfileTracking) {
    //   MercuryProfiler.instance.startTrackIsolateCommandStep('nativeIsolateCommandToDart');
    // }

    commands = nativeIsolateCommandToDart(rawCommands.rawMemory, rawCommands.length, context.contextId);

    // prof:
    // if (enableMercuryProfileTracking) {
    //   MercuryProfiler.instance.finishTrackIsolateCommandStep();
    //   MercuryProfiler.instance.startTrackIsolateCommandStep('execIsolateCommands');
    // }

    execIsolateCommands(context, commands);

    // prof:
    // if (enableMercuryProfileTracking) {
    //   MercuryProfiler.instance.finishTrackIsolateCommandStep();
    // }
  }

  // prof:
  // if (enableMercuryProfileTracking) {
  //   MercuryProfiler.instance.finishTrackIsolateCommand();
  // }
}
