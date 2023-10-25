/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#include "main_command_buffer.h"
#include "core/dart_methods.h"
#include "core/executing_context.h"
#include "foundation/logging.h"
#include "include/mercury_bridge.h"

namespace mercury {

MainCommandBuffer::MainCommandBuffer(ExecutingContext* context)
    : context_(context), buffer_((MainCommandItem*)malloc(sizeof(MainCommandItem) * MAXIMUM_UI_COMMAND_SIZE)) {}

MainCommandBuffer::~MainCommandBuffer() {
  free(buffer_);
}

void MainCommandBuffer::addCommand(MainCommand type,
                                 std::unique_ptr<SharedNativeString>&& args_01,
                                 void* nativePtr,
                                 void* nativePtr2,
                                 bool request_ui_update) {
  MainCommandItem item{static_cast<int32_t>(type), args_01.get(), nativePtr, nativePtr2};
  addCommand(item, request_ui_update);
}

void MainCommandBuffer::addCommand(const MainCommandItem& item, bool request_ui_update) {
  if (UNLIKELY(!context_->dartIsolateContext()->valid())) {
    return;
  }

  if (size_ >= max_size_) {
    buffer_ = (MainCommandItem*)realloc(buffer_, sizeof(MainCommandItem) * max_size_ * 2);
    max_size_ = max_size_ * 2;
  }

#if FLUTTER_BACKEND
  if (UNLIKELY(request_ui_update && !update_batched_ && context_->IsContextValid() &&
               context_->dartMethodPtr()->requestBatchUpdate != nullptr)) {
    context_->dartMethodPtr()->requestBatchUpdate(context_->contextId());
    update_batched_ = true;
  }
#endif

  buffer_[size_] = item;
  size_++;
}

MainCommandItem* MainCommandBuffer::data() {
  return buffer_;
}

int64_t MainCommandBuffer::size() {
  return size_;
}

bool MainCommandBuffer::empty() {
  return size_ == 0;
}

void MainCommandBuffer::clear() {
  size_ = 0;
  memset(buffer_, 0, sizeof(buffer_));
  update_batched_ = false;
}

}  // namespace mercury
