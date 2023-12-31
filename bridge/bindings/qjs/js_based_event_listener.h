/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef BRIDGE_BINDINGS_QJS_JS_BASED_EVENT_LISTENER_H_
#define BRIDGE_BINDINGS_QJS_JS_BASED_EVENT_LISTENER_H_

#include <quickjs/quickjs.h>
#include "core/event/event_listener.h"
#include "core/executing_context.h"
#include "foundation/casting.h"

namespace mercury {

// |JSBasedEventListener| is the base class for JS-based event listeners,
// i.e. EventListener and EventHandler in the standards.
// This provides the essential APIs of JS-based event listeners and also
// implements the common features.
class JSBasedEventListener : public EventListener {
 public:
  // Implements step 2. of "inner invoke".
  // See: https://dom.spec.whatwg.org/#concept-event-listener-inner-invoke
  void Invoke(ExecutingContext* context, Event* event, ExceptionState& exception_state) override;

  // Implements "get the current value of the event handler".
  // https://html.spec.whatwg.org/C/#getting-the-current-value-of-the-event-handler
  // Returns v8::Null with firing error event instead of throwing an exception
  // on failing to compile the uncompiled script body in eventHandler's value.
  // Also, this can return empty because of crbug.com/881688 .
  virtual JSValue GetListenerObject() = 0;

  bool IsJSBasedEventListener() const override { return true; }
  virtual bool IsJSEventListener() const { return false; }
  virtual bool IsJSEventHandler() const { return false; }

 protected:
  JSBasedEventListener();

 private:
  // Performs "call a user object's operation", required in "inner-invoke".
  // "The event handler processing algorithm" corresponds to this in the case of
  // EventHandler.
  // This may throw an exception on invoking the listener.
  // See step 2-10:
  // https://dom.spec.whatwg.org/#concept-event-listener-inner-invoke
  virtual void InvokeInternal(EventTarget&, Event&, ExceptionState& exception_state) = 0;
};

template <>
struct DowncastTraits<JSBasedEventListener> {
  static bool AllowFrom(const EventListener& event_listener) { return event_listener.IsJSBasedEventListener(); }
};

}  // namespace mercury

#endif  // BRIDGE_BINDINGS_QJS_JS_BASED_EVENT_LISTENER_H_
