/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef BRIDGE_FOUNDATION_ISOLATE_COMMAND_BUFFER_H_
#define BRIDGE_FOUNDATION_ISOLATE_COMMAND_BUFFER_H_

#include <cinttypes>
#include "bindings/qjs/native_string_utils.h"
#include "native_value.h"

namespace mercury {

class ExecutingContext;

enum class IsolateCommand {
  kCreateGlobal,
  kDisposeBindingObject,
  kAddEvent,
  kRemoveEvent,
};

#define MAXIMUM_ISOLATE_COMMAND_SIZE 2048

struct IsolateCommandItem {
  IsolateCommandItem() = default;
  explicit IsolateCommandItem(int32_t type, SharedNativeString* args_01, void* nativePtr, void* nativePtr2)
      : type(type),
        string_01(reinterpret_cast<int64_t>(args_01 != nullptr ? args_01->string() : nullptr)),
        args_01_length(args_01 != nullptr ? args_01->length() : 0),
        nativePtr(reinterpret_cast<int64_t>(nativePtr)),
        nativePtr2(reinterpret_cast<int64_t>(nativePtr2)){};
  int32_t type{0};
  int32_t args_01_length{0};
  int64_t string_01{0};
  int64_t nativePtr{0};
  int64_t nativePtr2{0};
};

class IsolateCommandBuffer {
 public:
  IsolateCommandBuffer() = delete;
  explicit IsolateCommandBuffer(ExecutingContext* context);
  ~IsolateCommandBuffer();
  void addCommand(IsolateCommand type,
                  std::unique_ptr<SharedNativeString>&& args_01,
                  void* nativePtr,
                  void* nativePtr2,
                  bool request_isolate_update = true);
  IsolateCommandItem* data();
  int64_t size();
  bool empty();
  void clear();

 private:
  void addCommand(const IsolateCommandItem& item, bool request_isolate_update = true);

  ExecutingContext* context_{nullptr};
  IsolateCommandItem* buffer_{nullptr};
  bool update_batched_{false};
  int64_t size_{0};
  int64_t max_size_{MAXIMUM_ISOLATE_COMMAND_SIZE};
};

}  // namespace mercury

#endif  // BRIDGE_FOUNDATION_Isolate_COMMAND_BUFFER_H_
