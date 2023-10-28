/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#include <atomic>
#include <cassert>
#include <thread>

#include "bindings/qjs/native_string_utils.h"
#include "core/dart_isolate_context.h"
#include "core/mercury_isolate.h"
#include "foundation/isolate_command_buffer.h"
#include "foundation/logging.h"
#include "include/mercury_bridge.h"

#if defined(_WIN32)
#define SYSTEM_NAME "windows"  // Windows
#elif defined(_WIN64)
#define SYSTEM_NAME "windows"  // Windows
#elif defined(__CYGWIN__) && !defined(_WIN32)
#define SYSTEM_NAME "windows"  // Windows (Cygwin POSIX under Microsoft Window)
#elif defined(__ANDROID__)
#define SYSTEM_NAME "android"  // Android (implies Linux, so it must come first)
#elif defined(__linux__)
#define SYSTEM_NAME "linux"                    // Debian, Ubuntu, Gentoo, Fedora, openSUSE, RedHat, Centos and other
#elif defined(__APPLE__) && defined(__MACH__)  // Apple OSX and iOS (Darwin)
#include <TargetConditionals.h>
#if TARGET_IPHONE_SIMULATOR == 1
#define SYSTEM_NAME "ios"  // Apple iOS Simulator
#elif TARGET_OS_IPHONE == 1
#define SYSTEM_NAME "ios"  // Apple iOS
#elif TARGET_OS_MAC == 1
#define SYSTEM_NAME "macos"  // Apple macOS
#endif
#else
#define SYSTEM_NAME "unknown"
#endif

static std::atomic<int64_t> unique_page_id{0};

void* initDartIsolateContext(uint64_t* dart_methods, int32_t dart_methods_len) {
  void* ptr = new mercury::DartIsolateContext(dart_methods, dart_methods_len);
  return ptr;
}

void* allocateNewMercuryIsolate(void* dart_isolate_context, int32_t target_mercury_isolate_id) {
  assert(dart_isolate_context != nullptr);
  auto mercury_isolate =
      std::make_unique<mercury::MercuryIsolate>((mercury::DartIsolateContext*)dart_isolate_context,
                                                        target_mercury_isolate_id, nullptr);
  void* ptr = mercury_isolate.get();
  ((mercury::DartIsolateContext*)dart_isolate_context)->AddNewIsolate(std::move(mercury_isolate));
  return ptr;
}

int64_t newMercuryIsolateId() {
  return unique_page_id++;
}

void disposeMercuryIsolate(void* dart_isolate_context, void* ptr) {
  auto* mercury_isolate = reinterpret_cast<mercury::MercuryIsolate*>(ptr);
  assert(std::this_thread::get_id() == mercury_isolate->currentThread());
  ((mercury::DartIsolateContext*)dart_isolate_context)->RemoveIsolate(mercury_isolate);
}

int8_t evaluateScripts(void* ptr,
                       SharedNativeString* code,
                       uint8_t** parsed_bytecodes,
                       uint64_t* bytecode_len,
                       const char* bundleFilename,
                       int32_t startLine) {
  auto mercury_isolate = reinterpret_cast<mercury::MercuryIsolate*>(ptr);
  assert(std::this_thread::get_id() == mercury_isolate->currentThread());
  return mercury_isolate->evaluateScript(reinterpret_cast<mercury::SharedNativeString*>(code), parsed_bytecodes, bytecode_len,
                              bundleFilename, startLine)
             ? 1
             : 0;
}

int8_t evaluateQuickjsByteCode(void* ptr, uint8_t* bytes, int32_t byteLen) {
  auto mercury_isolate = reinterpret_cast<mercury::MercuryIsolate*>(ptr);
  assert(std::this_thread::get_id() == mercury_isolate->currentThread());
  return mercury_isolate->evaluateByteCode(bytes, byteLen) ? 1 : 0;
}

NativeValue* invokeModuleEvent(void* ptr,
                               SharedNativeString* module_name,
                               const char* eventType,
                               void* event,
                               NativeValue* extra) {
  auto mercury_isolate = reinterpret_cast<mercury::MercuryIsolate*>(ptr);
  assert(std::this_thread::get_id() == mercury_isolate->currentThread());
  auto* result = mercury_isolate->invokeModuleEvent(reinterpret_cast<mercury::SharedNativeString*>(module_name), eventType, event,
                                         reinterpret_cast<mercury::NativeValue*>(extra));
  return reinterpret_cast<NativeValue*>(result);
}

static MercuryInfo* mercuryInfo{nullptr};

MercuryInfo* getMercuryInfo() {
  if (mercuryInfo == nullptr) {
    mercuryInfo = new MercuryInfo();
    mercuryInfo->app_name = "Mercury";
    mercuryInfo->app_revision = APP_REV;
    mercuryInfo->app_version = APP_VERSION;
    mercuryInfo->system_name = SYSTEM_NAME;
  }

  return mercuryInfo;
}

void* getIsolateCommandItems(void* isolate_) {
  auto isolate = reinterpret_cast<mercury::MercuryIsolate*>(isolate_);
  assert(std::this_thread::get_id() == isolate->currentThread());
  return isolate->GetExecutingContext()->isolateCommandBuffer()->data();
}

int64_t getIsolateCommandItemSize(void* isolate_) {
  auto isolate = reinterpret_cast<mercury::MercuryIsolate*>(isolate_);
  assert(std::this_thread::get_id() == isolate->currentThread());
  return isolate->GetExecutingContext()->isolateCommandBuffer()->size();
}

void clearIsolateCommandItems(void* isolate_) {
  auto isolate = reinterpret_cast<mercury::MercuryIsolate*>(isolate_);
  assert(std::this_thread::get_id() == isolate->currentThread());
  isolate->GetExecutingContext()->isolateCommandBuffer()->clear();
}

// Callbacks when dart context object was finalized by Dart GC.
static void finalize_dart_context(void* isolate_callback_data, void* peer) {
  auto* dart_isolate_context = (mercury::DartIsolateContext*)peer;
  delete dart_isolate_context;
}

void init_dart_dynamic_linking(void* data) {
  if (Dart_InitializeApiDL(data) != 0) {
    printf("Failed to initialize dart VM API\n");
  }
}

void register_dart_context_finalizer(Dart_Handle dart_handle, void* dart_isolate_context) {
  Dart_NewFinalizableHandle_DL(dart_handle, reinterpret_cast<void*>(dart_isolate_context),
                               sizeof(mercury::DartIsolateContext), finalize_dart_context);
}
