/*
 * Copyright (C) 2019-2022 The Kraken authors. All rights reserved.
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#include "isolate_command_buffer.h"
#include "core/dart_methods.h"
#include "core/executing_context.h"
#include "foundation/logging.h"
#include "include/mercury_bridge.h"

namespace mercury {

IsolateCommandBuffer::IsolateCommandBuffer(ExecutingContext* context)
    : context_(context), buffer_((IsolateCommandItem*)malloc(sizeof(IsolateCommandItem) * MAXIMUM_ISOLATE_COMMAND_SIZE)) {}

IsolateCommandBuffer::~IsolateCommandBuffer() {
  free(buffer_);
}

void IsolateCommandBuffer::addCommand(IsolateCommand type,
                                 std::unique_ptr<SharedNativeString>&& args_01,
                                 void* nativePtr,
                                 void* nativePtr2,
                                 bool request_isolate_update) {
  IsolateCommandItem item{static_cast<int32_t>(type), args_01.get(), nativePtr, nativePtr2};
  addCommand(item, request_isolate_update);
}

void IsolateCommandBuffer::addCommand(const IsolateCommandItem& item, bool request_isolate_update) {
  if (UNLIKELY(!context_->dartIsolateContext()->valid())) {
    return;
  }

  if (size_ >= max_size_) {
    buffer_ = (IsolateCommandItem*)realloc(buffer_, sizeof(IsolateCommandItem) * max_size_ * 2);
    max_size_ = max_size_ * 2;
  }

#if FLUTTER_BACKEND
  if (UNLIKELY(request_isolate_update && !update_batched_ && context_->IsContextValid() &&
               context_->dartMethodPtr()->requestBatchUpdate != nullptr)) {
    context_->dartMethodPtr()->requestBatchUpdate(context_->contextId());
    update_batched_ = true;
  }
#endif

  buffer_[size_] = item;
  size_++;
}

IsolateCommandItem* IsolateCommandBuffer::data() {
  return buffer_;
}

int64_t IsolateCommandBuffer::size() {
  return size_;
}

bool IsolateCommandBuffer::empty() {
  return size_ == 0;
}

void IsolateCommandBuffer::clear() {
  size_ = 0;
  memset(buffer_, 0, sizeof(buffer_));
  update_batched_ = false;
}

}  // namespace mercury
