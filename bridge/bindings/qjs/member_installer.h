/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef BRIDGE_MEMBER_INSTALLER_H
#define BRIDGE_MEMBER_INSTALLER_H

#include <quickjs/quickjs.h>
#include <initializer_list>

namespace mercury {

class ExecutingContext;

// Flags for object properties.
enum JSPropFlag {
  normal = JS_PROP_NORMAL,
  writable = JS_PROP_WRITABLE,
  enumerable = JS_PROP_ENUMERABLE,
  configurable = JS_PROP_CONFIGURABLE
};

// Combine multiple prop flags.
int combinePropFlags(JSPropFlag a, JSPropFlag b);
int combinePropFlags(JSPropFlag a, JSPropFlag b, JSPropFlag c);

// A set of utility functions to define attributes members as ES properties.
class MemberInstaller {
 public:
  struct AttributeConfig {
    AttributeConfig& operator=(const AttributeConfig&) = delete;
    JSAtom key;
    JSCFunction* getter{nullptr};
    JSCFunction* setter{nullptr};
    JSValue value{JS_NULL};
    int flag{JS_PROP_C_W_E};  // Flags for object properties.
  };

  struct FunctionConfig {
    FunctionConfig& operator=(const FunctionConfig&) = delete;
    const char* name;
    JSCFunction* function;
    size_t length;
    int flag{JS_PROP_C_W_E};  // Flags for object properties.
  };

  static void InstallAttributes(ExecutingContext* context, JSValue root, std::initializer_list<AttributeConfig> config);
  static void InstallFunctions(ExecutingContext* context, JSValue root, std::initializer_list<FunctionConfig> config);
};

}  // namespace mercury

#endif  // BRIDGE_MEMBER_INSTALLER_H
