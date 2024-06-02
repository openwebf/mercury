/*
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#include "api.h"
#include "core/dart_isolate_context.h"
#include "core/mercury_isolate.h"
#include "multiple_threading/dispatcher.h"

namespace mercury {

static void ReturnEvaluateScriptsInternal(Dart_PersistentHandle persistent_handle,
                                          EvaluateQuickjsByteCodeCallback result_callback,
                                          bool is_success) {
  Dart_Handle handle = Dart_HandleFromPersistent_DL(persistent_handle);
  result_callback(handle, is_success ? 1 : 0);
  Dart_DeletePersistentHandle_DL(persistent_handle);
}

void evaluateScriptsInternal(void* mercury_isolate_,
                             const char* code,
                             uint64_t code_len,
                             uint8_t** parsed_bytecodes,
                             uint64_t* bytecode_len,
                             const char* bundleFilename,
                             int32_t startLine,
                             int64_t profile_id,
                             Dart_Handle persistent_handle,
                             EvaluateScriptsCallback result_callback) {
  auto mercury_isolate = reinterpret_cast<mercury::MercuryIsolate*>(mercury_isolate_);
  assert(std::this_thread::get_id() == mercury_isolate->currentThread());

  // prof: mercury_isolate->dartIsolateContext()->profiler()->StartTrackEvaluation(profile_id);

  bool is_success = mercury_isolate->evaluateScript(code, code_len, parsed_bytecodes, bytecode_len, bundleFilename, startLine);

  // prof: mercury_isolate->dartIsolateContext()->profiler()->FinishTrackEvaluation(profile_id);

  mercury_isolate->dartIsolateContext()->dispatcher()->PostToDart(mercury_isolate->isDedicated(), ReturnEvaluateScriptsInternal,
                                                       persistent_handle, result_callback, is_success);
}

static void ReturnEvaluateQuickjsByteCodeResultToDart(Dart_PersistentHandle persistent_handle,
                                                      EvaluateQuickjsByteCodeCallback result_callback,
                                                      bool is_success) {
  Dart_Handle handle = Dart_HandleFromPersistent_DL(persistent_handle);
  result_callback(handle, is_success ? 1 : 0);
  Dart_DeletePersistentHandle_DL(persistent_handle);
}

void evaluateQuickjsByteCodeInternal(void* mercury_isolate_,
                                     uint8_t* bytes,
                                     int32_t byteLen,
                                     int64_t profile_id,
                                     Dart_PersistentHandle persistent_handle,
                                     EvaluateQuickjsByteCodeCallback result_callback) {
  auto mercury_isolate = reinterpret_cast<mercury::MercuryIsolate*>(mercury_isolate_);
  assert(std::this_thread::get_id() == mercury_isolate->currentThread());

  // prof: mercury_isolate->dartIsolateContext()->profiler()->StartTrackEvaluation(profile_id);

  bool is_success = mercury_isolate->evaluateByteCode(bytes, byteLen);

  // prof: mercury_isolate->dartIsolateContext()->profiler()->FinishTrackEvaluation(profile_id);

  mercury_isolate->dartIsolateContext()->dispatcher()->PostToDart(mercury_isolate->isDedicated(), ReturnEvaluateQuickjsByteCodeResultToDart,
                                                       persistent_handle, result_callback, is_success);
}

static void ReturnInvokeEventResultToDart(Dart_Handle persistent_handle,
                                          InvokeModuleEventCallback result_callback,
                                          mercury::NativeValue* result) {
  Dart_Handle handle = Dart_HandleFromPersistent_DL(persistent_handle);
  result_callback(handle, result);
  Dart_DeletePersistentHandle_DL(persistent_handle);
}

void invokeModuleEventInternal(void* mercury_isolate_,
                               void* module_name,
                               const char* eventType,
                               void* event,
                               void* extra,
                               Dart_Handle persistent_handle,
                               InvokeModuleEventCallback result_callback) {
  auto mercury_isolate = reinterpret_cast<mercury::MercuryIsolate*>(mercury_isolate_);
  auto dart_isolate_context = mercury_isolate->executingContext()->dartIsolateContext();
  assert(std::this_thread::get_id() == mercury_isolate->currentThread());

  // prof: mercury_isolate->dartIsolateContext()->profiler()->StartTrackAsyncEvaluation();

  auto* result = mercury_isolate->invokeModuleEvent(reinterpret_cast<mercury::SharedNativeString*>(module_name), eventType, event,
                                         reinterpret_cast<mercury::NativeValue*>(extra));

  // prof: mercury_isolate->dartIsolateContext()->profiler()->FinishTrackAsyncEvaluation();

  dart_isolate_context->dispatcher()->PostToDart(mercury_isolate->isDedicated(), ReturnInvokeEventResultToDart, persistent_handle,
                                                 result_callback, result);
}

static void ReturnDumpByteCodeResultToDart(Dart_Handle persistent_handle, DumpQuickjsByteCodeCallback result_callback) {
  Dart_Handle handle = Dart_HandleFromPersistent_DL(persistent_handle);
  result_callback(handle);
  Dart_DeletePersistentHandle_DL(persistent_handle);
}

void dumpQuickJsByteCodeInternal(void* mercury_isolate_,
                                 int64_t profile_id,
                                 const char* code,
                                 int32_t code_len,
                                 uint8_t** parsed_bytecodes,
                                 uint64_t* bytecode_len,
                                 const char* url,
                                 Dart_PersistentHandle persistent_handle,
                                 DumpQuickjsByteCodeCallback result_callback) {
  auto mercury_isolate = reinterpret_cast<mercury::MercuryIsolate*>(mercury_isolate_);
  auto dart_isolate_context = mercury_isolate->executingContext()->dartIsolateContext();

  // prof: dart_isolate_context->profiler()->StartTrackEvaluation(profile_id);

  assert(std::this_thread::get_id() == mercury_isolate->currentThread());
  uint8_t* bytes = mercury_isolate->dumpByteCode(code, code_len, url, bytecode_len);
  *parsed_bytecodes = bytes;

  // prof: dart_isolate_context->profiler()->FinishTrackEvaluation(profile_id);

  dart_isolate_context->dispatcher()->PostToDart(mercury_isolate->isDedicated(), ReturnDumpByteCodeResultToDart, persistent_handle,
                                                 result_callback);
}

}  // namespace mercury
