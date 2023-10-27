/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
#ifndef BRIDGE_GLOBAL_H
#define BRIDGE_GLOBAL_H

#include "bindings/qjs/atomic_string.h"
#include "bindings/qjs/wrapper_type_info.h"
#include "core/event/event_target.h"
#include "foundation/isolate_command_buffer.h"
#include "global_event_handlers.h"

namespace mercury {

class Global : public EventTargetWithInlineData {
  DEFINE_WRAPPERTYPEINFO();

 public:
  Global() = delete;
  Global(ExecutingContext* context);

  Global* open(ExceptionState& exception_state);
  Global* open(const AtomicString& url, ExceptionState& exception_state);

  [[nodiscard]] const Global* global() const { return this; }
  [[nodiscard]] const Global* self() const { return this; }
  [[nodiscard]] const Global* parent() const { return this; }

  AtomicString btoa(const AtomicString& source, ExceptionState& exception_state);
  AtomicString atob(const AtomicString& source, ExceptionState& exception_state);

  void postMessage(const ScriptValue& message, ExceptionState& exception_state);
  void postMessage(const ScriptValue& message, const AtomicString& target_origin, ExceptionState& exception_state);

  double requestAnimationFrame(const std::shared_ptr<QJSFunction>& callback, ExceptionState& exceptionState);
  void cancelAnimationFrame(double request_id, ExceptionState& exception_state);

  bool IsGlobalOrWorkerScope() const override;

  void Trace(GCVisitor* visitor) const override;

  // Override default ToQuickJS() to return Global object when access `global` property.
  JSValue ToQuickJS() const override;
};

template <>
struct DowncastTraits<Global> {
  static bool AllowFrom(const EventTarget& event_target) { return event_target.IsGlobalOrWorkerScope(); }
  static bool AllowFrom(const BindingObject& binding_object) {
    return binding_object.IsEventTarget() && DynamicTo<EventTarget>(binding_object)->IsGlobalOrWorkerScope();
  }
};

}  // namespace mercury

#endif  // BRIDGE_GLOBAL_H
