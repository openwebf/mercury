/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef BRIDGE_BINDINGS_QJS_CPPGC_LOCAL_HANDLE_H_
#define BRIDGE_BINDINGS_QJS_CPPGC_LOCAL_HANDLE_H_

#include <quickjs/quickjs.h>
#include <type_traits>
#include "foundation/casting.h"
#include "foundation/macros.h"
#include "mutation_scope.h"

namespace mercury {

template <typename T>
class LocalTrait;
class ScriptWrappable;

/**
 * A stack allocated class which hold object reference temporary.
 */
template <typename T>
class Local {
  MERCURY_STACK_ALLOCATED();

 public:
  static Local<T> Empty() { return Local<T>(nullptr); }

  Local() = delete;
  ~Local();

  inline T* Get() const { return raw_; }

 protected:
  explicit Local(T* p) : raw_(p) {
    static_assert(std::is_base_of<ScriptWrappable, T>::value, "Local-Handle only accept ScriptWrappble params.");
  };

 private:
  T* raw_;
  friend class LocalTrait<T>;
};

template <typename T>
class LocalTrait {
 public:
  template <typename... Args>
  static Local<T> Allocate(Args&&... args) {
    return Local<T>(std::forward<Args>(args)...);
  }

  friend class Local<T>;
};

template <typename T, typename... Args>
Local<T> MakeLocal(Args&&... args) {
  return LocalTrait<T>::Allocate(std::forward<Args>(args)...);
}

}  // namespace mercury

#endif  // BRIDGE_BINDINGS_QJS_CPPGC_LOCAL_HANDLE_H_
