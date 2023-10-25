/*
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef BRIDGE_CORE_MODULE_GLOBAL_EVENT_HANDLERS_H_
#define BRIDGE_CORE_MODULE_GLOBAL_EVENT_HANDLERS_H_

#include "event_type_names.h"
#include "foundation/macros.h"

namespace mercury {

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
