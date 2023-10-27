/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:mercury/devtools.dart';
import 'package:mercury/src/global/global.dart';
import 'package:mercury/src/global/event_target.dart';
import 'package:mercury/mercury.dart';

// Error handler when load bundle failed.
typedef LoadErrorHandler = void Function(FlutterError error, StackTrace stack);
typedef LoadHandler = void Function(MercuryController controller);
typedef TitleChangedHandler = void Function(String title);
typedef JSErrorHandler = void Function(String message);
typedef JSLogHandler = void Function(int level, String message);
typedef PendingCallback = void Function();

// See http://github.com/flutter/flutter/wiki/Desktop-shells
/// If the current platform is a desktop platform that isn't yet supported by
/// TargetPlatform, override the default platform to one that is.
/// Otherwise, do nothing.
/// No need to handle macOS, as it has now been added to TargetPlatform.
void setTargetPlatformForDesktop() {
  if (Platform.isLinux || Platform.isWindows) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }
}

abstract class DevToolsService {
  /// Design prevDevTool for reload page,
  /// do not use it in any other place.
  /// More detail see [InspectPageModule.handleReloadPage].
  static DevToolsService? prevDevTools;

  static final Map<int, DevToolsService> _contextDevToolMap = {};
  static DevToolsService? getDevToolOfContextId(int contextId) {
    return _contextDevToolMap[contextId];
  }

  /// Used for debugger inspector.
  UIInspector? _uiInspector;
  UIInspector? get uiInspector => _uiInspector;

  late Isolate _isolateServer;
  Isolate get isolateServer => _isolateServer;
  set isolateServer(Isolate isolate) {
    _isolateServer = isolate;
  }

  SendPort? _isolateServerPort;
  SendPort? get isolateServerPort => _isolateServerPort;
  set isolateServerPort(SendPort? value) {
    _isolateServerPort = value;
  }

  MercuryController? _controller;
  MercuryController? get controller => _controller;

  void init(MercuryController controller) {
    _contextDevToolMap[controller.context.contextId] = this;
    _controller = controller;
    spawnIsolateInspectorServer(this, controller);
    _uiInspector = UIInspector(this);
  }

  bool get isReloading => _reloading;
  bool _reloading = false;

  void willReload() {
    _reloading = true;
  }

  void didReload() {
    _reloading = false;
    _isolateServerPort!.send(InspectorReload(_controller!.context.contextId));
  }

  void dispose() {
    _uiInspector?.dispose();
    _contextDevToolMap.remove(controller!.context.contextId);
    _controller = null;
    _isolateServerPort = null;
    _isolateServer.kill();
  }
}

// An mercury View Controller designed for multiple mercury context control.
class MercuryContextController {
  MercuryController rootController;

  MercuryContextController({
      this.enableDebug = false,
      required this.rootController}) {
    if (enableDebug) {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    }
    BindingBridge.setup();
    _contextId = initBridge(this);

    Future.microtask(() {
      // Execute IsolateCommand.createGlobal to initialize the global.
      flushIsolateCommand(this);
    });
  }

  final Map<int, BindingObject> _nativeObjects = {};

  T? getBindingObject<T>(Pointer pointer) {
    return _nativeObjects[pointer.address] as T?;
  }

  bool hasBindingObject(Pointer pointer) {
    return _nativeObjects.containsKey(pointer.address);
  }

  void setBindingObject(Pointer pointer, BindingObject bindingObject) {
    assert(!_nativeObjects.containsKey(pointer.address));
    _nativeObjects[pointer.address] = bindingObject;
  }

  void removeBindingObject(Pointer pointer) {
    _nativeObjects.remove(pointer.address);
  }

  // Index value which identify javascript runtime context.
  late int _contextId;
  int get contextId => _contextId;

  // Enable print debug message when rendering.
  bool enableDebug;

  // Kraken have already disposed.
  bool _disposed = false;

  bool get disposed => _disposed;

  late Global global;

  void initGlobal(MercuryContextController context, Pointer<NativeBindingObject> pointer) {
    global = Global(BindingContext(context, _contextId, pointer));
  }

  void evaluateJavaScripts(String code) async {
    assert(!_disposed, 'Mercury have already disposed');
    await evaluateScripts(_contextId, code);
  }

  // Dispose controller and recycle all resources.
  void dispose() {
    _disposed = true;

    clearIsolateCommand(_contextId);

    disposeMercuryIsolate(_contextId);

    _nativeObjects.forEach((key, object) {
      object.dispose();
    });
    _nativeObjects.clear();

    global.dispose();
  }

  void addEvent(Pointer<NativeBindingObject> nativePtr, String eventType, {Pointer<AddEventListenerOptions>? addEventListenerOptions}) {
    if (!hasBindingObject(nativePtr)) return;
    EventTarget? target = getBindingObject<EventTarget>(nativePtr);
    if (target != null) {
      BindingBridge.listenEvent(target, eventType, addEventListenerOptions: addEventListenerOptions);
    }
  }

  void removeEvent(Pointer<NativeBindingObject> nativePtr, String eventType, {bool isCapture = false}) {
    if (!hasBindingObject(nativePtr)) return;
    EventTarget? target = getBindingObject<EventTarget>(nativePtr);
    if (target != null) {
      BindingBridge.unlistenEvent(target, eventType, isCapture: isCapture);
    }
  }

  // Call from JS Bridge when the BindingObject class on the JS side had been Garbage collected.
  void disposeBindingObject(MercuryContextController context, Pointer<NativeBindingObject> pointer) async {
    BindingObject? bindingObject = getBindingObject(pointer);
    bindingObject?.dispose();
    context.removeBindingObject(pointer);
    malloc.free(pointer);
  }
}

// An controller designed to control mercury's functional modules.
class MercuryModuleController with TimerMixin {
  late ModuleManager _moduleManager;
  ModuleManager get moduleManager => _moduleManager;

  MercuryModuleController(MercuryController controller, int contextId) {
    _moduleManager = ModuleManager(controller, contextId);
  }

  Future<void> initialize() async {
    await _moduleManager.initialize();
  }

  void dispose() {
    disposeTimer();
    _moduleManager.dispose();
  }
}

class MercuryController {
  static final Map<int, MercuryController?> _controllerMap = {};
  static final Map<String, int> _nameIdMap = {};

  UriParser? uriParser;

  static MercuryController? getControllerOfJSContextId(int? contextId) {
    if (!_controllerMap.containsKey(contextId)) {
      return null;
    }

    return _controllerMap[contextId];
  }

  static Map<int, MercuryController?> getControllerMap() {
    return _controllerMap;
  }

  static MercuryController? getControllerOfName(String name) {
    if (!_nameIdMap.containsKey(name)) return null;
    int? contextId = _nameIdMap[name];
    return getControllerOfJSContextId(contextId);
  }

  LoadHandler? onLoad;

  // Error handler when load bundle failed.
  LoadErrorHandler? onLoadError;

  // Error handler when got javascript error when evaluate javascript codes.
  JSErrorHandler? onJSError;

  final DevToolsService? devToolsService;
  final HttpClientInterceptor? httpClientInterceptor;

  MercuryMethodChannel? _methodChannel;

  MercuryMethodChannel? get methodChannel => _methodChannel;

  JSLogHandler? _onJSLog;
  JSLogHandler? get onJSLog => _onJSLog;
  set onJSLog(JSLogHandler? jsLogHandler) {
    _onJSLog = jsLogHandler;
  }

  String? _name;
  String? get name => _name;
  set name(String? value) {
    if (value == null) return;
    if (_name != null) {
      int? contextId = _nameIdMap[_name];
      _nameIdMap.remove(_name);
      _nameIdMap[value] = contextId!;
    }
    _name = value;
  }

  // The mercury context entrypoint bundle.
  MercuryBundle? _entrypoint;

  MercuryController(
    String? name, {
    bool showPerformanceOverlay = false,
    bool enableDebug = false,
    bool autoExecuteEntrypoint = true,
    MercuryMethodChannel? methodChannel,
    MercuryBundle? entrypoint,
    this.onLoad,
    this.onLoadError,
    this.onJSError,
    this.httpClientInterceptor,
    this.devToolsService,
    this.uriParser,
  })  : _name = name,
        _entrypoint = entrypoint {

    _methodChannel = methodChannel;
    MercuryMethodChannel.setJSMethodCallCallback(this);

    _context = MercuryContextController(
      enableDebug: enableDebug,
      rootController: this,
    );

    final int contextId = _context.contextId;

    _module = MercuryModuleController(this, contextId);

    assert(!_controllerMap.containsKey(contextId), 'found exist contextId of MercuryController, contextId: $contextId');
    _controllerMap[contextId] = this;
    assert(!_nameIdMap.containsKey(name), 'found exist name of MercuryController, name: $name');
    if (name != null) {
      _nameIdMap[name] = contextId;
    }

    setupHttpOverrides(httpClientInterceptor, contextId: contextId);

    uriParser ??= UriParser();

    if (devToolsService != null) {
      devToolsService!.init(this);
    }

    if (autoExecuteEntrypoint) {
      executeEntrypoint();
    }
  }

  late MercuryContextController _context;

  MercuryContextController get context {
    return _context;
  }

  late MercuryModuleController _module;

  MercuryModuleController get module {
    return _module;
  }

  static Uri fallbackBundleUri([int? id]) {
    // The fallback origin uri, like `vm://bundle/0`
    return Uri(scheme: 'vm', host: 'bundle', path: id != null ? '$id' : null);
  }

  Future<void> unload() async {
    assert(!_context._disposed, 'Mercury have already disposed');
    clearIsolateCommand(_context.contextId);

    // Wait for next microtask to make sure C++ native Elements are GC collected.
    Completer completer = Completer();
    Future.microtask(() {
      _module.dispose();
      _context.dispose();

      int oldId = _context.contextId;

      _context = MercuryContextController(
          enableDebug: _context.enableDebug,
          rootController: this,);

      _module = MercuryModuleController(this, _context.contextId);

      // Reconnect the new contextId to the Controller
      _controllerMap.remove(oldId);
      _controllerMap[_context.contextId] = this;
      if (name != null) {
        _nameIdMap[name!] = _context.contextId;
      }

      completer.complete();
    });

    return completer.future;
  }

  String? get _url {
    return null;
  }

  Uri? get _uri {
    return Uri.parse(url);
  }

  String get url => _url ?? 'http://mercury.app';
  Uri? get uri => _uri;

  Future<void> reload() async {
    assert(!_context._disposed, 'Mercury have already disposed');

    if (devToolsService != null) {
      devToolsService!.willReload();
    }

    await unload();
    await executeEntrypoint();

    if (devToolsService != null) {
      devToolsService!.didReload();
    }
  }

  Future<void> load(MercuryBundle bundle) async {
    assert(!_context._disposed, 'Mercury have already disposed');

    if (devToolsService != null) {
      devToolsService!.willReload();
    }

    await unload();

    // Update entrypoint.
    _entrypoint = bundle;

    await executeEntrypoint();

    if (devToolsService != null) {
      devToolsService!.didReload();
    }
  }

  String? getResourceContent(String? url) {
    MercuryBundle? entrypoint = _entrypoint;
    if (url == this.url && entrypoint != null && entrypoint.isResolved) {
      return utf8.decode(entrypoint.data!);
    }
    return null;
  }

  bool _paused = false;
  bool get paused => _paused;

  final List<PendingCallback> _pendingCallbacks = [];

  void pushPendingCallbacks(PendingCallback callback) {
    _pendingCallbacks.add(callback);
  }

  void flushPendingCallbacks() {
    for (int i = 0; i < _pendingCallbacks.length; i++) {
      _pendingCallbacks[i]();
    }
    _pendingCallbacks.clear();
  }

  bool _disposed = false;
  bool get disposed => _disposed;

  void dispose() {
    _module.dispose();
    _context.dispose();
    _controllerMap[_context.contextId] = null;
    _controllerMap.remove(_context.contextId);
    _nameIdMap.remove(name);
    // To release entrypoint bundle memory.
    _entrypoint?.dispose();

    devToolsService?.dispose();
    _disposed = true;
  }

  String get origin {
    Uri uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}:${uri.port}';
  }

  Future<void> executeEntrypoint(
      {bool shouldResolve = true, bool shouldEvaluate = true}) async {
    if (_entrypoint != null && shouldResolve) {
      await Future.wait([
        _resolveEntrypoint(),
        _module.initialize()
      ]);
      if (_entrypoint!.isResolved && shouldEvaluate) {
        await _evaluateEntrypoint();
      } else {
        throw FlutterError('Unable to resolve $_entrypoint');
      }
    } else {
      throw FlutterError('Entrypoint is empty.');
    }
  }

  // Resolve the entrypoint bundle.
  // In general you should use executeEntrypoint, which including resolving and evaluating.
  Future<void> _resolveEntrypoint() async {
    assert(!_context._disposed, 'Mercury have already disposed');

    MercuryBundle? bundleToLoad = _entrypoint;
    if (bundleToLoad == null) {
      // Do nothing if bundle is null.
      return;
    }

    // Resolve the bundle, including network download or other fetching ways.
    try {
      await bundleToLoad.resolve(context.contextId);
    } catch (e, stack) {
      if (onLoadError != null) {
        onLoadError!(FlutterError(e.toString()), stack);
      }
      // Not to dismiss this error.
      rethrow;
    }
  }

  // Execute the content from entrypoint bundle.
  Future<void> _evaluateEntrypoint() async {

    assert(!_context._disposed, 'Mercury have already disposed');
    if (_entrypoint != null) {
      MercuryBundle entrypoint = _entrypoint!;
      int contextId = _context.contextId;
      assert(entrypoint.isResolved, 'The mercury bundle $entrypoint is not resolved to evaluate.');

      Uint8List data = entrypoint.data!;
      if (entrypoint.isJavascript) {
        // Prefer sync decode in loading entrypoint.
        await evaluateScripts(contextId, await resolveStringFromData(data, preferSync: true), url: url);
      } else if (entrypoint.isBytecode) {
        evaluateQuickjsByteCode(contextId, data);
      } else if (entrypoint.contentType.primaryType == 'text') {
        // Fallback treating text content as JavaScript.
        try {
          await evaluateScripts(contextId, await resolveStringFromData(data, preferSync: true), url: url);
        } catch (error) {
          print('Fallback to execute JavaScript content of $url');
          rethrow;
        }
      } else {
        // The resource type can not be evaluated.
        throw FlutterError('Can\'t evaluate content of $url');
      }

      _dispatchGlobalLoadEvent();
    }
  }



  void _dispatchGlobalLoadEvent() {
    Event event = Event(EVENT_LOAD);
    _context.global.dispatchEvent(event);

    if (onLoad != null) {
      onLoad!(this);
    }
  }
}
