/*
 * Copyright (C) 2022-present The WebF authors. All rights reserved.
 */

#ifndef MULTI_THREADING_ISOLATE_COMMAND_H_
#define MULTI_THREADING_ISOLATE_COMMAND_H_

#include <atomic>
#include <memory>
#include "foundation/native_type.h"
#include "foundation/isolate_command_buffer.h"
#include "foundation/isolate_command_strategy.h"

namespace mercury {

struct NativeBindingObject;

class SharedIsolateCommand : public DartReadable {
 public:
  SharedIsolateCommand(ExecutingContext* context);

  void AddCommand(IsolateCommand type,
                  std::unique_ptr<SharedNativeString>&& args_01,
                  NativeBindingObject* native_binding_object,
                  void* nativePtr2,
                  bool request_isolate_update = true);

  void* data();
  uint32_t kindFlag();
  int64_t size();
  bool empty();
  void clear();
  void SyncToActive();
  void SyncToReserve();

  void ConfigureSyncCommandBufferSize(size_t size);

 private:
  void swap(std::unique_ptr<IsolateCommandBuffer>& original, std::unique_ptr<IsolateCommandBuffer>& target);
  void appendCommand(std::unique_ptr<IsolateCommandBuffer>& original, std::unique_ptr<IsolateCommandBuffer>& target);
  std::unique_ptr<IsolateCommandBuffer> active_buffer = nullptr;    // The isolate commands which accessible from Dart side
  std::unique_ptr<IsolateCommandBuffer> reserve_buffer_ = nullptr;  // The isolate commands which are ready to swap to active.
  std::unique_ptr<IsolateCommandBuffer> waiting_buffer_ =
      nullptr;  // The isolate commands which recorded from JS operations and sync to reserve_buffer by once.
  std::atomic<bool> is_blocking_writing_;
  ExecutingContext* context_;
  std::unique_ptr<IsolateCommandSyncStrategy> isolate_command_sync_strategy_ = nullptr;
  friend class IsolateCommandBuffer;
  friend class IsolateCommandSyncStrategy;
};

}  // namespace mercury

#endif  // MULTI_THREADING_ISOLATE_COMMAND_H_
