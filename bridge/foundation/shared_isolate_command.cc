/*
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#include "shared_isolate_command.h"
#include "core/executing_context.h"
#include "foundation/logging.h"
#include "isolate_command_buffer.h"

namespace mercury {

SharedIsolateCommand::SharedIsolateCommand(ExecutingContext* context)
    : context_(context),
      active_buffer(std::make_unique<IsolateCommandBuffer>(context)),
      reserve_buffer_(std::make_unique<IsolateCommandBuffer>(context)),
      waiting_buffer_(std::make_unique<IsolateCommandBuffer>(context)),
      isolate_command_sync_strategy_(std::make_unique<IsolateCommandSyncStrategy>(this)),
      is_blocking_writing_(false) {}

void SharedIsolateCommand::AddCommand(IsolateCommand type,
                                 std::unique_ptr<SharedNativeString>&& args_01,
                                 NativeBindingObject* native_binding_object,
                                 void* nativePtr2,
                                 bool request_isolate_update) {
  if (!context_->isDedicated()) {
    active_buffer->addCommand(type, std::move(args_01), native_binding_object, nativePtr2, request_isolate_update);
    return;
  }

  if (type == IsolateCommand::kFinishRecordingCommand || isolate_command_sync_strategy_->ShouldSync()) {
    SyncToActive();
  }

  isolate_command_sync_strategy_->RecordIsolateCommand(type, args_01, native_binding_object, nativePtr2, request_isolate_update);
}

// first called by dart to being read commands.
void* SharedIsolateCommand::data() {
  // simply spin wait for the swapBuffers to finish.
  while (is_blocking_writing_.load(std::memory_order::memory_order_acquire)) {
  }

  return active_buffer->data();
}

uint32_t SharedIsolateCommand::kindFlag() {
  return active_buffer->kindFlag();
}

// second called by dart to get the size of commands.
int64_t SharedIsolateCommand::size() {
  return active_buffer->size();
}

// third called by dart to clear commands.
void SharedIsolateCommand::clear() {
  active_buffer->clear();
}

// called by c++ to check if there are commands.
bool SharedIsolateCommand::empty() {
  if (context_->isDedicated()) {
    return reserve_buffer_->empty() && waiting_buffer_->empty();
  }

  return active_buffer->empty();
}

void SharedIsolateCommand::SyncToReserve() {
  if (waiting_buffer_->empty())
    return;

  size_t waiting_size = waiting_buffer_->size();
  size_t origin_reserve_size = reserve_buffer_->size();

  if (reserve_buffer_->empty()) {
    swap(reserve_buffer_, waiting_buffer_);
  } else {
    appendCommand(reserve_buffer_, waiting_buffer_);
  }

  assert(waiting_buffer_->empty());
  assert(reserve_buffer_->size() == waiting_size + origin_reserve_size);
}

void SharedIsolateCommand::ConfigureSyncCommandBufferSize(size_t size) {
  isolate_command_sync_strategy_->ConfigWaitingBufferSize(size);
}

void SharedIsolateCommand::SyncToActive() {
  SyncToReserve();

  assert(waiting_buffer_->empty());

  if (reserve_buffer_->empty())
    return;

  isolate_command_sync_strategy_->Reset();
  context_->dartMethodPtr()->requestBatchUpdate(context_->isDedicated(), context_->contextId());

  size_t reserve_size = reserve_buffer_->size();
  size_t origin_active_size = active_buffer->size();
  appendCommand(active_buffer, reserve_buffer_);
  assert(reserve_buffer_->empty());
  assert(active_buffer->size() == reserve_size + origin_active_size);
}

void SharedIsolateCommand::swap(std::unique_ptr<IsolateCommandBuffer>& target, std::unique_ptr<IsolateCommandBuffer>& original) {
  is_blocking_writing_.store(true, std::memory_order::memory_order_release);
  std::swap(target, original);
  is_blocking_writing_.store(false, std::memory_order::memory_order_release);
}

void SharedIsolateCommand::appendCommand(std::unique_ptr<IsolateCommandBuffer>& target,
                                    std::unique_ptr<IsolateCommandBuffer>& original) {
  is_blocking_writing_.store(true, std::memory_order::memory_order_release);

  IsolateCommandItem* command_item = original->data();
  target->addCommands(command_item, original->size());

  original->clear();

  is_blocking_writing_.store(false, std::memory_order::memory_order_release);
}

}  // namespace mercury
