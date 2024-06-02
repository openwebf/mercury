/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef MERCURY_BRIDGE_EXPORT_H
#define MERCURY_BRIDGE_EXPORT_H

#include <include/dart_api_dl.h>
#include <functional>
#include <thread>

#if defined(_WIN32)
#define MERCURY_EXPORT_C extern "C" __declspec(dllexport)
#define MERCURY_EXPORT __declspec(dllexport)
#else
#define MERCURY_EXPORT_C extern "C" __attribute__((visibility("default"))) __attribute__((used))
#define MERCURY_EXPORT __attribute__((__visibility__("default")))
#endif

typedef struct SharedNativeString SharedNativeString;
typedef struct NativeValue NativeValue;
typedef struct NativeScreen NativeScreen;
typedef struct NativeByteCode NativeByteCode;

struct MercuryInfo {
  const char* app_name{nullptr};
  const char* app_version{nullptr};
  const char* app_revision{nullptr};
  const char* system_name{nullptr};
};

typedef void (*Task)(void*);
typedef std::function<void(bool)> DartWork;
typedef void (*AllocateNewIsolateCallback)(Dart_Handle dart_handle, void*);
typedef void (*DisposeIsolateCallback)(Dart_Handle dart_handle);
typedef void (*InvokeModuleEventCallback)(Dart_Handle dart_handle, void*);
typedef void (*EvaluateQuickjsByteCodeCallback)(Dart_Handle dart_handle, int8_t);
typedef void (*DumpQuickjsByteCodeCallback)(Dart_Handle);
typedef void (*ParseHTMLCallback)(Dart_Handle);
typedef void (*EvaluateScriptsCallback)(Dart_Handle dart_handle, int8_t);

MERCURY_EXPORT_C
void* initDartIsolateContextSync(int64_t dart_port,
                                 uint64_t* dart_methods,
                                 int32_t dart_methods_len,
                                 int8_t enable_profile);

MERCURY_EXPORT_C
void allocateNewIsolate(double thread_identity,
                     int32_t sync_buffer_size,
                     void* dart_isolate_context,
                     Dart_Handle dart_handle,
                     AllocateNewIsolateCallback result_callback);

MERCURY_EXPORT_C
void* allocateNewIsolateSync(uint64_t* dart_methods, int32_t dart_methods_len);
MERCURY_EXPORT_C
int64_t newMercuryIsolateIdSync();

MERCURY_EXPORT_C
void disposeMercuryIsolate(double dedicated_thread,
                 void* dart_isolate_context,
                 void* isolate,
                 Dart_Handle dart_handle,
                 DisposePageCallback result_callback);

MERCURY_EXPORT_C
void evaluateScripts(void* isolate,
                     const char* code,
                     uint64_t code_len,
                     uint8_t** parsed_bytecodes,
                     uint64_t* bytecode_len,
                     const char* bundleFilename,
                     int32_t start_line,
                     int64_t profile_id,
                     Dart_Handle dart_handle,
                     EvaluateQuickjsByteCodeCallback result_callback);
MERCURY_EXPORT_C
void evaluateQuickjsByteCode(void* isolate,
                             uint8_t* bytes,
                             int32_t byteLen,
                             int64_t profile_id,
                             Dart_Handle dart_handle,
                             EvaluateQuickjsByteCodeCallback result_callback);

MERCURY_EXPORT_C
void dumpQuickjsByteCode(void* isolate,
                         int64_t profile_id,
                         const char* code,
                         int32_t code_len,
                         uint8_t** parsed_bytecodes,
                         uint64_t* bytecode_len,
                         const char* url,
                         Dart_Handle dart_handle,
                         DumpQuickjsByteCodeCallback result_callback);
MERCURY_EXPORT_C
void invokeModuleEvent(void* isolate,
                       SharedNativeString* module,
                       const char* eventType,
                       void* event,
                       NativeValue* extra,
                       Dart_Handle dart_handle,
                       InvokeModuleEventCallback result_callback);
// prof: WEBF_EXPORT_C
// prof: void collectNativeProfileData(void* ptr, const char** data, uint32_t* len);
// prof: WEBF_EXPORT_C
// prof: void clearNativeProfileData(void* ptr);
MERCURY_EXPORT_C
MercuryInfo* getMercuryInfo();

MERCURY_EXPORT_C
void* getIsolateCommandItems(void* isolate);
WEBF_EXPORT_C
uint32_t getIsolateCommandKindFlag(void* isolate);
MERCURY_EXPORT_C
int64_t getIsolateCommandItemSize(void* isolate);
MERCURY_EXPORT_C
void clearIsolateCommandItems(void* isolate);
WEBF_EXPORT_C int8_t isJSThreadBlocked(void* dart_isolate_context, double context_id);

WEBF_EXPORT_C void executeNativeCallback(DartWork* work_ptr);
MERCURY_EXPORT_C
void init_dart_dynamic_linking(void* data);
MERCURY_EXPORT_C
void register_dart_context_finalizer(Dart_Handle dart_handle, void* dart_isolate_context);

#endif  // MERCURY_BRIDGE_EXPORT_H
