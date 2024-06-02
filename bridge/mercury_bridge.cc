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
#include "core/api/api.h"
#include "core/dart_isolate_context.h"
#include "foundation/native_type.h"
#include "include/dart_api.h"
#include "multiple_threading/dispatcher.h"
#include "multiple_threading/task.h"

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

static std::atomic<int64_t> unique_isolate_id{1};

int64_t newIsolateIdSync() {
  return unique_isolate_id++;
}

void* initDartIsolateContextSync(int64_t dart_port,
                                 uint64_t* dart_methods,
                                 int32_t dart_methods_len,
                                 int8_t enable_profile) {
  auto dispatcher = std::make_unique<mercury::multi_threading::Dispatcher>(dart_port);

#if ENABLE_LOG
  MERCURY_LOG(INFO) << "[Dispatcher]: initDartIsolateContextSync Call BEGIN";
#endif
  auto* dart_isolate_context = new mercury::DartIsolateContext(dart_methods, dart_methods_len, enable_profile == 1);
  dart_isolate_context->SetDispatcher(std::move(dispatcher));

#if ENABLE_LOG
  MERCURY_LOG(INFO) << "[Dispatcher]: initDartIsolateContextSync Call END";
#endif

  return dart_isolate_context;
}

void* allocateNewIsolateSync(double thread_identity, void* ptr) {
#if ENABLE_LOG
  MERCURY_LOG(INFO) << "[Dispatcher]: allocateNewIsolateSync Call BEGIN";
#endif
  auto* dart_isolate_context = (mercury::DartIsolateContext*)ptr;
  assert(dart_isolate_context != nullptr);

  // prof: dart_isolate_context->profiler()->StartTrackInitialize();

  void* result = static_cast<mercury::DartIsolateContext*>(dart_isolate_context)->AddNewIsolateSync(thread_identity);
#if ENABLE_LOG
  MERCURY_LOG(INFO) << "[Dispatcher]: allocateNewIsolateSync Call END";
#endif

  // prof: dart_isolate_context->profiler()->FinishTrackInitialize();

  return result;
}

void allocateNewIsolate(double thread_identity,
                     int32_t sync_buffer_size,
                     void* ptr,
                     Dart_Handle dart_handle,
                     AllocateNewPageCallback result_callback) {
#if ENABLE_LOG
  MERCURY_LOG(INFO) << "[Dispatcher]: allocateNewIsolate Call BEGIN";
#endif
  auto* dart_isolate_context = (mercury::DartIsolateContext*)ptr;
  assert(dart_isolate_context != nullptr);
  Dart_PersistentHandle persistent_handle = Dart_NewPersistentHandle_DL(dart_handle);

  static_cast<mercury::DartIsolateContext*>(dart_isolate_context)
      ->AddNewIsolate(thread_identity, sync_buffer_size, persistent_handle, result_callback);
#if ENABLE_LOG
  MERCURY_LOG(INFO) << "[Dispatcher]: allocateNewIsolate Call END";
#endif
}

int64_t newMercuryIsolateId() {
  return unique_isolate_id++;
}

void disposeMercuryIsolateSync(double thread_identity, void* ptr, void* isolate_) {
#if ENABLE_LOG
  MERCURY_LOG(INFO) << "[Dispatcher]: disposeMercuryIsolateSync Call BEGIN";
#endif
  auto* dart_isolate_context = (mercury::DartIsolateContext*)ptr;
  ((mercury::DartIsolateContext*)dart_isolate_context)
      ->RemoveIsolateSync(thread_identity, static_cast<mercury::MercuryIsolate*>(isolate_));
#if ENABLE_LOG
  MERCURY_LOG(INFO) << "[Dispatcher]: disposeMercuryIsolateSync Call END";
#endif
}

void evaluateScripts(void* isolate_,
                     const char* code,
                     uint64_t code_len,
                     uint8_t** parsed_bytecodes,
                     uint64_t* bytecode_len,
                     const char* bundleFilename,
                     int32_t start_line,
                     int64_t profile_id,
                     Dart_Handle dart_handle,
                     EvaluateScriptsCallback result_callback) {
#if ENABLE_LOG
  MERCURY_LOG(VERBOSE) << "[Dart] evaluateScriptsWrapper call" << std::endl;
#endif
  auto isolate = reinterpret_cast<mercury::MercuryIsolate*>(isolate_);
  Dart_PersistentHandle persistent_handle = Dart_NewPersistentHandle_DL(dart_handle);
  isolate->executingContext()->dartIsolateContext()->dispatcher()->PostToJs(
      isolate->isDedicated(), isolate->contextId(), mercury::evaluateScriptsInternal, isolate_, code, code_len, parsed_bytecodes,
      bytecode_len, bundleFilename, start_line, profile_id, persistent_handle, result_callback);
}

void dumpQuickjsByteCode(void* isolate_,
                         int64_t profile_id,
                         const char* code,
                         int32_t code_len,
                         uint8_t** parsed_bytecodes,
                         uint64_t* bytecode_len,
                         const char* url,
                         Dart_Handle dart_handle,
                         DumpQuickjsByteCodeCallback result_callback) {
#if ENABLE_LOG
  MERCURY_LOG(VERBOSE) << "[Dart] dumpQuickjsByteCode call" << std::endl;
#endif

  auto isolate = reinterpret_cast<mercury::MercuryIsolate*>(isolate_);
  Dart_PersistentHandle persistent_handle = Dart_NewPersistentHandle_DL(dart_handle);
  isolate->dartIsolateContext()->dispatcher()->PostToJs(
      isolate->isDedicated(), isolate->contextId(), mercury::dumpQuickJsByteCodeInternal, isolate, profile_id, code, code_len,
      parsed_bytecodes, bytecode_len, url, persistent_handle, result_callback);
}

void evaluateQuickjsByteCode(void* isolate_,
                             uint8_t* bytes,
                             int32_t byteLen,
                             int64_t profile_id,
                             Dart_Handle dart_handle,
                             EvaluateQuickjsByteCodeCallback result_callback) {
#if ENABLE_LOG
  MERCURY_LOG(VERBOSE) << "[Dart] evaluateQuickjsByteCodeWrapper call" << std::endl;
#endif
  auto isolate = reinterpret_cast<mercury::MercuryIsolate*>(isolate_);
  Dart_PersistentHandle persistent_handle = Dart_NewPersistentHandle_DL(dart_handle);
  isolate->dartIsolateContext()->dispatcher()->PostToJs(isolate->isDedicated(), isolate->contextId(),
                                                     mercury::evaluateQuickjsByteCodeInternal, isolate_, bytes, byteLen,
                                                     profile_id, persistent_handle, result_callback);
}

void registerPluginByteCode(uint8_t* bytes, int32_t length, const char* pluginName) {
  mercury::ExecutingContext::plugin_byte_code[pluginName] = mercury::NativeByteCode{bytes, length};
}

void registerPluginCode(const char* code, int32_t length, const char* pluginName) {
  mercury::ExecutingContext::plugin_string_code[pluginName] = std::string(code, length);
}

void invokeModuleEvent(void* page_,
                       SharedNativeString* module,
                       const char* eventType,
                       void* event,
                       NativeValue* extra,
                       Dart_Handle dart_handle,
                       InvokeModuleEventCallback result_callback) {
  Dart_PersistentHandle persistent_handle = Dart_NewPersistentHandle_DL(dart_handle);
  auto page = reinterpret_cast<mercury::MercuryIsolate*>(page_);
  auto dart_isolate_context = page->executingContext()->dartIsolateContext();
  auto is_dedicated = page->executingContext()->isDedicated();
  auto context_id = page->contextId();
  dart_isolate_context->dispatcher()->PostToJs(is_dedicated, context_id, mercury::invokeModuleEventInternal, page_, module,
                                               eventType, event, extra, persistent_handle, result_callback);
}

// prof: stuff

// void collectNativeProfileData(void* ptr, const char** data, uint32_t* len) {
//   auto* dart_isolate_context = static_cast<webf::DartIsolateContext*>(ptr);
//   std::string result = dart_isolate_context->profiler()->ToJSON();

//   *data = static_cast<const char*>(webf::dart_malloc(sizeof(char) * result.size() + 1));
//   memcpy((void*)*data, result.c_str(), sizeof(char) * result.size() + 1);
//   *len = result.size();
// }

// void clearNativeProfileData(void* ptr) {
//   auto* dart_isolate_context = static_cast<webf::DartIsolateContext*>(ptr);
//   dart_isolate_context->profiler()->clear();
// }

static MercuryInfo* mercuryInfo{nullptr};

MercuryInfo* getMercuryInfo() {
  if (mercuryInfo == nullptr) {
    mercuryInfo = new MercuryInfo();
    mercuryInfo->app_name = "Mercuryjs";
    mercuryInfo->app_revision = APP_REV;
    mercuryInfo->app_version = APP_VERSION;
    mercuryInfo->system_name = SYSTEM_NAME;
  }

  return mercuryInfo;
}

void* getIsolateCommandItems(void* isolate_) {
  auto isolate = reinterpret_cast<mercury::MercuryIsolate*>(isolate_);
  return isolate->executingContext()->isolateCommandBuffer()->data();
}

uint32_t getUICommandKindFlag(void* page_) {
  auto page = reinterpret_cast<mercury::MercuryIsolate*>(page_);
  return page->executingContext()->isolateCommandBuffer()->kindFlag();
}

int64_t getIsolateCommandItemSize(void* isolate_) {
  auto isolate = reinterpret_cast<mercury::MercuryIsolate*>(isolate_);
  return isolate->executingContext()->isolateCommandBuffer()->size();
}

void clearIsolateCommandItems(void* isolate_) {
  auto isolate = reinterpret_cast<mercury::MercuryIsolate*>(isolate_);
  isolate->executingContext()->isolateCommandBuffer()->clear();
}

// Callbacks when dart context object was finalized by Dart GC.
static void finalize_dart_context(void* isolate_callback_data, void* peer) {
  MERCURY_LOG(VERBOSE) << "[Dispatcher]: BEGIN FINALIZE DART CONTEXT: ";
  auto* dart_isolate_context = (mercury::DartIsolateContext*)peer;
  dart_isolate_context->Dispose([dart_isolate_context]() {
    free(dart_isolate_context);
#if ENABLE_LOG
    MERCURY_LOG(VERBOSE) << "[Dispatcher]: SUCCESS FINALIZE DART CONTEXT";
#endif
  });
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

int8_t isJSThreadBlocked(void* dart_isolate_context_, double context_id) {
  auto* dart_isolate_context = static_cast<mercury::DartIsolateContext*>(dart_isolate_context_);
  auto thread_group_id = static_cast<int32_t>(context_id);
  return dart_isolate_context->dispatcher()->IsThreadBlocked(thread_group_id) ? 1 : 0;
}

// run in the dart isolate thread
void executeNativeCallback(DartWork* work_ptr) {
  auto dart_work = *(work_ptr);
  dart_work(false);
  delete work_ptr;
}
