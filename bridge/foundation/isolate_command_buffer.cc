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

IsolateCommandKind GetKindFromIsolateCommand(IsolateCommand command) {
  switch (command) {
    case IsolateCommand::kCreateGlobal:
    case IsolateCommand::kAddEvent:
    case IsolateCommand::kRemoveEvent:
      return IsolateCommandKind::kEvent;
    case IsolateCommand::kDisposeBindingObject:
      return IsolateCommandKind::kDisposeBindingObject;
    // prof: case IsolateCommand::kStartRecordingCommand:
    // prof: case IsolateCommand::kFinishRecordingCommand:
    // prof:   return IsolateCommandKind::kOperation;
  }
}

IsolateCommandBuffer::IsolateCommandBuffer(ExecutingContext* context)
    : context_(context), buffer_((IsolateCommandItem*)malloc(sizeof(IsolateCommandItem) * MAXIMUM_ISOLATE_COMMAND_SIZE)) {}

IsolateCommandBuffer::~IsolateCommandBuffer() {
  free(buffer_);
}

void IsolateCommandBuffer::addCommand(IsolateCommand command,
                                 std::unique_ptr<SharedNativeString>&& args_01,
                                 void* nativePtr,
                                 void* nativePtr2,
                                 bool request_isolate_update) {
  IsolateCommandItem item{static_cast<int32_t>(command), args_01.get(), nativePtr, nativePtr2};
  updateFlags(command);
  addCommand(item, request_isolate_update);
}

void IsolateCommandBuffer::updateFlags(IsolateCommand command) {
  IsolateCommandKind type = GetKindFromIsolateCommand(command);
  kind_flag = kind_flag | type;
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
  if (UNLIKELY(request_isolate_update && !update_batched_ && context_->IsContextValid())) {
    context_->dartMethodPtr()->requestBatchUpdate(context_->isDedicated(), context_->contextId());
    update_batched_ = true;
  }
#endif

  buffer_[size_] = item;
  size_++;
}

void IsolateCommandBuffer::addCommands(const mercury::IsolateCommandItem* items, int64_t item_size, bool request_isolate_update) {
  if (UNLIKELY(!context_->dartIsolateContext()->valid())) {
    return;
  }

  int64_t target_size = size_ + item_size;
  if (target_size > max_size_) {
    buffer_ = (IsolateCommandItem*)realloc(buffer_, sizeof(IsolateCommandItem) * target_size * 2);
    max_size_ = target_size * 2;
  }

#if FLUTTER_BACKEND
  if (UNLIKELY(request_isolate_update && !update_batched_ && context_->IsContextValid())) {
    context_->dartMethodPtr()->requestBatchUpdate(context_->isDedicated(), context_->contextId());
    update_batched_ = true;
  }
#endif

  std::memcpy(buffer_ + size_, items, sizeof(IsolateCommandItem) * item_size);
  size_ = target_size;
}

IsolateCommandItem* IsolateCommandBuffer::data() {
  return buffer_;
}

uint32_t IsolateCommandBuffer::kindFlag() {
  return kind_flag;
}

int64_t IsolateCommandBuffer::size() {
  return size_;
}

bool IsolateCommandBuffer::empty() {
  return size_ == 0;
}

void IsolateCommandBuffer::clear() {
  memset(buffer_, 0, sizeof(IsolateCommandItem) * size_);
  size_ = 0;
  kind_flag = 0;
  update_batched_ = false;
}

}  // namespace mercury
