/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef MERCURY_BINDINGS_QJS_UNION_BASE_H_
#define MERCURY_BINDINGS_QJS_UNION_BASE_H_

#include <quickjs/quickjs.h>
#include "bindings/qjs/cppgc/trace_if_needed.h"
#include "exception_state.h"

namespace mercury {

class GCVisitor;

class UnionBase {
 public:
  virtual ~UnionBase() = default;
  virtual JSValue ToQuickJSValue(JSContext* ctx, ExceptionState& exception_state) const = 0;
  virtual void Trace(GCVisitor* visitor) const = 0;
};

}  // namespace mercury

#endif  // MERCURY_BINDINGS_QJS_UNION_BASE_H_
