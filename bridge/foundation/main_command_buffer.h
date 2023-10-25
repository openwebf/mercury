/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef BRIDGE_FOUNDATION_UI_COMMAND_BUFFER_H_
#define BRIDGE_FOUNDATION_UI_COMMAND_BUFFER_H_

#include <cinttypes>
#include "bindings/qjs/native_string_utils.h"
#include "native_value.h"

namespace mercury {

class ExecutingContext;

enum class MainCommand {
  kCreateElement,
  kCreateTextNode,
  kCreateComment,
  kCreateDocument,
  kCreateGlobal,
  kDisposeBindingObject,
  kAddEvent,
  kRemoveNode,
  kInsertAdjacentNode,
  kSetStyle,
  kClearStyle,
  kSetAttribute,
  kRemoveAttribute,
  kCloneNode,
  kRemoveEvent,
  kCreateDocumentFragment,
  kCreateSVGElement,
  kCreateElementNS,
};

#define MAXIMUM_UI_COMMAND_SIZE 2048

struct MainCommandItem {
  MainCommandItem() = default;
  explicit MainCommandItem(int32_t type, SharedNativeString* args_01, void* nativePtr, void* nativePtr2)
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

class MainCommandBuffer {
 public:
  MainCommandBuffer() = delete;
  explicit MainCommandBuffer(ExecutingContext* context);
  ~MainCommandBuffer();
  void addCommand(MainCommand type,
                  std::unique_ptr<SharedNativeString>&& args_01,
                  void* nativePtr,
                  void* nativePtr2,
                  bool request_ui_update = true);
  MainCommandItem* data();
  int64_t size();
  bool empty();
  void clear();

 private:
  void addCommand(const MainCommandItem& item, bool request_ui_update = true);

  ExecutingContext* context_{nullptr};
  MainCommandItem* buffer_{nullptr};
  bool update_batched_{false};
  int64_t size_{0};
  int64_t max_size_{MAXIMUM_UI_COMMAND_SIZE};
};

}  // namespace mercury

#endif  // BRIDGE_FOUNDATION_UI_COMMAND_BUFFER_H_
