/*
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#include "dart_isolate_context.h"
#include <unordered_set>
#include "event_factory.h"
#include "logging.h"
#include "multiple_threading/looper.h"
#include "mercury_isolate.h"
#include "names_installer.h"

namespace mercury {

thread_local std::unordered_set<DartWireContext*> alive_wires;

IsolateGroup::~IsolateGroup() {
  for (auto isolate : isolates_) {
    delete isolate;
  }
}

void IsolateGroup::AddNewIsolate(mercury::MercuryIsolate* new_isolate) {
  assert(std::find(isolates_.begin(), isolates_.end(), new_isolate) == isolates_.end());
  isolates_.push_back(new_isolate);
}

void IsolateGroup::RemoveIsolate(mercury::MercuryIsolate* isolate) {
  isolates_.erase(std::find(isolates_.begin(), isolates_.end(), isolate));
}

void WatchDartWire(DartWireContext* wire) {
  alive_wires.emplace(wire);
}

bool IsDartWireAlive(DartWireContext* wire) {
  return alive_wires.find(wire) != alive_wires.end();
}

void DeleteDartWire(DartWireContext* wire) {
  alive_wires.erase(wire);
  delete wire;
}

static void ClearUpWires(JSRuntime* runtime) {
  for (auto& wire : alive_wires) {
    JS_FreeValueRT(runtime, wire->jsObject.QJSValue());
    wire->disposed = true;
  }
  alive_wires.clear();
}

const std::unique_ptr<DartContextData>& DartIsolateContext::EnsureData() const {
  if (data_ == nullptr) {
    data_ = std::make_unique<DartContextData>();
  }
  return data_;
}

thread_local JSRuntime* runtime_{nullptr};
thread_local uint32_t running_dart_isolates = 0;
thread_local bool is_name_installed_ = false;

void InitializeBuiltInStrings(JSContext* ctx) {
  if (!is_name_installed_) {
    names_installer::Init(ctx);
    is_name_installed_ = true;
  }
}

void DartIsolateContext::InitializeJSRuntime() {
  if (runtime_ != nullptr)
    return;
  runtime_ = JS_NewRuntime();
  // Avoid stack overflow when running in multiple threads.
  JS_UpdateStackTop(runtime_);
  // Bump up the built-in classId. To make sure the created classId are larger than JS_CLASS_CUSTOM_CLASS_INIT_COUNT.
  for (int i = 0; i < JS_CLASS_CUSTOM_CLASS_INIT_COUNT - JS_CLASS_GC_TRACKER + 2; i++) {
    JSClassID id{0};
    JS_NewClassID(&id);
  }
}

void DartIsolateContext::FinalizeJSRuntime() {
  if (running_dart_isolates > 0)
    return;

  // Prebuilt strings stored in JSRuntime. Only needs to dispose when runtime disposed.
  names_installer::Dispose();
  HTMLElementFactory::Dispose();
  SVGElementFactory::Dispose();
  EventFactory::Dispose();
  ClearUpWires(runtime_);
  JS_TurnOnGC(runtime_);
  JS_FreeRuntime(runtime_);
  runtime_ = nullptr;
  is_name_installed_ = false;
}

DartIsolateContext::DartIsolateContext(const uint64_t* dart_methods, int32_t dart_methods_length, bool profile_enabled)
    : is_valid_(true),
      running_thread_(std::this_thread::get_id()),
      // prof: profiler_(std::make_unique<WebFProfiler>(profile_enabled)),
      dart_method_ptr_(std::make_unique<DartMethodPointer>(this, dart_methods, dart_methods_length)) {
  is_valid_ = true;
  running_dart_isolates++;
  InitializeJSRuntime();
}

JSRuntime* DartIsolateContext::runtime() {
  return runtime_;
}

DartIsolateContext::~DartIsolateContext() {}

void DartIsolateContext::Dispose(multi_threading::Callback callback) {
  dispatcher_->Dispose([this, &callback]() {
    is_valid_ = false;
    data_.reset();
    isolates_in_isolate_thread_.clear();
    running_dart_isolates--;
    FinalizeJSRuntime();
    callback();
  });
}

void DartIsolateContext::InitializeNewIsolateInJSThread(IsolateGroup* isolate_group,
                                                     DartIsolateContext* dart_isolate_context,
                                                     double isolate_context_id,
                                                     int32_t sync_buffer_size,
                                                     Dart_Handle dart_handle,
                                                     AllocateNewIsolateCallback result_callback) {
  dart_isolate_context->profiler()->StartTrackInitialize();
  DartIsolateContext::InitializeJSRuntime();
  auto* isolate = new MercuryIsolate(dart_isolate_context, true, sync_buffer_size, isolate_context_id, nullptr);

  dart_isolate_context->profiler()->FinishTrackInitialize();

  dart_isolate_context->dispatcher_->PostToDart(true, HandleNewIsolateResult, isolate_group, dart_handle, result_callback,
                                                isolate);
}

void DartIsolateContext::DisposeIsolateAndKilledJSThread(DartIsolateContext* dart_isolate_context,
                                                      MercuryIsolate* isolate,
                                                      int thread_group_id,
                                                      Dart_Handle dart_handle,
                                                      DisposeIsolateCallback result_callback) {
  delete isolate;
  dart_isolate_context->dispatcher_->PostToDart(true, HandleDisposeIsolateAndKillJSThread, dart_isolate_context,
                                                thread_group_id, dart_handle, result_callback);
}

void DartIsolateContext::DisposeIsolateInJSThread(DartIsolateContext* dart_isolate_context,
                                               MercuryIsolate* isolate,
                                               Dart_Handle dart_handle,
                                               DisposeIsolateCallback result_callback) {
  delete isolate;
  dart_isolate_context->dispatcher_->PostToDart(true, HandleDisposeIsolate, dart_handle, result_callback);
}

void* DartIsolateContext::AddNewIsolate(double thread_identity,
                                     int32_t sync_buffer_size,
                                     Dart_Handle dart_handle,
                                     AllocateNewIsolateCallback result_callback) {
  bool is_in_flutter_isolate_thread = thread_identity < 0;
  assert(is_in_flutter_isolate_thread == false);

  int thread_group_id = static_cast<int>(thread_identity);

  IsolateGroup* isolate_group;
  if (!dispatcher_->IsThreadGroupExist(thread_group_id)) {
    dispatcher_->AllocateNewJSThread(thread_group_id);
    isolate_group = new IsolateGroup();
    dispatcher_->SetOpaqueForJSThread(thread_group_id, isolate_group, [](void* p) {
      delete static_cast<IsolateGroup*>(p);
      DartIsolateContext::FinalizeJSRuntime();
    });
  } else {
    isolate_group = static_cast<IsolateGroup*>(dispatcher_->GetOpaque(thread_group_id));
  }

  dispatcher_->PostToJs(true, thread_group_id, InitializeNewIsolateInJSThread, isolate_group, this, thread_identity,
                        sync_buffer_size, dart_handle, result_callback);
  return nullptr;
}

void* DartIsolateContext::AddNewIsolateSync(double thread_identity) {
  profiler()->StartTrackSteps("MercuryIsolate::Initialize");
  auto isolate = std::make_unique<MercuryIsolate>(this, false, 0, thread_identity, nullptr);
  profiler()->FinishTrackSteps();

  void* p = isolate.get();
  isolates_in_isolate_thread_.emplace(std::move(isolate));
  return p;
}

void DartIsolateContext::HandleNewIsolateResult(IsolateGroup* isolate_group,
                                             Dart_Handle persistent_handle,
                                             AllocateNewIsolateCallback result_callback,
                                             MercuryIsolate* new_isolate) {
  isolate_group->AddNewIsolate(new_isolate);
  Dart_Handle handle = Dart_HandleFromPersistent_DL(persistent_handle);
  result_callback(handle, new_isolate);
  Dart_DeletePersistentHandle_DL(persistent_handle);
}

void DartIsolateContext::HandleDisposeIsolate(Dart_Handle persistent_handle, DisposeIsolateCallback result_callback) {
  Dart_Handle handle = Dart_HandleFromPersistent_DL(persistent_handle);
  result_callback(handle);
  Dart_DeletePersistentHandle_DL(persistent_handle);
}

void DartIsolateContext::HandleDisposeIsolateAndKillJSThread(DartIsolateContext* dart_isolate_context,
                                                          int thread_group_id,
                                                          Dart_Handle persistent_handle,
                                                          DisposeIsolateCallback result_callback) {
  dart_isolate_context->dispatcher_->KillJSThreadSync(thread_group_id);

  Dart_Handle handle = Dart_HandleFromPersistent_DL(persistent_handle);
  result_callback(handle);
  Dart_DeletePersistentHandle_DL(persistent_handle);
}

void DartIsolateContext::RemoveIsolate(double thread_identity,
                                    MercuryIsolate* isolate,
                                    Dart_Handle dart_handle,
                                    DisposeIsolateCallback result_callback) {
  bool is_in_flutter_isolate_thread = thread_identity < 0;
  assert(is_in_flutter_isolate_thread == false);

  int thread_group_id = static_cast<int>(isolate->contextId());
  auto isolate_group = static_cast<IsolateGroup*>(dispatcher_->GetOpaque(thread_group_id));

  isolate_group->RemoveIsolate(isolate);

  if (isolate_group->Empty()) {
    isolate->executingContext()->SetContextInValid();
    dispatcher_->PostToJs(true, thread_group_id, DisposeIsolateAndKilledJSThread, this, isolate, thread_group_id, dart_handle,
                          result_callback);
  } else {
    dispatcher_->PostToJs(true, thread_group_id, DisposeIsolateInJSThread, this, isolate, dart_handle, result_callback);
  }
}

void DartIsolateContext::RemoveIsolateSync(double thread_identity, MercuryIsolate* isolate) {
  for (auto it = isolates_in_isolate_thread_.begin(); it != isolates_in_isolate_thread_.end(); ++it) {
    if (it->get() == isolate) {
      isolates_in_isolate_thread_.erase(it);
      break;
    }
  }
}

}  // namespace mercury
