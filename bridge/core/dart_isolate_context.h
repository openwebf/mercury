/*
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef MERCURY_DART_CONTEXT_H_
#define MERCURY_DART_CONTEXT_H_

#include <set>
#include "bindings/qjs/script_value.h"
#include "dart_context_data.h"
#include "dart_methods.h"
#include "multiple_threading/dispatcher.h"

namespace mercury {

class MercuryIsolate;
class DartIsolateContext;

class IsolateGroup {
 public:
  ~IsolateGroup();
  void AddNewIsolate(MercuryIsolate* new_isolate);
  void RemoveIsolate(MercuryIsolate* isolate);
  bool Empty() { return isolates_.empty(); }

  std::vector<MercuryIsolate*>* isolates() { return &isolates_; };

 private:
  std::vector<MercuryIsolate*> isolates_;
};

struct DartWireContext {
  ScriptValue jsObject;
  bool is_dedicated;
  double context_id;
  bool disposed;
  multi_threading::Dispatcher* dispatcher;
};

void InitializeBuiltInStrings(JSContext* ctx);

void WatchDartWire(DartWireContext* wire);
bool IsDartWireAlive(DartWireContext* wire);
void DeleteDartWire(DartWireContext* wire);

// DartIsolateContext has a 1:1 correspondence with a dart isolates.
class DartIsolateContext {
 public:
  explicit DartIsolateContext(const uint64_t* dart_methods, int32_t dart_methods_length, bool profile_enabled);

  JSRuntime* runtime();
  FORCE_INLINE bool valid() { return is_valid_; }
  FORCE_INLINE DartMethodPointer* dartMethodPtr() const { return dart_method_ptr_.get(); }
  FORCE_INLINE const std::unique_ptr<multi_threading::Dispatcher>& dispatcher() const { return dispatcher_; }
  FORCE_INLINE void SetDispatcher(std::unique_ptr<multi_threading::Dispatcher>&& dispatcher) {
    dispatcher_ = std::move(dispatcher);
  }
  // prof: FORCE_INLINE WebFProfiler* profiler() const { return profiler_.get(); };

  const std::unique_ptr<DartContextData>& EnsureData() const;

  void* AddNewIsolate(double thread_identity,
                   int32_t sync_buffer_size,
                   Dart_Handle dart_handle,
                   AllocateNewIsolateCallback result_callback);
  void* AddNewIsolateSync(double thread_identity);
  void RemoveIsolate(double thread_identity, MercuryIsolate* isolate, Dart_Handle dart_handle, DisposeIsolateCallback result_callback);
  void RemoveIsolateSync(double thread_identity, MercuryIsolate* isolate);

  ~DartIsolateContext();
  void Dispose(multi_threading::Callback callback);

 private:
  static void InitializeJSRuntime();
  static void FinalizeJSRuntime();
  static void InitializeNewIsolateInJSThread(IsolateGroup* isolate_group,
                                          DartIsolateContext* dart_isolate_context,
                                          double isolate_context_id,
                                          int32_t sync_buffer_size,
                                          Dart_Handle dart_handle,
                                          AllocateNewIsolateCallback result_callback);
  static void DisposeIsolateAndKilledJSThread(DartIsolateContext* dart_isolate_context,
                                           MercuryIsolate* isolate,
                                           int thread_group_id,
                                           Dart_Handle dart_handle,
                                           DisposeIsolateCallback result_callback);
  static void DisposeIsolateInJSThread(DartIsolateContext* dart_isolate_context,
                                    MercuryIsolate* isolate,
                                    Dart_Handle dart_handle,
                                    DisposeIsolateCallback result_callback);
  static void HandleNewIsolateResult(IsolateGroup* isolate_group,
                                  Dart_Handle persistent_handle,
                                  AllocateNewIsolateCallback result_callback,
                                  MercuryIsolate* new_isolate);
  static void HandleDisposeIsolate(Dart_Handle persistent_handle, DisposeIsolateCallback result_callback);
  static void HandleDisposeIsolateAndKillJSThread(DartIsolateContext* dart_isolate_context,
                                               int thread_group_id,
                                               Dart_Handle persistent_handle,
                                               DisposeIsolateCallback result_callback);

  // prof: std::unique_ptr<WebFProfiler> profiler_;
  int is_valid_{false};
  std::thread::id running_thread_;
  mutable std::unique_ptr<DartContextData> data_;
  std::unordered_set<std::unique_ptr<MercuryIsolate>> isolates_in_ui_thread_;
  std::unique_ptr<multi_threading::Dispatcher> dispatcher_ = nullptr;
  // Dart methods ptr should keep alive when ExecutingContext is disposing.
  const std::unique_ptr<DartMethodPointer> dart_method_ptr_ = nullptr;
};

}  // namespace mercury

#endif
