/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
#ifndef BRIDGE_JS_CONTEXT_H
#define BRIDGE_JS_CONTEXT_H

#include <quickjs/list.h>
#include <quickjs/quickjs.h>
#include <atomic>
#include <cassert>
#include <cmath>
#include <cstring>
#include <locale>
#include <memory>
#include <mutex>
#include <set>
#include <unordered_map>
#include "bindings/qjs/rejected_promises.h"
#include "bindings/qjs/script_value.h"
#include "dart_isolate_context.h"
#include "dart_methods.h"
#include "executing_context_data.h"
#include "foundation/macros.h"
#include "foundation/isolate_command_buffer.h"
#include "module/timer/timer_coordinator.h"
#include "module/module_callback.h"
#include "module/module_listener_container.h"
#include "module/module_context_coordinator.h"
#include "script_state.h"
#include "defined_properties.h"

namespace mercury {

struct NativeByteCode {
  uint8_t* bytes;
  int32_t length;
};

class ExecutingContext;
class Global;
class MemberMutationScope;
class ErrorEvent;
class DartContext;
class ScriptWrappable;

using JSExceptionHandler = std::function<void(ExecutingContext* context, const char* message)>;

bool isContextValid(int32_t contextId);

// An environment in which script can execute. This class exposes the common
// properties of script execution environments on the mercury.
// Global : Document : ExecutionContext = 1 : 1 : 1 at any point in time.
class ExecutingContext {
 public:
  ExecutingContext() = delete;
  ExecutingContext(DartIsolateContext* dart_isolate_context,
                   int32_t contextId,
                   JSExceptionHandler handler,
                   void* owner);
  ~ExecutingContext();

  static ExecutingContext* From(JSContext* ctx);

  bool EvaluateJavaScript(const uint16_t* code,
                          size_t codeLength,
                          uint8_t** parsed_bytecodes,
                          uint64_t* bytecode_len,
                          const char* sourceURL,
                          int startLine);
  bool EvaluateJavaScript(const char16_t* code, size_t length, const char* sourceURL, int startLine);
  bool EvaluateJavaScript(const char* code, size_t codeLength, const char* sourceURL, int startLine);
  bool EvaluateByteCode(uint8_t* bytes, size_t byteLength);
  bool IsContextValid() const;
  bool IsCtxValid() const;
  JSValue GlobalObject();
  JSContext* ctx();
  FORCE_INLINE int32_t contextId() const { return context_id_; };
  FORCE_INLINE int32_t uniqueId() const { return unique_id_; }
  void* owner();
  bool HandleException(JSValue* exc);
  bool HandleException(ScriptValue* exc);
  bool HandleException(ExceptionState& exception_state);
  void ReportError(JSValueConst error);
  void DrainPendingPromiseJobs();
  void DefineGlobalProperty(const char* prop, JSValueConst value);
  ExecutionContextData* contextData();
  uint8_t* DumpByteCode(const char* code, uint32_t codeLength, const char* sourceURL, size_t* bytecodeLength);

  // Make global object inherit from GlobalProperties.
  void InstallGlobal();

  // Register active script wrappers.
  void RegisterActiveScriptWrappers(ScriptWrappable* script_wrappable);
  void InActiveScriptWrappers(ScriptWrappable* script_wrappable);

  // Gets the TimerCoordinator which maintains the "active timer
  // list" of tasks created by setTimeout and setInterval. The
  // TimerCoordinator is owned by the ExecutionContext and should
  // not be used after the ExecutionContext is destroyed.
  TimerCoordinator* Timers();

  // Gets the ModuleListeners which registered by `mercury.addModuleListener API`.
  ModuleListenerContainer* ModuleListeners();

  // Gets the ModuleCallbacks which from the 4th parameter of `mercury.invokeModule` function.
  ModuleContextCoordinator* ModuleContexts();

  // Get current script state.
  ScriptState* GetScriptState() { return &script_state_; }

  void SetMutationScope(MemberMutationScope& mutation_scope);
  bool HasMutationScope() const { return active_mutation_scope != nullptr; }
  MemberMutationScope* mutationScope() const { return active_mutation_scope; }
  void ClearMutationScope();

  FORCE_INLINE Global* global() const { return global_; }
  IsolateCommandBuffer isolate_command_buffer_{this};
  FORCE_INLINE DartIsolateContext* dartIsolateContext() const { return dart_isolate_context_; };
  FORCE_INLINE const std::unique_ptr<DartMethodPointer>& dartMethodPtr() {
    assert(dart_isolate_context_->valid());
    return dart_isolate_context_->dartMethodPtr();
  }
  FORCE_INLINE std::chrono::time_point<std::chrono::system_clock> timeOrigin() const { return time_origin_; }

  FORCE_INLINE IsolateCommandBuffer* isolateCommandBuffer() { return &isolate_command_buffer_; };

  void FlushIsolateCommand();

  void DispatchErrorEvent(ErrorEvent* error_event);
  void DispatchErrorEventInterval(ErrorEvent* error_event);
  void ReportErrorEvent(ErrorEvent* error_event);

  static void DispatchGlobalUnhandledRejectionEvent(ExecutingContext* context,
                                                    JSValueConst promise,
                                                    JSValueConst error);
  static void DispatchGlobalRejectionHandledEvent(ExecutingContext* context, JSValueConst promise, JSValueConst error);
  static void DispatchGlobalErrorEvent(ExecutingContext* context, JSValueConst error);

  // Bytecodes which registered by mercury plugins.
  static std::unordered_map<std::string, NativeByteCode> plugin_byte_code;
  // Raw string codes which registered by mercury plugins.
  static std::unordered_map<std::string, std::string> plugin_string_code;

 private:
  std::chrono::time_point<std::chrono::system_clock> time_origin_;
  int32_t unique_id_;

  static void promiseRejectTracker(JSContext* ctx,
                                   JSValueConst promise,
                                   JSValueConst reason,
                                   JS_BOOL is_handled,
                                   void* opaque);
  DartIsolateContext* dart_isolate_context_{nullptr};
  // Keep mainCommandBuffer above ScriptState to make sure we can collect all disposedEventTarget command when free
  // JSContext. When call JSFreeContext(ctx) inside ScriptState, all eventTargets will be finalized and MainCommandBuffer
  // will be fill up to MainCommand::disposeEventTarget commands.
  // ----------------------------------------------------------------------
  // All members above ScriptState will be freed after ScriptState freed
  // ----------------------------------------------------------------------
  ScriptState script_state_{dart_isolate_context_};
  // ----------------------------------------------------------------------
  // All members below will be free before ScriptState freed.
  // ----------------------------------------------------------------------
  bool is_context_valid_{false};
  int32_t context_id_;
  JSExceptionHandler handler_;
  void* owner_;
  JSValue global_object_{JS_NULL};
  Global* global_{nullptr};
  TimerCoordinator timers_;
  ModuleListenerContainer module_listener_container_;
  ModuleContextCoordinator module_contexts_;
  ExecutionContextData context_data_{this};
  bool in_dispatch_error_event_{false};
  RejectedPromises rejected_promises_;
  MemberMutationScope* active_mutation_scope{nullptr};
  std::set<ScriptWrappable*> active_wrappers_;
};

class ObjectProperty {
  MERCURY_DISALLOW_COPY_ASSIGN_AND_MOVE(ObjectProperty);

 public:
  ObjectProperty() = delete;

  // Define an property on object with a JSValue.
  explicit ObjectProperty(ExecutingContext* context, JSValueConst thisObject, const char* property, JSValue value)
      : m_value(value) {
    JS_DefinePropertyValueStr(context->ctx(), thisObject, property, value, JS_PROP_ENUMERABLE);
  }

  JSValue value() const { return m_value; }

 private:
  JSValue m_value{JS_NULL};
};

}  // namespace mercury

#endif  // BRIDGE_JS_CONTEXT_H
