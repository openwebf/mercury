/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
#ifndef KRAKE_CONSOLE_H
#define KRAKE_CONSOLE_H

#include "bindings/qjs/atomic_string.h"
#include "bindings/qjs/script_value.h"
#include "core/executing_context.h"

namespace mercury {

class Console final {
 public:
  static void __mercury_print__(ExecutingContext* context,
                             const AtomicString& log,
                             const AtomicString& level,
                             ExceptionState& exception);
  static void __mercury_print__(ExecutingContext* context, const AtomicString& log, ExceptionState& exception_state);
  static bool __mercury_is_proxy__(ExecutingContext* context, const ScriptValue& log, ExceptionState& exception_state);
};

}  // namespace mercury

#endif  // KRAKE_CONSOLE_H
