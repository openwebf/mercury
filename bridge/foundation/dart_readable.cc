/*
* Copyright (C) 2022-present The WebF authors. All rights reserved.
*/

#include "stdlib.h"
#include "dart_readable.h"

#if WIN32
#include <Windows.h>
#endif


namespace mercury {

void* dart_malloc(std::size_t size) {
#if WIN32
  return CoTaskMemAlloc(size);
#else
  return malloc(size);
#endif
}

void dart_free(void* ptr) {
#if WIN32
  return CoTaskMemFree(ptr);
#else
  return free(ptr);
#endif
}

void* DartReadable::operator new(std::size_t size) {
  return dart_malloc(size);
}

void DartReadable::operator delete(void* memory) noexcept {
  dart_free(memory);
}


}
