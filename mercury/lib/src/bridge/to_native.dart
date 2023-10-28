/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:mercury/src/global/event.dart';
import 'package:mercury/mercury.dart';

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

typedef NativeGetMercuryInfo = Pointer<NativeMercuryInfo> Function();
typedef DartGetMercuryInfo = Pointer<NativeMercuryInfo> Function();

final DartGetMercuryInfo _getMercuryInfo =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeGetMercuryInfo>>('getMercuryInfo').asFunction();

final MercuryInfo _cachedInfo = MercuryInfo(_getMercuryInfo());

final HashMap<int, Pointer<Void>> _allocatedMercuryIsolates = HashMap();

Pointer<Void>? getAllocatedMercuryIsolate(int contextId) {
  return _allocatedMercuryIsolates[contextId];
}

MercuryInfo getMercuryInfo() {
  return _cachedInfo;
}

// Register invokeEventListener
typedef NativeInvokeEventListener = Pointer<NativeValue> Function(
    Pointer<Void>, Pointer<NativeString>, Pointer<Utf8> eventType, Pointer<Void> nativeEvent, Pointer<NativeValue>);
typedef DartInvokeEventListener = Pointer<NativeValue> Function(
    Pointer<Void>, Pointer<NativeString>, Pointer<Utf8> eventType, Pointer<Void> nativeEvent, Pointer<NativeValue>);

final DartInvokeEventListener _invokeModuleEvent =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeInvokeEventListener>>('invokeModuleEvent').asFunction();

dynamic invokeModuleEvent(int contextId, String moduleName, Event? event, extra) {
  if (MercuryController.getControllerOfJSContextId(contextId) == null) {
    return null;
  }
  MercuryController controller = MercuryController.getControllerOfJSContextId(contextId)!;
  Pointer<NativeString> nativeModuleName = stringToNativeString(moduleName);
  Pointer<Void> rawEvent = event == null ? nullptr : event.toRaw().cast<Void>();
  Pointer<NativeValue> extraData = malloc.allocate(sizeOf<NativeValue>());
  toNativeValue(extraData, extra);
  assert(_allocatedMercuryIsolates.containsKey(contextId));
  Pointer<NativeValue> dispatchResult = _invokeModuleEvent(
      _allocatedMercuryIsolates[contextId]!, nativeModuleName, event == null ? nullptr : event.type.toNativeUtf8(), rawEvent, extraData);
  dynamic result = fromNativeValue(controller.context, dispatchResult);
  malloc.free(dispatchResult);
  malloc.free(extraData);
  return result;
}

typedef DartDispatchEvent = int Function(int contextId, Pointer<NativeBindingObject> nativeBindingObject,
    Pointer<NativeString> eventType, Pointer<Void> nativeEvent, int isCustomEvent);

dynamic emitModuleEvent(int contextId, String moduleName, Event? event, extra) {
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
typedef NativeEvaluateScripts = Int8 Function(
    Pointer<Void>, Pointer<NativeString> code, Pointer<Pointer<Uint8>> parsedBytecodes, Pointer<Uint64> bytecodeLen, Pointer<Utf8> url, Int32 startLine);
typedef DartEvaluateScripts = int Function(
    Pointer<Void>, Pointer<NativeString> code, Pointer<Pointer<Uint8>> parsedBytecodes, Pointer<Uint64> bytecodeLen, Pointer<Utf8> url, int startLine);

// Register parseHTML
typedef NativeParseHTML = Void Function(Pointer<Void>, Pointer<Utf8> code, Int32 length);
typedef DartParseHTML = void Function(Pointer<Void>, Pointer<Utf8> code, int length);

final DartEvaluateScripts _evaluateScripts =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeEvaluateScripts>>('evaluateScripts').asFunction();

final DartParseHTML _parseHTML =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeParseHTML>>('parseHTML').asFunction();

int _anonymousScriptEvaluationId = 0;

class ScriptByteCode {
  ScriptByteCode();
  late Uint8List bytes;
}

Future<bool> evaluateScripts(int contextId, String code, {String? url, int line = 0}) async {
  if (MercuryController.getControllerOfJSContextId(contextId) == null) {
    return false;
  }
  // Assign `vm://$id` for no url (anonymous scripts).
  if (url == null) {
    url = 'vm://$_anonymousScriptEvaluationId';
    _anonymousScriptEvaluationId++;
  }

  QuickJSByteCodeCacheObject cacheObject = await QuickJSByteCodeCache.getCacheObject(code);
  if (QuickJSByteCodeCacheObject.cacheMode == ByteCodeCacheMode.DEFAULT && cacheObject.valid && cacheObject.bytes != null) {
    bool result = evaluateQuickjsByteCode(contextId, cacheObject.bytes!);
    // If the bytecode evaluate failed, remove the cached file and fallback to raw javascript mode.
    if (!result) {
      await cacheObject.remove();
    }

    return result;
  } else {
    Pointer<NativeString> nativeString = stringToNativeString(code);
    Pointer<Utf8> _url = url.toNativeUtf8();
    try {
      assert(_allocatedMercuryIsolates.containsKey(contextId));
      int result;
      if (QuickJSByteCodeCache.isCodeNeedCache(code)) {
        // Export the bytecode from scripts
        Pointer<Pointer<Uint8>> bytecodes = malloc.allocate(sizeOf<Pointer<Uint8>>());
        Pointer<Uint64> bytecodeLen = malloc.allocate(sizeOf<Uint64>());
        result = _evaluateScripts(_allocatedMercuryIsolates[contextId]!, nativeString, bytecodes, bytecodeLen, _url, line);
        Uint8List bytes = bytecodes.value.asTypedList(bytecodeLen.value);
        // Save to disk cache
        QuickJSByteCodeCache.putObject(code, bytes);
      } else {
        result = _evaluateScripts(_allocatedMercuryIsolates[contextId]!, nativeString, nullptr, nullptr, _url, line);
      }
      return result == 1;
    } catch (e, stack) {
      print('$e\n$stack');
    }
    freeNativeString(nativeString);
    malloc.free(_url);
  }
  return false;
}

typedef NativeEvaluateQuickjsByteCode = Int8 Function(Pointer<Void>, Pointer<Uint8> bytes, Int32 byteLen);
typedef DartEvaluateQuickjsByteCode = int Function(Pointer<Void>, Pointer<Uint8> bytes, int byteLen);

final DartEvaluateQuickjsByteCode _evaluateQuickjsByteCode = MercuryDynamicLibrary.ref
    .lookup<NativeFunction<NativeEvaluateQuickjsByteCode>>('evaluateQuickjsByteCode')
    .asFunction();

bool evaluateQuickjsByteCode(int contextId, Uint8List bytes) {
  if (MercuryController.getControllerOfJSContextId(contextId) == null) {
    return false;
  }
  Pointer<Uint8> byteData = malloc.allocate(sizeOf<Uint8>() * bytes.length);
  byteData.asTypedList(bytes.length).setAll(0, bytes);
  assert(_allocatedMercuryIsolates.containsKey(contextId));
  int result = _evaluateQuickjsByteCode(_allocatedMercuryIsolates[contextId]!, byteData, bytes.length);
  malloc.free(byteData);
  return result == 1;
}

void parseHTML(int contextId, String code) {
  if (MercuryController.getControllerOfJSContextId(contextId) == null) {
    return;
  }
  Pointer<Utf8> nativeCode = code.toNativeUtf8();
  try {
    assert(_allocatedMercuryIsolates.containsKey(contextId));
    _parseHTML(_allocatedMercuryIsolates[contextId]!, nativeCode, nativeCode.length);
  } catch (e, stack) {
    print('$e\n$stack');
  }
  malloc.free(nativeCode);
}

// Register initJsEngine
typedef NativeInitDartIsolateContext = Pointer<Void> Function(Pointer<Uint64> dartMethods, Int32 methodsLength);
typedef DartInitDartIsolateContext = Pointer<Void> Function(Pointer<Uint64> dartMethods, int methodsLength);

final DartInitDartIsolateContext _initDartIsolateContext =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeInitDartIsolateContext>>('initDartIsolateContext').asFunction();

Pointer<Void> initDartIsolateContext(List<int> dartMethods) {
  Pointer<Uint64> bytes = malloc.allocate<Uint64>(sizeOf<Uint64>() * dartMethods.length);
  Uint64List nativeMethodList = bytes.asTypedList(dartMethods.length);
  nativeMethodList.setAll(0, dartMethods);
  return _initDartIsolateContext(bytes, dartMethods.length);
}

typedef NativeDisposeMercuryIsolate = Void Function(Pointer<Void>, Pointer<Void> mercuryIsolate);
typedef DartDisposeMercuryIsolate = void Function(Pointer<Void>, Pointer<Void> mercuryIsolate);

final DartDisposeMercuryIsolate _disposeMercuryIsolate =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeDisposeMercuryIsolate>>('disposeMercuryIsolate').asFunction();

void disposeMercuryIsolate(int contextId) {
  Pointer<Void> mercuryIsolate = _allocatedMercuryIsolates[contextId]!;
  _disposeMercuryIsolate(dartContext.pointer, mercuryIsolate);
  _allocatedMercuryIsolates.remove(contextId);
}

typedef NativeNewMercuryIsolateId = Int64 Function();
typedef DartNewMercuryIsolateId = int Function();

final DartNewMercuryIsolateId _newMercuryIsolateId = MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeNewMercuryIsolateId>>('newMercuryIsolateId').asFunction();

int newMercuryIsolateId() {
  return _newMercuryIsolateId();
}

typedef NativeAllocateNewMercuryIsolate = Pointer<Void> Function(Pointer<Void>, Int32);
typedef DartAllocateNewMercuryIsolate = Pointer<Void> Function(Pointer<Void>, int);

final DartAllocateNewMercuryIsolate _allocateNewMercuryIsolate =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeAllocateNewMercuryIsolate>>('allocateNewMercuryIsolate').asFunction();

void allocateNewMercuryIsolate(int targetContextId) {
  Pointer<Void> mercuryIsolate = _allocateNewMercuryIsolate(dartContext.pointer, targetContextId);
  assert(!_allocatedMercuryIsolates.containsKey(targetContextId));
  _allocatedMercuryIsolates[targetContextId] = mercuryIsolate;
}

typedef NativeInitDartDynamicLinking = Void Function(Pointer<Void> data);
typedef DartInitDartDynamicLinking = void Function(Pointer<Void> data);

final DartInitDartDynamicLinking _initDartDynamicLinking =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeInitDartDynamicLinking>>('init_dart_dynamic_linking').asFunction();

void initDartDynamicLinking() {
  _initDartDynamicLinking(NativeApi.initializeApiDLData);
}

typedef NativeRegisterDartContextFinalizer = Void Function(Handle object, Pointer<Void> dart_context);
typedef DartRegisterDartContextFinalizer = void Function(Object object, Pointer<Void> dart_context);

final DartRegisterDartContextFinalizer _registerDartContextFinalizer =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeRegisterDartContextFinalizer>>('register_dart_context_finalizer').asFunction();

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

final bool isEnabledLog = !kReleaseMode && Platform.environment['ENABLE_MERCURY_JS_LOG'] == 'true';


typedef NativeDispatchIsolateTask = Void Function(Int32 contextId, Pointer<Void> context, Pointer<Void> callback);
typedef DartDispatchIsolateTask = void Function(int contextId, Pointer<Void> context, Pointer<Void> callback);

void dispatchIsolateTask(int contextId, Pointer<Void> context, Pointer<Void> callback) {
  // _dispatchIsolateTask(contextId, context, callback);
}

enum IsolateCommandType {
  createGlobal,
  createEventTarget,
  disposeBindingObject,
  addEvent,
  removeEvent,
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

typedef NativeGetIsolateCommandItemSize = Int64 Function(Pointer<Void>);
typedef DartGetIsolateCommandItemSize = int Function(Pointer<Void>);

final DartGetIsolateCommandItemSize _getIsolateCommandItemSize =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeGetIsolateCommandItemSize>>('getIsolateCommandItemSize').asFunction();

typedef NativeClearIsolateCommandItems = Void Function(Pointer<Void>);
typedef DartClearIsolateCommandItems = void Function(Pointer<Void>);

final DartClearIsolateCommandItems _clearIsolateCommandItems =
    MercuryDynamicLibrary.ref.lookup<NativeFunction<NativeClearIsolateCommandItems>>('clearIsolateCommandItems').asFunction();

class IsolateCommand {
  late final IsolateCommandType type;
  late final String args;
  late final Pointer nativePtr;
  late final Pointer nativePtr2;

  @override
  String toString() {
    return 'IsolateCommand(type: $type, args: $args, nativePtr: $nativePtr, nativePtr2: $nativePtr2)';
  }
}

// struct IsolateCommandItem {
//   int32_t type;             // offset: 0 ~ 0.5
//   int32_t args_01_length;   // offset: 0.5 ~ 1
//   const uint16_t *string_01;// offset: 1
//   void* nativePtr;          // offset: 2
//   void* nativePtr2;         // offset: 3
// };
const int nativeCommandSize = 4;
const int typeAndArgs01LenMemOffset = 0;
const int args01StringMemOffset = 1;
const int nativePtrMemOffset = 2;
const int native2PtrMemOffset = 3;

// We found there are performance bottleneck of reading native memory with Dart FFI API.
// So we align all Isolate instructions to a whole block of memory, and then convert them into a dart array at one time,
// To ensure the fastest subsequent random access.
List<IsolateCommand> readNativeIsolateCommandToDart(Pointer<Uint64> nativeCommandItems, int commandLength, int contextId) {
  List<int> rawMemory =
      nativeCommandItems.cast<Int64>().asTypedList(commandLength * nativeCommandSize).toList(growable: false);
  List<IsolateCommand> results = List.generate(commandLength, (int _i) {
    int i = _i * nativeCommandSize;
    IsolateCommand command = IsolateCommand();

    int typeArgs01Combine = rawMemory[i + typeAndArgs01LenMemOffset];

    //      int32_t        int32_t
    // +-------------+-----------------+
    // |      type     | args_01_length  |
    // +-------------+-----------------+
    int args01Length = (typeArgs01Combine >> 32).toSigned(32);
    int type = (typeArgs01Combine ^ (args01Length << 32)).toSigned(32);

    command.type = IsolateCommandType.values[type];

    int args01StringMemory = rawMemory[i + args01StringMemOffset];
    if (args01StringMemory != 0) {
      Pointer<Uint16> args_01 = Pointer.fromAddress(args01StringMemory);
      command.args = uint16ToString(args_01, args01Length);
      malloc.free(args_01);
    } else {
      command.args = '';
    }

    int nativePtrValue = rawMemory[i + nativePtrMemOffset];
    command.nativePtr = nativePtrValue != 0 ? Pointer.fromAddress(rawMemory[i + nativePtrMemOffset]) : nullptr;

    int nativePtr2Value = rawMemory[i + native2PtrMemOffset];
    command.nativePtr2 = nativePtr2Value != 0 ? Pointer.fromAddress(nativePtr2Value) : nullptr;

    if (isEnabledLog) {
      String printMsg = 'nativePtr: ${command.nativePtr} type: ${command.type} args: ${command.args} nativePtr2: ${command.nativePtr2}';
      print(printMsg);
    }
    return command;
  }, growable: false);

  // Clear native command.
  _clearIsolateCommandItems(_allocatedMercuryIsolates[contextId]!);

  return results;
}

void clearIsolateCommand(int contextId) {
  assert(_allocatedMercuryIsolates.containsKey(contextId));
  _clearIsolateCommandItems(_allocatedMercuryIsolates[contextId]!);
}

void flushIsolateCommandWithContextId(int contextId) {
  MercuryController? controller = MercuryController.getControllerOfJSContextId(contextId);
  if (controller != null) {
    flushIsolateCommand(controller.context);
  }
}

void flushIsolateCommand(MercuryContextController context) {
  assert(_allocatedMercuryIsolates.containsKey(context.contextId));
  Pointer<Uint64> nativeCommandItems = _getIsolateCommandItems(_allocatedMercuryIsolates[context.contextId]!);
  int commandLength = _getIsolateCommandItemSize(_allocatedMercuryIsolates[context.contextId]!);

  if (commandLength == 0 || nativeCommandItems == nullptr) {
    return;
  }

  List<IsolateCommand> commands = readNativeIsolateCommandToDart(nativeCommandItems, commandLength, context.contextId);

  // For new isolate commands, we needs to tell engine to update frames.
  for (int i = 0; i < commandLength; i++) {
    IsolateCommand command = commands[i];
    IsolateCommandType commandType = command.type;
    Pointer nativePtr = command.nativePtr;

    try {
      switch (commandType) {
        case IsolateCommandType.createGlobal:
          context.initGlobal(context, nativePtr.cast<NativeBindingObject>());
          break;
        case IsolateCommandType.createEventTarget:
          context.createEventTarget(context, command.args, nativePtr.cast<NativeBindingObject>());
          break;
        case IsolateCommandType.disposeBindingObject:
          context.disposeBindingObject(context, nativePtr.cast<NativeBindingObject>());
          break;
        case IsolateCommandType.addEvent:
          Pointer<AddEventListenerOptions> eventListenerOptions = command.nativePtr2.cast<AddEventListenerOptions>();
          context.addEvent(nativePtr.cast<NativeBindingObject>(), command.args, addEventListenerOptions: eventListenerOptions);
          break;
        case IsolateCommandType.removeEvent:
          bool isCapture = command.nativePtr2.address == 1;
          context.removeEvent(nativePtr.cast<NativeBindingObject>(), command.args, isCapture: isCapture);
          break;
        default:
          break;
      }
    } catch (e, stack) {
      print('$e\n$stack');
    }
  }
}
