/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#include "binding_initializer.h"
#include "core/executing_context.h"

#include "qjs_blob.h"
#include "qjs_close_event.h"
#include "qjs_console.h"
#include "qjs_custom_event.h"
#include "qjs_error_event.h"
#include "qjs_event.h"
#include "qjs_event_target.h"
#include "qjs_message_event.h"
#include "qjs_module_manager.h"
#include "qjs_promise_rejection_event.h"
#include "qjs_global.h"
#include "qjs_global_or_worker_scope.h"

namespace mercury {

void InstallBindings(ExecutingContext* context) {
  // Must follow the inheritance order when install.
  // Exp: Node extends EventTarget, EventTarget must be install first.
  QJSGlobalOrWorkerScope::Install(context);
  QJSModuleManager::Install(context);
  QJSConsole::Install(context);
  QJSEventTarget::Install(context);
  QJSGlobal::Install(context);
  QJSEvent::Install(context);
  QJSErrorEvent::Install(context);
  QJSBlob::Install(context);
  QJSPromiseRejectionEvent::Install(context);
  QJSMessageEvent::Install(context);
  QJSCloseEvent::Install(context);
  QJSCustomEvent::Install(context);
}

}  // namespace mercury
