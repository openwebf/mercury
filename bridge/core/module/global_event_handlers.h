/*
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef BRIDGE_CORE_MODULE_GLOBAL_EVENT_HANDLERS_H_
#define BRIDGE_CORE_MODULE_GLOBAL_EVENT_HANDLERS_H_

#include "core/event/event_target.h"
#include "event_type_names.h"
#include "foundation/macros.h"

namespace mercury {

#define DEFINE_STATIC_GLOBAL_ATTRIBUTE_EVENT_LISTENER(lower_name, symbol_name)                            \
  static std::shared_ptr<EventListener> on##lower_name(EventTarget& eventTarget) {                        \
    return eventTarget.GetAttributeEventListener(event_type_names::symbol_name);                          \
  }                                                                                                       \
  static void setOn##lower_name(EventTarget& eventTarget, const std::shared_ptr<EventListener>& listener, \
                                ExceptionState& exception_state) {                                        \
    eventTarget.SetAttributeEventListener(event_type_names::symbol_name, listener, exception_state);      \
  }

class GlobalEventHandlers {
  MERCURY_STATIC_ONLY(GlobalEventHandlers);

 public:
  DEFINE_STATIC_GLOBAL_ATTRIBUTE_EVENT_LISTENER(message, kmessage);
  DEFINE_STATIC_GLOBAL_ATTRIBUTE_EVENT_LISTENER(messageerror, kmessageerror);
  DEFINE_STATIC_GLOBAL_ATTRIBUTE_EVENT_LISTENER(rejectionhandled, krejectionhandled);
  DEFINE_STATIC_GLOBAL_ATTRIBUTE_EVENT_LISTENER(unhandledrejection, kunhandledrejection);
};

}  // namespace mercury

#endif  // BRIDGE_CORE_FRAME_GLOBAL_EVENT_HANDLERS_H_
