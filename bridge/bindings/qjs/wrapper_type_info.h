/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
#ifndef BRIDGE_WRAPPER_TYPE_INFO_H
#define BRIDGE_WRAPPER_TYPE_INFO_H

#include <quickjs/quickjs.h>
#include <cassert>
#include "bindings/qjs/qjs_engine_patch.h"

namespace mercury {

class EventTarget;
class TouchList;

// Define all built-in wrapper class id.
enum {
  JS_CLASS_GC_TRACKER = JS_CLASS_INIT_COUNT + 1,
  JS_CLASS_EVENT,
  JS_CLASS_ERROR_EVENT,
  JS_CLASS_MESSAGE_EVENT,
  JS_CLASS_LOAD_EVENT,
  JS_CLASS_CLOSE_EVENT,
  JS_CLASS_CUSTOM_EVENT,
  JS_CLASS_PROMISE_REJECTION_EVENT,
  JS_CLASS_EVENT_TARGET,
  JS_CLASS_GLOBAL,

  JS_CLASS_CUSTOM_CLASS_INIT_COUNT /* last entry for predefined classes */
};

// Callback when get property using index.
// exp: obj[0]
using IndexedPropertyGetterHandler = JSValue (*)(JSContext* ctx, JSValue obj, uint32_t index);

// Callback when get property using string or symbol.
// exp: obj['hello']
using StringPropertyGetterHandler = JSValue (*)(JSContext* ctx, JSValue obj, JSAtom atom);

// Callback when set property using index.
// exp: obj[0] = value;
using IndexedPropertySetterHandler = bool (*)(JSContext* ctx, JSValueConst obj, uint32_t index, JSValueConst value);

// Callback when set property using string or symbol.
// exp: obj['hello'] = value;
using StringPropertySetterHandler = bool (*)(JSContext* ctx, JSValueConst obj, JSAtom atom, JSValueConst value);

// Callback when delete property using string or symbol.
// exp: delete obj['hello']
using StringPropertyDeleteHandler = bool (*)(JSContext* ctx, JSValueConst obj, JSAtom prop);

// Callback when check property exist on object.
// exp: 'hello' in obj;
using PropertyCheckerHandler = bool (*)(JSContext* ctx, JSValueConst obj, JSAtom atom);

// Callback when enums all property on object.
// exp: Object.keys(obj);
using PropertyEnumerateHandler = int (*)(JSContext* ctx, JSPropertyEnum** ptab, uint32_t* plen, JSValueConst obj);

// This struct provides a way to store a bunch of information that is helpful
// when creating quickjs objects. Each quickjs bindings class has exactly one static
// WrapperTypeInfo member, so comparing pointers is a safe way to determine if
// types match.
class WrapperTypeInfo final {
 public:
  bool equals(const WrapperTypeInfo* that) const { return this == that; }

  bool isSubclass(const WrapperTypeInfo* that) const {
    for (const WrapperTypeInfo* current = this; current; current = current->parent_class) {
      if (current == that)
        return true;
    }
    return false;
  }

  JSClassID classId{0};
  const char* className{nullptr};
  const WrapperTypeInfo* parent_class{nullptr};
  JSClassCall* callFunc{nullptr};
  IndexedPropertyGetterHandler indexed_property_getter_handler_{nullptr};
  IndexedPropertySetterHandler indexed_property_setter_handler_{nullptr};
  StringPropertyGetterHandler string_property_getter_handler_{nullptr};
  StringPropertySetterHandler string_property_setter_handler_{nullptr};
  PropertyCheckerHandler property_checker_handler_{nullptr};
  PropertyEnumerateHandler property_enumerate_handler_{nullptr};
  StringPropertyDeleteHandler property_delete_handler_{nullptr};
};

}  // namespace mercury

#endif  // BRIDGE_WRAPPER_TYPE_INFO_H
