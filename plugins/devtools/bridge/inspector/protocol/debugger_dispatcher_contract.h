/*
 * Copyright (C) 2020-present The Kraken authors. All rights reserved.
 */

#ifndef KRAKEN_DEBUGGER_DEBUG_DISPATCHER_CONTRACT_H
#define KRAKEN_DEBUGGER_DEBUG_DISPATCHER_CONTRACT_H

#include "inspector/protocol/debugger_backend.h"
#include "inspector/protocol/uber_dispatcher.h"

namespace kraken {
namespace debugger {
class DebuggerDispatcherContract {
public:
  static void wire(UberDispatcher *, DebuggerBackend *);

private:
  DebuggerDispatcherContract() {}
};
} // namespace debugger
} // namespace kraken

#endif // KRAKEN_DEBUGGER_DEBUG_DISPATCHER_CONTRACT_H
