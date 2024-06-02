/*
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#include "isolate_command_strategy.h"
#include <math.h>
#include "core/binding_object.h"
#include "logging.h"
#include "shared_isolate_command.h"

namespace mercury {

static uint64_t set_nth_bit_to_zero(uint64_t source, size_t nth) {
  uint64_t bitmask = ~(1ULL << nth);
  return source & bitmask;
}

uint64_t WaitingStatus::MaxSize() {
  return 64 * storage.size();
}

void WaitingStatus::Reset() {
  for (auto& i : storage) {
    i = IsolateNT64_MAX;
  }
}

bool WaitingStatus::IsFullActive() {
  return std::all_of(storage.begin(), storage.end(), [](uint64_t i) { return i == 0; });
}

void WaitingStatus::SetActiveAtIndex(uint64_t index) {
  size_t storage_index = floor(index / 64);

  if (storage_index < storage.size()) {
    storage[storage_index] = set_nth_bit_to_zero(storage[storage_index], index % 64);
  }
}

IsolateCommandSyncStrategy::IsolateCommandSyncStrategy(SharedIsolateCommand* host) : host_(host) {}

bool IsolateCommandSyncStrategy::ShouldSync() {
  return should_sync;
}

void IsolateCommandSyncStrategy::Reset() {
  should_sync = false;
  waiting_status.Reset();
  frequency_map_.clear();
}
void IsolateCommandSyncStrategy::RecordIsolateCommand(IsolateCommand type,
                                            std::unique_ptr<SharedNativeString>& args_01,
                                            NativeBindingObject* native_binding_object,
                                            void* native_ptr2,
                                            bool request_isolate_update) {
  switch (type) {
    // prof: case IsolateCommand::kStartRecordingCommand:
    case IsolateCommand::kCreateGlobal:
    case IsolateCommand::kRemoveEvent:
    case IsolateCommand::kAddEvent:
    case IsolateCommand::kDisposeBindingObject: {
      host_->waiting_buffer_->addCommand(type, std::move(args_01), native_binding_object, native_ptr2,
                                         request_isolate_update);
      break;
    }
    // prof: case IsolateCommand::kFinishRecordingCommand:
    // prof:   break;
  }
}

void IsolateCommandSyncStrategy::ConfigWaitingBufferSize(size_t size) {
  waiting_status.storage.reserve(size);
  for (int i = 0; i < size; i++) {
    waiting_status.storage.emplace_back(IsolateNT64_MAX);
  }
}

void IsolateCommandSyncStrategy::SyncToReserve() {
  host_->SyncToReserve();
  waiting_status.Reset();
  frequency_map_.clear();
  should_sync = true;
}

void IsolateCommandSyncStrategy::SyncToReserveIfNecessary() {
  if (frequency_map_.size() > waiting_status.MaxSize() && waiting_status.IsFullActive()) {
    SyncToReserve();
  }
}

void IsolateCommandSyncStrategy::RecordOperationForPointer(NativeBindingObject* ptr) {
  size_t index;
  if (frequency_map_.count(ptr) == 0) {
    index = frequency_map_.size();

    // Store the bit wise index for ptr.
    frequency_map_[ptr] = index;
  } else {
    index = frequency_map_[ptr];
  }

  // Update flag's nth bit wise to 0
  waiting_status.SetActiveAtIndex(index);

  SyncToReserveIfNecessary();
}

}  // namespace mercury
