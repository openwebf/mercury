/*
* Copyright (C) 2022-present The WebF authors. All rights reserved.
*/

#ifndef MERCURY_DART_READABLE_H
#define MERCURY_DART_READABLE_H

#include <cstddef>

namespace mercury {

void* dart_malloc(std::size_t size);
void dart_free(void* ptr);

// Shared C struct which can be read by dart through Dart FFI.
struct DartReadable {
  // Dart FFI use ole32 as it's allocator, we need to override the default allocator to compact with Dart FFI.
  static void* operator new(std::size_t size);
  static void operator delete(void* memory) noexcept;
};

}

#endif  // MERCURY_DART_READABLE_H
