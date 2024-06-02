/*
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef MULTI_THREADING_ISOLATE_COMMAND_STRATEGY_H
#define MULTI_THREADING_ISOLATE_COMMAND_STRATEGY_H

#include <unordered_map>
#include <vector>
#include "foundation/isolate_command_buffer.h"

namespace mercury {

class SharedIsolateCommand;
struct SharedNativeString;
struct NativeBindingObject;

struct WaitingStatus {
  std::vector<uint64_t> storage;
  uint64_t MaxSize();
  void Reset();
  bool IsFullActive();
  void SetActiveAtIndex(uint64_t index);
};

class IsolateCommandSyncStrategy {
 public:
  IsolateCommandSyncStrategy(SharedIsolateCommand* shared_isolate_command);

  bool ShouldSync();
  void Reset();
  void RecordIsolateCommand(IsolateCommand type,
                       std::unique_ptr<SharedNativeString>& args_01,
                       NativeBindingObject* native_ptr,
                       void* native_ptr2,
                       bool request_isolate_update);
  void ConfigWaitingBufferSize(size_t size);

 private:
  void SyncToReserve();
  void SyncToReserveIfNecessary();
  void RecordOperationForPointer(NativeBindingObject* ptr);

  bool should_sync{false};
  SharedIsolateCommand* host_;
  WaitingStatus waiting_status;
  size_t sync_buffer_size_;
  std::unordered_map<void*, size_t> frequency_map_;
  friend class SharedIsolateCommand;
};

}  // namespace mercury

#endif  // MULTI_THREADING_ISOLATE_COMMAND_STRATEGY_H
