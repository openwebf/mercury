/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:mercury_js/bridge.dart';
import 'package:mercury_js/src/global/event_target.dart';

enum AppearEventType { none, appear, disappear }

const String EVENT_OPEN = 'open';
const String EVENT_CLOSE = 'close';
const String EVENT_LOAD = 'load';
const String EVENT_ERROR = 'error';
const String EVENT_MESSAGE = 'message';
const String EVENT_CANCEL = 'cancel';
const String EVENT_FINISH = 'finish';
const String EVENT_CHANGE = 'change';
const String EVENT_STATE_START = 'start';
const String EVENT_STATE_UPDATE = 'update';
const String EVENT_STATE_END = 'end';
const String EVENT_STATE_CANCEL = 'cancel';

// @TODO: inherit BindingObject to receive value from Cpp side.
/// reference: https://developer.mozilla.org/zh-CN/docs/Web/API/Event
class Event {
  String type;

  // A boolean value indicating whether the event bubbles. The default is false.
  bool bubbles;

  // A boolean value indicating whether the event can be cancelled. The default is false.
  bool cancelable;

  // A boolean value indicating whether the event will trigger listeners outside of a shadow root (see Event.composed for more details).
  bool composed;
  EventTarget? currentTarget;
  EventTarget? target;
  int timeStamp = DateTime.now().millisecondsSinceEpoch;
  bool defaultPrevented = false;
  bool _immediateBubble = true;
  bool propagationStopped = false;

  Pointer<Void> sharedJSProps = nullptr;
  int propLen = 0;
  int allocateLen = 0;

  Event(
    this.type, {
    this.bubbles = false,
    this.cancelable = false,
    this.composed = false,
  });

  void preventDefault() {
    if (cancelable) {
      defaultPrevented = true;
    }
  }

  bool canBubble() => _immediateBubble;

  void stopImmediatePropagation() {
    _immediateBubble = false;
  }

  void stopPropagation() {
    bubbles = false;
  }

  Pointer toRaw([int extraLength = 0, bool isCustomEvent = false]) {
    Pointer<RawEvent> event = malloc.allocate<RawEvent>(sizeOf<RawEvent>());

    EventTarget? _target = target;
    EventTarget? _currentTarget = currentTarget;

    List<int> methods = [
      stringToNativeString(type).address,
      bubbles ? 1 : 0,
      cancelable ? 1 : 0,
      composed ? 1 : 0,
      timeStamp,
      defaultPrevented ? 1 : 0,
      (_target != null && _target.pointer != null) ? _target.pointer!.address : nullptr.address,
      (_currentTarget != null && _currentTarget.pointer != null) ? _currentTarget.pointer!.address : nullptr.address,
      sharedJSProps.address, // EventProps* props
      propLen,  // int64_t props_len
      allocateLen   // int64_t alloc_size;
    ];

    // Allocate extra bytes to store subclass's members.
    int nativeStructSize = methods.length + extraLength;

    final Pointer<Uint64> bytes = malloc.allocate<Uint64>(nativeStructSize * sizeOf<Uint64>());
    bytes.asTypedList(methods.length).setAll(0, methods);
    event.ref.bytes = bytes;
    event.ref.length = methods.length;
    event.ref.is_custom_event = isCustomEvent ? 1 : 0;

    return event.cast<Pointer>();
  }

  @override
  String toString() {
    return 'Event($type)';
  }
}

/// reference: http://dev.w3.org/2006/webapi/DOM-Level-3-Events/html/DOM3-Events.html#interface-CustomEvent
/// Attention: Detail now only can be a string.
class CustomEvent extends Event {
  dynamic detail;

  CustomEvent(
    String type, {
    this.detail = null,
    super.bubbles,
    super.cancelable,
    super.composed,
  }) : super(type);

  @override
  Pointer toRaw([int extraLength = 0, bool isCustomEvent = false]) {
    Pointer<NativeValue> detailValue = malloc.allocate(sizeOf<NativeValue>());
    toNativeValue(detailValue, detail);
    List<int> methods = [detailValue.address];

    Pointer<RawEvent> rawEvent = super.toRaw(methods.length, true).cast<RawEvent>();
    int currentStructSize = rawEvent.ref.length + methods.length;
    Uint64List bytes = rawEvent.ref.bytes.asTypedList(currentStructSize);
    bytes.setAll(rawEvent.ref.length, methods);
    rawEvent.ref.length = currentStructSize;

    return rawEvent;
  }
}

/// reference: https://developer.mozilla.org/en-US/docs/Web/API/MessageEvent
class MessageEvent extends Event {
  /// The data sent by the message emitter.
  final dynamic data;

  /// A USVString representing the origin of the message emitter.
  final String origin;
  final String lastEventId;
  final String source;

  MessageEvent(this.data, {this.origin = '', this.lastEventId = '', this.source = ''}) : super(EVENT_MESSAGE);

  @override
  Pointer toRaw([int extraLength = 0, bool isCustomEvent = false]) {
    Pointer<NativeValue> nativeData = malloc.allocate(sizeOf<NativeValue>());
    toNativeValue(nativeData, data);
    List<int> methods = [
      nativeData.address,
      stringToNativeString(origin).address,
      stringToNativeString(lastEventId).address,
      stringToNativeString(source).address
    ];

    Pointer<RawEvent> rawEvent = super.toRaw(methods.length).cast<RawEvent>();
    int currentStructSize = rawEvent.ref.length + methods.length;
    Uint64List bytes = rawEvent.ref.bytes.asTypedList(currentStructSize);
    bytes.setAll(rawEvent.ref.length, methods);
    rawEvent.ref.length = currentStructSize;

    return rawEvent;
  }
}


/// reference: https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent/CloseEvent
class CloseEvent extends Event {
  /// An unsigned short containing the close code sent by the server
  final int code;

  /// Indicating the reason the server closed the connection.
  final String reason;

  /// Indicates whether or not the connection was cleanly closed
  final bool wasClean;

  CloseEvent(this.code, this.reason, this.wasClean) : super(EVENT_CLOSE);

  @override
  Pointer toRaw([int extraLength = 0, bool isCustomEvent = false]) {
    List<int> methods = [code, stringToNativeString(reason).address, wasClean ? 1 : 0];

    Pointer<RawEvent> rawEvent = super.toRaw(methods.length).cast<RawEvent>();
    int currentStructSize = rawEvent.ref.length + methods.length;
    Uint64List bytes = rawEvent.ref.bytes.asTypedList(currentStructSize);
    bytes.setAll(rawEvent.ref.length, methods);
    rawEvent.ref.length = currentStructSize;

    return rawEvent;
  }
}
