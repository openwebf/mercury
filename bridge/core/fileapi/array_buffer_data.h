/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */
#ifndef BRIDGE_CORE_FILEAPI_ARRAY_BUFFER_DATA_H_
#define BRIDGE_CORE_FILEAPI_ARRAY_BUFFER_DATA_H_

#include <cstdint>

namespace mercury {

struct ArrayBufferData {
  uint8_t* buffer;
  int32_t length;
};

}  // namespace mercury

#endif  // BRIDGE_CORE_FILEAPI_ARRAY_BUFFER_DATA_H_
