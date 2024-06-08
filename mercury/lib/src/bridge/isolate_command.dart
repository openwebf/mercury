/*
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:mercuryjs/bridge.dart';
import 'package:mercuryjs/foundation.dart';
import 'package:mercuryjs/launcher.dart';
import 'package:mercuryjs/module.dart';

class IsolateCommand {
  late final IsolateCommandType type;
  late final String args;
  late final Pointer nativePtr;
  late final Pointer nativePtr2;

  IsolateCommand();
  IsolateCommand.from(this.type, this.args, this.nativePtr, this.nativePtr2);

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

const int commandBufferPrefix = 1;

bool enableMercuryCommandLog = !kReleaseMode && Platform.environment['ENABLE_WEBF_JS_LOG'] == 'true';

// We found there are performance bottleneck of reading native memory with Dart FFI API.
// So we align all Isolate instructions to a whole block of memory, and then convert them into a dart array at one time,
// To ensure the fastest subsequent random access.
List<IsolateCommand> nativeIsolateCommandToDart(List<int> rawMemory, int commandLength, double contextId) {
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
    return command;
  }, growable: false);

  return results;
}

void execIsolateCommands(MercuryContextController context, List<IsolateCommand> commands) {
  Map<int, bool> pendingStylePropertiesTargets = {};

  for(IsolateCommand command in commands) {
    IsolateCommandType commandType = command.type;

    if (enableMercuryCommandLog) {
      String printMsg;
      switch(command.type) {
        default:
          printMsg = 'nativePtr: ${command.nativePtr} type: ${command.type} args: ${command.args} nativePtr2: ${command.nativePtr2}';
      }
      print(printMsg);
    }

    // prof: if (commandType == IsolateCommandType.startRecordingCommand || commandType == IsolateCommandType.finishRecordingCommand) continue;

    Pointer nativePtr = command.nativePtr;

    // prof:
    try {
      switch (commandType) {
        case IsolateCommandType.createGlobal:
          // if (enableMercuryProfileTracking) {
          //   MercuryProfiler.instance.startTrackIsolateCommandStep('FlushIsolateCommand.createWindow');
          // }

          context.initGlobal(context, nativePtr.cast<NativeBindingObject>());

          // if (enableMercuryProfileTracking) {
          //   MercuryProfiler.instance.finishTrackIsolateCommandStep();
          // }
          break;
        case IsolateCommandType.disposeBindingObject:
          // if (enableMercuryProfileTracking) {
          //   MercuryProfiler.instance.startTrackIsolateCommandStep('FlushIsolateCommand.createWindow');
          // }

          context.disposeBindingObject(context, nativePtr.cast<NativeBindingObject>());

          // if (enableMercuryProfileTracking) {
          //   MercuryProfiler.instance.finishTrackIsolateCommandStep();
          // }
          break;
        case IsolateCommandType.addEvent:
          // if (enableMercuryProfileTracking) {
          //   MercuryProfiler.instance.startTrackIsolateCommandStep('FlushIsolateCommand.addEvent');
          // }

          Pointer<AddEventListenerOptions> eventListenerOptions = command.nativePtr2.cast<AddEventListenerOptions>();
          context.addEvent(nativePtr.cast<NativeBindingObject>(), command.args,
              addEventListenerOptions: eventListenerOptions);

          // if (enableMercuryProfileTracking) {
          //   MercuryProfiler.instance.finishTrackIsolateCommandStep();
          // }

          break;
        case IsolateCommandType.removeEvent:
          // if (enableMercuryProfileTracking) {
          //   MercuryProfiler.instance.startTrackIsolateCommandStep('FlushIsolateCommand.removeEvent');
          // }
          bool isCapture = command.nativePtr2.address == 1;
          context.removeEvent(nativePtr.cast<NativeBindingObject>(), command.args, isCapture: isCapture);
          // if (enableMercuryProfileTracking) {
          //   MercuryProfiler.instance.finishTrackIsolateCommandStep();
          // }
          break;
        default:
          break;
      }
    } catch (e, stack) {
      print('$e\n$stack');
    }
  }

  // if (enableMercuryProfileTracking) {
  //   MercuryProfiler.instance.finishTrackIsolateCommandStep();
  // }
}
