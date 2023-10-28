/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#include "dart_methods.h"
#include <cassert>

namespace mercury {

mercury::DartMethodPointer::DartMethodPointer(const uint64_t* dart_methods, int32_t dart_methods_length) {
  size_t i = 0;
  invokeModule = reinterpret_cast<InvokeModule>(dart_methods[i++]);
  reloadApp = reinterpret_cast<ReloadApp>(dart_methods[i++]);
  setTimeout = reinterpret_cast<SetTimeout>(dart_methods[i++]);
  setInterval = reinterpret_cast<SetInterval>(dart_methods[i++]);
  clearTimeout = reinterpret_cast<ClearTimeout>(dart_methods[i++]);
  flushIsolateCommand = reinterpret_cast<FlushIsolateCommand>(dart_methods[i++]);
  create_binding_object = reinterpret_cast<CreateBindingObject>(dart_methods[i++]);

  onJsError = reinterpret_cast<OnJSError>(dart_methods[i++]);
  onJsLog = reinterpret_cast<OnJSLog>(dart_methods[i++]);

  assert_m(i == dart_methods_length, "Dart native methods count is not equal with C++ side method registrations.");
}
}  // namespace mercury
